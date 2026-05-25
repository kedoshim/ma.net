import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/player_face.dart';
import '../services/haptics_manager.dart';
import '../services/preferences_service.dart';
import '../theme/app_colors.dart';
import 'player_face_indicator.dart';

class OptionsPopup extends StatefulWidget {
  final PlayerFaceData playerFace;
  final VoidCallback onEnterMouseMode;
  final ColorTheme currentTheme;
  final ValueChanged<ColorTheme> onThemeChanged;
  final VoidCallback? onDisconnectRequested;
  final VoidCallback? onRumbleTest;

  const OptionsPopup({
    super.key,
    required this.playerFace,
    required this.onEnterMouseMode,
    required this.currentTheme,
    required this.onThemeChanged,
    this.onDisconnectRequested,
    this.onRumbleTest,
  });

  @override
  State<OptionsPopup> createState() => _OptionsPopupState();
}

class _OptionsPopupState extends State<OptionsPopup>
    with SingleTickerProviderStateMixin {
  bool _rumbleEnabled = true;
  late ColorTheme _selectedTheme;
  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;
  bool _showWebHint = false;
  Timer? _webHintTimer;

  @override
  void initState() {
    super.initState();
    _selectedTheme = widget.currentTheme;

    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _bounceAnimation = TweenSequence([
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 1.25,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.25,
          end: 0.9,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 0.9,
          end: 1.05,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.05,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 20,
      ),
    ]).animate(_bounceController);

    PreferencesService.instance.getRumbleEnabled().then((v) {
      if (mounted) setState(() => _rumbleEnabled = v);
    });
  }

  @override
  void dispose() {
    _webHintTimer?.cancel();
    _bounceController.dispose();
    super.dispose();
  }

  void _toggleRumble() {
    if (kIsWeb) {
      setState(() => _showWebHint = true);
      _webHintTimer?.cancel();
      _webHintTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() => _showWebHint = false);
        }
      });
      _bounceController.forward(from: 0.0);
      return;
    }

    final newValue = !_rumbleEnabled;
    setState(() => _rumbleEnabled = newValue);
    HapticsManager.instance.setEnabled(newValue);
    if (newValue) {
      widget.onRumbleTest?.call();
    }
  }

  IconData _getNextModeIcon(MovementMode mode) {
    switch (mode) {
      case MovementMode.dpad:
        return Icons.control_camera_rounded;
      case MovementMode.fixedJoystick:
        return Icons.touch_app_rounded;
      case MovementMode.floatingJoystick:
        return Icons.gamepad_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.screenBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: const BorderSide(
          color: AppColors.textPrimary,
          width: AppColors.borderThickness,
        ),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(
                left: 24,
                top: 16,
                right: 16,
                bottom: 8,
              ),
              child: Row(
                children: [
                  const Text(
                    'Opcoes',
                    style: TextStyle(
                      fontFamily: 'momo',
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  if (kIsWeb)
                    AnimatedBuilder(
                      animation: _bounceAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _bounceAnimation.value,
                          child: child,
                        );
                      },
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          backgroundColor: AppColors.highlightColor.withValues(
                            alpha: 0.2,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        icon: const Icon(
                          Icons.android_rounded,
                          size: 18,
                          color: AppColors.textPrimary,
                        ),
                        label: const Text(
                          'Baixar App',
                          style: TextStyle(
                            fontFamily: 'momo',
                            fontSize: 12,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        onPressed: () async {
                          final url = Uri.base.resolve('/apk');
                          try {
                            await launchUrl(url, webOnlyWindowName: '_blank');
                          } catch (e) {
                            debugPrint('Could not launch download URL: $e');
                          }
                        },
                      ),
                    ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close,
                      size: 24,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      LayoutBuilder(
                        builder: (context, constraints) {
                          return SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minWidth: constraints.maxWidth,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _OptionButton(
                                    icon: _rumbleEnabled
                                        ? Icons.vibration_rounded
                                        : Icons.mobile_off_rounded,
                                    label: 'Vibracao',
                                    isActive: _rumbleEnabled,
                                    onTap: _toggleRumble,
                                  ),
                                  const SizedBox(width: 12),
                                  _OptionButton(
                                    icon: Icons.mouse_outlined,
                                    label: 'Mouse',
                                    onTap: () {
                                      Navigator.of(context).pop();
                                      widget.onEnterMouseMode();
                                    },
                                  ),
                                  if (!kIsWeb) const SizedBox(width: 12),
                                  if (!kIsWeb)
                                    _OptionButton(
                                      icon: Icons.link_off_rounded,
                                      label: 'Sair',
                                      onTap: () {
                                        Navigator.of(context).pop();
                                        widget.onDisconnectRequested?.call();
                                      },
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOut,
                        child: _showWebHint
                            ? Padding(
                                padding: const EdgeInsets.only(top: 16),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.info_outline_rounded,
                                      size: 14,
                                      color: AppColors.textPrimary.withValues(
                                        alpha: 0.7,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Vibracao apenas no app Android!',
                                      style: TextStyle(
                                        fontFamily: 'momo',
                                        fontSize: 12,
                                        color: AppColors.textPrimary.withValues(
                                          alpha: 0.7,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                      const SizedBox(height: 32),
                      const Text(
                        'Cores do ma.net',
                        style: TextStyle(
                          fontFamily: 'momo',
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildThemeSelector(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeSelector() {
    final themes = ColorTheme.values;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(themes.length, (index) {
        final theme = themes[index];
        final themeColor = AppColors.getTheme(theme);
        final isSelected = _selectedTheme == theme;

        return GestureDetector(
          onTap: () {
            setState(() => _selectedTheme = theme);
            AppColors.setTheme(theme);
            widget.onThemeChanged(theme);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 8),
            width: isSelected ? 48 : 40,
            height: isSelected ? 48 : 40,
            decoration: BoxDecoration(
              color: themeColor.background,
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.textPrimary,
                width: isSelected ? 4 : 2,
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _OptionButton extends StatefulWidget {
  final IconData? icon;
  final Widget? customIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _OptionButton({
    this.icon,
    this.customIcon,
    required this.label,
    this.isActive = true,
    required this.onTap,
  }) : assert(icon != null || customIcon != null);

  @override
  State<_OptionButton> createState() => _OptionButtonState();
}

class _OptionButtonState extends State<_OptionButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.isActive
        ? AppColors.highlightColor.withValues(alpha: 0.3)
        : AppColors.textPrimary.withValues(alpha: 0.05);

    final fgColor = widget.isActive
        ? AppColors.textPrimary
        : AppColors.textPrimary.withValues(alpha: 0.5);

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.9 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: widget.isActive
                  ? AppColors.textPrimary
                  : AppColors.textPrimary.withValues(alpha: 0.2),
              width: AppColors.borderThickness,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              widget.customIcon ?? Icon(widget.icon, size: 32, color: fgColor),
              const SizedBox(height: 8),
              Text(
                widget.label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'momo',
                  fontSize: 12,
                  color: fgColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
