import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../services/host_api_service.dart';
import '../../services/session_controller.dart';
import '../../theme/app_colors.dart';
import '../../widgets/player_face_indicator.dart';
import '../home_page/gamepad_state.dart';
import 'face_playground.dart';

enum _OverlayItem { resume, addPlayers, layout, switchGame, closeGame }

enum _OverlayPanel { menu, players, layouts }

/// In-game overlay (opened with the phones' Home button): MaNet's window over
/// a dimmed snapshot of the game. Driven by any player's controller —
/// up/down (d-pad or stick) moves, A confirms, B goes back — or by mouse.
class GameOverlay extends StatefulWidget {
  final PresetCatalog? presetCatalog;

  const GameOverlay({super.key, this.presetCatalog});

  @override
  State<GameOverlay> createState() => _GameOverlayState();
}

class _GameOverlayState extends State<GameOverlay>
    with SingleTickerProviderStateMixin {
  static const _stickThreshold = 0.6;
  static const _repeatDelay = Duration(milliseconds: 260);

  _OverlayPanel _panel = _OverlayPanel.menu;
  int _index = 0;
  int _layoutIndex = 0;
  _OverlayItem? _confirming;
  String? _activePresetId;
  ConnectionInfo? _connection;
  StreamSubscription<PadButtonEvent>? _buttons;
  late final Ticker _ticker;
  final Map<String, DateTime> _lastStickMove = {};
  final Set<String> _stickArmed = {};
  final FocusNode _focus = FocusNode();

  List<_OverlayItem> get _items => [
    _OverlayItem.resume,
    _OverlayItem.addPlayers,
    _OverlayItem.layout,
    _OverlayItem.switchGame,
    _OverlayItem.closeGame,
  ];

  List<ControllerPreset> get _presets {
    final catalog = widget.presetCatalog;
    if (catalog == null) return const [];
    return [
      ...catalog.builtInPresets,
      ...catalog.gamePresets,
      ...catalog.customPresets,
    ];
  }

  @override
  void initState() {
    super.initState();
    _activePresetId = widget.presetCatalog?.activePresetId;
    _buttons = context.read<GamepadState>().buttonEvents.listen(_onButton);
    _ticker = createTicker(_onTick)..start();
    unawaited(_loadConnection());
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  Future<void> _loadConnection() async {
    try {
      final info = await context
          .read<SessionController>()
          .api
          .fetchConnectionInfo();
      if (mounted) setState(() => _connection = info);
    } catch (_) {}
  }

  @override
  void dispose() {
    _buttons?.cancel();
    _ticker.dispose();
    _focus.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------- input

  /// Only the player who opened the overlay drives it (anyone when the
  /// host opened it or the opener left). Other players kept playing until a
  /// moment ago; their input must not move this menu.
  bool _canDrive(String deviceId) {
    final owner = context.read<SessionController>().snapshot.overlayOwner;
    return owner == null || owner == deviceId;
  }

  void _onTick(Duration _) {
    final gamepads = context.read<GamepadState>();
    final now = DateTime.now();
    for (final player in context.read<SessionController>().snapshot.players) {
      if (!_canDrive(player.deviceId)) continue;
      final y = gamepads.inputListenable(player.deviceId).value.stickY;
      if (y.abs() < _stickThreshold) {
        _lastStickMove.remove(player.deviceId);
        _stickArmed.add(player.deviceId);
        continue;
      }
      // A stick already tilted when the overlay opened (still steering the
      // game) only navigates after it returns to the center once.
      if (!_stickArmed.contains(player.deviceId)) continue;
      final last = _lastStickMove[player.deviceId];
      if (last != null && now.difference(last) < _repeatDelay) continue;
      _lastStickMove[player.deviceId] = now;
      _move(y > 0 ? 1 : -1);
    }
  }

  void _onButton(PadButtonEvent event) {
    if (!event.pressed || !_canDrive(event.deviceId)) return;
    switch (event.button) {
      case 'UP':
        _move(-1);
      case 'DOWN':
        _move(1);
      case 'A':
        _activate();
      case 'B':
        _back();
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowUp) {
      _move(-1);
    } else if (key == LogicalKeyboardKey.arrowDown) {
      _move(1);
    } else if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.space) {
      _activate();
    } else if (key == LogicalKeyboardKey.escape) {
      _back();
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  void _move(int delta) {
    setState(() {
      _confirming = null;
      if (_panel == _OverlayPanel.layouts) {
        if (_presets.isNotEmpty) {
          _layoutIndex = (_layoutIndex + delta).clamp(0, _presets.length - 1);
        }
      } else if (_panel == _OverlayPanel.menu) {
        _index = (_index + delta).clamp(0, _items.length - 1);
      }
    });
  }

  void _activate() {
    switch (_panel) {
      case _OverlayPanel.players:
        setState(() => _panel = _OverlayPanel.menu);
      case _OverlayPanel.layouts:
        _selectLayout(_layoutIndex);
      case _OverlayPanel.menu:
        _runItem(_items[_index]);
    }
  }

  void _back() {
    if (_panel != _OverlayPanel.menu) {
      setState(() => _panel = _OverlayPanel.menu);
    } else if (_confirming != null) {
      setState(() => _confirming = null);
    } else {
      context.read<SessionController>().setOverlay(false);
    }
  }

  void _runItem(_OverlayItem item) {
    final session = context.read<SessionController>();
    final running = session.snapshot.runningGame;
    switch (item) {
      case _OverlayItem.resume:
        session.setOverlay(false);
      case _OverlayItem.addPlayers:
        setState(() => _panel = _OverlayPanel.players);
      case _OverlayItem.layout:
        final active = _presets.indexWhere((p) => p.id == _activePresetId);
        setState(() {
          _layoutIndex = active < 0 ? 0 : active;
          _panel = _OverlayPanel.layouts;
        });
      case _OverlayItem.switchGame || _OverlayItem.closeGame:
        // Destructive: ask for a second press first.
        if (_confirming != item) {
          setState(() => _confirming = item);
          return;
        }
        if (item == _OverlayItem.switchGame) {
          session.switchGame();
        } else if (running?.tracked ?? false) {
          session.stopGame();
        } else {
          session.returnFromGame();
        }
    }
  }

  Future<void> _selectLayout(int index) async {
    if (index >= _presets.length) return;
    final preset = _presets[index];
    setState(() => _activePresetId = preset.id);
    try {
      await context.read<SessionController>().api.selectPreset(preset.id);
    } catch (_) {}
  }

  // ------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final snapshot = session.snapshot;
    final strings = context.l10n.session;

    return Focus(
      focusNode: _focus,
      onKeyEvent: _onKey,
      child: Material(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (snapshot.overlayShotId != null)
              ImageFiltered(
                imageFilter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Image.network(
                  session.api.overlayShotUrl(snapshot.overlayShotId!),
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  errorBuilder: (context, error, stack) =>
                      const SizedBox.shrink(),
                ),
              ),
            Container(color: Colors.black.withValues(alpha: 0.55)),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // The left column is the overlay owner's area.
                    SizedBox(
                      width: 380,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildOwnerHeader(context),
                          const SizedBox(height: 16),
                          Flexible(
                            child: SingleChildScrollView(
                              child: _buildMenu(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      child: _panel == _OverlayPanel.menu
                          ? const SizedBox(width: 0)
                          : Padding(
                              padding: const EdgeInsets.only(left: 24),
                              child: SizedBox(
                                width: 460,
                                child: _buildPanel(context),
                              ),
                            ),
                    ),
                    const SizedBox(width: 24),
                    // Everyone else plays with their faces meanwhile.
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            strings.playgroundTitle,
                            style: _hintStyle.copyWith(fontSize: 18),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            strings.playgroundHint,
                            style: _hintStyle.copyWith(
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Expanded(
                            child: FacePlayground(
                              deviceIds: [
                                for (final player in snapshot.players)
                                  if (player.deviceId != snapshot.overlayOwner)
                                    player.deviceId,
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 40,
              right: 40,
              bottom: 12,
              child: Text(
                strings.overlayHint,
                textAlign: TextAlign.center,
                style: _hintStyle,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPanel(BuildContext context) {
    final session = context.read<SessionController>();
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: switch (_panel) {
        _OverlayPanel.players => _PlayersPanel(
          key: const ValueKey('players'),
          qrUrl: session.api.getQrCodeUrl(_connection?.id),
          link: _connection?.url,
          slots: context.watch<GamepadState>().slots,
        ),
        _OverlayPanel.layouts => _LayoutsPanel(
          key: const ValueKey('layouts'),
          presets: _presets,
          focusedIndex: _layoutIndex,
          activeId: _activePresetId,
          onSelect: (i) {
            setState(() => _layoutIndex = i);
            _selectLayout(i);
          },
        ),
        _OverlayPanel.menu => const SizedBox.shrink(key: ValueKey('none')),
      },
    );
  }

  /// Top of the owner's area: who is driving the overlay.
  Widget _buildOwnerHeader(BuildContext context) {
    final strings = context.l10n.session;
    final session = context.read<SessionController>();
    final gamepads = context.watch<GamepadState>();
    final owner = gamepads.deviceById(session.snapshot.overlayOwner ?? '');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: owner?.color ?? AppColors.highlightColor,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.textPrimary, width: 4),
      ),
      child: Row(
        children: [
          if (owner != null)
            PlayerFaceIndicator(face: owner.face, size: 64)
          else
            const Icon(
              Icons.mouse_rounded,
              size: 48,
              color: AppColors.textPrimary,
            ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  owner?.name ?? strings.overlayHostOwner,
                  style: _titleStyle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  strings.overlayInCharge,
                  style: _bodyStyle.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenu(BuildContext context) {
    final strings = context.l10n.session;
    final session = context.read<SessionController>();
    final running = session.snapshot.runningGame;
    final tracked = running?.tracked ?? false;
    final freeMode = session.snapshot.freeMode;

    String label(_OverlayItem item) => switch (item) {
      _OverlayItem.resume => strings.overlayResume,
      _OverlayItem.addPlayers => strings.overlayAddPlayers,
      _OverlayItem.layout => strings.overlayLayout,
      _OverlayItem.switchGame => strings.overlaySwitchGame,
      _OverlayItem.closeGame => freeMode
          ? strings.leaveFreeMode
          : (tracked ? strings.closeGame : strings.returnToLobby),
    };

    IconData icon(_OverlayItem item) => switch (item) {
      _OverlayItem.resume => Icons.play_arrow_rounded,
      _OverlayItem.addPlayers => Icons.person_add_alt_1_rounded,
      _OverlayItem.layout => Icons.gamepad_rounded,
      _OverlayItem.switchGame => Icons.swap_horiz_rounded,
      _OverlayItem.closeGame =>
        tracked ? Icons.close_rounded : Icons.home_rounded,
    };

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.screenBackground,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.textPrimary, width: 4),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('ma•net', style: _titleStyle.copyWith(fontSize: 18)),
          const SizedBox(height: 4),
          Text(strings.playing(running?.name ?? ''), style: _titleStyle),
          const SizedBox(height: 10),
          const SizedBox(height: 18),
          for (var i = 0; i < _items.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _MenuEntry(
                icon: icon(_items[i]),
                label: _confirming == _items[i]
                    ? strings.overlayConfirm(label(_items[i]))
                    : label(_items[i]),
                focused: _panel == _OverlayPanel.menu && i == _index,
                warning: _confirming == _items[i],
                onHover: () {
                  if (_panel == _OverlayPanel.menu && _index != i)
                    setState(() => _index = i);
                },
                onTap: () {
                  setState(() {
                    _panel = _OverlayPanel.menu;
                    _index = i;
                  });
                  _runItem(_items[i]);
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _MenuEntry extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool focused;
  final bool warning;
  final VoidCallback onHover;
  final VoidCallback onTap;

  const _MenuEntry({
    required this.icon,
    required this.label,
    required this.focused,
    required this.warning,
    required this.onHover,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final background = warning
        ? Colors.red.shade200
        : (focused ? AppColors.highlightColor : AppColors.lightColor);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => onHover(),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedScale(
          scale: focused ? 1.04 : 1,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutBack,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: AppColors.textPrimary,
                width: focused ? 4 : 2.5,
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: AppColors.textPrimary, size: 26),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: _itemStyle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayersPanel extends StatelessWidget {
  final String qrUrl;
  final String? link;
  final List<SlotModel> slots;

  const _PlayersPanel({
    super.key,
    required this.qrUrl,
    this.link,
    required this.slots,
  });

  @override
  Widget build(BuildContext context) {
    final strings = context.l10n.session;
    final nextFree = slots.indexWhere((slot) => slot.device == null);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.screenBackground,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.textPrimary, width: 4),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(strings.overlayPlayersTitle, style: _titleStyle),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                for (var i = 0; i < slots.length; i++)
                  _SeatSquare(
                    index: i,
                    device: slots[i].device,
                    isNext: i == nextFree,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              nextFree >= 0
                  ? strings.overlayNextSeat(nextFree + 1)
                  : strings.overlayNoSeat,
              style: _bodyStyle.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            Container(
              width: 200,
              height: 200,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.textPrimary, width: 3),
              ),
              child: Image.network(qrUrl, fit: BoxFit.contain),
            ),
            if (link != null) ...[
              const SizedBox(height: 10),
              SelectableText(link!, style: _titleStyle.copyWith(fontSize: 16)),
            ],
            const SizedBox(height: 8),
            Text(
              strings.overlaySeatsHint,
              style: _bodyStyle,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// One player position (P1, P2...) and who sits in it.
class _SeatSquare extends StatelessWidget {
  final int index;
  final DeviceModel? device;
  final bool isNext;

  const _SeatSquare({
    required this.index,
    required this.device,
    required this.isNext,
  });

  @override
  Widget build(BuildContext context) {
    final strings = context.l10n.session;
    return Container(
      width: 92,
      height: 108,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isNext ? AppColors.highlightColor : AppColors.lightColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.textPrimary, width: isNext ? 4 : 3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('p${index + 1}', style: _itemStyle),
          const Spacer(),
          Center(
            child: device != null
                ? PlayerFaceIndicator(face: device!.face, size: 36)
                : Icon(
                    isNext ? Icons.add_rounded : Icons.person_outline_rounded,
                    size: 32,
                    color: AppColors.textPrimary.withValues(
                      alpha: isNext ? 1 : 0.4,
                    ),
                  ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              device?.name ?? strings.freeSeat,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _bodyStyle.copyWith(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _LayoutsPanel extends StatefulWidget {
  final List<ControllerPreset> presets;
  final int focusedIndex;
  final String? activeId;
  final ValueChanged<int> onSelect;

  const _LayoutsPanel({
    super.key,
    required this.presets,
    required this.focusedIndex,
    required this.activeId,
    required this.onSelect,
  });

  @override
  State<_LayoutsPanel> createState() => _LayoutsPanelState();
}

class _LayoutsPanelState extends State<_LayoutsPanel> {
  // All entries are built (the list is short) so the focused one can always
  // be scrolled into view as the controller moves through it.
  final List<GlobalKey> _keys = [];

  @override
  void initState() {
    super.initState();
    _revealFocused();
  }

  @override
  void didUpdateWidget(_LayoutsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusedIndex != widget.focusedIndex) _revealFocused();
  }

  void _revealFocused() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.focusedIndex >= _keys.length) return;
      final target = _keys[widget.focusedIndex].currentContext;
      if (target != null) {
        Scrollable.ensureVisible(
          target,
          alignment: 0.5,
          duration: const Duration(milliseconds: 180),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.l10n.session;
    while (_keys.length < widget.presets.length) {
      _keys.add(GlobalKey());
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.screenBackground,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppColors.textPrimary, width: 4),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(strings.overlayLayoutTitle, style: _titleStyle),
            const SizedBox(height: 12),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < widget.presets.length; i++)
                      Padding(
                        key: _keys[i],
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _MenuEntry(
                          icon: widget.presets[i].id == widget.activeId
                              ? Icons.check_circle_rounded
                              : Icons.gamepad_outlined,
                          label: widget.presets[i].name,
                          focused: i == widget.focusedIndex,
                          warning: false,
                          onHover: () {},
                          onTap: () => widget.onSelect(i),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const TextStyle _titleStyle = TextStyle(
  fontFamily: 'momo',
  fontWeight: FontWeight.bold,
  fontSize: 24,
  color: AppColors.textPrimary,
);

const TextStyle _itemStyle = TextStyle(
  fontFamily: 'momo',
  fontWeight: FontWeight.bold,
  fontSize: 18,
  color: AppColors.textPrimary,
);

const TextStyle _bodyStyle = TextStyle(
  fontFamily: 'momo',
  fontSize: 14,
  color: AppColors.textPrimary,
);

const TextStyle _hintStyle = TextStyle(
  fontFamily: 'momo',
  fontWeight: FontWeight.bold,
  fontSize: 14,
  color: Colors.white,
);
