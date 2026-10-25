import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/player_face.dart';
import '../../theme/app_colors.dart';
import '../player_face_indicator.dart';
import 'phone_game_frame.dart';

/// What floats over a phone game: a small Home button (the player's face)
/// that opens a menu, or, while the pad is up, a button back to the game.
class PhoneGameControls extends StatelessWidget {
  const PhoneGameControls({
    super.key,
    required this.playerFace,
    required this.padShown,
    required this.menuOpen,
    required this.onMenuOpenChanged,
    required this.onShowPad,
    required this.onBackToGame,
    required this.onLeave,
  });

  final PlayerFaceData playerFace;
  final bool padShown;
  final bool menuOpen;
  final ValueChanged<bool> onMenuOpenChanged;
  final VoidCallback onShowPad;
  final VoidCallback onBackToGame;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    if (padShown) return _BackToGame(onTap: onBackToGame);

    final strings = context.l10n.phoneGame;
    return Stack(
      children: [
        // A tap outside the menu closes it, without reaching the game.
        if (menuOpen)
          Positioned.fill(
            child: phoneGameTouchShield(
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onMenuOpenChanged(false),
                child: const ColoredBox(color: Colors.black26),
              ),
            ),
          ),
        Positioned(
          left: 10,
          top: 10,
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                phoneGameTouchShield(
                  _Pressable(
                    onTap: () => onMenuOpenChanged(!menuOpen),
                    child: PlayerFaceIndicator(
                      face: playerFace,
                      size: 46,
                      roundedSquare: true,
                      borderColor: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                AnimatedScale(
                  scale: menuOpen ? 1 : 0,
                  alignment: Alignment.topLeft,
                  duration: Duration(milliseconds: menuOpen ? 420 : 160),
                  curve: menuOpen ? Curves.elasticOut : Curves.easeIn,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _MenuButton(
                        icon: Icons.sports_esports_rounded,
                        label: strings.showPad,
                        onTap: onShowPad,
                      ),
                      const SizedBox(height: 8),
                      _MenuButton(
                        icon: Icons.logout_rounded,
                        label: strings.leave,
                        onTap: onLeave,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Drawn the way the pad is: the web pad turns a portrait phone sideways,
/// so the button turns with it to sit at the pad's top.
class _BackToGame extends StatelessWidget {
  const _BackToGame({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final button = Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: _MenuButton(
          icon: Icons.phone_android_rounded,
          label: context.l10n.phoneGame.backToGame,
          onTap: onTap,
        ),
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final portrait = constraints.maxHeight > constraints.maxWidth;
        if (!kIsWeb || !portrait) return button;
        return RotatedBox(quarterTurns: 1, child: button);
      },
    );
  }
}

class _MenuButton extends StatelessWidget {
  const _MenuButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
            Icon(icon, size: 20, color: AppColors.textPrimary),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'momo',
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
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

/// On the pad while a phone game (Jackbox) runs: someone sets the game up
/// with the pad, then everyone taps this to play on the phone. It breathes
/// so nobody misses it.
class JoinPhoneGameButton extends StatefulWidget {
  const JoinPhoneGameButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  State<JoinPhoneGameButton> createState() => _JoinPhoneGameButtonState();
}

class _JoinPhoneGameButtonState extends State<JoinPhoneGameButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween<double>(begin: 1, end: 1.07)
          .animate(CurvedAnimation(parent: _breath, curve: Curves.easeInOut)),
      child: _Pressable(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.highlightColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.textPrimary, width: 4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.phone_android_rounded,
                size: 26,
                color: AppColors.textPrimary,
              ),
              const SizedBox(width: 10),
              Text(
                context.l10n.phoneGame.join,
                style: const TextStyle(
                  fontFamily: 'momo',
                  fontSize: 18,
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
