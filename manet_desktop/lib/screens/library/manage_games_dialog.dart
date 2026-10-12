import 'dart:io';
import 'dart:math' as math;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../models/session_models.dart';
import '../../services/host_api_service.dart';
import '../../services/session_controller.dart';
import '../../theme/app_colors.dart';
import '../../widgets/juicy_widgets.dart';
import '../../widgets/layout_editor_view.dart';
import '../../models/controller_branding.dart';
import 'cover_search_dialog.dart';

/// The host's list of registered games, with add / edit / delete.
class ManageGamesDialog extends StatelessWidget {
  final PresetCatalog? presetCatalog;

  const ManageGamesDialog({super.key, this.presetCatalog});

  Future<void> _edit(BuildContext context, [GameEntry? game]) async {
    await showDialog(
      context: context,
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<SessionController>(),
        child: GameEditorDialog(game: game, presetCatalog: presetCatalog),
      ),
    );
  }

  Future<void> _delete(BuildContext context, GameEntry game) async {
    final strings = context.l10n.session;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => JuicyDialog(
        title: strings.deleteGame,
        maxWidth: 420,
        actions: [
          JuicyButton(
            onPressed: () => Navigator.pop(c, false),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Text(strings.cancel, style: _buttonStyle),
          ),
          JuicyButton(
            onPressed: () => Navigator.pop(c, true),
            backgroundColor: Colors.red.shade200,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Text(strings.deleteGame, style: _buttonStyle),
          ),
        ],
        child: Text(strings.deleteGameConfirm(game.name), style: _bodyStyle),
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<SessionController>().deleteGame(game.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.l10n.session;
    final games = context.watch<SessionController>().games;

    return JuicyDialog(
      title: strings.gamesTitle,
      maxWidth: 560,
      actions: [
        JuicyButton(
          onPressed: () => _edit(context),
          backgroundColor: AppColors.highlightColor,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Text(strings.addGame, style: _buttonStyle),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (games.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(strings.emptyLibrary, style: _bodyStyle),
            ),
          for (final game in games)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  _Thumb(path: game.coverPath),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          game.name,
                          style: _bodyStyle.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          strings.playersRange(
                            game.minPlayers,
                            game.maxPlayers,
                          ),
                          style: _captionStyle,
                        ),
                      ],
                    ),
                  ),
                  JuicyIconButton(
                    size: 36,
                    borderRadius: 10,
                    icon: const Icon(Icons.edit_rounded, size: 18),
                    onTap: () => _edit(context, game),
                  ),
                  const SizedBox(width: 6),
                  JuicyIconButton(
                    size: 36,
                    borderRadius: 10,
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    onTap: () => _delete(context, game),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  final String path;

  const _Thumb({required this.path});

  @override
  Widget build(BuildContext context) {
    final hasImage = path.isNotEmpty && File(path).existsSync();
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.textPrimary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.textPrimary, width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: hasImage
          ? Image.file(File(path), fit: BoxFit.cover)
          : const Icon(
              Icons.sports_esports_rounded,
              color: AppColors.textPrimary,
            ),
    );
  }
}

/// Add or edit one game.
class GameEditorDialog extends StatefulWidget {
  final GameEntry? game;
  final PresetCatalog? presetCatalog;

  const GameEditorDialog({super.key, this.game, this.presetCatalog});

  @override
  State<GameEditorDialog> createState() => _GameEditorDialogState();
}

class _GameEditorDialogState extends State<GameEditorDialog> {
  late final TextEditingController _name;
  late final TextEditingController _path;
  late final TextEditingController _arguments;
  late String _coverPath;
  late int _minPlayers;
  late int _maxPlayers;
  String? _presetId;
  String? _controllerMode;
  late List<GameRule> _rules;
  int? _display;
  late bool _fullscreen;
  List<DisplayInfo> _displays = const [];
  late List<ControllerPreset> _presets;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final game = widget.game;
    _name = TextEditingController(text: game?.name ?? '');
    _path = TextEditingController(text: game?.path ?? '');
    _arguments = TextEditingController(text: game?.arguments ?? '');
    _coverPath = game?.coverPath ?? '';
    _minPlayers = game?.minPlayers ?? 1;
    _maxPlayers = game?.maxPlayers ?? 4;
    _presetId = game?.presetId;
    _controllerMode = game?.controllerMode;
    _rules = [...?game?.rules];
    _display = game?.display;
    _fullscreen = game?.fullscreen ?? true;
    final catalog = widget.presetCatalog;
    _presets = [
      if (catalog != null) ...[
        ...catalog.builtInPresets,
        ...catalog.gamePresets,
        ...catalog.customPresets,
      ],
    ];
    _loadDisplays();
  }

  Future<void> _loadDisplays() async {
    try {
      final displays = await context
          .read<SessionController>()
          .api
          .fetchDisplays();
      if (mounted) setState(() => _displays = displays);
    } catch (_) {}
  }

  @override
  void dispose() {
    _name.dispose();
    _path.dispose();
    _arguments.dispose();
    super.dispose();
  }

  Future<void> _pickExecutable() async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Games', extensions: ['exe', 'lnk', 'url', 'bat']),
      ],
    );
    if (file == null) return;
    setState(() {
      _path.text = file.path;
      if (_name.text.trim().isEmpty) {
        _name.text = p.basenameWithoutExtension(file.path);
      }
    });
  }

  Future<void> _pickCover() async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'Images',
          extensions: ['png', 'jpg', 'jpeg', 'webp', 'gif'],
        ),
      ],
    );
    if (file != null) setState(() => _coverPath = file.path);
  }

  Future<void> _searchCover() async {
    final path = await showDialog<String>(
      context: context,
      builder: (_) => CoverSearchDialog(initialQuery: _name.text.trim()),
    );
    if (path != null && mounted) setState(() => _coverPath = path);
  }

  /// Opens the controller layout creator; the new layout gets selected.
  Future<void> _createLayout(ValueChanged<String> select) async {
    final api = context.read<SessionController>().api;
    final branding = ValueNotifier(
      ControllerBranding.modeFromWire(_controllerMode ?? 'x360'),
    );
    final created = await showDialog<ControllerPreset>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: AppColors.screenBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: const BorderSide(
            color: AppColors.textPrimary,
            width: AppColors.borderThickness,
          ),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960, maxHeight: 680),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: LayoutEditorView(
              api: api,
              brandingModeListenable: branding,
              existingNames: [for (final preset in _presets) preset.name],
              onCancel: () => Navigator.of(dialogContext).pop(),
              onSaved: (preset) => Navigator.of(dialogContext).pop(preset),
            ),
          ),
        ),
      ),
    );
    branding.dispose();
    if (created != null && mounted) {
      setState(() => _presets = [..._presets, created]);
      select(created.id);
    }
  }

  void _suggestXinputRule() {
    setState(() {
      if (_maxPlayers <= 4) _maxPlayers = 8;
      _rules = [
        GameRule(minPlayers: 1, maxPlayers: 4, controllerMode: 'x360'),
        GameRule(minPlayers: 5, maxPlayers: _maxPlayers, controllerMode: 'ds4'),
      ];
    });
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final game = GameEntry(
      id: widget.game?.id ?? '',
      name: _name.text.trim(),
      path: _path.text.trim(),
      arguments: _arguments.text.trim(),
      coverPath: _coverPath,
      minPlayers: _minPlayers,
      maxPlayers: _maxPlayers,
      presetId: _presetId,
      controllerMode: _controllerMode,
      rules: _rules,
      display: _display,
      fullscreen: _fullscreen,
    );
    try {
      await context.read<SessionController>().saveGame(game);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) setState(() => _error = context.l10n.session.saveError);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.l10n.session;

    return JuicyDialog(
      title: widget.game == null ? strings.addGame : strings.editGame,
      maxWidth: 760,
      actions: [
        JuicyButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Text(strings.cancel, style: _buttonStyle),
        ),
        JuicyButton(
          onPressed: _saving ? null : _save,
          backgroundColor: AppColors.highlightColor,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Text(strings.saveGame, style: _buttonStyle),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _label(strings.gamePath),
          Row(
            children: [
              Expanded(child: _field(_path, hint: strings.gamePathHint)),
              const SizedBox(width: 8),
              _smallButton(strings.chooseFile, _pickExecutable),
            ],
          ),
          _label(strings.gameName),
          _field(_name),
          _label(strings.gameArguments),
          _field(_arguments),
          _label(strings.gameCover),
          Row(
            children: [
              _Thumb(path: _coverPath),
              const SizedBox(width: 10),
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    JuicyButton(
                      onPressed: _searchCover,
                      backgroundColor: AppColors.highlightColor,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.image_search_rounded,
                            size: 18,
                            color: AppColors.textPrimary,
                          ),
                          const SizedBox(width: 6),
                          Text(strings.findCover, style: _buttonStyle),
                        ],
                      ),
                    ),
                    _smallButton(strings.chooseCover, _pickCover),
                    if (_coverPath.isNotEmpty)
                      _smallButton(
                        strings.removeCover,
                        () => setState(() => _coverPath = ''),
                      ),
                  ],
                ),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label(strings.minPlayers),
                    _intDropdown(
                      _minPlayers,
                      (v) => setState(() {
                        _minPlayers = v;
                        if (_maxPlayers < v) _maxPlayers = v;
                      }),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label(strings.maxPlayers),
                    _intDropdown(
                      _maxPlayers,
                      (v) => setState(() {
                        _maxPlayers = v;
                        if (_minPlayers > v) _minPlayers = v;
                      }),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label(strings.gameMode),
                    _modeDropdown(
                      _controllerMode,
                      (v) => setState(() => _controllerMode = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label(strings.gameLayout),
                    _layoutPicker(
                      _presetId,
                      (v) => setState(() => _presetId = v),
                    ),
                  ],
                ),
              ),
            ],
          ),
          _label(strings.rulesTitle),
          Text(strings.rulesHint, style: _captionStyle),
          const SizedBox(height: 8),
          for (var i = 0; i < _rules.length; i++) _ruleRow(i),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _smallButton(
                strings.addRule,
                () => setState(() {
                  final start = _rules.isEmpty
                      ? _minPlayers
                      : _rules.last.maxPlayers + 1;
                  final from = start.clamp(1, 8);
                  _rules = [
                    ..._rules,
                    GameRule(
                      minPlayers: from,
                      maxPlayers: math.max(from, _maxPlayers),
                    ),
                  ];
                }),
              ),
              _smallButton(strings.suggestXinputRule, _suggestXinputRule),
            ],
          ),
          _label(strings.displayTitle),
          _dropdown<int?>(
            value: _displays.any((d) => d.index == _display) ? _display : null,
            items: {
              null: strings.displayAuto,
              for (final d in _displays)
                d.index: strings.displayLabel(
                  d.index + 1,
                  d.primary,
                  d.width,
                  d.height,
                ),
            },
            onChanged: (v) => setState(() => _display = v),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      strings.fullscreenGame,
                      style: _bodyStyle.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(strings.fullscreenGameHint, style: _captionStyle),
                  ],
                ),
              ),
              JuicyToggle(
                value: _fullscreen,
                onChanged: (v) => setState(() => _fullscreen = v),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: _bodyStyle.copyWith(color: Colors.red.shade700),
            ),
          ],
        ],
      ),
    );
  }

  Widget _ruleRow(int index) {
    final strings = context.l10n.session;
    final rule = _rules[index];
    void update(GameRule next) =>
        setState(() => _rules = [..._rules]..[index] = next);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(strings.ruleFrom, style: _bodyStyle),
          const SizedBox(width: 6),
          SizedBox(
            width: 70,
            child: _intDropdown(
              rule.minPlayers,
              (v) => update(
                rule.copyWith(
                  minPlayers: v,
                  maxPlayers: math.max(v, rule.maxPlayers),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(strings.ruleTo, style: _bodyStyle),
          const SizedBox(width: 6),
          SizedBox(
            width: 70,
            child: _intDropdown(
              rule.maxPlayers,
              (v) => update(
                rule.copyWith(
                  maxPlayers: v,
                  minPlayers: math.min(v, rule.minPlayers),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _modeDropdown(
              rule.controllerMode,
              (v) => update(rule.copyWith(controllerMode: () => v)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _layoutPicker(
              rule.presetId,
              (v) => update(rule.copyWith(presetId: () => v)),
            ),
          ),
          const SizedBox(width: 6),
          JuicyIconButton(
            size: 36,
            borderRadius: 10,
            icon: const Icon(Icons.close_rounded, size: 18),
            onTap: () => setState(() => _rules = [..._rules]..removeAt(index)),
          ),
        ],
      ),
    );
  }

  Widget _modeDropdown(String? value, ValueChanged<String?> onChanged) =>
      _dropdown<String?>(
        value: value,
        items: {
          null: context.l10n.session.keepMode,
          'x360': 'x•input',
          'ds4': 'd•input',
        },
        onChanged: onChanged,
      );

  /// Layout dropdown with a "+" that opens the layout creator.
  Widget _layoutPicker(String? value, ValueChanged<String?> onChanged) {
    return Row(
      children: [
        Expanded(
          child: _dropdown<String?>(
            value: _presets.any((preset) => preset.id == value) ? value : null,
            items: {
              null: context.l10n.session.noLayout,
              for (final preset in _presets) preset.id: preset.name,
            },
            onChanged: onChanged,
          ),
        ),
        const SizedBox(width: 6),
        Tooltip(
          message: context.l10n.session.createLayout,
          child: JuicyIconButton(
            size: 36,
            borderRadius: 10,
            icon: const Icon(Icons.add_rounded, size: 20),
            onTap: () => _createLayout((id) => onChanged(id)),
          ),
        ),
      ],
    );
  }

  Widget _smallButton(String label, VoidCallback onPressed) => JuicyButton(
    onPressed: onPressed,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    child: Text(label, style: _buttonStyle),
  );

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(top: 14, bottom: 6),
    child: Text(text, style: _bodyStyle.copyWith(fontWeight: FontWeight.bold)),
  );

  Widget _field(TextEditingController controller, {String? hint}) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.textPrimary, width: 2),
    );
    return TextField(
      controller: controller,
      style: _bodyStyle,
      decoration: InputDecoration(
        hintText: hint,
        isDense: true,
        filled: true,
        fillColor: AppColors.lightColor,
        border: border,
        enabledBorder: border,
      ),
    );
  }

  Widget _intDropdown(int value, ValueChanged<int> onChanged) => _dropdown<int>(
    value: value,
    items: {for (var i = 1; i <= 8; i++) i: '$i'},
    onChanged: (v) => onChanged(v ?? value),
  );

  Widget _dropdown<T>({
    required T value,
    required Map<T, String> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.lightColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.textPrimary, width: 2),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          style: _bodyStyle,
          items: [
            for (final entry in items.entries)
              DropdownMenuItem<T>(
                value: entry.key,
                child: Text(entry.value, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

const TextStyle _bodyStyle = TextStyle(
  fontFamily: 'momo',
  fontSize: 14,
  color: AppColors.textPrimary,
);

const TextStyle _buttonStyle = TextStyle(
  fontFamily: 'momo',
  fontWeight: FontWeight.bold,
  fontSize: 14,
  color: AppColors.textPrimary,
);

final TextStyle _captionStyle = TextStyle(
  fontFamily: 'momo',
  fontSize: 12,
  color: AppColors.textPrimary.withValues(alpha: 0.65),
);
