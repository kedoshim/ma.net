import 'package:flutter/material.dart';

import '../services/host_api_service.dart';
import '../theme/app_colors.dart';

class PresetSelectorDialog extends StatefulWidget {
  const PresetSelectorDialog({super.key, required this.api});

  final HostApiService api;

  @override
  State<PresetSelectorDialog> createState() => _PresetSelectorDialogState();
}

class _PresetSelectorDialogState extends State<PresetSelectorDialog> {
  PresetCatalog? _catalog;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final catalog = await widget.api.fetchPresets();
      if (mounted) {
        setState(() {
          _catalog = catalog;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _selectPreset(ControllerPreset preset) async {
    setState(() => _saving = true);
    try {
      await widget.api.selectPreset(preset.id);
      await _load();
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _openEditor({ControllerPreset? preset}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) =>
          _PresetEditorDialog(api: widget.api, preset: preset),
    );

    if (result == true) {
      await _load();
    }
  }

  Future<void> _deletePreset(ControllerPreset preset) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.screenBackground,
        title: const Text('Excluir preset'),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Presets',
                          style: TextStyle(
                            fontFamily: 'pico',
                            fontSize: 28,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _saving ? null : () => _openEditor(),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Criar preset'),
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
              else if (_catalog == null)
                const Expanded(
                  child: Center(
                    child: Text('Não foi possivel carregar os presets.'),
                  ),
                )
              else
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionTitle(
                          title: 'Presets de jogos',
                          subtitle:
                              'Sugestoes leves e faceis de expandir depois.',
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          children: _catalog!.gamePresets
                              .map(
                                (preset) => _PresetCard(
                                  preset: preset,
                                  activePresetId: _catalog!.activePresetId,
                                  onSelect: _saving
                                      ? null
                                      : () => _selectPreset(preset),
                                ),
                              )
                              .toList(),
                        ),
                        const SizedBox(height: 28),
                        Text(
                          "Seus presets personalizados",
                          style: const TextStyle(
                            fontFamily: 'pico',
                            fontSize: 22,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (_catalog!.customPresets.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.textPrimary),
                            ),
                            child: const Text(
                              'Ainda nao ha presets personalizados. Crie um e monte o controle do seu jeito.',
                            ),
                          )
                        else
                          Wrap(
                            spacing: 16,
                            runSpacing: 16,
                            children: _catalog!.customPresets
                                .map(
                                  (preset) => _PresetCard(
                                    preset: preset,
                                    activePresetId: _catalog!.activePresetId,
                                    onSelect: _saving
                                        ? null
                                        : () => _selectPreset(preset),
                                    footer: Row(
                                      children: [
                                        TextButton.icon(
                                          onPressed: _saving
                                              ? null
                                              : () =>
                                                    _openEditor(preset: preset),
                                          icon: const Icon(Icons.edit_rounded),
                                          label: const Text('Renomear/editar'),
                                        ),
                                        TextButton.icon(
                                          onPressed: _saving
                                              ? null
                                              : () => _deletePreset(preset),
                                          icon: const Icon(
                                            Icons.delete_outline_rounded,
                                          ),
                                          label: const Text('Excluir'),
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
  }
}

class _PresetEditorDialog extends StatefulWidget {
  const _PresetEditorDialog({required this.api, this.preset});

  final HostApiService api;
  final ControllerPreset? preset;

  @override
  State<_PresetEditorDialog> createState() => _PresetEditorDialogState();
}

class _PresetEditorDialogState extends State<_PresetEditorDialog> {
  static const List<String> _allButtons = [
    'btnY',
    'btnB',
    'btnX',
    'btnA',
    'btnRB',
    'btnRT',
    'btnLB',
    'btnLT',
    'btnRSB',
    'btnLSB',
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
    _nameController = TextEditingController(text: preset?.name ?? 'Meu preset');
    _movementMode = preset?.layout.movementMode ?? 'floatingJoystick';
    _visibleButtons = {
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
    return const {
      'btnA',
      'btnB',
      'btnX',
      'btnY',
      'btnLB',
      'btnRB',
    }.contains(buttonId);
  }

  String _labelForButton(String buttonId) {
    return buttonId.replaceFirst('btn', '');
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
                  widget.preset == null ? 'Criar preset' : 'Editar preset',
                  style: const TextStyle(
                    fontFamily: 'pico',
                    fontSize: 24,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    _EditorField(controller: _nameController, label: 'Nome'),
                  ],
                ),
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
                              fontFamily: 'pico',
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
                                label: 'Joystick Fixo',
                                description: 'Sempre visivel e previsivel',
                                selected: _movementMode == 'fixedJoystick',
                                onTap: () => setState(
                                  () => _movementMode = 'fixedJoystick',
                                ),
                              ),
                              _MovementChoiceChip(
                                label: 'Joystick Flutuante',
                                description: 'Recomendado na maioria dos casos',
                                selected: _movementMode == 'floatingJoystick',
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
                              fontFamily: 'pico',
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
                              return FilterChip(
                                label: Text(
                                  _labelForButton(buttonId),
                                  style: const TextStyle(
                                    fontFamily: 'pico',
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                selected: isVisible,
                                onSelected: (selected) {
                                  setState(
                                    () => _visibleButtons[buttonId] = selected,
                                  );
                                },
                                backgroundColor: AppColors.backgroundColor
                                    .withValues(alpha: 0.12),
                                selectedColor: AppColors.highlightColor
                                    .withValues(alpha: 0.18),
                                checkmarkColor: AppColors.highlightColor,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(
                                    color: isVisible
                                        ? AppColors.highlightColor
                                        : AppColors.textPrimary,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'Ordem (Arraste os botoes no preview)',
                            style: TextStyle(
                              fontFamily: 'pico',
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
                              border: Border.all(color: AppColors.textPrimary),
                            ),
                            child: _PresetPreview(
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
                                  if (draggedIndex != -1 && targetIndex != -1) {
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
                      child: Text(widget.preset == null ? 'Criar' : 'Salvar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PresetCard extends StatelessWidget {
  const _PresetCard({
    required this.preset,
    required this.activePresetId,
    required this.onSelect,
    this.footer,
  });

  final ControllerPreset preset;
  final String activePresetId;
  final VoidCallback? onSelect;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final isActive = preset.id == activePresetId;

    return Container(
      width: 330,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: isActive
            ? AppColors.highlightColor.withValues(alpha: 0.18)
            : AppColors.backgroundColor.withValues(alpha: 0.12),
        border: Border.all(
          color: isActive ? AppColors.highlightColor : AppColors.textPrimary,
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  preset.name,
                  style: const TextStyle(
                    fontFamily: 'pico',
                    fontSize: 22,
                    color: AppColors.textPrimary,
                  ),
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
                  child: const Text('Ativo'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _PresetPreview(layout: preset.layout),
          const SizedBox(height: 12),
          Row(
            children: [
              FilledButton(
                onPressed: onSelect,
                style: FilledButton.styleFrom(
                  backgroundColor: isActive
                      ? AppColors.highlightColor
                      : AppColors.textPrimary,
                ),
                child: Text(isActive ? 'Selecionado' : 'Usar preset'),
              ),
            ],
          ),
          if (footer != null) ...[const SizedBox(height: 8), footer!],
        ],
      ),
    );
  }
}

class _PresetPreview extends StatelessWidget {
  const _PresetPreview({required this.layout, this.onReorder});

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
                ? _PreviewDpad()
                : _PreviewStick(
                    floating: layout.movementMode == 'floatingJoystick',
                  ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'ma•net',
                  style: TextStyle(
                    fontSize: 10,
                    fontFamily: 'pico',
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _PreviewCenterButton(label: '⧉'),
                    const SizedBox(width: 4),
                    _PreviewCenterButton(label: '≡'),
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
                _PreviewColumn(buttons: columns[0], onReorder: onReorder),
                const SizedBox(width: 4),
                _PreviewColumn(buttons: columns[1], onReorder: onReorder),
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
  const _PreviewColumn({required this.buttons, this.onReorder});

  final List<String> buttons;
  final void Function(String, String)? onReorder;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: buttons.map((btnId) {
          final box = Container(
            width: double.infinity,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.backgroundColor,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.textPrimary, width: 1),
            ),
            child: Text(
              btnId.replaceFirst('btn', ''),
              style: const TextStyle(
                fontSize: 10,
                fontFamily: 'pico',
                color: AppColors.textPrimary,
              ),
            ),
          );

          final content = Padding(padding: const EdgeInsets.all(2), child: box);

          if (onReorder == null) {
            return Expanded(child: content);
          }

          return Expanded(
            child: DragTarget<String>(
              onWillAcceptWithDetails: (details) => details.data != btnId,
              onAcceptWithDetails: (details) => onReorder!(details.data, btnId),
              builder: (context, candidateData, rejectedData) {
                final isTarget = candidateData.isNotEmpty;
                return Draggable<String>(
                  data: btnId,
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

    return Container(
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
    );
  }
}

class _PreviewStick extends StatelessWidget {
  const _PreviewStick({required this.floating});

  final bool floating;

  @override
  Widget build(BuildContext context) {
    return Stack(
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
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.textPrimary,
          ),
        ),
      ],
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
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'pico',
            fontSize: 22,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(subtitle),
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
      width: 260,
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
