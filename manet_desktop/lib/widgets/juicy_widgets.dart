import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../services/sound_effect_service.dart';

/// Reusable Juicy Button with squash-and-stretch on press, spring rebound, and hover lift.
class JuicyButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final Color? borderColor;
  final double? borderThickness;
  final dynamic borderRadius;
  final EdgeInsetsGeometry? padding;
  final bool playSounds;
  final List<BoxShadow>? customShadows;

  const JuicyButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.backgroundColor,
    this.borderColor,
    this.borderThickness,
    this.borderRadius,
    this.padding,
    this.playSounds = true,
    this.customShadows,
  });

  @override
  State<JuicyButton> createState() => _JuicyButtonState();
}

class _JuicyButtonState extends State<JuicyButton>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  bool _isPressed = false;
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _onTapDown() {
    if (widget.onPressed == null) return;
    setState(() => _isPressed = true);
    // Squash down instantly
    _animController.animateTo(0.6,
        duration: const Duration(milliseconds: 60), curve: Curves.easeOutCubic);
  }

  void _onTapUp() {
    if (widget.onPressed == null) return;
    setState(() => _isPressed = false);
    // Elastic release overshoot
    _animController.forward(from: 0.6);
    if (widget.playSounds) {
      try {
        SoundEffectService.instance.playThemeSelect();
      } catch (_) {}
    }
    widget.onPressed?.call();
  }

  void _onTapCancel() {
    if (widget.onPressed == null) return;
    setState(() => _isPressed = false);
    _animController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final isDisabled = widget.onPressed == null;
    final borderCol = widget.borderColor ?? AppColors.textPrimary;
    final borderThick = widget.borderThickness ?? AppColors.borderThickness;

    return MouseRegion(
      onEnter: (_) {
        if (isDisabled) return;
        setState(() => _isHovered = true);
        if (widget.playSounds) {
          try {
            SoundEffectService.instance.playHover();
          } catch (_) {}
        }
      },
      onExit: (_) {
        if (isDisabled) return;
        setState(() => _isHovered = false);
      },
      cursor: isDisabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => _onTapDown(),
        onTapUp: (_) => _onTapUp(),
        onTapCancel: () => _onTapCancel(),
        child: AnimatedBuilder(
          animation: _animController,
          builder: (context, child) {
            double value = _animController.value;
            // Squash scale logic: scaleX increases slightly, scaleY reduces
            double scaleX = 1.0;
            double scaleY = 1.0;
            double translateY = 0.0;

            if (_isPressed) {
              // Tap squash
              scaleX = 1.0 + (value * 0.08);
              scaleY = 1.0 - (value * 0.08);
              translateY = value * 4.0;
            } else if (_animController.isAnimating) {
              // Elastic rebound
              double t = (value - 0.6) / 0.4;
              if (t > 0) {
                double spring = math.sin(t * math.pi * 2.5) * (1.0 - t) * 0.12;
                scaleX = 1.0 - spring;
                scaleY = 1.0 + spring;
                translateY = spring * -4.0;
              }
            } else if (_isHovered) {
              scaleX = 1.04;
              scaleY = 1.04;
              translateY = -2.0;
            }

            final bgColor = isDisabled
                ? AppColors.greyDisabled
                : (widget.backgroundColor ?? AppColors.highlightColor);

            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..translate(0.0, translateY)
                ..scale(scaleX, scaleY),
              child: Container(
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: widget.borderRadius is BorderRadiusGeometry
                      ? (widget.borderRadius as BorderRadiusGeometry)
                      : (widget.borderRadius is num
                          ? BorderRadius.circular((widget.borderRadius as num).toDouble())
                          : BorderRadius.circular(20)),
                  border: Border.all(
                    color: isDisabled ? borderCol.withValues(alpha: 0.4) : borderCol,
                    width: borderThick,
                  ),
                  boxShadow: widget.customShadows ?? (isDisabled
                      ? []
                      : [
                          BoxShadow(
                            color: AppColors.textPrimary.withValues(alpha: _isHovered ? 0.25 : 0.15),
                            offset: Offset(0, _isHovered ? 6 : 3),
                            blurRadius: _isHovered ? 8 : 4,
                          ),
                        ]),
                ),
                padding: widget.padding ??
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Opacity(
                  opacity: isDisabled ? 0.5 : 1.0,
                  child: widget.child,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Bouncy Juicy Icon Button with circular outline and touch compression.
class JuicyIconButton extends StatefulWidget {
  final Widget icon;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Color? iconColor;
  final Color? borderColor;
  final double? borderThickness;
  final double size;
  final double borderRadius;
  final bool playSounds;
  final Color? hoverBackgroundColor;
  final Color? hoverIconColor;

  const JuicyIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.backgroundColor,
    this.iconColor,
    this.borderColor,
    this.borderThickness,
    this.size = 56.0,
    this.borderRadius = 16.0,
    this.playSounds = true,
    this.hoverBackgroundColor,
    this.hoverIconColor,
  });

  @override
  State<JuicyIconButton> createState() => _JuicyIconButtonState();
}

class _JuicyIconButtonState extends State<JuicyIconButton>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  bool _isPressed = false;
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDisabled = widget.onTap == null;
    final scale = _isPressed ? 0.88 : (_isHovered ? 1.12 : 1.0);
    final rotate = _isHovered ? 0.05 : 0.0;

    return MouseRegion(
      onEnter: (_) {
        if (isDisabled) return;
        setState(() => _isHovered = true);
        if (widget.playSounds) {
          try {
            SoundEffectService.instance.playHover();
          } catch (_) {}
        }
      },
      onExit: (_) {
        if (isDisabled) return;
        setState(() => _isHovered = false);
      },
      cursor: isDisabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) {
          if (isDisabled) return;
          setState(() => _isPressed = true);
        },
        onTapUp: (_) {
          if (isDisabled) return;
          setState(() => _isPressed = false);
          if (widget.playSounds) {
            try {
              SoundEffectService.instance.playThemeSelect();
            } catch (_) {}
          }
          widget.onTap?.call();
        },
        onTapCancel: () {
          if (isDisabled) return;
          setState(() => _isPressed = false);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutBack,
          transformAlignment: Alignment.center,
          transform: Matrix4.identity()
            ..scale(scale)
            ..rotateZ(rotate),
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: isDisabled
                ? AppColors.greyDisabled.withValues(alpha: 0.5)
                : (_isHovered
                    ? (widget.hoverBackgroundColor ?? AppColors.textPrimary)
                    : (widget.backgroundColor ?? Colors.transparent)),
            borderRadius: BorderRadius.circular(widget.borderRadius),
            border: Border.all(
              color: isDisabled
                  ? (widget.borderColor ?? AppColors.textPrimary).withValues(alpha: 0.4)
                  : (widget.borderColor ?? AppColors.textPrimary),
              width: widget.borderThickness ?? 3.0,
            ),
          ),
          child: Center(
            child: IconTheme(
              data: IconThemeData(
                color: isDisabled
                    ? AppColors.textPrimary.withValues(alpha: 0.3)
                    : (_isHovered
                        ? (widget.hoverIconColor ?? AppColors.screenBackground)
                        : (widget.iconColor ?? AppColors.textPrimary)),
                size: widget.size * 0.6,
              ),
              child: widget.icon,
            ),
          ),
        ),
      ),
    );
  }
}

/// Juicy Card with lift elevation, spring selection borders, and hover wiggle.
class JuicyCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final bool isSelected;
  final Color? selectedColor;
  final Color? backgroundColor;
  final double borderRadius;
  final double borderThickness;

  const JuicyCard({
    super.key,
    required this.child,
    this.onTap,
    this.isSelected = false,
    this.selectedColor,
    this.backgroundColor,
    this.borderRadius = 24.0,
    this.borderThickness = 4.0,
  });

  @override
  State<JuicyCard> createState() => _JuicyCardState();
}

class _JuicyCardState extends State<JuicyCard>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  bool _isPressed = false;
  late AnimationController _wiggleController;

  @override
  void initState() {
    super.initState();
    _wiggleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
  }

  @override
  void dispose() {
    _wiggleController.dispose();
    super.dispose();
  }

  void _wiggle() {
    _wiggleController.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    final isSelected = widget.isSelected;
    final brandColor = widget.selectedColor ?? AppColors.highlightColor;
    final borderColor = isSelected ? brandColor : AppColors.textPrimary;
    final borderWidth = isSelected ? widget.borderThickness + 2.0 : widget.borderThickness;
    final scale = _isPressed
        ? 0.97
        : (isSelected ? 1.04 : (_isHovered ? 1.02 : 1.0));

    final bgColor = isSelected
        ? brandColor.withValues(alpha: 0.08)
        : (widget.backgroundColor ?? AppColors.lightColor);

    return MouseRegion(
      onEnter: (_) {
        setState(() => _isHovered = true);
        _wiggle();
        try {
          SoundEffectService.instance.playHover();
        } catch (_) {}
      },
      onExit: (_) => setState(() => _isHovered = false),
      cursor: widget.onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) {
          setState(() => _isPressed = false);
          widget.onTap?.call();
        },
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedBuilder(
          animation: _wiggleController,
          builder: (context, child) {
            double wiggleAngle = 0.0;
            if (_wiggleController.isAnimating) {
              double t = _wiggleController.value;
              wiggleAngle = math.sin(t * math.pi * 3) * (1.0 - t) * 0.015;
            }

            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..scale(scale)
                ..rotateZ(wiggleAngle),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(widget.borderRadius),
                  border: Border.all(color: borderColor, width: borderWidth),
                ),
                child: child,
              ),
            );
          },
          child: widget.child,
        ),
      ),
    );
  }
}

/// Juicy Dialog Wrapper that scales into view with elastic overshoot.
class JuicyDialog extends StatelessWidget {
  final Widget child;
  final String? title;
  final List<Widget>? actions;
  final double maxWidth;

  const JuicyDialog({
    super.key,
    required this.child,
    this.title,
    this.actions,
    this.maxWidth = 540,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.3, end: 1.0),
      duration: const Duration(milliseconds: 550),
      curve: Curves.elasticOut,
      builder: (context, scale, child) {
        return Transform.scale(
          scale: scale,
          alignment: Alignment.center,
          child: child,
        );
      },
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          width: maxWidth,
          decoration: BoxDecoration(
            color: AppColors.screenBackground,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: AppColors.textPrimary,
              width: AppColors.borderThickness + 1.0,
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                offset: Offset(0, 10),
                blurRadius: 20,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (title != null)
                Padding(
                  padding: const EdgeInsets.only(left: 24, right: 16, top: 20, bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title!,
                          style: AppTheme.titleMedium.copyWith(
                            fontFamily: 'momo',
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      JuicyIconButton(
                        size: 36,
                        borderRadius: 10,
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onTap: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
              Flexible(
                child: Padding(
                  padding: EdgeInsets.only(
                    left: 24,
                    right: 24,
                    top: title == null ? 24 : 8,
                    bottom: actions == null ? 24 : 12,
                  ),
                  child: SingleChildScrollView(child: child),
                ),
              ),
              if (actions != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.textPrimary.withValues(alpha: 0.03),
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: actions!
                        .map((a) => Padding(
                              padding: const EdgeInsets.only(left: 12),
                              child: a,
                            ))
                        .toList(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Juicy Bouncy Switch/Toggle with elastic thumb animation.
class JuicyToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final String? activeLabel;
  final String? inactiveLabel;

  const JuicyToggle({
    super.key,
    required this.value,
    required this.onChanged,
    this.activeLabel,
    this.inactiveLabel,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutBack,
          width: 90,
          height: 44,
          decoration: BoxDecoration(
            color: value ? AppColors.highlightColor : AppColors.greyDisabled.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.textPrimary, width: 3),
          ),
          child: Stack(
            children: [
              AnimatedAlign(
                duration: const Duration(milliseconds: 350),
                curve: Curves.elasticOut,
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 1.0, end: 1.0),
                    duration: const Duration(milliseconds: 200),
                    builder: (context, scale, child) {
                      return Container(
                        width: 30,
                        height: 30,
                        decoration: const BoxDecoration(
                          color: AppColors.lightColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black12,
                              offset: Offset(0, 2),
                              blurRadius: 2,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            value ? ':D' : ':(',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monomaniac',
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
