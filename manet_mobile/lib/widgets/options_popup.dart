import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../models/player_face.dart';
import '../services/haptics_manager.dart';
import '../services/preferences_service.dart';
import '../theme/app_colors.dart';
import '../l10n/app_localizations.dart';
import 'juicy_widgets.dart';
import 'android_onboarding_dialog.dart';

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

  void _showSensitivityDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (context) {
        return const SensitivityDialog();
      },
    );
  }



  Widget _buildLanguageButton(BuildContext context, Locale locale, String label) {
    final isSelected = context.currentLocale.languageCode == locale.languageCode;
    return JuicyCard(
      isSelected: isSelected,
      selectedColor: AppColors.highlightColor,
      backgroundColor: AppColors.backgroundColor,
      borderRadius: 12,
      borderThickness: 3.0,
      onTap: () {
        context.setLocale(locale);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Text(
          label,
          style: const TextStyle(
            fontFamily: 'momo',
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
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
                  Text(
                    context.l10n.options.title,
                    style: const TextStyle(
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
                        label: Text(
                          context.l10n.options.downloadApp,
                          style: const TextStyle(
                            fontFamily: 'momo',
                            fontSize: 12,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        onPressed: () {
                          showDialog(
                            context: context,
                            barrierDismissible: true,
                            useRootNavigator: true,
                            builder: (dialogContext) {
                              return AndroidOnboardingDialog(
                                onDownloadClicked: () {
                                  PreferencesService.instance.setHasSeenAndroidOnboarding(true);
                                },
                                onDismissClicked: () {
                                  PreferencesService.instance.setHasSeenAndroidOnboarding(true);
                                },
                              );
                            },
                          );
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
                                    label: context.l10n.options.vibration,
                                    isActive: _rumbleEnabled,
                                    onTap: _toggleRumble,
                                  ),
                                  const SizedBox(width: 12),
                                  _OptionButton(
                                    icon: Icons.tune_rounded,
                                    label: context.l10n.options.sensitivity,
                                    onTap: _showSensitivityDialog,
                                  ),
                                  const SizedBox(width: 12),
                                  _OptionButton(
                                    icon: Icons.mouse_outlined,
                                    label: context.l10n.options.mouseMode,
                                    onTap: () {
                                      Navigator.of(context).pop();
                                      widget.onEnterMouseMode();
                                    },
                                  ),
                                  if (!kIsWeb) const SizedBox(width: 12),
                                  if (!kIsWeb)
                                    _OptionButton(
                                      icon: Icons.link_off_rounded,
                                      label: context.l10n.options.exitDisconnect,
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
                                      context.l10n.options.vibrationAndroidOnly,
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
                      Text(
                        context.l10n.options.themeColorsTitle,
                        style: const TextStyle(
                          fontFamily: 'momo',
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildThemeSelector(),
                      const SizedBox(height: 24),
                      Text(
                        context.l10n.options.languageTitle,
                        style: const TextStyle(
                          fontFamily: 'momo',
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildLanguageButton(context, const Locale('pt', 'BR'), 'Português'),
                          const SizedBox(width: 16),
                          _buildLanguageButton(context, const Locale('en', 'US'), 'English'),
                        ],
                      ),
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

class SensitivityDialog extends StatefulWidget {
  const SensitivityDialog({super.key});

  @override
  State<SensitivityDialog> createState() => _SensitivityDialogState();
}

class _SensitivityDialogState extends State<SensitivityDialog> {
  double _leftStick = 1.0;
  double _rightStick = 1.0;
  double _swipeAccel = 0.0;
  double _antiDeadzone = 0.10;
  double _responseCurve = 0.5;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = PreferencesService.instance;
    final left = await prefs.getLeftStickSensitivity();
    final right = await prefs.getRightStickSensitivity();
    final swipe = await prefs.getSwipeAccelerationIntensity();
    final antiDead = await prefs.getRightStickAntiDeadzone();
    final respCurve = await prefs.getRightStickResponseCurve();
    if (mounted) {
      setState(() {
        _leftStick = left;
        _rightStick = right;
        _swipeAccel = swipe;
        _antiDeadzone = antiDead;
        _responseCurve = respCurve;
        _loaded = true;
      });
    }
  }

  Future<void> _savePreferences() async {
    final prefs = PreferencesService.instance;
    await prefs.setLeftStickSensitivity(_leftStick);
    await prefs.setRightStickSensitivity(_rightStick);
    await prefs.setSwipeAccelerationIntensity(_swipeAccel);
    await prefs.setRightStickAntiDeadzone(_antiDeadzone);
    await prefs.setRightStickResponseCurve(_responseCurve);
  }

  String _getCurveLabel(double val) {
    if (val == 0.0) return context.l10n.options.responseCurveLinear;
    if (val <= 0.5) return context.l10n.options.responseCurveMild;
    if (val <= 1.2) return context.l10n.options.responseCurveMedium;
    return context.l10n.options.responseCurveAggressive;
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const SizedBox.shrink();
    }

    return Dialog(
      backgroundColor: AppColors.screenBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: const BorderSide(
          color: AppColors.textPrimary,
          width: AppColors.borderThickness,
        ),
      ),
      child: Container(
        width: 320,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.options.sensitivityTitle,
                style: const TextStyle(
                  fontFamily: 'momo',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 20),
              // Left Stick Slider
              Text(
                '${context.l10n.options.leftStickSensitivity}: ${_leftStick.toStringAsFixed(1)}x',
                style: const TextStyle(
                  fontFamily: 'momo',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              SliderTheme(
                data: SliderThemeData(
                  activeTrackColor: AppColors.highlightColor,
                  inactiveTrackColor: AppColors.textPrimary.withValues(alpha: 0.1),
                  thumbColor: AppColors.textPrimary,
                  overlayColor: AppColors.highlightColor.withValues(alpha: 0.2),
                ),
                child: Slider(
                  value: _leftStick,
                  min: 0.5,
                  max: 2.5,
                  divisions: 20,
                  onChanged: (val) {
                    setState(() => _leftStick = val);
                  },
                ),
              ),
              const SizedBox(height: 10),
              // Right Stick Slider
              Text(
                '${context.l10n.options.rightStickSensitivity}: ${_rightStick.toStringAsFixed(1)}x',
                style: const TextStyle(
                  fontFamily: 'momo',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              SliderTheme(
                data: SliderThemeData(
                  activeTrackColor: AppColors.highlightColor,
                  inactiveTrackColor: AppColors.textPrimary.withValues(alpha: 0.1),
                  thumbColor: AppColors.textPrimary,
                  overlayColor: AppColors.highlightColor.withValues(alpha: 0.2),
                ),
                child: Slider(
                  value: _rightStick,
                  min: 0.5,
                  max: 2.5,
                  divisions: 20,
                  onChanged: (val) {
                    setState(() => _rightStick = val);
                  },
                ),
              ),
              const SizedBox(height: 10),
              // Swipe Acceleration Slider
              Text(
                '${context.l10n.options.swipeAcceleration}: ${_swipeAccel.toStringAsFixed(1)}x',
                style: const TextStyle(
                  fontFamily: 'momo',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              SliderTheme(
                data: SliderThemeData(
                  activeTrackColor: AppColors.highlightColor,
                  inactiveTrackColor: AppColors.textPrimary.withValues(alpha: 0.1),
                  thumbColor: AppColors.textPrimary,
                  overlayColor: AppColors.highlightColor.withValues(alpha: 0.2),
                ),
                child: Slider(
                  value: _swipeAccel,
                  min: 0.0,
                  max: 2.0,
                  divisions: 20,
                  onChanged: (val) {
                    setState(() => _swipeAccel = val);
                  },
                ),
              ),
              const SizedBox(height: 10),
              // Anti-Deadzone Slider
              Text(
                '${context.l10n.options.antiDeadzone}: ${(_antiDeadzone * 100).toStringAsFixed(0)}%',
                style: const TextStyle(
                  fontFamily: 'momo',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              SliderTheme(
                data: SliderThemeData(
                  activeTrackColor: AppColors.highlightColor,
                  inactiveTrackColor: AppColors.textPrimary.withValues(alpha: 0.1),
                  thumbColor: AppColors.textPrimary,
                  overlayColor: AppColors.highlightColor.withValues(alpha: 0.2),
                ),
                child: Slider(
                  value: _antiDeadzone,
                  min: 0.0,
                  max: 0.30,
                  divisions: 30,
                  onChanged: (val) {
                    setState(() => _antiDeadzone = val);
                  },
                ),
              ),
              const SizedBox(height: 10),
              // Response Curve Slider
              Text(
                '${context.l10n.options.responseCurve}: ${_getCurveLabel(_responseCurve)} (${_responseCurve.toStringAsFixed(1)})',
                style: const TextStyle(
                  fontFamily: 'momo',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              SliderTheme(
                data: SliderThemeData(
                  activeTrackColor: AppColors.highlightColor,
                  inactiveTrackColor: AppColors.textPrimary.withValues(alpha: 0.1),
                  thumbColor: AppColors.textPrimary,
                  overlayColor: AppColors.highlightColor.withValues(alpha: 0.2),
                ),
                child: Slider(
                  value: _responseCurve,
                  min: 0.0,
                  max: 2.0,
                  divisions: 20,
                  onChanged: (val) {
                    setState(() => _responseCurve = val);
                  },
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      context.l10n.common.cancel,
                      style: const TextStyle(
                        fontFamily: 'momo',
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  JuicyButton(
                    onTap: () async {
                      await _savePreferences();
                      if (context.mounted) {
                        Navigator.of(context).pop();
                      }
                    },
                    backgroundColor: AppColors.highlightColor,
                    borderRadius: 12,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      context.l10n.common.save,
                      style: const TextStyle(
                        fontFamily: 'momo',
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
