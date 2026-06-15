import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/controller_branding.dart';
import '../services/host_api_service.dart';
import '../theme/app_colors.dart';
import '../l10n/app_localizations.dart';
import 'layout_editor_view.dart';
import 'layout_preview_widgets.dart';

class LayoutBrowserDialog extends StatefulWidget {
  static const String recentLayoutsKey = 'layout_selector_recent_layout_ids';

  const LayoutBrowserDialog({
    super.key,
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
  State<LayoutBrowserDialog> createState() => _LayoutBrowserDialogState();
}

enum _LayoutDialogView { list, editor }

class _LayoutBrowserDialogState extends State<LayoutBrowserDialog> {
  late PresetCatalog _catalog;
  _LayoutDialogView _currentView = _LayoutDialogView.list;
  ControllerPreset? _editingPreset;
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
      final recent =
          prefs.getStringList(LayoutBrowserDialog.recentLayoutsKey) ??
          <String>[];
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
      if (recentCompare != 0) return recentCompare;
      if (a.id == _catalog.activePresetId) return -1;
      if (b.id == _catalog.activePresetId) return 1;
      if (a.isBuiltIn != b.isBuiltIn) return a.isBuiltIn ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return layouts;
  }

  List<String> get _allPresetNames {
    return [
      ..._catalog.builtInPresets.map((p) => p.name),
      ..._catalog.gamePresets.map((p) => p.name),
      ..._catalog.customPresets.map((p) => p.name),
    ];
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
      if (mounted) setState(() => _saving = false);
    }
  }

  void _openEditor({ControllerPreset? preset}) {
    setState(() {
      _editingPreset = preset;
      _currentView = _LayoutDialogView.editor;
    });
  }

  Future<void> _deleteLayout(ControllerPreset preset) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.screenBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.textPrimary, width: 4),
        ),
        title: Text(
          context.l10n.layoutEditor.deleteLayoutTitle,
          style: const TextStyle(
            fontFamily: 'momo',
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        content: Text(
          context.l10n.layoutEditor.deleteLayoutConfirm(preset.name),
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              context.l10n.common.cancel,
              style: const TextStyle(
                fontFamily: 'momo',
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B6B), // Playful soft red
              foregroundColor: AppColors.textPrimary,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(
                  color: AppColors.textPrimary,
                  width: 3,
                ),
              ),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              context.l10n.layoutEditor.deleteButton,
              style: const TextStyle(
                fontFamily: 'momo',
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _saving = true);
    try {
      await widget.api.deleteCustomPreset(preset.id);
      await _load();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ControllerBrandingMode>(
      valueListenable: widget.brandingModeListenable,
      builder: (context, brandingMode, _) {
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
            constraints: const BoxConstraints(maxWidth: 1120, maxHeight: 760),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      child: _currentView == _LayoutDialogView.list
                          ? Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        context.l10n.layoutEditor.browserTitle,
                                        style: const TextStyle(fontFamily: 'momo', fontSize: 28, color: AppColors.textPrimary),
                                      ),
                                    ),
                                    ElevatedButton.icon(
                                      onPressed: _saving
                                          ? null
                                          : () => _openEditor(),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.highlightColor,
                                        foregroundColor: AppColors.textPrimary,
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          side: const BorderSide(color: AppColors.textPrimary, width: 3),
                                        ),
                                      ),
                                      icon: const Icon(Icons.add_rounded),
                                      label: Text(
                                        context.l10n.layoutEditor.createLayoutButton,
                                        style: const TextStyle(fontFamily: 'momo', fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    IconButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(),
                                      icon: const Icon(Icons.close),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                Expanded(
                                  child: SingleChildScrollView(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _SectionTitle(
                                          title: context.l10n.layoutEditor.basicLayoutsTitle,
                                        ),
                                        const SizedBox(height: 12),
                                        Wrap(
                                          spacing: 16,
                                          runSpacing: 16,
                                          children: _quickLayouts
                                              .map(
                                                (p) => LayoutCard(
                                                  brandingMode: brandingMode,
                                                  preset: p,
                                                  activePresetId:
                                                      _catalog.activePresetId,
                                                  onSelect: _saving
                                                      ? null
                                                      : () => _selectLayout(p),
                                                ),
                                              )
                                              .toList(),
                                        ),
                                        const SizedBox(height: 28),
                                        _SectionTitle(
                                          title: context.l10n.layoutEditor.extraCustomLayoutsTitle,
                                        ),
                                        const SizedBox(height: 12),
                                        Wrap(
                                          spacing: 16,
                                          runSpacing: 16,
                                          children: _specialLayouts
                                              .map(
                                                (p) => LayoutCard(
                                                  brandingMode: brandingMode,
                                                  preset: p,
                                                  activePresetId:
                                                      _catalog.activePresetId,
                                                  badgeLabel: p.isBuiltIn
                                                      ? context.l10n.layoutEditor.badgeGame
                                                      : context.l10n.layoutEditor.badgeCustom,
                                                  onSelect: _saving
                                                      ? null
                                                      : () => _selectLayout(p),
                                                  footer: p.isBuiltIn
                                                      ? null
                                                      : Row(
                                                          children: [
                                                            TextButton.icon(
                                                              onPressed: () =>
                                                                  _openEditor(
                                                                    preset: p,
                                                                  ),
                                                              icon: const Icon(
                                                                Icons
                                                                    .edit_rounded,
                                                              ),
                                                              label: Text(
                                                                context.l10n.layoutEditor.editButton,
                                                              ),
                                                            ),
                                                            TextButton.icon(
                                                              onPressed: () =>
                                                                  _deleteLayout(
                                                                    p,
                                                                  ),
                                                              icon: const Icon(
                                                                Icons
                                                                    .delete_outline_rounded,
                                                              ),
                                                              label: Text(
                                                                context.l10n.layoutEditor.deleteButton,
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
                            )
                          : LayoutEditorView(
                              api: widget.api,
                              preset: _editingPreset,
                              existingNames: _allPresetNames,
                              brandingModeListenable:
                                  widget.brandingModeListenable,
                              onCancel: () => setState(
                                () => _currentView = _LayoutDialogView.list,
                              ),
                              onSaved: (createdPreset) async {
                                if (createdPreset != null) {
                                  await _selectLayout(createdPreset);
                                } else {
                                  await _load();
                                  setState(
                                    () => _currentView = _LayoutDialogView.list,
                                  );
                                }
                              },
                            ),
                    ),
            ),
          ),
        );
      },
    );
  }
}

class LayoutCard extends StatelessWidget {
  const LayoutCard({
    super.key,
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
            color: AppColors.backgroundColor,
            border: Border.all(
              color: isActive ? AppColors.highlightColor : AppColors.textPrimary,
              width: isActive ? 6 : 4,
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
                          displayNameFor(context, preset),
                          style: const TextStyle(fontFamily: 'momo', fontSize: 22, color: AppColors.textPrimary),
                        ),
                        if (badgeLabel != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: AppColors.screenBackground.withValues(alpha: 0.55),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(badgeLabel!, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (isActive)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: AppColors.highlightColor, borderRadius: BorderRadius.circular(999)),
                      child: Text(context.l10n.layoutEditor.activeBadge),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              StructuredLayoutPreview(brandingMode: brandingMode, layout: preset.layout),
              if (footer != null) ...[const SizedBox(height: 12), footer!],
            ],
          ),
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
    return Text(
      title,
      style: const TextStyle(fontFamily: 'momo', fontSize: 22),
    );
  }
}
