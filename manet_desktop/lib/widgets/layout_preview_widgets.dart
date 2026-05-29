import 'package:flutter/material.dart';
import '../models/controller_branding.dart';
import '../services/host_api_service.dart';
import '../theme/app_colors.dart';

String displayNameFor(ControllerPreset preset) {
  switch (preset.id) {
    case 'builtin-simple-shoulder':
      return 'Simples';
    case 'builtin-simple-trigger':
      return 'Padrao';
    case 'builtin-full':
      return 'Completo';
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

  @override
  Widget build(BuildContext context) {
    final double height = compact ? 100 : 140;

    final visible = layout.buttonOrder
        .where((buttonId) => layout.visibleButtons[buttonId] == true)
        .toList();

    final columns = _splitIntoColumns(visible);

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
            child: Row(
              children: [
                PreviewColumn(brandingMode: brandingMode, buttons: columns[0]),
                SizedBox(width: compact ? 2 : 4),
                PreviewColumn(brandingMode: brandingMode, buttons: columns[1]),
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

  @override
  Widget build(BuildContext context) {
    final Color surface = AppColors.backgroundColor;

    final visible = layout.buttonOrder
        .where((buttonId) => layout.visibleButtons[buttonId] == true)
        .toList();

    final columns = _splitIntoColumns(visible);

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
                child: layout.movementMode == 'dpad'
                    ? const PreviewDpad()
                    : PreviewStick(
                        floating: layout.movementMode == 'floatingJoystick',
                      ),
              ).scale(1.15),
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
                child: Row(
                  children: [
                    PreviewColumn(
                      brandingMode: brandingMode,
                      buttons: columns[0],
                      onReorder: onReorder,
                    ),
                    const SizedBox(width: 6),
                    PreviewColumn(
                      brandingMode: brandingMode,
                      buttons: columns[1],
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
    this.onReorder,
  });
  final ControllerBrandingMode brandingMode;
  final List<String> buttons;
  final void Function(String, String)? onReorder;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: buttons.map((buttonId) {
          final presentation = ControllerBranding.presentationFor(
            buttonId,
            brandingMode,
          );
          final box = Container(
            width: double.infinity,
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

          final content = Padding(padding: const EdgeInsets.all(2), child: box);
          if (onReorder == null) return Expanded(child: content);

          return Expanded(
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
        }).toList(),
      ),
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
