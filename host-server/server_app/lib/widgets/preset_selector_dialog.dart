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
      builder: (context) => _PresetEditorDialog(
        api: widget.api,
        preset: preset,
      ),
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
                        SizedBox(height: 6),
                        Text(
                          'Escolha um layout pronto para abrir e jogar.',
                          style: TextStyle(color: AppColors.textPrimary),
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
                  child: Center(child: Text('Nao foi possivel carregar os presets.')),
                )
              else
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionTitle(
                          title: 'Prontos para usar',
                          subtitle: 'Comece rapido com layouts pensados para onboarding.',
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          children: _catalog!.builtInPresets
                              .map(
                                (preset) => _PresetCard(
                                  preset: preset,
                                  activePresetId: _catalog!.activePresetId,
                                  onSelect: _saving ? null : () => _selectPreset(preset),
                                ),
                              )
                              .toList(),
                        ),
                        const SizedBox(height: 28),
                        _SectionTitle(
                          title: 'Presets de jogos',
                          subtitle: 'Sugestoes leves e faceis de expandir depois.',
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
                                  onSelect: _saving ? null : () => _selectPreset(preset),
                                ),
                              )
                              .toList(),
                        ),
                        const SizedBox(height: 28),
                        _SectionTitle(
                          title: 'Seus presets',
                          subtitle: 'Layouts personalizados salvos para o seu setup.',
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
                                    onSelect: _saving ? null : () => _selectPreset(preset),
                                    footer: Row(
                                      children: [
                                        TextButton.icon(
                                          onPressed: _saving
                                              ? null
                                              : () => _openEditor(preset: preset),
                                          icon: const Icon(Icons.edit_rounded),
                                          label: const Text('Renomear/editar'),
                                        ),
                                        TextButton.icon(
                                          onPressed: _saving
                                              ? null
                                              : () => _deletePreset(preset),
                                          icon: const Icon(Icons.delete_outline_rounded),
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
    'btnRS',
    'btnLS',
  ];

  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _bestForController;
  late final TextEditingController _prosController;
  late final TextEditingController _consController;
  late String _movementMode;
  late Map<String, bool> _visibleButtons;
  late List<String> _buttonOrder;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final preset = widget.preset;
    _nameController = TextEditingController(text: preset?.name ?? 'Meu preset');
    _descriptionController = TextEditingController(
      text: preset?.description ?? 'Preset personalizado para o seu estilo de jogo.',
    );
    _bestForController = TextEditingController(
      text: preset?.bestFor ?? 'Feito para o seu jeito de jogar',
    );
    _prosController = TextEditingController(
      text: preset?.pros ?? 'Pode ser ajustado para qualquer jogo.',
    );
    _consController = TextEditingController(
      text: preset?.cons ?? 'Depende da sua configuracao manual.',
    );
    _movementMode = preset?.layout.movementMode ?? 'floatingJoystick';
    _visibleButtons = {
      for (final buttonId in _allButtons)
        buttonId: preset?.layout.visibleButtons[buttonId] ?? _defaultVisible(buttonId),
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
    return const {'btnA', 'btnB', 'btnX', 'btnY', 'btnLB', 'btnRB'}.contains(buttonId);
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
          description: _descriptionController.text.trim(),
          bestFor: _bestForController.text.trim(),
          pros: _prosController.text.trim(),
          cons: _consController.text.trim(),
          layout: layout,
        );
      } else {
        await widget.api.updateCustomPreset(
          presetId: widget.preset!.id,
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          bestFor: _bestForController.text.trim(),
          pros: _prosController.text.trim(),
          cons: _consController.text.trim(),
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
    _descriptionController.dispose();
    _bestForController.dispose();
    _prosController.dispose();
    _consController.dispose();
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
                    _EditorField(
                      controller: _descriptionController,
                      label: 'Descricao curta',
                    ),
                    _EditorField(
                      controller: _bestForController,
                      label: 'Melhor para',
                    ),
                    _EditorField(controller: _prosController, label: 'Ponto forte'),
                    _EditorField(controller: _consController, label: 'Observacao'),
                  ],
                ),
                const SizedBox(height: 20),
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
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _MovementChoiceChip(
                      label: 'D-Pad',
                      description: 'Melhor para precisao e plataforma',
                      selected: _movementMode == 'dpad',
                      onTap: () => setState(() => _movementMode = 'dpad'),
                    ),
                    _MovementChoiceChip(
                      label: 'Joystick Fixo',
                      description: 'Sempre visivel e previsivel',
                      selected: _movementMode == 'fixedJoystick',
                      onTap: () => setState(() => _movementMode = 'fixedJoystick'),
                    ),
                    _MovementChoiceChip(
                      label: 'Joystick Flutuante',
                      description: 'Recomendado na maioria dos casos',
                      selected: _movementMode == 'floatingJoystick',
                      onTap: () => setState(() => _movementMode = 'floatingJoystick'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Text(
                  'Botoes visiveis e ordem',
                  style: TextStyle(
                    fontFamily: 'pico',
                    fontSize: 18,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  height: 280,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.textPrimary),
                  ),
                  child: ReorderableListView.builder(
                    itemCount: _buttonOrder.length,
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        if (newIndex > oldIndex) {
                          newIndex -= 1;
                        }
                        final item = _buttonOrder.removeAt(oldIndex);
                        _buttonOrder.insert(newIndex, item);
                      });
                    },
                    itemBuilder: (context, index) {
                      final buttonId = _buttonOrder[index];
                      return SwitchListTile(
                        key: ValueKey(buttonId),
                        title: Text(_labelForButton(buttonId)),
                        subtitle: Text('Posicao ${index + 1} na coluna de acoes'),
                        value: _visibleButtons[buttonId] == true,
                        onChanged: (value) {
                          setState(() => _visibleButtons[buttonId] = value);
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: AppColors.backgroundColor.withValues(alpha: 0.18),
                    border: Border.all(color: AppColors.textPrimary),
                  ),
                  child: _PresetPreview(layout: ControllerPresetLayout(
                    movementMode: _movementMode,
                    visibleButtons: _visibleButtons,
                    buttonOrder: _buttonOrder,
                  )),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _saving ? null : () => Navigator.of(context).pop(false),
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
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
          Text(preset.description),
          const SizedBox(height: 8),
          Text(
            preset.bestFor,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text('Pro: ${preset.pros}'),
          const SizedBox(height: 4),
          Text('Obs: ${preset.cons}'),
          const SizedBox(height: 12),
          Row(
            children: [
              FilledButton(
                onPressed: onSelect,
                child: Text(isActive ? 'Selecionado' : 'Usar preset'),
              ),
            ],
          ),
          if (footer != null) ...[
            const SizedBox(height: 8),
            footer!,
          ],
        ],
      ),
    );
  }
}

class _PresetPreview extends StatelessWidget {
  const _PresetPreview({required this.layout});

  final ControllerPresetLayout layout;

  @override
  Widget build(BuildContext context) {
    final visible = layout.buttonOrder
        .where((buttonId) => layout.visibleButtons[buttonId] == true)
        .toList();

    return Container(
      height: 140,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: AppColors.screenBackground.withValues(alpha: 0.9),
        border: Border.all(color: AppColors.textPrimary.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: layout.movementMode == 'dpad'
                  ? _PreviewDpad()
                  : _PreviewStick(floating: layout.movementMode == 'floatingJoystick'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: visible
                  .map(
                    (buttonId) => Container(
                      width: 42,
                      height: 42,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.backgroundColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.textPrimary),
                      ),
                      child: Text(
                        buttonId.replaceFirst('btn', ''),
                        style: const TextStyle(
                          fontFamily: 'pico',
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewDpad extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    Widget box() => Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: AppColors.backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.textPrimary),
      ),
    );

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        box(),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [box(), const SizedBox(width: 4), box()],
        ),
        const SizedBox(height: 4),
        box(),
      ],
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
          width: 74,
          height: 74,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.textPrimary),
            color: floating
                ? AppColors.highlightColor.withValues(alpha: 0.18)
                : AppColors.backgroundColor,
          ),
        ),
        Container(
          width: 28,
          height: 28,
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
