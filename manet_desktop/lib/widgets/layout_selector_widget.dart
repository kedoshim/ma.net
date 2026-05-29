import 'dart:async';

import 'package:flutter/foundation.dart' show ValueListenable, ValueNotifier;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/controller_branding.dart';
import '../services/host_api_service.dart';
import 'layout_browser_dialog.dart';
import 'layout_preview_widgets.dart';
import '../theme/app_colors.dart';

class LayoutSelectorWidget extends StatefulWidget {
  const LayoutSelectorWidget({
    super.key,
    required this.api,
    required this.catalog,
    required this.brandingModeListenable,
    this.onCatalogChanged,
  });

  final HostApiService api;
  final PresetCatalog catalog;
  final ValueListenable<ControllerBrandingMode> brandingModeListenable;
  final ValueChanged<PresetCatalog>? onCatalogChanged;

  @override
  State<LayoutSelectorWidget> createState() => _LayoutSelectorWidgetState();
}

class _LayoutSelectorWidgetState extends State<LayoutSelectorWidget> {
  OverlayEntry? _previewEntry;
  ValueNotifier<bool>? _previewVisible;
  Timer? _showTimer;
  Timer? _hideTimer;

  @override
  void dispose() {
    _showTimer?.cancel();
    _hideTimer?.cancel();
    _removePreview(immediate: true);
    super.dispose();
  }

  Future<void> _recordRecentLayout(String presetId) async {
    final prefs = await SharedPreferences.getInstance();
    final recent =
        prefs.getStringList(LayoutBrowserDialog.recentLayoutsKey) ?? <String>[];
    recent.remove(presetId);
    recent.insert(0, presetId);
    await prefs.setStringList(
      LayoutBrowserDialog.recentLayoutsKey,
      recent.take(24).toList(growable: false),
    );
  }

  Future<void> _handleCatalogRefresh(PresetCatalog catalog) async {
    if (!mounted) return;
    widget.onCatalogChanged?.call(catalog);
  }

  void _schedulePreviewOpen() {
    _hideTimer?.cancel();
    _showTimer?.cancel();
    _showTimer = Timer(const Duration(milliseconds: 110), _showPreview);
  }

  void _schedulePreviewClose() {
    _showTimer?.cancel();
    _hideTimer?.cancel();
    _hideTimer = Timer(
      const Duration(milliseconds: 120),
      () => _removePreview(),
    );
  }

  void _showPreview() {
    if (!mounted || _previewEntry != null) {
      return;
    }

    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    _previewVisible = ValueNotifier<bool>(true);
    _previewEntry = OverlayEntry(
      builder: (context) {
        final overlay = Overlay.of(context, rootOverlay: true);
        final RenderBox overlayBox =
            overlay.context.findRenderObject() as RenderBox;

        final size = renderBox.size;
        final position = renderBox.localToGlobal(
          Offset.zero,
          ancestor: overlayBox,
        );

        return _HoverPreviewOverlay(
          targetPosition: position,
          targetSize: size,
          overlaySize: overlayBox.size,
          visibleListenable: _previewVisible!,
          brandingModeListenable: widget.brandingModeListenable,
          preset: widget.catalog.activePreset,
        );
      },
    );
    Overlay.of(context, rootOverlay: true).insert(_previewEntry!);
  }

  void _removePreview({bool immediate = false}) {
    _showTimer?.cancel();
    _hideTimer?.cancel();
    if (_previewEntry == null) {
      return;
    }

    final entry = _previewEntry;
    final visible = _previewVisible;
    _previewEntry = null;
    _previewVisible = null;

    if (immediate || visible == null) {
      entry?.remove();
      visible?.dispose();
      return;
    }

    visible.value = false;
    Future<void>.delayed(const Duration(milliseconds: 150), () {
      entry?.remove();
      visible.dispose();
    });
  }

  Future<void> _openBrowser() async {
    _removePreview(immediate: true);
    final updatedCatalog = await showDialog<PresetCatalog>(
      context: context,
      builder: (context) => LayoutBrowserDialog(
        api: widget.api,
        initialCatalog: widget.catalog,
        brandingModeListenable: widget.brandingModeListenable,
        onRecordRecent: _recordRecentLayout,
      ),
    );

    if (updatedCatalog != null) {
      await _handleCatalogRefresh(updatedCatalog);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _schedulePreviewOpen(),
      onExit: (_) => _schedulePreviewClose(),
      cursor: SystemMouseCursors.click,
      child: InkWell(
        onTap: _openBrowser,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: AppColors.highlightColor,
              width: 1.5,
            )
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.gamepad_rounded,
                color: AppColors.textPrimary,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'Layout: ${displayNameFor(widget.catalog.activePreset)}',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: AppColors.textPrimary,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HoverPreviewOverlay extends StatelessWidget {
  const _HoverPreviewOverlay({
    required this.targetPosition,
    required this.targetSize,
    required this.overlaySize,
    required this.visibleListenable,
    required this.brandingModeListenable,
    required this.preset,
  });

  final Offset targetPosition;
  final Size targetSize;
  final Size overlaySize;
  final ValueListenable<bool> visibleListenable;
  final ValueListenable<ControllerBrandingMode> brandingModeListenable;
  final ControllerPreset preset;

  @override
  Widget build(BuildContext context) {
    const double previewWidth = 240.0;
    const double padding = 16.0;

    double x = targetPosition.dx + (targetSize.width / 2) - (previewWidth / 2);
    if (x < padding) x = padding;
    if (x + previewWidth > overlaySize.width - padding) {
      x = overlaySize.width - padding - previewWidth;
    }

    bool showBelow = targetPosition.dy < 160;

    return Positioned(
      left: x,
      bottom: showBelow ? null : overlaySize.height - targetPosition.dy + 12,
      top: showBelow ? targetPosition.dy + targetSize.height + 12 : null,
      child: Material(
        color: Colors.transparent,
        child: ValueListenableBuilder<bool>(
          valueListenable: visibleListenable,
          builder: (context, visible, _) {
            return TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.0, end: visible ? 1.0 : 0.0),
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                final opacity = value.clamp(0.0, 1.0);
                final scale = 0.95 + (0.05 * value);
                return Opacity(
                  opacity: opacity,
                  child: Transform.scale(
                    scale: scale,
                    alignment: showBelow
                        ? Alignment.topCenter
                        : Alignment.bottomCenter,
                    child: child,
                  ),
                );
              },
              child: ValueListenableBuilder<ControllerBrandingMode>(
                valueListenable: brandingModeListenable,
                builder: (context, brandingMode, _) {
                  return Container(
                    width: previewWidth,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.screenBackground,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.textPrimary,
                        width: 2.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.textPrimary.withValues(alpha: 0.1),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.gamepad_rounded,
                              size: 14,
                              color: AppColors.textPrimary.withValues(
                                alpha: 0.7,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                displayNameFor(preset),
                                style: const TextStyle(
                                  fontFamily: 'momo',
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        StructuredLayoutPreview(
                          brandingMode: brandingMode,
                          layout: preset.layout,
                          compact: true,
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
