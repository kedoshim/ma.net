import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../constants.dart';
import '../../utils/platform_detector.dart';

import '../../l10n/app_localizations.dart';
import '../../l10n/strings.dart';
import '../../models/player_face.dart';
import '../../services/haptics_manager.dart';
import '../../theme/app_colors.dart';
import '../../services/preferences_service.dart';
import '../../widgets/embedded_video/embedded_video.dart';
import '../../widgets/joystick.dart';
import '../../widgets/player_face_indicator.dart';
import 'controller_default_view.dart'
    show ControllerButtonStateCallback, ControllerDpad, showEditNameDialog;
import 'controller_screen_widgets.dart' show MovementModeToggleButton;

/// Where the menu controls are being used; changes the buttons shown.
enum MenuContext { lobby, library, tournament, overlay, playground }

/// Controls shown while the phone drives MaNet's menus instead of a game:
/// the stick on the left, the actions of the current screen on the right.
/// Buttons keep the gamepad look of the system: white rounded squares with
/// a black border (never colored, never round). Actions are sent as pad
/// buttons so a real controller works the same way: A select/ready, B
/// cancel/not ready, X info, Y emote.
class ControllerMenuView extends StatefulWidget {
  final MenuContext menuContext;
  final PlayerFaceData playerFace;
  final ValueChanged<Offset> onStickChanged;
  final VoidCallback onStickRelease;
  final ControllerButtonStateCallback onButtonStateChanged;
  final VoidCallback onOpenAvatar;
  final VoidCallback onOpenSeats;
  final String? ownerName;
  /// Lobby: this player said they are ready.
  final bool ready;
  /// Game selection: this player's vote is stuck on a game.
  final bool hasVote;
  /// Lobby: everyone is ready and the game selection opens at this time.
  final DateTime? lobbyCountdownEndsAt;
  /// Game selection: someone asked to go back to the lobby.
  final Map<String, dynamic>? lobbyRequest;
  final VoidCallback onBackToLobby;
  /// Game selection: the game whose details this phone shows (over the
  /// stick), with its cover served from [serverBase].
  final Map<String, dynamic>? details;
  final Uri? serverBase;
  final VoidCallback onCloseDetails;
  /// Lobby: the player's name, editable right there.
  final String? playerName;
  final ValueChanged<String> onNameChanged;
  final Future<String> Function() onRequestRandomName;
  final MovementMode? movementMode;
  final ValueChanged<MovementMode>? onMovementModeChanged;

  static void _defaultVoidCallback() {}
  static void _defaultStringCallback(String _) {}
  static Future<String> _defaultRandomNameCallback() async => '';

  const ControllerMenuView({
    super.key,
    required this.menuContext,
    required this.playerFace,
    required this.onStickChanged,
    required this.onStickRelease,
    required this.onButtonStateChanged,
    required this.onOpenAvatar,
    required this.onOpenSeats,
    this.onBackToLobby = _defaultVoidCallback,
    this.onCloseDetails = _defaultVoidCallback,
    this.onNameChanged = _defaultStringCallback,
    this.onRequestRandomName = _defaultRandomNameCallback,
    this.playerName,
    this.ownerName,
    this.ready = false,
    this.hasVote = false,
    this.lobbyCountdownEndsAt,
    this.lobbyRequest,
    this.details,
    this.serverBase,
    this.movementMode,
    this.onMovementModeChanged,
  });

  @override
  State<ControllerMenuView> createState() => _ControllerMenuViewState();
}

class _ControllerMenuViewState extends State<ControllerMenuView> {
  late MovementMode _movementMode;

  MovementMode get _defaultMode => widget.menuContext == MenuContext.overlay
      ? MovementMode.dpad
      : MovementMode.floatingJoystick;

  @override
  void initState() {
    super.initState();
    _movementMode = widget.movementMode ?? _defaultMode;
  }

  @override
  void didUpdateWidget(ControllerMenuView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.movementMode != null) {
      if (widget.movementMode != oldWidget.movementMode) {
        _movementMode = widget.movementMode!;
      }
    } else if (widget.menuContext != oldWidget.menuContext) {
      _movementMode = _defaultMode;
    }
  }

  void _press(String button) => widget.onButtonStateChanged(button, 'down');
  void _release(String button) => widget.onButtonStateChanged(button, 'up');

  void _toggleMovementMode() {
    widget.onStickRelease();
    for (final dir in ['UP', 'DOWN', 'LEFT', 'RIGHT']) {
      widget.onButtonStateChanged(dir, 'up');
    }
    final nextIndex = (_movementMode.index + 1) % MovementMode.values.length;
    final nextMode = MovementMode.values[nextIndex];
    setState(() {
      _movementMode = nextMode;
    });
    widget.onMovementModeChanged?.call(nextMode);
  }

  PadButton _pad(String button, String label, IconData? icon, {bool large = false}) =>
      PadButton(
        label: label,
        icon: icon,
        large: large,
        onDown: () => _press(button),
        onUp: () => _release(button),
        tapHaptic: false,
      );

  Widget _buildMovementControl({required double joystickSize}) {
    final Widget movementWidget = switch (_movementMode) {
      MovementMode.dpad => Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: ControllerDpad(
              centered: true,
              onButtonStateChanged: widget.onButtonStateChanged,
            ),
          ),
        ),
      MovementMode.floatingJoystick => AdaptiveJoystick(
          onChanged: (x, y) => widget.onStickChanged(Offset(x, y)),
          onReleased: widget.onStickRelease,
        ),
      MovementMode.fixedJoystick => Center(
          child: Joystick(
            size: joystickSize,
            onChanged: (x, y) => widget.onStickChanged(Offset(x, y)),
            onReleased: widget.onStickRelease,
          ),
        ),
    };

    return Stack(
      children: [
        Positioned.fill(child: movementWidget),
        Positioned(
          top: 0,
          left: 0,
          child: MovementModeToggleButton(
            mode: _movementMode,
            onToggle: _toggleMovementMode,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.l10n.menu;
    if (widget.menuContext == MenuContext.lobby || widget.menuContext == MenuContext.library) {
      return _buildLobby(context, strings);
    }
    final reading = widget.menuContext == MenuContext.library && widget.details != null;
    final left = reading
        ? GameInfoPanel(game: widget.details!, serverBase: widget.serverBase)
        : _buildMovementControl(joystickSize: 220);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              flex: reading ? 7 : 5,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: KeyedSubtree(key: ValueKey(reading), child: left),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 6,
              child: _buildActions(context, strings, reading),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActions(BuildContext context, MenuStrings strings, bool reading) {
    final faceButton = SmallPadButton(
      onTap: widget.onOpenAvatar,
      label: strings.face,
      leading: PlayerFaceIndicator(
        face: widget.playerFace,
        size: 26,
        roundedSquare: true,
        borderColor: AppColors.textPrimary,
      ),
    );

    switch (widget.menuContext) {
      case MenuContext.lobby:
        return _Column(
          hint: widget.lobbyCountdownEndsAt != null
              ? _CountdownHint(endsAt: widget.lobbyCountdownEndsAt!)
              : _Hint(widget.ready ? strings.waitingOthers : strings.lobbyHint),
          children: [
            _pair(
              _pad('A', strings.ready, Icons.check_rounded, large: true),
              widget.ready ? _pad('B', strings.notReady, Icons.close_rounded) : null,
            ),
            _pair(
              SmallPadButton(
                onTap: widget.onOpenSeats,
                label: strings.seat,
                leading: const Icon(Icons.swap_horiz_rounded, size: 24, color: AppColors.textPrimary),
              ),
              faceButton,
            ),
            _EmoteButton(onDown: () => _press('Y'), onUp: () => _release('Y')),
          ],
        );
      case MenuContext.library:
        return _Column(
          top: _LobbyRequestButton(request: widget.lobbyRequest, onTap: widget.onBackToLobby),
          hint: reading ? null : _Hint(strings.libraryHint),
          children: reading
              ? [
                  _pair(
                    _pad('A', strings.select, Icons.check_rounded, large: true),
                    PadButton(
                      label: strings.cancel,
                      icon: Icons.close_rounded,
                      onDown: widget.onCloseDetails,
                      onUp: () {},
                    ),
                  ),
                ]
              : [
                  _pair(
                    _pad('A', strings.select, Icons.check_rounded, large: true),
                    widget.hasVote ? _pad('B', strings.cancelSelection, Icons.close_rounded) : null,
                  ),
                  _pair(
                    _pad('X', strings.info, Icons.info_outline_rounded),
                    faceButton,
                  ),
                  _EmoteButton(onDown: () => _press('Y'), onUp: () => _release('Y')),
                ],
        );
      case MenuContext.tournament:
        return _Column(
          hint: _Hint(strings.tournamentHint),
          children: [
            faceButton,
            _EmoteButton(onDown: () => _press('Y'), onUp: () => _release('Y')),
          ],
        );
      case MenuContext.overlay || MenuContext.playground:
        final playground = widget.menuContext == MenuContext.playground;
        return _Column(
          hint: _Hint(
            playground
                ? strings.playgroundHint(widget.ownerName ?? strings.someone)
                : strings.overlayHint,
          ),
          children: [
            _pair(
              _pad('B', strings.back, Icons.undo_rounded),
              _pad(
                'A',
                playground ? strings.jump : strings.select,
                playground ? Icons.keyboard_double_arrow_up_rounded : Icons.check_rounded,
                large: true,
              ),
            ),
            _pair(
              faceButton,
              SmallPadButton(
                onTap: widget.onOpenSeats,
                label: strings.seat,
                leading: const Icon(Icons.swap_horiz_rounded, size: 24, color: AppColors.textPrimary),
              ),
            ),
          ],
        );
    }
  }

  /// QR code screen and game selection share one layout: stick on the left,
  /// who you are in the middle (face, name and seat / back to lobby) and two
  /// big buttons on the right. In the lobby: Ready (then Not ready) and the
  /// happy emote button. In the selection: Select (then Cancel selection)
  /// and Info. While reading a game's details they take the stick's place.
  Widget _buildLobby(BuildContext context, MenuStrings strings) {
    final library = widget.menuContext == MenuContext.library;
    final reading = library && widget.details != null;
    final name = (widget.playerName == null || widget.playerName!.isEmpty)
        ? context.l10n.editName.noName
        : widget.playerName!;

    PadButton big(String button, String label, IconData? icon) => PadButton(
      key: ValueKey('big_$button$label'),
      label: label,
      icon: icon,
      large: true,
      width: double.infinity,
      height: double.infinity,
      onDown: () => _press(button),
      onUp: () => _release(button),
      tapHaptic: false,
    );

    final Widget top;
    final Widget bottom;
    if (!library) {
      top = widget.ready
          ? big('B', strings.notReady, Icons.close_rounded)
          : big('A', strings.ready, Icons.check_rounded);
      bottom = big('Y', '', Icons.sentiment_very_satisfied_rounded);
    } else if (reading) {
      top = big('A', strings.select, Icons.check_rounded);
      bottom = PadButton(
        key: const ValueKey('close_details'),
        label: strings.cancel,
        icon: Icons.close_rounded,
        large: true,
        width: double.infinity,
        height: double.infinity,
        onDown: widget.onCloseDetails,
        onUp: () {},
      );
    } else {
      top = widget.hasVote
          ? big('B', strings.cancelSelection, Icons.close_rounded)
          : big('A', strings.select, Icons.check_rounded);
      bottom = big('X', strings.info, Icons.info_outline_rounded);
    }

    final Widget hint = !library && widget.lobbyCountdownEndsAt != null
        ? _CountdownHint(endsAt: widget.lobbyCountdownEndsAt!)
        : _Hint(
            library
                ? strings.libraryHint
                : (widget.ready ? strings.waitingOthers : strings.lobbyHint),
          );

    final middle = FittedBox(
      fit: BoxFit.scaleDown,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          hint,
          const SizedBox(height: 14),
          _OptionButton(
            onTap: widget.onOpenAvatar,
            label: strings.face,
            leading: PlayerFaceIndicator(
              face: widget.playerFace,
              size: 34,
              roundedSquare: true,
              borderColor: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          _OptionButton(
            onTap: () => showEditNameDialog(
              context,
              name,
              widget.onNameChanged,
              widget.onRequestRandomName,
              widget.playerFace,
            ),
            label: name,
            leading: const Icon(Icons.edit_rounded, size: 30, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 10),
          if (library)
            _LobbyRequestOption(request: widget.lobbyRequest, onTap: widget.onBackToLobby)
          else
            _OptionButton(
              onTap: widget.onOpenSeats,
              label: strings.seat,
              leading: const Icon(Icons.swap_horiz_rounded, size: 32, color: AppColors.textPrimary),
            ),
        ],
      ),
    );

    final layout = SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (reading)
              Expanded(
                flex: 8,
                child: GameInfoPanel(game: widget.details!, serverBase: widget.serverBase),
              )
            else ...[
              Expanded(
                flex: 4,
                child: _buildMovementControl(joystickSize: 200),
              ),
              Expanded(flex: 4, child: middle),
            ],
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: Column(
                children: [
                  if (reading) ...[
                    _LobbyRequestButton(request: widget.lobbyRequest, onTap: widget.onBackToLobby),
                    const SizedBox(height: 8),
                  ],
                  Expanded(flex: 3, child: top),
                  const SizedBox(height: 12),
                  Expanded(flex: 2, child: bottom),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    // In the phone's browser, the QR code screen invites to the app.
    if (library || !kIsWeb || !getIsAndroidBrowser()) return layout;
    return Stack(
      children: [
        Positioned.fill(child: layout),
        const Positioned(
          top: 6,
          left: 0,
          right: 0,
          child: Center(child: _AppTag()),
        ),
      ],
    );
  }

  static Widget _pair(Widget first, Widget? second) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      first,
      // The second button slides in next to the first (e.g. Cancel after
      // selecting).
      AnimatedSize(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutBack,
        child: second == null
            ? const SizedBox.shrink()
            : Padding(padding: const EdgeInsets.only(left: 12), child: second),
      ),
    ],
  );
}

class _Column extends StatelessWidget {
  final Widget? top;
  final Widget? hint;
  final List<Widget> children;

  const _Column({required this.children, this.top, this.hint});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (top != null) ...[top!, const SizedBox(height: 8)],
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (hint != null) ...[hint!, const SizedBox(height: 12)],
                for (final (index, child) in children.indexed) ...[
                  if (index > 0) const SizedBox(height: 12),
                  child,
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Hint extends StatelessWidget {
  final String text;

  const _Hint(this.text);

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 300),
      child: Text(text, textAlign: TextAlign.center, style: _bold),
    );
  }
}

/// "Starting in 3…" while the lobby counts down.
class _CountdownHint extends StatefulWidget {
  final DateTime endsAt;

  const _CountdownHint({required this.endsAt});

  @override
  State<_CountdownHint> createState() => _CountdownHintState();
}

class _CountdownHintState extends State<_CountdownHint> {
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final left = (widget.endsAt.difference(DateTime.now()).inMilliseconds / 1000).ceil().clamp(0, 99);
    return _Hint(context.l10n.menu.startingIn(left));
  }
}

/// Small button centered at the top: asks the others to go back to the
/// lobby, then shows how many agreed.
class _LobbyRequestButton extends StatelessWidget {
  final Map<String, dynamic>? request;
  final VoidCallback onTap;

  const _LobbyRequestButton({required this.request, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final strings = context.l10n.menu;
    final mine = request != null && (request!['mine'] == true || request!['myAnswer'] == true);
    final label = mine
        ? strings.lobbyWaiting(request!['yes'] as int? ?? 1, request!['needed'] as int? ?? 1)
        : strings.backToLobby;
    return SmallPadButton(
      onTap: mine ? () {} : onTap,
      label: label,
      leading: Icon(
        mine ? Icons.hourglass_top_rounded : Icons.home_rounded,
        size: 20,
        color: AppColors.textPrimary,
      ),
    );
  }
}

/// "It's better in the app" tag: opens the Android app download.
class _AppTag extends StatelessWidget {
  const _AppTag();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticsManager.instance.softTap();
        launchUrl(Uri.base.resolve(kAndroidAppUrl), webOnlyWindowName: '_blank');
      },
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 5, 14, 5),
        decoration: BoxDecoration(
          color: AppColors.lightColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.textPrimary, width: 2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.android_rounded, size: 22, color: AppColors.textPrimary),
            const SizedBox(width: 6),
            Text(context.l10n.menu.betterInApp, style: _bold.copyWith(fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

/// Wide "back to the lobby" option; once asked, shows how many agreed.
class _LobbyRequestOption extends StatelessWidget {
  final Map<String, dynamic>? request;
  final VoidCallback onTap;

  const _LobbyRequestOption({required this.request, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final strings = context.l10n.menu;
    final mine = request != null && (request!['mine'] == true || request!['myAnswer'] == true);
    return _OptionButton(
      onTap: mine ? () {} : onTap,
      label: mine
          ? strings.lobbyWaiting(request!['yes'] as int? ?? 1, request!['needed'] as int? ?? 1)
          : strings.backToLobby,
      leading: Icon(
        mine ? Icons.hourglass_top_rounded : Icons.home_rounded,
        size: 30,
        color: AppColors.textPrimary,
      ),
    );
  }
}

/// Rounded-square button with a label, like the gameplay buttons: white
/// with a black border.
class PadButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final bool large;
  final VoidCallback onDown;
  final VoidCallback onUp;
  final double? width;
  final double? height;

  /// False when [onDown] presses a gamepad button, which already plays that
  /// button's own haptic signature.
  final bool tapHaptic;

  const PadButton({
    super.key,
    required this.label,
    required this.onDown,
    required this.onUp,
    this.icon,
    this.large = false,
    this.width,
    this.height,
    this.tapHaptic = true,
  });

  @override
  State<PadButton> createState() => _PadButtonState();
}

class _PadButtonState extends State<PadButton> {
  bool _pressed = false;

  @override
  void dispose() {
    // Swapped out while held (e.g. Ready turning into Not ready): release.
    if (_pressed) widget.onUp();
    super.dispose();
  }

  void _setPressed(bool pressed) {
    if (_pressed == pressed) return;
    setState(() => _pressed = pressed);
    if (pressed) {
      if (widget.tapHaptic) HapticsManager.instance.softTap();
      widget.onDown();
    } else {
      widget.onUp();
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = widget.width ?? (widget.large ? 128.0 : 108.0);
    final height = widget.height ?? (widget.large ? 104.0 : 88.0);
    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1,
        duration: const Duration(milliseconds: 90),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 90),
          width: width,
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: _pressed ? AppColors.highlightColor : AppColors.lightColor,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.textPrimary, width: AppColors.borderThickness),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null)
                Icon(widget.icon, size: widget.large ? 48 : 30, color: AppColors.textPrimary),
              if (widget.label.isNotEmpty)
                Text(
                  widget.label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: TextStyle(
                    fontFamily: 'momo',
                    fontWeight: FontWeight.bold,
                    fontSize: widget.large ? 18 : 13,
                    height: 1.05,
                    color: AppColors.textPrimary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The blank button: no label, it only makes your face dance on the TV.
class _EmoteButton extends StatelessWidget {
  final VoidCallback onDown;
  final VoidCallback onUp;

  const _EmoteButton({required this.onDown, required this.onUp});

  @override
  Widget build(BuildContext context) {
    return PadButton(
      label: '',
      width: 248,
      height: 52,
      onDown: onDown,
      onUp: onUp,
      tapHaptic: false,
    );
  }
}

/// A wide option in the middle of the lobby screen (face, name, seat).
class _OptionButton extends StatelessWidget {
  final VoidCallback onTap;
  final String label;
  final Widget leading;

  const _OptionButton({required this.onTap, required this.label, required this.leading});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticsManager.instance.softTap();
        onTap();
      },
      child: Container(
        width: 230,
        height: 62,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: AppColors.lightColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.textPrimary, width: AppColors.borderThickness),
        ),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _bold.copyWith(fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SmallPadButton extends StatelessWidget {
  final VoidCallback onTap;
  final String label;
  final Widget leading;

  const SmallPadButton({super.key, required this.onTap, required this.label, required this.leading});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticsManager.instance.softTap();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.lightColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.textPrimary, width: 2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            leading,
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'momo',
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// YouTube video id from the usual link shapes, for the thumbnail.
String? youTubeId(String url) {
  final uri = Uri.tryParse(url.trim());
  if (uri == null) return null;
  final host = uri.host.replaceFirst('www.', '').replaceFirst('m.', '');
  if (host == 'youtu.be' && uri.pathSegments.isNotEmpty) {
    return uri.pathSegments.first;
  }
  if (host == 'youtube.com' || host == 'music.youtube.com') {
    if (uri.queryParameters['v'] case final v? when v.isNotEmpty) return v;
    final segments = uri.pathSegments;
    if (segments.length >= 2 &&
        (segments.first == 'embed' || segments.first == 'shorts')) {
      return segments[1];
    }
  }
  return null;
}

/// A game's details on the phone (over the stick while reading): cover on
/// the left, and a scrollable column on the right with name, trailer video,
/// screenshots and text description.
class GameInfoPanel extends StatelessWidget {
  final Map<String, dynamic> game;
  final Uri? serverBase;

  const GameInfoPanel({super.key, required this.game, this.serverBase});

  @override
  Widget build(BuildContext context) {
    final strings = context.l10n.menu;
    final cover = game['coverUrl'] as String?;
    final coverUri = cover == null || serverBase == null ? null : serverBase!.resolve(cover);
    final tags = (game['tags'] as List<dynamic>? ?? const []).map((t) => '$t').toList();
    final shots = (game['screenshots'] as List<dynamic>? ?? const []).map((s) => '$s').toList();
    final description = (game['description'] as String? ?? '').trim();
    final trailerUrl = (game['trailerUrl'] as String? ?? '').trim();
    final videoId = youTubeId(trailerUrl);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.lightColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.textPrimary, width: AppColors.borderThickness),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Coluna Esquerda: Imagem grandona do jogo (aspect ratio 2:3)
            AspectRatio(
              aspectRatio: 2 / 3,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: GestureDetector(
                  onTap: coverUri != null
                      ? () => _openShots(context, [coverUri.toString(), ...shots], 0)
                      : null,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.screenBackground,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.textPrimary,
                        width: 2.5,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: coverUri != null
                        ? Image.network(
                            coverUri.toString(),
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => _buildCoverPlaceholder(),
                          )
                        : _buildCoverPlaceholder(),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            // Coluna Direita: Scrollável com Nome -> Vídeo -> Imagens -> Texto
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Nome
                    Text(
                      game['name'] as String? ?? '',
                      style: _bold.copyWith(fontSize: 22),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.group_rounded,
                          size: 16,
                          color: AppColors.textPrimary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          strings.playersRange(
                            game['minPlayers'] as int? ?? 1,
                            game['maxPlayers'] as int? ?? 1,
                          ),
                          style: _faint.copyWith(fontSize: 13),
                        ),
                      ],
                    ),
                    if (tags.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final tag in tags)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.backgroundColor.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AppColors.textPrimary,
                                  width: 1.5,
                                ),
                              ),
                              child: Text(tag, style: _bold.copyWith(fontSize: 11)),
                            ),
                        ],
                      ),
                    ],

                    // 2. Vídeo grandão
                    if (trailerUrl.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      _TrailerCard(trailerUrl: trailerUrl, videoId: videoId),
                    ],

                    // 3. Imagens
                    if (shots.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      SizedBox(
                        height: 130,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: shots.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 8),
                          itemBuilder: (context, index) => GestureDetector(
                            onTap: () => _openShots(context, shots, index),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppColors.textPrimary,
                                    width: 2,
                                  ),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: Image.network(
                                  shots[index],
                                  height: 130,
                                  width: 220,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => const SizedBox(
                                    width: 220,
                                    height: 130,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],

                    // 4. Depois texto
                    const SizedBox(height: 14),
                    Text(
                      description.isEmpty ? strings.noDescription : description,
                      style: _body,
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

  Widget _buildCoverPlaceholder() {
    return Center(
      child: Icon(
        Icons.sports_esports_rounded,
        size: 48,
        color: AppColors.textPrimary.withValues(alpha: 0.4),
      ),
    );
  }



  void _openShots(BuildContext context, List<String> shots, int index) {
    if (shots.isEmpty) return;
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      useRootNavigator: false,
      builder: (dialogContext) => Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(dialogContext).pop(),
              child: PageView(
                controller: PageController(initialPage: index),
                children: [
                  for (final shot in shots)
                    InteractiveViewer(
                      child: Center(
                        child: Image.network(
                          shot,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => const Center(
                            child: Icon(
                              Icons.broken_image_rounded,
                              size: 48,
                              color: Colors.white54,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: GestureDetector(
                onTap: () {
                  HapticsManager.instance.softTap();
                  Navigator.of(dialogContext).pop();
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.lightColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.textPrimary,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    size: 20,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrailerCard extends StatefulWidget {
  final String trailerUrl;
  final String? videoId;

  const _TrailerCard({
    required this.trailerUrl,
    this.videoId,
  });

  @override
  State<_TrailerCard> createState() => _TrailerCardState();
}

class _TrailerCardState extends State<_TrailerCard> {
  bool _isPlaying = false;

  @override
  void didUpdateWidget(covariant _TrailerCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.videoId != oldWidget.videoId || widget.trailerUrl != oldWidget.trailerUrl) {
      _isPlaying = false;
    }
  }

  void _play() async {
    HapticsManager.instance.softTap();
    if (isEmbeddedVideoSupported && widget.videoId != null && widget.videoId!.isNotEmpty) {
      setState(() {
        _isPlaying = true;
      });
    } else {
      final uri = Uri.tryParse(widget.trailerUrl);
      if (uri != null) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  void _stop() {
    HapticsManager.instance.softTap();
    setState(() {
      _isPlaying = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.textPrimary,
            width: 2.5,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_isPlaying && widget.videoId != null) ...[
              getEmbeddedVideo(widget.videoId!),
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: _stop,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.lightColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.textPrimary,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ] else ...[
              GestureDetector(
                onTap: _play,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (widget.videoId != null)
                      Image.network(
                        'https://img.youtube.com/vi/${widget.videoId}/hqdefault.jpg',
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
                      ),
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.black54, Colors.black26],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                      ),
                    ),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.lightColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.textPrimary,
                            width: 2.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.play_arrow_rounded,
                              size: 24,
                              color: AppColors.textPrimary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Trailer',
                              style: _bold.copyWith(fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}


/// Someone asked to leave the game selection: agree or not.
class LobbyRequestDialog extends StatelessWidget {
  final Map<String, dynamic> request;

  const LobbyRequestDialog({super.key, required this.request});

  @override
  Widget build(BuildContext context) {
    final strings = context.l10n.menu;
    final from = (request['from'] as Map<String, dynamic>?) ?? const {};
    return Dialog(
      backgroundColor: AppColors.lightColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: AppColors.textPrimary, width: AppColors.borderThickness),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PlayerFaceIndicator(
              face: PlayerFaceData.fromJson(from),
              size: 56,
              roundedSquare: true,
              borderColor: AppColors.textPrimary,
            ),
            const SizedBox(height: 12),
            Text(
              strings.lobbyRequestOffer(from['name'] as String? ?? ''),
              textAlign: TextAlign.center,
              style: _bold.copyWith(fontSize: 17),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _SheetButton(label: strings.stayHere, onTap: () => Navigator.of(context).pop(false)),
                const SizedBox(width: 12),
                _SheetButton(label: strings.goBack, onTap: () => Navigator.of(context).pop(true)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Who sits where, with this phone's options: trade places with someone,
/// go to the bench or take a free seat. [onAction] gets the message to send.
class SeatsSheet extends StatelessWidget {
  final Map<String, dynamic> seats;
  final String? me;
  final ValueChanged<Map<String, dynamic>> onAction;

  const SeatsSheet({super.key, required this.seats, required this.me, required this.onAction});

  @override
  Widget build(BuildContext context) {
    final strings = context.l10n.menu;
    final slots = (seats['slots'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();
    final bench = (seats['bench'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();
    final mySlot = slots.where((s) => (s['player'] as Map?)?['deviceId'] == me).firstOrNull;
    final hasFreeSeat = slots.any((s) => s['player'] == null);

    void act(Map<String, dynamic> message) {
      HapticsManager.instance.softTap();
      onAction(message);
      Navigator.of(context).pop();
    }

    Widget seatRow(String label, Map<String, dynamic>? player) {
      final isMe = player?['deviceId'] == me;
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isMe ? AppColors.highlightColor.withValues(alpha: 0.35) : AppColors.lightColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.textPrimary, width: 2),
          ),
          child: Row(
            children: [
              SizedBox(width: 34, child: Text(label, style: _bold)),
              if (player != null) ...[
                PlayerFaceIndicator(
                  face: PlayerFaceData.fromJson(player),
                  size: 30,
                  roundedSquare: true,
                  borderColor: AppColors.textPrimary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isMe ? strings.you(player['name'] as String? ?? '') : (player['name'] as String? ?? ''),
                    style: _bold,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (!isMe)
                  _SheetButton(
                    label: strings.swap,
                    onTap: () => act({'type': 'swap_request', 'target': player['deviceId']}),
                  ),
              ] else
                Expanded(child: Text(strings.freeSeat, style: _faint)),
            ],
          ),
        ),
      );
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(strings.seatsTitle, style: _bold.copyWith(fontSize: 20)),
            const SizedBox(height: 4),
            Text(strings.seatsHint, style: _faint),
            const SizedBox(height: 12),
            for (final slot in slots) seatRow('P${(slot['slot'] as int) + 1}', slot['player'] as Map<String, dynamic>?),
            if (bench.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(strings.bench, style: _bold),
              const SizedBox(height: 6),
              for (final player in bench) seatRow('—', player),
            ],
            const SizedBox(height: 8),
            if (mySlot != null)
              _SheetButton(label: strings.goToBench, wide: true, onTap: () => act({'type': 'seat_bench'}))
            else if (hasFreeSeat)
              _SheetButton(label: strings.joinGame, wide: true, onTap: () => act({'type': 'seat_join'})),
          ],
        ),
      ),
    );
  }
}

class _SheetButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool wide;

  const _SheetButton({required this.label, required this.onTap, this.wide = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        alignment: wide ? Alignment.center : null,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.highlightColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.textPrimary, width: 2),
        ),
        child: Text(label, style: _bold),
      ),
    );
  }
}

/// Someone asked this phone to trade places.
class SwapOfferDialog extends StatelessWidget {
  final Map<String, dynamic> from;
  final int? fromSlot;
  final int? toSlot;

  const SwapOfferDialog({super.key, required this.from, this.fromSlot, this.toSlot});

  @override
  Widget build(BuildContext context) {
    final strings = context.l10n.menu;
    String seat(int? slot) => slot == null ? strings.bench : 'P${slot + 1}';
    return Dialog(
      backgroundColor: AppColors.lightColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: AppColors.textPrimary, width: AppColors.borderThickness),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PlayerFaceIndicator(
              face: PlayerFaceData.fromJson(from),
              size: 56,
              roundedSquare: true,
              borderColor: AppColors.textPrimary,
            ),
            const SizedBox(height: 12),
            Text(
              strings.swapOffer(from['name'] as String? ?? '', seat(fromSlot), seat(toSlot)),
              textAlign: TextAlign.center,
              style: _bold.copyWith(fontSize: 17),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _SheetButton(label: strings.decline, onTap: () => Navigator.of(context).pop(false)),
                const SizedBox(width: 12),
                _SheetButton(label: strings.accept, onTap: () => Navigator.of(context).pop(true)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

const TextStyle _bold = TextStyle(
  fontFamily: 'momo',
  fontWeight: FontWeight.bold,
  fontSize: 15,
  color: AppColors.textPrimary,
);

const TextStyle _faint = TextStyle(fontFamily: 'momo', fontSize: 13, color: Color(0x99222222));

const TextStyle _body = TextStyle(fontFamily: 'momo', fontSize: 14, height: 1.3, color: AppColors.textPrimary);
