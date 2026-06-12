import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import '../models/controller_branding.dart';
import '../services/host_api_service.dart';
import '../theme/app_colors.dart';
import '../l10n/app_localizations.dart';
import 'layout_preview_widgets.dart';

class LayoutEditorView extends StatefulWidget {
  const LayoutEditorView({
    super.key,
    required this.api,
    required this.brandingModeListenable,
    this.preset,
    required this.onCancel,
    required this.onSaved,
  });

  final HostApiService api;
  final ValueListenable<ControllerBrandingMode> brandingModeListenable;
  final ControllerPreset? preset;
  final VoidCallback onCancel;
  final VoidCallback onSaved;

  @override
  State<LayoutEditorView> createState() => _LayoutEditorViewState();
}

class _LayoutEditorViewState extends State<LayoutEditorView> {
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

  static const List<String> _rightStickButtons = <String>[
    'RS_FIXED',
    'RS_BUTTON',
    'RS_SWIPE',
  ];

  late final TextEditingController _nameController;
  late String _movementMode;
  late Map<String, bool> _visibleButtons;
  late List<String> _buttonOrder;
  late String _rightLayoutMode;
  late Map<String, int> _buttonSizes;
  bool _saving = false;
  bool _nameInitialized = false;

  @override
  void initState() {
    super.initState();
    final preset = widget.preset;
    _nameController = TextEditingController(
      text: preset?.name ?? '',
    );
    _movementMode = preset?.layout.movementMode ?? 'floatingJoystick';
    _rightLayoutMode = preset?.layout.rightLayoutMode ?? 'columns';
    _buttonSizes = Map<String, int>.from(preset?.layout.buttonSizes ?? const <String, int>{});
    _visibleButtons = <String, bool>{
      for (final id in _allButtons)
        id: preset?.layout.visibleButtons[id] ?? _defaultVisible(id),
      for (final id in _rightStickButtons)
        id: preset?.layout.visibleButtons[id] ?? false,
    };
    final allowedButtons = <String>[..._allButtons, ..._rightStickButtons];
    _buttonOrder = List<String>.from(
      preset?.layout.buttonOrder.where(allowedButtons.contains) ?? allowedButtons,
    );
    for (final id in allowedButtons) {
      if (!_buttonOrder.contains(id)) _buttonOrder.add(id);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_nameInitialized) {
      if (_nameController.text.isEmpty && widget.preset == null) {
        _nameController.text = context.l10n.layoutEditor.defaultNewLayoutName;
      }
      _nameInitialized = true;
    }
  }

  static bool _defaultVisible(String id) =>
      const {'LB', 'RB', 'A', 'B', 'X', 'Y'}.contains(id);

  Future<void> _save() async {
    setState(() => _saving = true);
    final layout = ControllerPresetLayout(
      movementMode: _movementMode,
      visibleButtons: _visibleButtons,
      buttonOrder: _buttonOrder,
      rightLayoutMode: _rightLayoutMode,
      buttonSizes: _buttonSizes,
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
      if (mounted) widget.onSaved();
    } finally {
      if (mounted) setState(() => _saving = false);
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
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: widget.onCancel,
                  icon: const Icon(Icons.arrow_back_ios_new_rounded),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    style: const TextStyle(
                      fontFamily: 'momo',
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      hintText: context.l10n.layoutEditor.nameHint,
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(
                          color: AppColors.textPrimary.withValues(alpha: 0.1),
                          width: 4,
                        ),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(
                          color: AppColors.highlightColor,
                          width: 4,
                        ),
                      ),
                      hintStyle: TextStyle(
                        color: AppColors.textPrimary.withValues(alpha: 0.2),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.highlightColor,
                    foregroundColor: AppColors.textPrimary,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 20,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(
                        color: AppColors.textPrimary,
                        width: 3,
                      ),
                    ),
                  ),
                  child: Text(
                    widget.preset == null
                        ? context.l10n.layoutEditor.createButtonUpper
                        : context.l10n.layoutEditor.saveButtonUpper,
                    style: const TextStyle(
                      fontFamily: 'momo',
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.layoutEditor.movementModeTitle,
                          style: TextStyle(
                            fontFamily: 'momo',
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                            color: AppColors.textPrimary.withValues(alpha: 0.5),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _MovementChoiceChip(
                          label: context.l10n.layoutEditor.dpadLabel,
                          icon: Icons.grid_view_rounded,
                          headline: context.l10n.layoutEditor.dpadHeadline,
                          description: context.l10n.layoutEditor.dpadDesc,
                          selected: _movementMode == 'dpad',
                          onTap: () => setState(() => _movementMode = 'dpad'),
                        ),
                        const SizedBox(height: 12),
                        _MovementChoiceChip(
                          label: context.l10n.layoutEditor.fixedJoystickLabel,
                          icon: Icons.radio_button_checked,
                          headline: context.l10n.layoutEditor.fixedJoystickHeadline,
                          description: context.l10n.layoutEditor.fixedJoystickDesc,
                          selected: _movementMode == 'fixedJoystick',
                          onTap: () =>
                              setState(() => _movementMode = 'fixedJoystick'),
                        ),
                        const SizedBox(height: 12),
                        _MovementChoiceChip(
                          label: context.l10n.layoutEditor.floatingJoystickLabel,
                          icon: Icons.gesture_rounded,
                          headline: context.l10n.layoutEditor.floatingJoystickHeadline,
                          description: context.l10n.layoutEditor.floatingJoystickDesc,
                          selected: _movementMode == 'floatingJoystick',
                          onTap: () => setState(
                            () => _movementMode = 'floatingJoystick',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    flex: 6,
                    child: ReorderLayoutPreview(
                      brandingMode: brandingMode,
                      layout: ControllerPresetLayout(
                        movementMode: _movementMode,
                        visibleButtons: _visibleButtons,
                        buttonOrder: _buttonOrder,
                        rightLayoutMode: _rightLayoutMode,
                        buttonSizes: _buttonSizes,
                      ),
                      onReorder: (draggedId, targetId) {
                        setState(() {
                          final dIdx = _buttonOrder.indexOf(draggedId);
                          final tIdx = _buttonOrder.indexOf(targetId);
                          if (dIdx != -1 && tIdx != -1) {
                            final temp = _buttonOrder[dIdx];
                            _buttonOrder[dIdx] = _buttonOrder[tIdx];
                            _buttonOrder[tIdx] = temp;
                          }
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    flex: 3,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.l10n.layoutEditor.visibleButtonsTitle,
                            style: TextStyle(
                              fontFamily: 'momo',
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                              color: AppColors.textPrimary.withValues(alpha: 0.5),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: _allButtons.map((id) {
                              return _EditorToggleChip(
                                presentation: ControllerBranding.presentationFor(
                                  id,
                                  brandingMode,
                                ),
                                isSelected: _visibleButtons[id] == true,
                                onTap: (val) =>
                                    setState(() => _visibleButtons[id] = val),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.highlightColor.withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.highlightColor.withValues(
                                  alpha: 0.2,
                                ),
                                width: 2,
                              ),
                            ),
                            child: Text(
                              context.l10n.layoutEditor.visibleButtonsTip,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                height: 1.4,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            context.l10n.layoutEditor.rightLayoutTitle,
                            style: TextStyle(
                              fontFamily: 'momo',
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                              color: AppColors.textPrimary.withValues(alpha: 0.5),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _buildLayoutModeSegment('columns', context.l10n.layoutEditor.rightLayoutColumnsLabel),
                              const SizedBox(width: 12),
                              _buildLayoutModeSegment('rows', context.l10n.layoutEditor.rightLayoutRowsLabel),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Text(
                            context.l10n.layoutEditor.rightSticksTitle,
                            style: TextStyle(
                              fontFamily: 'momo',
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                              color: AppColors.textPrimary.withValues(alpha: 0.5),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildRightStickRow('RS_FIXED', context.l10n.layoutEditor.rightStickFixedLabel),
                          const SizedBox(height: 12),
                          _buildRightStickRow('RS_BUTTON', context.l10n.layoutEditor.rightStickFloatingLabel),
                          const SizedBox(height: 12),
                          _buildRightStickRow('RS_SWIPE', context.l10n.layoutEditor.rightStickSwipeLabel),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLayoutModeSegment(String mode, String label) {
    final isSelected = _rightLayoutMode == mode;
    return InkWell(
      onTap: () {
        setState(() {
          _rightLayoutMode = mode;
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.highlightColor
              : AppColors.backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppColors.textPrimary
                : AppColors.textPrimary.withValues(alpha: 0.1),
            width: 2.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'momo',
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: isSelected
                ? AppColors.textPrimary
                : AppColors.textPrimary.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }

  Widget _buildRightStickRow(String id, String label) {
    final isVisible = _visibleButtons[id] == true;
    final supportsSize = id == 'RS_BUTTON' || id == 'RS_SWIPE';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Checkbox(
              value: isVisible,
              activeColor: AppColors.highlightColor,
              checkColor: AppColors.textPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              side: const BorderSide(color: AppColors.textPrimary, width: 2),
              onChanged: (val) {
                setState(() {
                  _visibleButtons[id] = val == true;
                  if (val == true && !_buttonOrder.contains(id)) {
                    _buttonOrder.add(id);
                  }
                });
              },
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'momo',
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
        if (isVisible && supportsSize) ...[
          Padding(
            padding: const EdgeInsets.only(left: 36, bottom: 8, top: 4),
            child: Row(
              children: [
                _buildSizeToggleChip(id, 1, 'Flex 1'),
                const SizedBox(width: 8),
                _buildSizeToggleChip(id, 2, 'Flex 2'),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSizeToggleChip(String id, int value, String label) {
    final defaultFlex = id == 'RS_SWIPE' ? 2 : 1;
    final currentValue = _buttonSizes[id] ?? defaultFlex;
    final isSelected = currentValue == value;

    return InkWell(
      onTap: () {
        setState(() {
          _buttonSizes[id] = value;
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.highlightColor
              : AppColors.backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppColors.textPrimary
                : AppColors.textPrimary.withValues(alpha: 0.1),
            width: 2,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'momo',
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: isSelected
                ? AppColors.textPrimary
                : AppColors.textPrimary.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }
}

class _MovementChoiceChip extends StatelessWidget {
  const _MovementChoiceChip({
    required this.label,
    required this.headline,
    required this.description,
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final String headline;
  final String description;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.highlightColor
              : AppColors.backgroundColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected
                ? AppColors.textPrimary
                : AppColors.textPrimary.withValues(alpha: 0.1),
            width: 4,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 32, color: AppColors.textPrimary),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    headline,
                    style: const TextStyle(
                      fontFamily: 'momo',
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditorToggleChip extends StatelessWidget {
  const _EditorToggleChip({
    required this.presentation,
    required this.isSelected,
    required this.onTap,
  });
  final ControllerButtonPresentation presentation;
  final bool isSelected;
  final ValueChanged<bool> onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onTap(!isSelected),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.highlightColor
              : AppColors.backgroundColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppColors.textPrimary
                : AppColors.textPrimary.withValues(alpha: 0.1),
            width: 3,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white
                    : presentation.accentColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: isSelected
                    ? Border.all(color: AppColors.textPrimary, width: 2)
                    : null,
              ),
              child: Center(
                child: ControllerButtonBrand(
                  presentation: presentation,
                  size: 14,
                  textColor: isSelected
                      ? AppColors.textPrimary
                      : presentation.accentColor,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              presentation.shortLabel,
              style: TextStyle(
                fontFamily: 'momo',
                fontWeight: FontWeight.w900,
                color: isSelected
                    ? AppColors.textPrimary
                    : AppColors.textPrimary.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
