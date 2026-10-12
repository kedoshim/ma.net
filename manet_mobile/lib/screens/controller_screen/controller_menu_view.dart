import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/player_face.dart';
import '../../services/haptics_manager.dart';
import '../../theme/app_colors.dart';
import '../../widgets/joystick.dart';
import '../../widgets/player_face_indicator.dart';
import 'controller_default_view.dart' show ControllerButtonStateCallback;

/// Where the menu controls are being used; changes the hint shown.
enum MenuContext { lobby, library, tournament, overlay, playground }

/// Controls shown while the phone drives MaNet's menus instead of a game:
/// a stick plus game-independent actions — Select, Back, Avatar and Seat.
/// Select/Back are sent as A/B, which every MaNet screen understands (in the
/// overlay playground, Select makes the face jump). Keeps the gamepad look:
/// rounded squares, never round buttons.
class ControllerMenuView extends StatelessWidget {
  final MenuContext menuContext;
  final PlayerFaceData playerFace;
  final ValueChanged<Offset> onStickChanged;
  final VoidCallback onStickRelease;
  final ControllerButtonStateCallback onButtonStateChanged;
  final VoidCallback onOpenAvatar;
  final VoidCallback onOpenSeats;
  final String? ownerName;

  const ControllerMenuView({
    super.key,
    required this.menuContext,
    required this.playerFace,
    required this.onStickChanged,
    required this.onStickRelease,
    required this.onButtonStateChanged,
    required this.onOpenAvatar,
    required this.onOpenSeats,
    this.ownerName,
  });

  @override
  Widget build(BuildContext context) {
    final strings = context.l10n.menu;
    final hint = switch (menuContext) {
      MenuContext.lobby => strings.lobbyHint,
      MenuContext.library => strings.libraryHint,
      MenuContext.tournament => strings.tournamentHint,
      MenuContext.overlay => strings.overlayHint,
      MenuContext.playground => strings.playgroundHint(ownerName ?? strings.someone),
    };
    final playground = menuContext == MenuContext.playground;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              flex: 5,
              child: Center(
                child: Joystick(
                  size: 220,
                  onChanged: (x, y) => onStickChanged(Offset(x, y)),
                  onReleased: onStickRelease,
                ),
              ),
            ),
            Expanded(
              flex: 6,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    hint,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'momo',
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _PadButton(
                        label: strings.back,
                        icon: Icons.undo_rounded,
                        color: AppColors.lightColor,
                        onDown: () => onButtonStateChanged('B', 'down'),
                        onUp: () => onButtonStateChanged('B', 'up'),
                      ),
                      const SizedBox(width: 14),
                      _PadButton(
                        label: playground ? strings.jump : strings.select,
                        icon: playground ? Icons.keyboard_double_arrow_up_rounded : Icons.check_rounded,
                        color: playerFace.color,
                        large: true,
                        onDown: () => onButtonStateChanged('A', 'down'),
                        onUp: () => onButtonStateChanged('A', 'up'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _SmallPadButton(
                        onTap: onOpenAvatar,
                        label: strings.avatar,
                        leading: PlayerFaceIndicator(
                          face: playerFace,
                          size: 28,
                          roundedSquare: true,
                          borderColor: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      _SmallPadButton(
                        onTap: onOpenSeats,
                        label: strings.seat,
                        leading: const Icon(Icons.swap_horiz_rounded, size: 24, color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Rounded-square button with a label, like the gameplay buttons.
class _PadButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool large;
  final VoidCallback onDown;
  final VoidCallback onUp;

  const _PadButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onDown,
    required this.onUp,
    this.large = false,
  });

  @override
  State<_PadButton> createState() => _PadButtonState();
}

class _PadButtonState extends State<_PadButton> {
  bool _pressed = false;

  void _setPressed(bool pressed) {
    if (_pressed == pressed) return;
    setState(() => _pressed = pressed);
    if (pressed) {
      HapticsManager.instance.softTap();
      widget.onDown();
    } else {
      widget.onUp();
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = widget.large ? 128.0 : 100.0;
    final height = widget.large ? 104.0 : 88.0;
    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1,
        duration: const Duration(milliseconds: 90),
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: widget.color,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.textPrimary, width: AppColors.borderThickness),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, size: widget.large ? 40 : 30, color: AppColors.textPrimary),
              Text(
                widget.label,
                style: const TextStyle(
                  fontFamily: 'momo',
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
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

class _SmallPadButton extends StatelessWidget {
  final VoidCallback onTap;
  final String label;
  final Widget leading;

  const _SmallPadButton({required this.onTap, required this.label, required this.leading});

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
