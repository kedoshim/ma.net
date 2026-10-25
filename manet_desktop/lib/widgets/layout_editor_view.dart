import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import '../models/controller_branding.dart';
import '../models/layout_draft.dart';
import '../services/host_api_service.dart';
import '../theme/app_colors.dart';
import '../l10n/app_localizations.dart';
import 'editable_layout_preview.dart';
import 'juicy_widgets.dart';

class LayoutEditorView extends StatefulWidget {
  const LayoutEditorView({
    super.key,
    required this.api,
    required this.brandingModeListenable,
    this.preset,
    required this.existingNames,
    required this.onCancel,
    required this.onSaved,
  });

  final HostApiService api;
  final ValueListenable<ControllerBrandingMode> brandingModeListenable;
  final ControllerPreset? preset;
  final List<String> existingNames;
  final VoidCallback onCancel;
  final ValueChanged<ControllerPreset?> onSaved;

  @override
  State<LayoutEditorView> createState() => _LayoutEditorViewState();
}

/// Three columns: options for the whole controller, the preview (where
/// buttons are picked and dragged around) and the picked button's options.
class _LayoutEditorViewState extends State<LayoutEditorView> {
  late final TextEditingController _nameController;
  late final LayoutDraft _draft;
  String? _selectedId;
  bool _dragging = false;
  bool _saving = false;
  bool _nameInitialized = false;

  @override
  void initState() {
    super.initState();
    final preset = widget.preset;
    _nameController = TextEditingController(
      text: preset?.name ?? '',
    );
    _draft = LayoutDraft.from(preset?.layout);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_nameInitialized) {
      if (_nameController.text.isEmpty && widget.preset == null) {
        _nameController.text = _generateNextDefaultName(
          context.l10n.layoutEditor.defaultNewLayoutName,
          widget.existingNames,
        );
      }
      _nameInitialized = true;
    }
  }

  String _generateNextDefaultName(String baseName, List<String> existingNames) {
    final regExp = RegExp(r'^(.*?)\s*(\d+)$');
    final match = regExp.firstMatch(baseName);

    String base;
    String numStr;
    if (match != null) {
      base = match.group(1)?.trim() ?? baseName;
      numStr = match.group(2) ?? '001';
    } else {
      base = baseName;
      numStr = '001';
    }

    int padding = numStr.length;
    int num = int.tryParse(numStr) ?? 1;

    final existingLower = existingNames.map((n) => n.toLowerCase()).toSet();

    while (true) {
      final formattedNum = num.toString().padLeft(padding, '0');
      final candidateName = '$base $formattedNum';
      if (!existingLower.contains(candidateName.toLowerCase())) {
        return candidateName;
      }
      num++;
    }
  }

  void _showValidationError(String message) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.screenBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.textPrimary, width: 4),
        ),
        title: Text(
          context.l10n.common.error,
          style: const TextStyle(
            fontFamily: 'momo',
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        content: Text(
          message,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 16),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.highlightColor,
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
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              context.l10n.common.ok,
              style: const TextStyle(
                fontFamily: 'momo',
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showValidationError(context.l10n.layoutEditor.nameEmptyError);
      return;
    }

    final lowerName = name.toLowerCase();
    final isDuplicate = widget.existingNames.any((existing) {
      if (widget.preset != null &&
          existing.toLowerCase() == widget.preset!.name.toLowerCase()) {
        return false;
      }
      return existing.toLowerCase() == lowerName;
    });

    if (isDuplicate) {
      _showValidationError(context.l10n.layoutEditor.duplicateNameError);
      return;
    }

    setState(() => _saving = true);
    final layout = _draft.toLayout();
    try {
      ControllerPreset? createdPreset;
      if (widget.preset == null) {
        createdPreset = await widget.api.createCustomPreset(
          name: name,
          layout: layout,
        );
      } else {
        await widget.api.updateCustomPreset(
          presetId: widget.preset!.id,
          name: name,
          layout: layout,
        );
      }
      if (mounted) widget.onSaved(createdPreset);
    } catch (exc) {
      if (mounted) {
        _showValidationError(exc.toString());
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _edit(VoidCallback change) => setState(change);

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
            const SizedBox(height: 20),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 3,
                    child: SingleChildScrollView(child: _controllerOptions()),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    flex: 6,
                    child: Column(
                      children: [
                        Expanded(
                          child: EditableLayoutPreview(
                            brandingMode: brandingMode,
                            draft: _draft,
                            selectedId: _selectedId,
                            dragging: _dragging,
                            onSelect: (id) => _edit(() => _selectedId = id),
                            onDragChanged: (value) =>
                                setState(() => _dragging = value),
                            onDropLeft: (id, slot) => _edit(() {
                              _draft.moveToLeft(id, slot);
                              _selectedId = id;
                            }),
                            onDropRight: (id, target) => _edit(() {
                              _draft.moveToRight(id, target: target);
                              _selectedId = id;
                            }),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          context.l10n.layoutEditor.dragToLeftHint,
                          textAlign: TextAlign.center,
                          style: _tipStyle,
                        ),
                        const SizedBox(height: 12),
                        _tray(brandingMode),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    flex: 3,
                    child: SingleChildScrollView(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 260),
                        switchInCurve: Curves.easeOutBack,
                        transitionBuilder: (child, animation) =>
                            ScaleTransition(
                              scale: Tween(begin: 0.9, end: 1.0)
                                  .animate(animation),
                              child: FadeTransition(
                                opacity: animation,
                                child: child,
                              ),
                            ),
                        child: KeyedSubtree(
                          key: ValueKey(_selectedId),
                          child: _inspector(brandingMode),
                        ),
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

  // --- whole controller ---

  Widget _controllerOptions() {
    final strings = context.l10n.layoutEditor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _title(strings.movementModeTitle),
        const SizedBox(height: 10),
        for (final (mode, icon, headline, description) in [
          ('dpad', Icons.grid_view_rounded, strings.dpadHeadline, strings.dpadDesc),
          ('fixedJoystick', Icons.radio_button_checked, strings.fixedJoystickHeadline, strings.fixedJoystickDesc),
          ('floatingJoystick', Icons.gesture_rounded, strings.floatingJoystickHeadline, strings.floatingJoystickDesc),
        ]) ...[
          _MovementChoiceChip(
            icon: icon,
            headline: headline,
            description: description,
            selected: _draft.movementMode == mode,
            onTap: () => _edit(() => _draft.movementMode = mode),
          ),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 16),
        _title(strings.rightLayoutTitle),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final (mode, label) in [
              ('columns', strings.rightLayoutColumnsLabel),
              ('rows', strings.rightLayoutRowsLabel),
            ])
              _segment(
                label: label,
                isSelected: _draft.rightLayoutMode == mode,
                onTap: () => _edit(() => _draft.rightLayoutMode = mode),
              ),
          ],
        ),
        const SizedBox(height: 24),
        _title(strings.rightSticksTitle),
        const SizedBox(height: 6),
        for (final id in LayoutDraft.rightSticks) _stickRow(id),
      ],
    );
  }

  Widget _stickRow(String id) {
    return Row(
      children: [
        Checkbox(
          value: _draft.isVisible(id),
          activeColor: AppColors.highlightColor,
          checkColor: AppColors.textPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          side: const BorderSide(color: AppColors.textPrimary, width: 2),
          onChanged: (value) => _edit(() {
            _draft.setVisible(id, value == true);
            if (value == true) _selectedId = id;
          }),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => _edit(() => _selectedId = id),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                _stickLabel(id),
                style: const TextStyle(
                  fontFamily: 'momo',
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Every button, shown or not: pick one here, drag a hidden one onto the
  /// pad to show it, or drop one back here to hide it.
  Widget _tray(ControllerBrandingMode brandingMode) {
    final strings = context.l10n.layoutEditor;
    return DragTarget<String>(
      onAcceptWithDetails: (d) => _edit(() {
        _draft.setVisible(d.data, false);
        _selectedId = d.data;
      }),
      builder: (context, candidates, _) => AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: candidates.isNotEmpty
              ? AppColors.highlightColor.withValues(alpha: 0.2)
              : AppColors.backgroundColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.textPrimary, width: 3),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _title(strings.trayTitle),
                const SizedBox(width: 10),
                Expanded(child: Text(strings.trayHint, style: _tipStyle)),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final id in LayoutDraft.buttons)
                  Draggable<String>(
                    data: id,
                    onDragStarted: () => setState(() => _dragging = true),
                    onDragEnd: (_) => setState(() => _dragging = false),
                    feedback: Material(
                      color: Colors.transparent,
                      child: _EditorToggleChip(
                        presentation: ControllerBranding.presentationFor(id, brandingMode),
                        isSelected: true,
                        onTap: (_) {},
                      ),
                    ),
                    child: Opacity(
                      opacity: _draft.isVisible(id) ? 1.0 : 0.45,
                      child: _EditorToggleChip(
                        presentation: ControllerBranding.presentationFor(id, brandingMode),
                        isSelected: _selectedId == id,
                        isActive: _draft.isVisible(id),
                        onTap: (_) => _edit(() => _selectedId = id),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- the picked button ---

  Widget _inspector(ControllerBrandingMode brandingMode) {
    final strings = context.l10n.layoutEditor;
    final id = _selectedId;
    if (id == null) {
      return Padding(
        padding: const EdgeInsets.only(top: 40),
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.highlightColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.textPrimary, width: 4),
              ),
              child: const Text(
                ':)',
                style: TextStyle(
                  fontFamily: 'momo',
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              strings.inspectorEmptyTitle,
              style: const TextStyle(
                fontFamily: 'momo',
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              strings.inspectorEmptyHint,
              textAlign: TextAlign.center,
              style: _tipStyle,
            ),
          ],
        ),
      );
    }

    final isStick = LayoutDraft.isStick(id);
    final visible = _draft.isVisible(id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.highlightColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.textPrimary, width: 3),
              ),
              child: isStick
                  ? const Icon(Icons.gamepad_rounded, color: AppColors.textPrimary)
                  : ControllerButtonBrand(
                      presentation: ControllerBranding.presentationFor(id, brandingMode),
                      size: 22,
                      textColor: AppColors.textPrimary,
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                isStick
                    ? _stickLabel(id)
                    : ControllerBranding.presentationFor(id, brandingMode).shortLabel,
                style: const TextStyle(
                  fontFamily: 'momo',
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _toggleRow(
          strings.onScreenLabel,
          visible,
          (value) => _edit(() => _draft.setVisible(id, value)),
        ),
        if (!visible) ...[
          const SizedBox(height: 6),
          Text(strings.hiddenHint, style: _tipStyle),
        ] else if (isStick)
          ..._stickOptions(id)
        else
          ..._buttonOptions(id),
      ],
    );
  }

  List<Widget> _buttonOptions(String id) {
    final strings = context.l10n.layoutEditor;
    final left = _draft.isLeft(id);
    return [
      const SizedBox(height: 14),
      Row(
        children: [
          Icon(
            left ? Icons.west_rounded : Icons.east_rounded,
            size: 18,
            color: AppColors.textPrimary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              left ? strings.sideLeft : strings.sideRight,
              style: const TextStyle(
                fontFamily: 'momo',
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 6),
      Text(context.l10n.layoutEditor.leftRowTip, style: _tipStyle),
      const SizedBox(height: 18),
      Opacity(
        opacity: left ? 0.4 : 1.0,
        child: IgnorePointer(
          ignoring: left,
          child: _toggleRow(
            strings.aimLabel,
            _draft.isAim(id),
            (value) => _edit(() => _draft.setAim(id, value)),
          ),
        ),
      ),
      const SizedBox(height: 6),
      Text(left ? strings.aimLeftDisabled : strings.aimButtonsTip, style: _tipStyle),
      AnimatedSize(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutBack,
        child: _draft.isAim(id)
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  _toggleRow(
                    strings.releaseAimLabel,
                    _draft.isReleaseAim(id),
                    (value) => _edit(() => _draft.setReleaseAim(id, value)),
                  ),
                  const SizedBox(height: 6),
                  Text(strings.releaseAimButtonsTip, style: _tipStyle),
                ],
              )
            : const SizedBox(width: double.infinity),
      ),
    ];
  }

  List<Widget> _stickOptions(String id) {
    final strings = context.l10n.layoutEditor;
    final brandingMode = widget.brandingModeListenable.value;
    return [
      if (id != 'RS_FIXED') ...[
        const SizedBox(height: 18),
        _title(strings.stickSizeLabel),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final (size, label) in [
              (1, strings.sizeSmall),
              (2, strings.sizeBig),
            ])
              _segment(
                label: label,
                isSelected: _draft.sizeOf(id) == size,
                onTap: () => _edit(() => _draft.buttonSizes[id] = size),
              ),
          ],
        ),
      ],
      const SizedBox(height: 22),
      _title(strings.rightStickFireTitle),
      const SizedBox(height: 6),
      Text(strings.rightStickFireTip, style: _tipStyle),
      const SizedBox(height: 10),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final (mode, label) in [
            ('off', strings.rightStickFireOff),
            ('touch', strings.rightStickFireTouch),
            ('ring', strings.rightStickFireRing),
          ])
            _segment(
              label: label,
              isSelected: _draft.rightStickFire == mode,
              onTap: () => _edit(() => _draft.rightStickFire = mode),
            ),
        ],
      ),
      if (_draft.rightStickFire != 'off') ...[
        const SizedBox(height: 14),
        Text(
          strings.fireButtonLabel,
          style: const TextStyle(
            fontFamily: 'momo',
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final button in LayoutDraft.fireButtons)
              _EditorToggleChip(
                presentation: ControllerBranding.presentationFor(button, brandingMode),
                isSelected: _draft.rightStickFireButton == button,
                onTap: (_) => _edit(() => _draft.rightStickFireButton = button),
              ),
          ],
        ),
      ],
      const SizedBox(height: 10),
      Text(strings.fireSharedHint, style: _tipStyle),
    ];
  }

  // --- small pieces ---

  String _stickLabel(String id) {
    final strings = context.l10n.layoutEditor;
    return switch (id) {
      'RS_FIXED' => strings.rightStickFixedLabel,
      'RS_BUTTON' => strings.rightStickFloatingLabel,
      _ => strings.rightStickSwipeLabel,
    };
  }

  static const TextStyle _tipStyle = TextStyle(
    fontFamily: 'momo',
    fontSize: 11,
    fontWeight: FontWeight.bold,
    height: 1.4,
    color: AppColors.textPrimary,
  );

  Widget _title(String text) => Text(
        text,
        style: TextStyle(
          fontFamily: 'momo',
          fontSize: 14,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
          color: AppColors.textPrimary.withValues(alpha: 0.5),
        ),
      );

  Widget _toggleRow(String label, bool value, ValueChanged<bool> onChanged) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: 'momo',
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(width: 8),
        JuicyToggle(value: value, onChanged: onChanged),
      ],
    );
  }

  Widget _segment({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
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
}

class _MovementChoiceChip extends StatelessWidget {
  const _MovementChoiceChip({
    required this.headline,
    required this.description,
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  final String headline;
  final String description;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.highlightColor
              : AppColors.backgroundColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? AppColors.textPrimary
                : AppColors.textPrimary.withValues(alpha: 0.1),
            width: 3,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 24, color: AppColors.textPrimary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    headline,
                    style: const TextStyle(
                      fontFamily: 'momo',
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    description,
                    style: TextStyle(
                      fontFamily: 'momo',
                      fontSize: 11,
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
    this.isActive = false,
  });
  final ControllerButtonPresentation presentation;
  final bool isSelected;

  /// Not picked, but on: drawn solid instead of faded.
  final bool isActive;
  final ValueChanged<bool> onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onTap(!isSelected),
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.highlightColor
              : AppColors.backgroundColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? AppColors.textPrimary
                : AppColors.textPrimary.withValues(alpha: isActive ? 0.6 : 0.1),
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
                borderRadius: BorderRadius.circular(7),
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
                color: isSelected || isActive
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
