import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/player_face.dart';
import '../../theme/app_colors.dart';
import '../player_face_indicator.dart';
import 'phone_game_frame.dart';

/// What floats over a site (Jackbox, a game manual): the player's face.
/// A tap brings the pad back (the site stays loaded underneath); a drag
/// moves it off whatever it covers, and it snaps to the nearest side.
class PhoneGameControls extends StatefulWidget {
  const PhoneGameControls({
    super.key,
    required this.playerFace,
    required this.padShown,
    required this.onShowPad,
  });

  final PlayerFaceData playerFace;
  final bool padShown;
  final VoidCallback onShowPad;

  @override
  State<PhoneGameControls> createState() => _PhoneGameControlsState();
}

class _PhoneGameControlsState extends State<PhoneGameControls> {
  static const double _size = 46;
  static const double _margin = 10;

  // Kept for the next site too: once moved off something, it stays off.
  static Offset? _lastSpot;

  Offset? _spot;
  bool _dragging = false;

  Offset _clamp(Offset spot, Size area) => Offset(
    spot.dx.clamp(_margin, area.width - _size - _margin),
    spot.dy.clamp(_margin, area.height - _size - _margin),
  );

  void _snap(Size area) {
    final spot = _spot!;
    final left = spot.dx + _size / 2 < area.width / 2;
    setState(() {
      _dragging = false;
      _spot = _clamp(
        Offset(left ? _margin : area.width - _size - _margin, spot.dy),
        area,
      );
      _lastSpot = _spot;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.padShown) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final area = constraints.biggest;
        final spot = _clamp(
          _spot ?? _lastSpot ?? const Offset(_margin, _margin),
          area,
        );
        return Stack(
          children: [
            AnimatedPositioned(
              duration: Duration(milliseconds: _dragging ? 0 : 380),
              curve: Curves.easeOutBack,
              left: spot.dx,
              top: spot.dy,
              child: phoneGameTouchShield(
                GestureDetector(
                  onPanStart: (_) => setState(() {
                    _dragging = true;
                    _spot = spot;
                  }),
                  onPanUpdate: (details) => setState(
                    () => _spot = _clamp(_spot! + details.delta, area),
                  ),
                  onPanEnd: (_) => _snap(area),
                  child: _Pressable(
                    onTap: widget.onShowPad,
                    child: AnimatedScale(
                      scale: _dragging ? 1.15 : 1,
                      duration: const Duration(milliseconds: 160),
                      curve: Curves.easeOutBack,
                      child: PlayerFaceIndicator(
                        face: widget.playerFace,
                        size: _size,
                        roundedSquare: true,
                        borderColor: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Pressable extends StatefulWidget {
  const _Pressable({required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.88 : 1,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// On the pad while a site is set for the running game (Jackbox, a manual),
/// or one is open underneath: opens it, or goes back to it. Kept small so
/// whoever plays with the pad isn't in its way; it pops in once to be seen.
class JoinPhoneGameButton extends StatefulWidget {
  const JoinPhoneGameButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  State<JoinPhoneGameButton> createState() => _JoinPhoneGameButtonState();
}

class _JoinPhoneGameButtonState extends State<JoinPhoneGameButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  )..forward();

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: CurvedAnimation(parent: _pop, curve: Curves.elasticOut),
      child: _Pressable(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.textPrimary,
              width: AppColors.borderThickness,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.language_rounded,
                size: 20,
                color: AppColors.textPrimary,
              ),
              const SizedBox(width: 8),
              Text(
                context.l10n.phoneGame.join,
                style: const TextStyle(
                  fontFamily: 'momo',
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
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
