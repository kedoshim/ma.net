import 'dart:async';

import 'package:flutter/foundation.dart' show ValueListenable, ValueNotifier;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/controller_branding.dart';
import '../services/host_api_service.dart';
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
  static const String _recentLayoutsKey = 'layout_selector_recent_layout_ids';

  OverlayEntry? _previewEntry;
  ValueNotifier<bool>? _previewVisible;
  Timer? _showTimer;
  Timer? _hideTimer;

  ControllerPreset get _activeLayout => widget.catalog.activePreset;

  @override
  void dispose() {
    _showTimer?.cancel();
    _hideTimer?.cancel();
    _removePreview(immediate: true);
    super.dispose();
  }

  Future<void> _recordRecentLayout(String presetId) async {
    final prefs = await SharedPreferences.getInstance();
    final recent = prefs.getStringList(_recentLayoutsKey) ?? <String>[];
    recent.remove(presetId);
    recent.insert(0, presetId);
    await prefs.setStringList(
      _recentLayoutsKey,
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
          preset: _activeLayout,
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
      builder: (context) => _LayoutBrowserDialog(
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
      child: InkWell(
        onTap: _openBrowser,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.textPrimary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(18),
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
                'Layout: ${_displayNameFor(_activeLayout)}',
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
                        color: AppColors.textPrimary.withValues(alpha: 0.15),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
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
                                _displayNameFor(preset),
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
                        _StructuredLayoutPreview(
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

class _LayoutBrowserDialog extends StatefulWidget {
  const _LayoutBrowserDialog({
    required this.api,
    required this.initialCatalog,
    required this.brandingModeListenable,
    required this.onRecordRecent,
  });

  final HostApiService api;
  final PresetCatalog initialCatalog;
  final ValueListenable<ControllerBrandingMode> brandingModeListenable;
  final Future<void> Function(String presetId) onRecordRecent;

  @override
  State<_LayoutBrowserDialog> createState() => _LayoutBrowserDialogState();
}

class _LayoutBrowserDialogState extends State<_LayoutBrowserDialog> {
  static const String _recentLayoutsKey = 'layout_selector_recent_layout_ids';

  late PresetCatalog _catalog;
  bool _loading = true;
  bool _saving = false;
  List<String> _recentLayoutIds = const <String>[];

  @override
  void initState() {
    super.initState();
    _catalog = widget.initialCatalog;
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final recent = prefs.getStringList(_recentLayoutsKey) ?? <String>[];
      final catalog = await widget.api.fetchPresets();
      if (!mounted) return;
      setState(() {
        _catalog = catalog;
        _recentLayoutIds = recent;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  List<ControllerPreset> get _quickLayouts {
    const builtInOrder = <String, int>{
      'builtin-simple-shoulder': 0,
      'builtin-simple-trigger': 1,
      'builtin-full': 2,
    };
    final builtIns = List<ControllerPreset>.from(_catalog.builtInPresets);
    builtIns.sort((a, b) {
      final aIndex = builtInOrder[a.id] ?? 99;
      final bIndex = builtInOrder[b.id] ?? 99;
      return aIndex.compareTo(bIndex);
    });
    return builtIns;
  }

  List<ControllerPreset> get _specialLayouts {
    final layouts = <ControllerPreset>[
      ..._catalog.gamePresets,
      ..._catalog.customPresets,
    ];

    int rankOf(String id) {
      final index = _recentLayoutIds.indexOf(id);
      return index == -1 ? 1 << 20 : index;
    }

    layouts.sort((a, b) {
      final recentCompare = rankOf(a.id).compareTo(rankOf(b.id));
      if (recentCompare != 0) {
        return recentCompare;
      }

      if (a.id == _catalog.activePresetId) return -1;
      if (b.id == _catalog.activePresetId) return 1;

      if (a.isBuiltIn != b.isBuiltIn) {
        return a.isBuiltIn ? -1 : 1;
      }

      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return layouts;
  }

  Future<void> _selectLayout(ControllerPreset preset) async {
    setState(() => _saving = true);
    try {
      await widget.api.selectPreset(preset.id);
      await widget.onRecordRecent(preset.id);
      final catalog = await widget.api.fetchPresets();
      if (!mounted) return;
      Navigator.of(context).pop(catalog);
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _openEditor({ControllerPreset? preset}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => _LayoutEditorDialog(
        api: widget.api,
        preset: preset,
        brandingModeListenable: widget.brandingModeListenable,
      ),
    );

    if (result == true) {
      await _load();
    }
  }

  Future<void> _deleteLayout(ControllerPreset preset) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.screenBackground,
        title: const Text('Excluir layout'),
        content: Text('Deseja excluir "${preset.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    setState(() => _saving = true);
    try {
      await widget.api.deleteCustomPreset(preset.id);
      await _load();
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ControllerBrandingMode>(
      valueListenable: widget.brandingModeListenable,
      builder: (context, brandingMode, _) {
        return Dialog(
          backgroundColor: AppColors.screenBackground,
          insetPadding: const EdgeInsets.all(32),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
            side: const BorderSide(
              color: AppColors.textPrimary,
              width: AppColors.borderThickness,
            ),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120, maxHeight: 760),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Layouts',
                          style: TextStyle(
                            fontFamily: 'momo',
                            fontSize: 28,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _saving ? null : () => _openEditor(),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Criar layout'),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (_loading)
                    const Expanded(
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _SectionTitle(title: 'Quick Layouts'),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 16,
                              runSpacing: 16,
                              children: _quickLayouts
                                  .map(
                                    (preset) => _LayoutCard(
                                      brandingMode: brandingMode,
                                      preset: preset,
                                      activePresetId: _catalog.activePresetId,
                                      onSelect: _saving
                                          ? null
                                          : () => _selectLayout(preset),
                                    ),
                                  )
                                  .toList(),
                            ),
                            const SizedBox(height: 28),
                            const _SectionTitle(
                              title: 'Extras e Personalizados',
                            ),
                            const SizedBox(height: 12),
                            if (_specialLayouts.isEmpty)
                              Container(
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                child: const Text(
                                  'Ainda nao ha layouts extras. Crie um layout personalizado para jogos especificos.',
                                ),
                              )
                            else
                              Wrap(
                                spacing: 16,
                                runSpacing: 16,
                                children: _specialLayouts
                                    .map(
                                      (preset) => _LayoutCard(
                                        brandingMode: brandingMode,
                                        preset: preset,
                                        activePresetId: _catalog.activePresetId,
                                        badgeLabel: preset.isBuiltIn
                                            ? 'Jogo'
                                            : 'Personalizado',
                                        onSelect: _saving
                                            ? null
                                            : () => _selectLayout(preset),
                                        footer: preset.isBuiltIn
                                            ? null
                                            : Row(
                                                children: [
                                                  TextButton.icon(
                                                    onPressed: _saving
                                                        ? null
                                                        : () => _openEditor(
                                                            preset: preset,
                                                          ),
                                                    icon: const Icon(
                                                      Icons.edit_rounded,
                                                    ),
                                                    label: const Text('Editar'),
                                                  ),
                                                  TextButton.icon(
                                                    onPressed: _saving
                                                        ? null
                                                        : () => _deleteLayout(
                                                            preset,
                                                          ),
                                                    icon: const Icon(
                                                      Icons
                                                          .delete_outline_rounded,
                                                    ),
                                                    label: const Text(
                                                      'Excluir',
                                                    ),
                                                  ),
                                                ],
                                              ),
                                      ),
                                    )
                                    .toList(),
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LayoutCard extends StatelessWidget {
  const _LayoutCard({
    required this.brandingMode,
    required this.preset,
    required this.activePresetId,
    required this.onSelect,
    this.badgeLabel,
    this.footer,
  });

  final ControllerBrandingMode brandingMode;
  final ControllerPreset preset;
  final String activePresetId;
  final VoidCallback? onSelect;
  final String? badgeLabel;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final isActive = preset.id == activePresetId;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onSelect,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          width: 330,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: isActive
                ? AppColors.highlightColor.withValues(alpha: 0.18)
                : AppColors.backgroundColor.withValues(alpha: 0.12),
            border: Border.all(
              color: isActive
                  ? AppColors.highlightColor
                  : AppColors.textPrimary,
              width: 2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _displayNameFor(preset),
                          style: const TextStyle(
                            fontFamily: 'momo',
                            fontSize: 22,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (badgeLabel != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.screenBackground.withValues(
                                alpha: 0.55,
                              ),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: AppColors.textPrimary.withValues(
                                  alpha: 0.2,
                                ),
                              ),
                            ),
                            child: Text(
                              badgeLabel!,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (isActive)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.highlightColor,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text('Atual'),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              _StructuredLayoutPreview(
                brandingMode: brandingMode,
                layout: preset.layout,
              ),
              if (footer != null) ...[const SizedBox(height: 12), footer!],
            ],
          ),
        ),
      ),
    );
  }
}

class _StructuredLayoutPreview extends StatelessWidget {
  const _StructuredLayoutPreview({
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
    final double height = compact ? 100 : 130;
    final Color surface = AppColors.screenBackground.withValues(alpha: 0.9);
    final Color outline = AppColors.textPrimary.withValues(alpha: 0.16);

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
        color: surface,
        border: Border.all(color: outline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 3,
            child: layout.movementMode == 'dpad'
                ? const _PreviewDpad()
                : _PreviewStick(
                    floating: layout.movementMode == 'floatingJoystick',
                  ),
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
                _PreviewColumn(brandingMode: brandingMode, buttons: columns[0]),
                SizedBox(width: compact ? 2 : 4),
                _PreviewColumn(brandingMode: brandingMode, buttons: columns[1]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LayoutEditorDialog extends StatefulWidget {
  const _LayoutEditorDialog({
    required this.api,
    required this.brandingModeListenable,
    this.preset,
  });

  final HostApiService api;
  final ValueListenable<ControllerBrandingMode> brandingModeListenable;
  final ControllerPreset? preset;

  @override
  State<_LayoutEditorDialog> createState() => _LayoutEditorDialogState();
}

class _LayoutEditorDialogState extends State<_LayoutEditorDialog> {
  static const List<String> _allButtons = <String>[
    'Y',
    'B',
    'X',
    'A',
    'RB',
    'RT',
    'LB',
    'LT',
    'RSB',
    'LSB',
  ];

  late final TextEditingController _nameController;
  late String _movementMode;
  late Map<String, bool> _visibleButtons;
  late List<String> _buttonOrder;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final preset = widget.preset;
    _nameController = TextEditingController(text: preset?.name ?? 'Meu layout');
    _movementMode = preset?.layout.movementMode ?? 'floatingJoystick';
    _visibleButtons = <String, bool>{
      for (final buttonId in _allButtons)
        buttonId:
            preset?.layout.visibleButtons[buttonId] ??
            _defaultVisible(buttonId),
    };
    _buttonOrder = List<String>.from(
      preset?.layout.buttonOrder.where(_allButtons.contains) ?? _allButtons,
    );
    for (final buttonId in _allButtons) {
      if (!_buttonOrder.contains(buttonId)) {
        _buttonOrder.add(buttonId);
      }
    }
  }

  static bool _defaultVisible(String buttonId) {
    return const <String>{'A', 'B', 'X', 'Y', 'LB', 'RB'}.contains(buttonId);
  }

  Future<void> _save() async {
    setState(() => _saving = true);

    final layout = ControllerPresetLayout(
      movementMode: _movementMode,
      visibleButtons: _visibleButtons,
      buttonOrder: _buttonOrder,
    );

    try {
      if (widget.preset == null) {
        await widget.api.createCustomPreset(
          name: _nameController.text.trim(),
          layout: layout,
        );
      } else {
        await widget.api.updateCustomPreset(
          presetId: widget.preset!.id,
          name: _nameController.text.trim(),
          layout: layout,
        );
      }

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ControllerBrandingMode>(
      valueListenable: widget.brandingModeListenable,
      builder: (context, brandingMode, _) {
        return Dialog(
          backgroundColor: AppColors.screenBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: AppColors.textPrimary, width: 2),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900, maxHeight: 760),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.preset == null ? 'Criar layout' : 'Editar layout',
                      style: const TextStyle(
                        fontFamily: 'momo',
                        fontSize: 24,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _EditorField(controller: _nameController, label: 'Nome'),
                    const SizedBox(height: 20),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Movimento',
                                style: TextStyle(
                                  fontFamily: 'momo',
                                  fontSize: 18,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                direction: Axis.vertical,
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  _MovementChoiceChip(
                                    label: 'D-Pad',
                                    description:
                                        'Melhor para precisao e plataforma',
                                    selected: _movementMode == 'dpad',
                                    onTap: () =>
                                        setState(() => _movementMode = 'dpad'),
                                  ),
                                  _MovementChoiceChip(
                                    label: 'Joystick fixo',
                                    description: 'Sempre visivel e previsivel',
                                    selected: _movementMode == 'fixedJoystick',
                                    onTap: () => setState(
                                      () => _movementMode = 'fixedJoystick',
                                    ),
                                  ),
                                  _MovementChoiceChip(
                                    label: 'Joystick flutuante',
                                    description:
                                        'Recomendado na maioria dos casos',
                                    selected:
                                        _movementMode == 'floatingJoystick',
                                    onTap: () => setState(
                                      () => _movementMode = 'floatingJoystick',
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Botoes visiveis',
                                style: TextStyle(
                                  fontFamily: 'momo',
                                  fontSize: 18,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _allButtons.map((buttonId) {
                                  final isVisible =
                                      _visibleButtons[buttonId] == true;
                                  final presentation =
                                      ControllerBranding.presentationFor(
                                        buttonId,
                                        brandingMode,
                                      );
                                  return FilterChip(
                                    tooltip: presentation.semanticLabel,
                                    label: ControllerButtonBrand(
                                      presentation: presentation,
                                      size: 18,
                                      textColor: AppColors.textPrimary,
                                    ),
                                    selected: isVisible,
                                    onSelected: (selected) {
                                      setState(
                                        () => _visibleButtons[buttonId] =
                                            selected,
                                      );
                                    },
                                    backgroundColor: AppColors.backgroundColor
                                        .withValues(alpha: 0.12),
                                    selectedColor: AppColors.highlightColor
                                        .withValues(alpha: 0.18),
                                    checkmarkColor: presentation.accentColor,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: BorderSide(
                                        color: isVisible
                                            ? presentation.accentColor
                                            : AppColors.textPrimary,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 24),
                              const Text(
                                'Ordem (arraste os botoes no preview)',
                                style: TextStyle(
                                  fontFamily: 'momo',
                                  fontSize: 18,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  color: AppColors.backgroundColor.withValues(
                                    alpha: 0.18,
                                  ),
                                  border: Border.all(
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                child: _ReorderLayoutPreview(
                                  brandingMode: brandingMode,
                                  layout: ControllerPresetLayout(
                                    movementMode: _movementMode,
                                    visibleButtons: _visibleButtons,
                                    buttonOrder: _buttonOrder,
                                  ),
                                  onReorder: (draggedId, targetId) {
                                    setState(() {
                                      final draggedIndex = _buttonOrder.indexOf(
                                        draggedId,
                                      );
                                      final targetIndex = _buttonOrder.indexOf(
                                        targetId,
                                      );
                                      if (draggedIndex != -1 &&
                                          targetIndex != -1) {
                                        final temp = _buttonOrder[draggedIndex];
                                        _buttonOrder[draggedIndex] =
                                            _buttonOrder[targetIndex];
                                        _buttonOrder[targetIndex] = temp;
                                      }
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: _saving
                              ? null
                              : () => Navigator.of(context).pop(false),
                          child: const Text('Cancelar'),
                        ),
                        const SizedBox(width: 12),
                        FilledButton(
                          onPressed: _saving ? null : _save,
                          child: Text(
                            widget.preset == null ? 'Criar' : 'Salvar',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ReorderLayoutPreview extends StatelessWidget {
  const _ReorderLayoutPreview({
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
    final visible = layout.buttonOrder
        .where((buttonId) => layout.visibleButtons[buttonId] == true)
        .toList();

    final columns = _splitIntoColumns(visible);

    return Container(
      height: 140,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: AppColors.screenBackground.withValues(alpha: 0.9),
        border: Border.all(
          color: AppColors.textPrimary.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 3,
            child: layout.movementMode == 'dpad'
                ? const _PreviewDpad()
                : _PreviewStick(
                    floating: layout.movementMode == 'floatingJoystick',
                  ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Text(
                  'ma net',
                  style: TextStyle(
                    fontSize: 10,
                    fontFamily: 'momo',
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _PreviewCenterButton(label: 'L'),
                    SizedBox(width: 4),
                    _PreviewCenterButton(label: 'R'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Row(
              children: [
                _PreviewColumn(
                  brandingMode: brandingMode,
                  buttons: columns[0],
                  onReorder: onReorder,
                ),
                const SizedBox(width: 4),
                _PreviewColumn(
                  brandingMode: brandingMode,
                  buttons: columns[1],
                  onReorder: onReorder,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewCenterButton extends StatelessWidget {
  const _PreviewCenterButton({required this.label});

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
        border: Border.all(color: AppColors.textPrimary, width: 1),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 8, color: AppColors.textPrimary),
      ),
    );
  }
}

class _PreviewColumn extends StatelessWidget {
  const _PreviewColumn({
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
              border: Border.all(color: AppColors.textPrimary, width: 1),
            ),
            child: ControllerButtonBrand(
              presentation: presentation,
              size: 14,
              textColor: AppColors.textPrimary,
            ),
          );

          final content = Padding(padding: const EdgeInsets.all(2), child: box);

          if (onReorder == null) {
            return Expanded(child: content);
          }

          return Expanded(
            child: DragTarget<String>(
              onWillAcceptWithDetails: (details) => details.data != buttonId,
              onAcceptWithDetails: (details) =>
                  onReorder!(details.data, buttonId),
              builder: (context, candidateData, rejectedData) {
                final isTarget = candidateData.isNotEmpty;
                return Draggable<String>(
                  data: buttonId,
                  feedback: Material(
                    color: Colors.transparent,
                    child: SizedBox(width: 60, height: 30, child: box),
                  ),
                  childWhenDragging: Opacity(opacity: 0.3, child: content),
                  child: Container(
                    foregroundDecoration: isTarget
                        ? BoxDecoration(
                            border: Border.all(color: Colors.green, width: 2),
                            borderRadius: BorderRadius.circular(8),
                          )
                        : null,
                    child: content,
                  ),
                );
              },
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _PreviewDpad extends StatelessWidget {
  const _PreviewDpad();

  @override
  Widget build(BuildContext context) {
    Widget box() => Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: AppColors.backgroundColor,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.textPrimary, width: 1),
      ),
    );

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Container(
        alignment: Alignment.center,
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
      ),
    );
  }
}

class _PreviewStick extends StatelessWidget {
  const _PreviewStick({required this.floating});

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
              border: Border.all(color: AppColors.textPrimary, width: 1),
              color: floating ? AppColors.screenBackground : Colors.transparent,
              boxShadow: floating
                  ? [
                      BoxShadow(
                        color: AppColors.textPrimary.withValues(alpha: 0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
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

class _MovementChoiceChip extends StatelessWidget {
  const _MovementChoiceChip({
    required this.label,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: selected
              ? AppColors.highlightColor.withValues(alpha: 0.16)
              : Colors.transparent,
          border: Border.all(
            color: selected ? AppColors.highlightColor : AppColors.textPrimary,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(description),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'momo',
            fontSize: 22,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _EditorField extends StatelessWidget {
  const _EditorField({required this.controller, required this.label});

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      child: TextField(
        controller: controller,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }
}

String _displayNameFor(ControllerPreset preset) {
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
