import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/controller_branding.dart';
import '../services/host_api_service.dart';
import '../theme/app_colors.dart';
import '../l10n/app_localizations.dart';

String displayNameFor(BuildContext context, ControllerPreset preset) {
  switch (preset.id) {
    case 'builtin-simple-shoulder':
      return context.currentLocale.languageCode == 'pt' ? 'Simples' : 'Simple';
    case 'builtin-simple-trigger':
      return context.currentLocale.languageCode == 'pt' ? 'Padrão' : 'Standard';
    case 'builtin-full':
      return context.currentLocale.languageCode == 'pt' ? 'Completo' : 'Full';
    default:
      return preset.name;
  }
}

class StructuredLayoutPreview extends StatelessWidget {
  const StructuredLayoutPreview({
    super.key,
    required this.brandingMode,
    required this.layout,
    this.compact = false,
  });

  final ControllerBrandingMode brandingMode;
  final ControllerPresetLayout layout;
  final bool compact;

  List<List<String>> _splitIntoColumns(List<String> buttons) {
    final left = <String>[];
    final right = <String>[];

    for (final button in buttons) {
      if (left.length <= right.length) {
        left.add(button);
      } else {
        right.add(button);
      }
    }

    if (left.length > right.length) {
      return [right, left];
    }

    return [left, right];
  }

  List<List<String>> _splitIntoRows(List<String> buttons) {
    final top = <String>[];
    final bottom = <String>[];

    for (final button in buttons) {
      if (top.length <= bottom.length) {
        top.add(button);
      } else {
        bottom.add(button);
      }
    }

    if (top.length < bottom.length) {
      return [bottom, top];
    }

    return [top, bottom];
  }

  @override
  Widget build(BuildContext context) {
    final double height = compact ? 100 : 140;

    final visible = layout.buttonOrder
        .where((buttonId) => layout.visibleButtons[buttonId] == true)
        .toList();

    final bool isRows = layout.rightLayoutMode == 'rows';
    final groups = isRows ? _splitIntoRows(visible) : _splitIntoColumns(visible);

    return Container(
      height: height,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 16,
        vertical: compact ? 8 : 12,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: compact ? Colors.transparent : AppColors.backgroundColor,
        border: compact
            ? null
            : Border.all(
                color: AppColors.textPrimary.withValues(alpha: 0.1),
                width: 2,
              ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 3,
            child: layout.movementMode == 'dpad'
                ? const PreviewDpad()
                : const PreviewStick(
                    floating:
                        false, // In static preview, stick is always visible center
                  ).scale(1.1),
          ),
          SizedBox(width: compact ? 4 : 8),
          Expanded(
            flex: 2,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'ma•net',
                  style: TextStyle(
                    fontSize: compact ? 8 : 10,
                    fontFamily: 'momo',
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: compact ? 4 : 8),
          Expanded(
            flex: 3,
            child: isRows
                ? Column(
                    children: [
                      PreviewColumn(
                        brandingMode: brandingMode,
                        buttons: groups[0],
                        buttonSizes: layout.buttonSizes,
                        isHorizontal: true,
                      ),
                      SizedBox(height: compact ? 2 : 4),
                      PreviewColumn(
                        brandingMode: brandingMode,
                        buttons: groups[1],
                        buttonSizes: layout.buttonSizes,
                        isHorizontal: true,
                      ),
                    ],
                  )
                : Row(
                    children: [
                      PreviewColumn(
                        brandingMode: brandingMode,
                        buttons: groups[0],
                        buttonSizes: layout.buttonSizes,
                      ),
                      SizedBox(width: compact ? 2 : 4),
                      PreviewColumn(
                        brandingMode: brandingMode,
                        buttons: groups[1],
                        buttonSizes: layout.buttonSizes,
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class ReorderLayoutPreview extends StatelessWidget {
  const ReorderLayoutPreview({
    super.key,
    required this.brandingMode,
    required this.layout,
    this.onReorder,
  });

  final ControllerBrandingMode brandingMode;
  final ControllerPresetLayout layout;
  final void Function(String, String)? onReorder;

  List<List<String>> _splitIntoColumns(List<String> buttons) {
    final left = <String>[];
    final right = <String>[];

    for (final button in buttons) {
      if (left.length <= right.length) {
        left.add(button);
      } else {
        right.add(button);
      }
    }

    if (left.length > right.length) {
      return [right, left];
    }

    return [left, right];
  }

  List<List<String>> _splitIntoRows(List<String> buttons) {
    final top = <String>[];
    final bottom = <String>[];

    for (final button in buttons) {
      if (top.length <= bottom.length) {
        top.add(button);
      } else {
        bottom.add(button);
      }
    }

    if (top.length < bottom.length) {
      return [bottom, top];
    }

    return [top, bottom];
  }

  @override
  Widget build(BuildContext context) {
    final Color surface = AppColors.backgroundColor;

    final visible = layout.buttonOrder
        .where((buttonId) => layout.visibleButtons[buttonId] == true)
        .toList();

    final bool isRows = layout.rightLayoutMode == 'rows';
    final groups = isRows ? _splitIntoRows(visible) : _splitIntoColumns(visible);

    return Center(
      child: AspectRatio(
        aspectRatio: 2.2 / 1.0,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppColors.textPrimary, width: 5),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 3,
                child: (layout.movementMode == 'dpad'
                        ? const PreviewDpad()
                        : PreviewStick(
                            floating: layout.movementMode == 'floatingJoystick',
                          ))
                    .scale(1.15),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: Center(
                  child: Text(
                    'ma•net',
                    style: TextStyle(
                      fontSize: 14,
                      fontFamily: 'momo',
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: isRows
                    ? Column(
                        children: [
                          PreviewColumn(
                            brandingMode: brandingMode,
                            buttons: groups[0],
                            buttonSizes: layout.buttonSizes,
                            onReorder: onReorder,
                            isHorizontal: true,
                          ),
                          const SizedBox(height: 6),
                          PreviewColumn(
                            brandingMode: brandingMode,
                            buttons: groups[1],
                            buttonSizes: layout.buttonSizes,
                            onReorder: onReorder,
                            isHorizontal: true,
                          ),
                        ],
                      ).scale(1.15)
                    : Row(
                        children: [
                          PreviewColumn(
                            brandingMode: brandingMode,
                            buttons: groups[0],
                            buttonSizes: layout.buttonSizes,
                            onReorder: onReorder,
                          ),
                          const SizedBox(width: 6),
                          PreviewColumn(
                            brandingMode: brandingMode,
                            buttons: groups[1],
                            buttonSizes: layout.buttonSizes,
                            onReorder: onReorder,
                          ),
                        ],
                      ).scale(1.15),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PreviewStick extends StatelessWidget {
  const PreviewStick({super.key, required this.floating});
  final bool floating;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: floating ? 70 : 82,
            height: floating ? 70 : 82,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(floating ? 15 : 18),
              border: Border.all(
                color: AppColors.textPrimary.withValues(alpha: 0.3),
                width: 2,
              ),
              color: floating ? AppColors.screenBackground : Colors.transparent,
            ),
          ),
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class PreviewDpad extends StatelessWidget {
  const PreviewDpad({super.key});

  @override
  Widget build(BuildContext context) {
    Widget box() => Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: AppColors.backgroundColor,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: AppColors.textPrimary.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
    );

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: SizedBox(
        width: 82,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            box(),
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [box(), box()],
            ),
            const SizedBox(height: 2),
            box(),
          ],
        ),
      ),
    );
  }
}

class PreviewColumn extends StatelessWidget {
  const PreviewColumn({
    super.key,
    required this.brandingMode,
    required this.buttons,
    this.buttonSizes = const {},
    this.onReorder,
    this.isHorizontal = false,
  });
  final ControllerBrandingMode brandingMode;
  final List<String> buttons;
  final Map<String, int> buttonSizes;
  final void Function(String, String)? onReorder;
  final bool isHorizontal;

  @override
  Widget build(BuildContext context) {
    final children = buttons.map((buttonId) {
      final defaultFlex = buttonId == 'RS_SWIPE' ? 2 : 1;
      final flex = buttonSizes[buttonId] ?? defaultFlex;

      Widget box;
      if (buttonId == 'RS_FIXED') {
        box = const RightStickFixedPreview();
      } else if (buttonId == 'RS_BUTTON') {
        box = const RightStickFloatingPreview(faded: true);
      } else if (buttonId == 'RS_SWIPE') {
        box = const RightStickSwipePreview();
      } else {
        final presentation = ControllerBranding.presentationFor(
          buttonId,
          brandingMode,
        );
        box = Container(
          width: double.infinity,
          height: isHorizontal ? double.infinity : null,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.backgroundColor,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: AppColors.textPrimary.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: ControllerButtonBrand(
            presentation: presentation,
            size: 14,
            textColor: AppColors.textPrimary,
          ),
        );
      }

      final content = Padding(padding: const EdgeInsets.all(2), child: box);
      if (onReorder == null) return Expanded(flex: flex, child: content);

      return Expanded(
        flex: flex,
        child: DragTarget<String>(
          onWillAcceptWithDetails: (details) => details.data != buttonId,
          onAcceptWithDetails: (details) =>
              onReorder!(details.data, buttonId),
          builder: (context, candidateData, rejectedData) {
            return Draggable<String>(
              data: buttonId,
              feedback: Material(
                color: Colors.transparent,
                child: SizedBox(width: 60, height: 30, child: box),
              ),
              childWhenDragging: Opacity(opacity: 0.3, child: content),
              child: content,
            );
          },
        ),
      );
    }).toList();

    return Expanded(
      child: isHorizontal
          ? Row(children: children)
          : Column(children: children),
    );
  }
}

class PreviewCenterButton extends StatelessWidget {
  const PreviewCenterButton({super.key, required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 16,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.backgroundColor,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: AppColors.textPrimary.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 8, color: AppColors.textPrimary),
      ),
    );
  }
}

extension LayoutWidgetScaling on Widget {
  Widget scale(double factor) => Transform.scale(scale: factor, child: this);
}

class RightStickFixedPreview extends StatelessWidget {
  const RightStickFixedPreview({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = math.min(constraints.maxWidth, constraints.maxHeight);
        final knobSize = size * 0.33;
        final borderRadius = size * 0.3;
        final borderWidth = size > 60 ? AppColors.borderThickness : 1.5;

        return Center(
          child: SizedBox(
            width: size,
            height: size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    color: AppColors.backgroundColor,
                    borderRadius: BorderRadius.circular(borderRadius),
                    border: Border.all(
                      color: AppColors.textPrimary,
                      width: borderWidth,
                    ),
                  ),
                ),
                Container(
                  width: knobSize,
                  height: knobSize,
                  decoration: BoxDecoration(
                    color: AppColors.textPrimary,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.lightColor,
                      width: borderWidth,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class RightStickFloatingPreview extends StatelessWidget {
  final bool faded;

  const RightStickFloatingPreview({
    super.key,
    this.faded = true,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = math.min(constraints.maxWidth, constraints.maxHeight);
        final symbolSize = size * 0.7;
        final knobSize = symbolSize * 0.33;
        final borderRadius = symbolSize * 0.3;
        final opacity = faded ? 0.3 : 1.0;
        final borderWidth = symbolSize > 60 ? AppColors.borderThickness : 1.5;

        return Center(
          child: SizedBox(
            width: symbolSize,
            height: symbolSize,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: symbolSize,
                  height: symbolSize,
                  decoration: BoxDecoration(
                    color: AppColors.backgroundColor.withValues(alpha: opacity * 0.15),
                    borderRadius: BorderRadius.circular(borderRadius),
                    border: Border.all(
                      color: AppColors.textPrimary.withValues(alpha: opacity),
                      width: borderWidth,
                    ),
                  ),
                ),
                Container(
                  width: knobSize,
                  height: knobSize,
                  decoration: BoxDecoration(
                    color: AppColors.textPrimary.withValues(alpha: opacity),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class RightStickSwipePreview extends StatelessWidget {
  final bool active;

  const RightStickSwipePreview({
    super.key,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = active
        ? AppColors.highlightColor
        : AppColors.textPrimary.withValues(alpha: 0.6);
    final iconColor = active
        ? AppColors.highlightColor.withValues(alpha: 0.4)
        : AppColors.textPrimary.withValues(alpha: 0.2);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final size = math.min(width, height);
        final fontSize = size > 80 ? 14.0 : 10.0;
        final iconSize = size > 80 ? 24.0 : 16.0;

        return Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            color: active
                ? AppColors.highlightColor.withValues(alpha: 0.15)
                : AppColors.backgroundColor.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: active ? AppColors.highlightColor : AppColors.textPrimary,
              width: AppColors.borderThickness,
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Text(
                'SWIPE PAD',
                style: TextStyle(
                  fontFamily: 'momo',
                  fontSize: fontSize,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              Positioned(
                left: size > 80 ? 10 : 4,
                child: Icon(
                  Icons.keyboard_arrow_left_rounded,
                  size: iconSize,
                  color: iconColor,
                ),
              ),
              Positioned(
                right: size > 80 ? 10 : 4,
                child: Icon(
                  Icons.keyboard_arrow_right_rounded,
                  size: iconSize,
                  color: iconColor,
                ),
              ),
              Positioned(
                top: size > 80 ? 10 : 4,
                child: Icon(
                  Icons.keyboard_arrow_up_rounded,
                  size: iconSize,
                  color: iconColor,
                ),
              ),
              Positioned(
                bottom: size > 80 ? 10 : 4,
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: iconSize,
                  color: iconColor,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
