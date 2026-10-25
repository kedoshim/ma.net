import 'dart:io';
import 'dart:math' as math;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_localizations.dart';
import '../../l10n/strings.dart';
import '../../models/session_models.dart';
import '../../services/host_api_service.dart';
import '../../services/session_controller.dart';
import '../../services/sound_effect_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/app_preferences.dart';
import '../../widgets/juicy_widgets.dart';
import '../../widgets/layout_editor_view.dart';
import '../../widgets/layout_preview_widgets.dart';
import '../../models/controller_branding.dart';
import 'cover_search_dialog.dart';
import 'game_media_widgets.dart';

/// The host's management dialog with tabs for registered games and launcher settings.
class ManageGamesDialog extends StatefulWidget {
  final PresetCatalog? presetCatalog;

  const ManageGamesDialog({super.key, this.presetCatalog});

  @override
  State<ManageGamesDialog> createState() => _ManageGamesDialogState();
}

class _ManageGamesDialogState extends State<ManageGamesDialog> {
  int _selectedTab = 0;

  Future<void> _edit(BuildContext context, [GameEntry? game]) async {
    await showDialog(
      context: context,
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<SessionController>(),
        child: GameEditorDialog(game: game, presetCatalog: widget.presetCatalog),
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

  Widget _buildTabBar(SessionStrings strings) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.textPrimary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.textPrimary, width: 2.5),
      ),
      child: Row(
        children: [
          Expanded(
            child: _tabButton(
              index: 0,
              label: strings.tabGames,
              icon: Icons.sports_esports_rounded,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _tabButton(
              index: 1,
              label: strings.tabLauncher,
              icon: Icons.tune_rounded,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabButton({
    required int index,
    required String label,
    required IconData icon,
  }) {
    final isSelected = _selectedTab == index;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          if (_selectedTab != index) {
            SoundEffectService.instance.playThemeSelect();
            setState(() => _selectedTab = index);
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.highlightColor : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: isSelected
                ? Border.all(color: AppColors.textPrimary, width: 2.5)
                : Border.all(color: Colors.transparent, width: 2.5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: AppColors.textPrimary),
              const SizedBox(width: 8),
              Text(
                label,
                style: _buttonStyle.copyWith(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGamesTab(
    BuildContext context,
    SessionStrings strings,
    List<GameEntry> games,
  ) {
    if (games.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Center(
          child: Text(strings.emptyLibrary, style: _bodyStyle),
        ),
      );
    }
    final sorted = [...games]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 360),
      child: SingleChildScrollView(
        child: Column(
          children: [
            for (final game in sorted)
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
      ),
    );
  }

  Widget _buildOptionSelector<T>({
    required String label,
    required T current,
    required List<({T value, String title, IconData icon})> options,
    required ValueChanged<T> onSelected,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: _bodyStyle.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final opt in options)
              JuicyCard(
                isSelected: current == opt.value,
                selectedColor: AppColors.highlightColor,
                borderRadius: 14,
                borderThickness: 3,
                onTap: () {
                  SoundEffectService.instance.playThemeSelect();
                  onSelected(opt.value);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(opt.icon, size: 18, color: AppColors.textPrimary),
                      const SizedBox(width: 8),
                      Text(
                        opt.title,
                        style: _buttonStyle.copyWith(fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildLauncherTab(BuildContext context, SessionStrings strings) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ValueListenableBuilder<String>(
            valueListenable: AppPreferences.cardStyleNotifier,
            builder: (context, cardStyle, _) => _buildOptionSelector<String>(
              label: strings.cardStyleLabel,
              current: cardStyle,
              options: [
                (
                  value: 'cover_only',
                  title: strings.cardStyleCoverOnly,
                  icon: Icons.image_rounded,
                ),
                (
                  value: 'classic',
                  title: strings.cardStyleClassic,
                  icon: Icons.view_sidebar_rounded,
                ),
              ],
              onSelected: (val) => AppPreferences.setCardStyle(val),
            ),
          ),
          const SizedBox(height: 18),
          ValueListenableBuilder<int>(
            valueListenable: AppPreferences.gridRowsNotifier,
            builder: (context, rows, _) => _buildOptionSelector<int>(
              label: strings.gridDensityLabel,
              current: rows,
              options: [
                (
                  value: 1,
                  title: strings.gridRows1,
                  icon: Icons.table_rows_rounded,
                ),
                (
                  value: 2,
                  title: strings.gridRows2,
                  icon: Icons.grid_view_rounded,
                ),
                (
                  value: 3,
                  title: strings.gridRows3,
                  icon: Icons.density_small_rounded,
                ),
              ],
              onSelected: (val) => AppPreferences.setGridRows(val),
            ),
          ),
          const SizedBox(height: 18),
          ValueListenableBuilder<String>(
            valueListenable: AppPreferences.sortOrderNotifier,
            builder: (context, sortOrder, _) => _buildOptionSelector<String>(
              label: strings.sortOrderLabel,
              current: sortOrder,
              options: [
                (
                  value: 'recent',
                  title: strings.sortRecent,
                  icon: Icons.history_rounded,
                ),
                (
                  value: 'alphabetical',
                  title: strings.sortAlphabetical,
                  icon: Icons.sort_by_alpha_rounded,
                ),
                (
                  value: 'players',
                  title: strings.sortPlayers,
                  icon: Icons.group_rounded,
                ),
              ],
              onSelected: (val) => AppPreferences.setSortOrder(val),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.l10n.session;
    final games = context.watch<SessionController>().games;

    return JuicyDialog(
      title: strings.manageGamesAndLauncher,
      maxWidth: 580,
      actions: [
        if (_selectedTab == 0)
          JuicyButton(
            onPressed: () => _edit(context),
            backgroundColor: AppColors.highlightColor,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Text(strings.addGame, style: _buttonStyle),
          ),
        JuicyButton(
          onPressed: () => Navigator.pop(context),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Text(strings.cancel, style: _buttonStyle),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTabBar(strings),
          const SizedBox(height: 16),
          if (_selectedTab == 0)
            _buildGamesTab(context, strings, games)
          else
            _buildLauncherTab(context, strings),
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
  static const int _maxPlayersLimit = 16;

  late final TextEditingController _name;
  late final TextEditingController _path;
  late final TextEditingController _arguments;
  late final TextEditingController _description;
  late final TextEditingController _tags;
  late final TextEditingController _trailer;
  // Extra images (links): shown on the card and on the phones with the
  // details. "Find game data" can fill them in.
  late List<String> _screenshots;
  bool _fetchingData = false;
  late String _coverPath;
  late int _minPlayers;
  late int _maxPlayers;
  String? _presetId;
  String? _controllerMode;
  late List<GameRule> _rules;
  int? _display;
  late bool _fullscreen;
  // The pad's website button (Jackbox): on/off plus the page it opens.
  late bool _phoneSite;
  late final TextEditingController _phoneUrl;
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
    _description = TextEditingController(text: game?.description ?? '');
    _tags = TextEditingController(text: game?.tags.join(', ') ?? '');
    _trailer = TextEditingController(text: game?.trailerUrl ?? '');
    _screenshots = [...?game?.screenshots];
    _coverPath = game?.coverPath ?? '';
    _minPlayers = game?.minPlayers ?? 1;
    _maxPlayers = game?.maxPlayers ?? 4;
    _presetId = game?.presetId;
    _controllerMode = game?.controllerMode;
    _rules = [...?game?.rules];
    _display = game?.display;
    _fullscreen = game?.fullscreen ?? true;
    _phoneSite = (game?.phoneUrl ?? '').isNotEmpty;
    _phoneUrl = TextEditingController(
      text: _phoneSite ? game!.phoneUrl : _jackboxUrl,
    );
    _name.addListener(_onNameChanged);
    final catalog = widget.presetCatalog;
    _presets = [
      if (catalog != null) ...[
        ...catalog.builtInPresets,
        ...catalog.gamePresets,
        ...catalog.customPresets,
      ],
    ];
    _loadDisplays();
    // The catalog handed in is a snapshot from when the games screen
    // opened: layouts made or edited since then would be missing or old.
    _reloadPresets();
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
    _description.dispose();
    _tags.dispose();
    _trailer.dispose();
    _phoneUrl.dispose();
    super.dispose();
  }

  static const _jackboxUrl = 'https://jackbox.tv';

  // The Jackbox tip shows while the name looks like one.
  void _onNameChanged() => setState(() {});

  bool get _looksLikeJackbox =>
      _name.text.toLowerCase().contains('jackbox') ||
      _path.text.toLowerCase().contains('jackbox');

  /// What gets saved: a bare host gets https, anything else is dropped (the
  /// server keeps only web pages).
  String get _phoneUrlToSave {
    if (!_phoneSite) return '';
    final text = _phoneUrl.text.trim();
    if (text.isEmpty) return '';
    return text.contains('://') ? text : 'https://$text';
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

  /// "Find cover" only changes the cover.
  Future<void> _searchCover() async {
    final pick = await showDialog<CoverPick>(
      context: context,
      builder: (_) => CoverSearchDialog(initialQuery: _name.text.trim()),
    );
    if (pick == null || !mounted) return;
    setState(() => _coverPath = pick.path);
  }

  /// "Find game data": search the game, then show everything the store has
  /// (cover, description, tags, trailer, images) and fill only the fields
  /// the host checks.
  Future<void> _fetchData() async {
    final pick = await showDialog<CoverPick>(
      context: context,
      builder: (_) => CoverSearchDialog(initialQuery: _name.text.trim()),
    );
    if (pick == null || !mounted) return;
    var details = pick.details;
    if (details == null && pick.steamAppId != null) {
      setState(() => _fetchingData = true);
      details = await SteamDetails.fetch(pick.steamAppId!);
      if (!mounted) return;
      setState(() => _fetchingData = false);
    }
    final chosen = await showDialog<Set<GameDataField>>(
      context: context,
      builder: (_) => GameDataPreviewDialog(
        pick: pick,
        details: details,
        filled: {
          if (_coverPath.isNotEmpty) GameDataField.cover,
          if (_description.text.trim().isNotEmpty) GameDataField.description,
          if (_tags.text.trim().isNotEmpty) GameDataField.tags,
          if (_trailer.text.trim().isNotEmpty) GameDataField.trailer,
          if (_screenshots.isNotEmpty) GameDataField.images,
        },
      ),
    );
    if (chosen == null || !mounted) return;
    final found = details;
    setState(() {
      if (chosen.contains(GameDataField.cover)) _coverPath = pick.path;
      if (found == null) return;
      if (chosen.contains(GameDataField.description)) {
        _description.text = found.description;
      }
      if (chosen.contains(GameDataField.tags)) {
        _tags.text = found.tags.join(', ');
      }
      if (chosen.contains(GameDataField.trailer)) {
        _trailer.text = found.trailerUrl;
      }
      if (chosen.contains(GameDataField.images)) {
        _screenshots = [...found.screenshots];
      }
    });
  }

  void _searchTrailer() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    launchUrl(
      Uri.https('www.youtube.com', '/results', {
        'search_query': '$name trailer',
      }),
      mode: LaunchMode.externalApplication,
    );
  }

  /// Opens the controller layout editor: a new layout gets selected, an
  /// edited one is reloaded so the preview shows the change.
  Future<void> _openLayoutEditor(
    ValueChanged<String> select, {
    ControllerPreset? preset,
  }) async {
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
              preset: preset,
              existingNames: [for (final p in _presets) p.name],
              onCancel: () => Navigator.of(dialogContext).pop(),
              onSaved: (saved) => Navigator.of(dialogContext).pop(saved),
            ),
          ),
        ),
      ),
    );
    branding.dispose();
    if (!mounted) return;
    // However the editor closed, the list comes back from the server, so a
    // new layout shows up and an edited one shows its changes.
    await _reloadPresets();
    if (!mounted || created == null) return;
    if (!_presets.any((p) => p.id == created.id)) {
      setState(() => _presets = [..._presets, created]);
    }
    select(created.id);
  }

  Future<void> _reloadPresets() async {
    try {
      final catalog = await context.read<SessionController>().api.fetchPresets();
      if (!mounted) return;
      setState(() => _presets = [
        ...catalog.builtInPresets,
        ...catalog.gamePresets,
        ...catalog.customPresets,
      ]);
    } catch (_) {}
  }

  ControllerPreset? _presetById(String? id) {
    for (final preset in _presets) {
      if (preset.id == id) return preset;
    }
    return null;
  }

  /// What the chosen layout looks like, so it isn't picked by name alone.
  Widget _layoutPreview() {
    final preset = _presetById(_presetId);
    return Container(
      height: 150,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(10),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.backgroundColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.textPrimary, width: 3),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOutBack,
        transitionBuilder: (child, animation) => ScaleTransition(
          scale: Tween(begin: 0.92, end: 1.0).animate(animation),
          child: FadeTransition(opacity: animation, child: child),
        ),
        child: preset == null
            ? Text(
                context.l10n.session.keepLayoutHint,
                key: const ValueKey('none'),
                textAlign: TextAlign.center,
                style: _captionStyle,
              )
            : StructuredLayoutPreview(
                key: ValueKey(preset),
                brandingMode: ControllerBranding.modeFromWire(
                  _controllerMode ?? 'x360',
                ),
                layout: preset.layout,
                compact: true,
              ),
      ),
    );
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
      description: _description.text.trim(),
      tags: [
        for (final tag in _tags.text.split(','))
          if (tag.trim().isNotEmpty) tag.trim(),
      ],
      trailerUrl: _trailer.text.trim(),
      addedAt: widget.game?.addedAt ?? 0,
      lastPlayedAt: widget.game?.lastPlayedAt ?? 0,
      screenshots: _screenshots,
      phoneUrl: _phoneUrlToSave,
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
          Row(
            children: [
              Expanded(child: _field(_name)),
              const SizedBox(width: 8),
              Tooltip(
                message: strings.fetchDataHint,
                child: JuicyButton(
                  onPressed: _fetchingData ? null : _fetchData,
                  backgroundColor: AppColors.highlightColor,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_fetchingData)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        const Icon(
                          Icons.auto_awesome_rounded,
                          size: 18,
                          color: AppColors.textPrimary,
                        ),
                      const SizedBox(width: 6),
                      Text(strings.fetchData, style: _buttonStyle),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (_fetchingData) ...[
            const SizedBox(height: 6),
            Text(strings.steamInfoLoading, style: _captionStyle),
          ],
          _label(strings.gameArguments),
          _field(_arguments),
          _label(strings.gameCover),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              CoverTile(
                path: _coverPath,
                onRemove: () => setState(() => _coverPath = ''),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    JuicyButton(
                      onPressed: _searchCover,
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
                  ],
                ),
              ),
            ],
          ),
          _label(strings.gameDescription),
          _field(_description, hint: strings.gameDescriptionHint, lines: 3),
          _label(strings.gameTags),
          _field(_tags, hint: strings.gameTagsHint),
          _label(strings.gameTrailer),
          Row(
            children: [
              Expanded(child: _field(_trailer, hint: strings.gameTrailerHint)),
              const SizedBox(width: 8),
              _smallButton(strings.searchTrailer, _searchTrailer),
            ],
          ),
          _label(strings.gameImages),
          ImageGallery(
            urls: _screenshots,
            onChanged: (urls) => setState(() => _screenshots = urls),
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
          _layoutPreview(),
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
                  final from = start.clamp(1, _maxPlayersLimit);
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
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      strings.phoneSiteButton,
                      style: _bodyStyle.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(strings.phoneSiteButtonHint, style: _captionStyle),
                  ],
                ),
              ),
              JuicyToggle(
                value: _phoneSite,
                onChanged: (v) => setState(() {
                  _phoneSite = v;
                  if (v && _phoneUrl.text.trim().isEmpty) {
                    _phoneUrl.text = _jackboxUrl;
                  }
                }),
              ),
            ],
          ),
          if (!_phoneSite && _looksLikeJackbox) ...[
            const SizedBox(height: 8),
            Text(
              '^-^  ${strings.phoneSiteJackboxTip}',
              style: _captionStyle.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutBack,
            alignment: Alignment.topCenter,
            child: _phoneSite
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label(strings.phoneSiteAddress),
                      _field(_phoneUrl, hint: _jackboxUrl),
                    ],
                  )
                : const SizedBox(width: double.infinity),
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
    final chosen = _presetById(value);
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
        if (chosen != null && !chosen.isBuiltIn) ...[
          const SizedBox(width: 6),
          Tooltip(
            message: context.l10n.session.editLayout,
            child: JuicyIconButton(
              size: 36,
              borderRadius: 10,
              icon: const Icon(Icons.edit_rounded, size: 18),
              onTap: () => _openLayoutEditor(
                (id) => onChanged(id),
                preset: chosen,
              ),
            ),
          ),
        ],
        const SizedBox(width: 6),
        Tooltip(
          message: context.l10n.session.createLayout,
          child: JuicyIconButton(
            size: 36,
            borderRadius: 10,
            icon: const Icon(Icons.add_rounded, size: 20),
            onTap: () => _openLayoutEditor((id) => onChanged(id)),
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

  Widget _field(
    TextEditingController controller, {
    String? hint,
    int lines = 1,
  }) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.textPrimary, width: 2),
    );
    return TextField(
      controller: controller,
      style: _bodyStyle,
      minLines: lines,
      maxLines: lines == 1 ? 1 : lines + 3,
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
    items: {for (var i = 1; i <= _maxPlayersLimit; i++) i: '$i'},
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
