import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../services/haptics_manager.dart';

/// Reusable Juicy Button for Mobile/Touch.
/// Instant compression on touch-down, spring overshoot on touch-up.
class JuicyButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final void Function(String state)? onStateChange; // Optional hook for 'down' / 'up' raw states (like game controllers)
  final Color? backgroundColor;
  final Color? borderColor;
  final dynamic borderRadius;
  final double borderThickness;
  final EdgeInsetsGeometry? padding;
  final bool enableHaptics;

  const JuicyButton({
    super.key,
    this.onTap,
    this.onStateChange,
    this.backgroundColor,
    this.borderColor,
    this.borderRadius,
    this.borderThickness = 4.0,
    this.padding,
    this.enableHaptics = true,
    required this.child,
  });

  @override
  State<JuicyButton> createState() => _JuicyButtonState();
}

class _JuicyButtonState extends State<JuicyButton>
    with SingleTickerProviderStateMixin {
  bool _isPressed = false;
  late AnimationController _animController;
  int? _pointerId;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _handlePressDown() {
    if (_isPressed) return;
    setState(() => _isPressed = true);
    _animController.animateTo(0.6,
        duration: const Duration(milliseconds: 50), curve: Curves.easeOutQuad);
    widget.onStateChange?.call('down');
    if (widget.enableHaptics) {
      try {
        HapticsManager.instance.softTap();
      } catch (_) {}
    }
  }

  void _handlePressUp() {
    if (!_isPressed) return;
    setState(() => _isPressed = false);
    _animController.forward(from: 0.6);
    widget.onStateChange?.call('up');
    widget.onTap?.call();
  }

  void _handlePressCancel() {
    if (!_isPressed) return;
    setState(() => _isPressed = false);
    _animController.reverse();
    widget.onStateChange?.call('up');
  }

  @override
  Widget build(BuildContext context) {
    final isDisabled = widget.onTap == null && widget.onStateChange == null;
    final borderCol = widget.borderColor ?? AppColors.textPrimary;
    final borderThick = widget.borderThickness;

    final bgColor = isDisabled
        ? AppColors.textPrimary.withValues(alpha: 0.2)
        : (_isPressed
            ? AppColors.highlightColor
            : (widget.backgroundColor ?? AppColors.backgroundColor));

    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (event) {
        if (isDisabled || _pointerId != null) return;
        _pointerId = event.pointer;
        _handlePressDown();
      },
      onPointerUp: (event) {
        if (event.pointer == _pointerId) {
          _pointerId = null;
          _handlePressUp();
        }
      },
      onPointerCancel: (event) {
        if (event.pointer == _pointerId) {
          _pointerId = null;
          _handlePressCancel();
        }
      },
      child: AnimatedBuilder(
        animation: _animController,
        builder: (context, child) {
          double value = _animController.value;
          double scaleX = 1.0;
          double scaleY = 1.0;
          double translateY = 0.0;

          if (_isPressed) {
            scaleX = 1.0 + (value * 0.08);
            scaleY = 1.0 - (value * 0.08);
            translateY = value * 4.0;
          } else if (_animController.isAnimating) {
            double t = (value - 0.6) / 0.4;
            if (t > 0) {
              double spring = math.sin(t * math.pi * 2.5) * (1.0 - t) * 0.12;
              scaleX = 1.0 - spring;
              scaleY = 1.0 + spring;
              translateY = spring * -4.0;
            }
          }

          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..translate(0.0, translateY)
              ..scale(scaleX, scaleY),
            child: Container(
              padding: widget.padding ?? const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: widget.borderRadius is BorderRadiusGeometry
                    ? (widget.borderRadius as BorderRadiusGeometry)
                    : (widget.borderRadius is double
                        ? BorderRadius.circular(widget.borderRadius as double)
                        : (widget.borderRadius is int
                            ? BorderRadius.circular((widget.borderRadius as int).toDouble())
                            : BorderRadius.circular(16))),
                border: Border.all(
                  color: isDisabled ? borderCol.withValues(alpha: 0.3) : borderCol,
                  width: borderThick,
                ),
              ),
              child: Opacity(
                opacity: isDisabled ? 0.4 : 1.0,
                child: widget.child,
            ),
          ),
        );
      },
    ),
  );
}
}

/// Reusable Juicy Card for Mobile/Touch.
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
    this.borderRadius = 20.0,
    this.borderThickness = 4.0,
  });

  @override
  State<JuicyCard> createState() => _JuicyCardState();
}

class _JuicyCardState extends State<JuicyCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isSelected = widget.isSelected;
    final brandColor = widget.selectedColor ?? AppColors.highlightColor;
    final borderColor = isSelected ? brandColor : AppColors.textPrimary;
    final borderWidth = isSelected ? widget.borderThickness + 1.5 : widget.borderThickness;
    final scale = _isPressed ? 0.96 : (isSelected ? 1.03 : 1.0);

    final bgColor = isSelected
        ? brandColor.withValues(alpha: 0.08)
        : (widget.backgroundColor ?? AppColors.backgroundColor);

    return GestureDetector(
      onTapDown: (_) {
        if (widget.onTap == null) return;
        setState(() => _isPressed = true);
        try {
          HapticsManager.instance.softTap();
        } catch (_) {}
      },
      onTapUp: (_) {
        if (widget.onTap == null) return;
        setState(() => _isPressed = false);
        widget.onTap?.call();
      },
      onTapCancel: () {
        if (widget.onTap == null) return;
        setState(() => _isPressed = false);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutBack,
        transformAlignment: Alignment.center,
        transform: Matrix4.identity()..scale(scale),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(widget.borderRadius),
          border: Border.all(color: borderColor, width: borderWidth),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: brandColor.withValues(alpha: 0.25),
                blurRadius: 8,
                spreadRadius: 1,
              ),
          ],
        ),
        child: widget.child,
      ),
    );
  }
}

/// Juicy Dialog for Mobile.
class JuicyDialog extends StatelessWidget {
  final Widget child;
  final String? title;
  final List<Widget>? actions;

  const JuicyDialog({
    super.key,
    required this.child,
    this.title,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.4, end: 1.0),
      duration: const Duration(milliseconds: 500),
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
          decoration: BoxDecoration(
            color: AppColors.screenBackground,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppColors.textPrimary,
              width: AppColors.borderThickness,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (title != null)
                Padding(
                  padding: const EdgeInsets.only(left: 20, right: 12, top: 16, bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title!,
                          style: const TextStyle(
                            fontFamily: 'momo',
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: AppColors.textPrimary),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
              Flexible(
                child: Padding(
                  padding: EdgeInsets.only(
                    left: 20,
                    right: 20,
                    top: title == null ? 20 : 4,
                    bottom: actions == null ? 20 : 12,
                  ),
                  child: SingleChildScrollView(child: child),
                ),
              ),
              if (actions != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: actions!
                        .map((a) => Padding(
                              padding: const EdgeInsets.only(left: 10),
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

/// Juicy Switch Toggle for Mobile.
class JuicyToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const JuicyToggle({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        onChanged(!value);
        try {
          HapticsManager.instance.softTap();
        } catch (_) {}
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 80,
        height: 40,
        decoration: BoxDecoration(
          color: value ? AppColors.highlightColor : Colors.grey[300],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.textPrimary, width: AppColors.borderThickness),
        ),
        child: Stack(
          children: [
            AnimatedAlign(
              duration: const Duration(milliseconds: 300),
              curve: Curves.elasticOut,
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.all(2.0),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      value ? ':D' : ':(',
                      style: const TextStyle(
                        fontFamily: 'monomaniac',
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
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
