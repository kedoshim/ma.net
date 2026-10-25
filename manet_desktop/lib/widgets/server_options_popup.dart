import 'package:flutter/material.dart';
import '../services/sound_effect_service.dart';
import '../theme/app_colors.dart';
import '../l10n/app_localizations.dart';
import 'juicy_widgets.dart';
import '../utils/app_preferences.dart';

class ServerOptionsPopup extends StatefulWidget {
  final ColorTheme currentTheme;
  final ValueChanged<ColorTheme> onThemeChanged;
  final int currentTimeoutMinutes;
  final ValueChanged<int> onTimeoutChanged;
  final ValueChanged<int>? onMatchSecondsChanged;
  /// Minutes an abandoned game waits before closing (0: never).
  final ValueChanged<int>? onAbandonCloseChanged;
  final ValueChanged<bool>? onFreeModeChanged;
  final ValueChanged<bool>? onConsoleModeChanged;
  final ValueChanged<String>? onLobbyStartRuleChanged;
  final ValueChanged<String>? onMousePasswordChanged;
  /// Console mode has no layout picker in the lobby; this opens the editor.
  final VoidCallback? onOpenLayouts;
  /// Join rule for the local network; the online one lives in "Play online".

  const ServerOptionsPopup({
    super.key,
    required this.currentTheme,
    required this.onThemeChanged,
    required this.currentTimeoutMinutes,
    required this.onTimeoutChanged,
    this.onMatchSecondsChanged,
    this.onAbandonCloseChanged,
    this.onFreeModeChanged,
    this.onConsoleModeChanged,
    this.onLobbyStartRuleChanged,
    this.onMousePasswordChanged,
    this.onOpenLayouts,
  });

  @override
  State<ServerOptionsPopup> createState() => _ServerOptionsPopupState();
}

class _ServerOptionsPopupState extends State<ServerOptionsPopup> {
  late ColorTheme _selectedTheme;
  late int _selectedTimeoutMinutes;
  bool _fullScreen = true;
  int _matchSeconds = 10;
  static const _abandonSteps = [0, 10, 20, 30, 45, 60, 90, 120];
  int _abandonMinutes = 30;
  bool _freeMode = true;
  bool _consoleMode = true;
  String _lobbyStartRule = 'majority';
  final TextEditingController _mousePassword = TextEditingController();
  bool _showPassword = false;

  /// The slider position closest to the saved minutes.
  int get _abandonStep {
    var best = 0;
    for (var i = 1; i < _abandonSteps.length; i++) {
      if ((_abandonSteps[i] - _abandonMinutes).abs() <
          (_abandonSteps[best] - _abandonMinutes).abs()) {
        best = i;
      }
    }
    return best;
  }

  @override
  void dispose() {
    _mousePassword.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _selectedTheme = widget.currentTheme;
    _selectedTimeoutMinutes = widget.currentTimeoutMinutes;
    AppPreferences.fullScreen().then((value) {
      if (mounted) setState(() => _fullScreen = value);
    });
    AppPreferences.matchSeconds().then((value) {
      if (mounted) setState(() => _matchSeconds = value);
    });
    AppPreferences.abandonCloseMinutes().then((value) {
      if (mounted) setState(() => _abandonMinutes = value);
    });
    AppPreferences.freeModeEnabled().then((value) {
      if (mounted) setState(() => _freeMode = value);
    });
    AppPreferences.consoleMode().then((value) {
      if (mounted) setState(() => _consoleMode = value);
    });
    AppPreferences.lobbyStartRule().then((value) {
      if (mounted) setState(() => _lobbyStartRule = value);
    });
    AppPreferences.mousePassword().then((value) {
      if (mounted) _mousePassword.text = value;
    });
  }

  Widget _buildLanguageButton(BuildContext context, Locale locale, String label) {
    final isSelected = context.currentLocale.languageCode == locale.languageCode;
    return JuicyCard(
      isSelected: isSelected,
      selectedColor: AppColors.highlightColor,
      backgroundColor: AppColors.lightColor,
      borderRadius: 12,
      borderThickness: 3.0,
      onTap: () {
        SoundEffectService.instance.playThemeSelect();
        context.setLocale(locale);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Text(
          label,
          style: const TextStyle(
            fontFamily: 'momo',
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return JuicyDialog(
      title: context.l10n.settings.title,
      maxWidth: 400,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.settings.colorsTitle,
            style: const TextStyle(
              fontFamily: 'momo',
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(ColorTheme.values.length, (index) {
              final theme = ColorTheme.values[index];
              final themeColor = AppColors.getTheme(theme);
              final isSelected = _selectedTheme == theme;

              return JuicyCard(
                isSelected: isSelected,
                selectedColor: themeColor.highlight,
                backgroundColor: themeColor.background,
                borderRadius: 12,
                borderThickness: 3.0,
                onTap: () {
                  SoundEffectService.instance.playThemeSelect();
                  setState(() => _selectedTheme = theme);
                  AppColors.setTheme(theme);
                  widget.onThemeChanged(theme);
                },
                child: const SizedBox(
                  width: 50,
                  height: 50,
                ),
              );
            }),
          ),
          const SizedBox(height: 24),
          Text(
            context.l10n.settings.timeoutTitle,
            style: const TextStyle(
              fontFamily: 'momo',
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: AppColors.highlightColor,
                    inactiveTrackColor: AppColors.greyDisabled.withValues(alpha: 0.3),
                    thumbColor: AppColors.highlightColor,
                    overlayColor: AppColors.highlightColor.withValues(alpha: 0.2),
                    valueIndicatorColor: AppColors.textPrimary,
                    valueIndicatorTextStyle: const TextStyle(
                      fontFamily: 'momo',
                      color: Colors.white,
                    ),
                  ),
                  child: Slider(
                    value: _selectedTimeoutMinutes.toDouble(),
                    min: 1,
                    max: 15,
                    divisions: 14,
                    label: context.l10n.settings.timeoutValue(_selectedTimeoutMinutes),
                    onChanged: (value) {
                      setState(() {
                        _selectedTimeoutMinutes = value.toInt();
                      });
                      widget.onTimeoutChanged(_selectedTimeoutMinutes);
                    },
                  ),
                ),
              ),
              SizedBox(
                width: 70,
                child: Center(
                  child: Text(
                    context.l10n.settings.timeoutValue(_selectedTimeoutMinutes),
                    style: const TextStyle(
                      fontFamily: 'momo',
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (widget.onMatchSecondsChanged != null) ...[
            const SizedBox(height: 24),
            Text(
              context.l10n.settings.matchSecondsTitle,
              style: const TextStyle(
                fontFamily: 'momo',
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: AppColors.textPrimary,
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: _matchSeconds.toDouble(),
                    min: 5,
                    max: 30,
                    divisions: 25,
                    activeColor: AppColors.highlightColor,
                    label: context.l10n.settings.matchSecondsValue(_matchSeconds),
                    onChanged: (value) =>
                        setState(() => _matchSeconds = value.round()),
                    onChangeEnd: (value) =>
                        widget.onMatchSecondsChanged!(value.round()),
                  ),
                ),
                SizedBox(
                  width: 70,
                  child: Center(
                    child: Text(
                      context.l10n.settings.matchSecondsValue(_matchSeconds),
                      style: const TextStyle(
                        fontFamily: 'momo',
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (widget.onAbandonCloseChanged != null) ...[
            const SizedBox(height: 24),
            Text(
              context.l10n.settings.abandonCloseTitle,
              style: const TextStyle(
                fontFamily: 'momo',
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              context.l10n.settings.abandonCloseHint,
              style: const TextStyle(
                fontFamily: 'momo',
                fontSize: 13,
                color: AppColors.textPrimary,
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: _abandonStep.toDouble(),
                    min: 0,
                    max: (_abandonSteps.length - 1).toDouble(),
                    divisions: _abandonSteps.length - 1,
                    activeColor: AppColors.highlightColor,
                    label: context.l10n.settings.abandonCloseValue(_abandonMinutes),
                    onChanged: (value) => setState(
                      () => _abandonMinutes = _abandonSteps[value.round()],
                    ),
                    onChangeEnd: (value) =>
                        widget.onAbandonCloseChanged!(_abandonSteps[value.round()]),
                  ),
                ),
                SizedBox(
                  width: 70,
                  child: Center(
                    child: Text(
                      context.l10n.settings.abandonCloseValue(_abandonMinutes),
                      style: const TextStyle(
                        fontFamily: 'momo',
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (widget.onConsoleModeChanged != null) ...[
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.settings.consoleModeTitle,
                        style: const TextStyle(
                          fontFamily: 'momo',
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        context.l10n.settings.consoleModeHint,
                        style: TextStyle(
                          fontFamily: 'momo',
                          fontSize: 12,
                          color: AppColors.textPrimary.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                JuicyToggle(
                  value: _consoleMode,
                  onChanged: (value) {
                    SoundEffectService.instance.playThemeSelect();
                    setState(() {
                      _consoleMode = value;
                      if (!value) _freeMode = true;
                    });
                    widget.onConsoleModeChanged!(value);
                  },
                ),
              ],
            ),
          ],
          if (widget.onOpenLayouts != null && _consoleMode) ...[
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.settings.layoutsTitle,
                        style: const TextStyle(
                          fontFamily: 'momo',
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        context.l10n.settings.layoutsHint,
                        style: TextStyle(
                          fontFamily: 'momo',
                          fontSize: 12,
                          color: AppColors.textPrimary.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                JuicyButton(
                  onPressed: widget.onOpenLayouts,
                  backgroundColor: AppColors.highlightColor,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.gamepad_rounded,
                        size: 18,
                        color: AppColors.textPrimary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        context.l10n.settings.layoutsOpen,
                        style: const TextStyle(
                          fontFamily: 'momo',
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
          if (widget.onLobbyStartRuleChanged != null && _consoleMode) ...[
            const SizedBox(height: 24),
            Text(
              context.l10n.settings.lobbyStartTitle,
              style: const TextStyle(
                fontFamily: 'momo',
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              context.l10n.settings.lobbyStartHint,
              style: TextStyle(
                fontFamily: 'momo',
                fontSize: 12,
                color: AppColors.textPrimary.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                for (final (rule, label) in [
                  ('majority', context.l10n.settings.lobbyStartMajority),
                  ('all', context.l10n.settings.lobbyStartAll),
                ]) ...[
                  JuicyCard(
                    isSelected: _lobbyStartRule == rule,
                    selectedColor: AppColors.highlightColor,
                    backgroundColor: AppColors.lightColor,
                    borderRadius: 12,
                    borderThickness: 3.0,
                    onTap: () {
                      SoundEffectService.instance.playThemeSelect();
                      setState(() => _lobbyStartRule = rule);
                      widget.onLobbyStartRuleChanged!(rule);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Text(
                        label,
                        style: const TextStyle(
                          fontFamily: 'momo',
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
              ],
            ),
          ],
          if (widget.onMousePasswordChanged != null && _consoleMode) ...[
            const SizedBox(height: 24),
            Text(
              context.l10n.settings.mousePasswordTitle,
              style: const TextStyle(
                fontFamily: 'momo',
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              context.l10n.settings.mousePasswordHint,
              style: TextStyle(
                fontFamily: 'momo',
                fontSize: 12,
                color: AppColors.textPrimary.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _mousePassword,
              obscureText: !_showPassword,
              onChanged: widget.onMousePasswordChanged,
              style: const TextStyle(fontFamily: 'momo', fontSize: 14, color: AppColors.textPrimary),
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: AppColors.lightColor,
                suffixIcon: IconButton(
                  icon: Icon(
                    _showPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                    color: AppColors.textPrimary,
                  ),
                  onPressed: () => setState(() => _showPassword = !_showPassword),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.textPrimary, width: 2),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.textPrimary, width: 2),
                ),
              ),
            ),
          ],
          // Tool mode always has free mode; the choice only exists in
          // console mode.
          if (widget.onFreeModeChanged != null && _consoleMode) ...[
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.settings.freeModeTitle,
                        style: const TextStyle(
                          fontFamily: 'momo',
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        context.l10n.settings.freeModeHint,
                        style: TextStyle(
                          fontFamily: 'momo',
                          fontSize: 12,
                          color: AppColors.textPrimary.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                JuicyToggle(
                  value: _freeMode,
                  onChanged: (value) {
                    SoundEffectService.instance.playThemeSelect();
                    setState(() => _freeMode = value);
                    widget.onFreeModeChanged!(value);
                  },
                ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Text(
                  context.l10n.settings.fullScreenTitle,
                  style: const TextStyle(
                    fontFamily: 'momo',
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              JuicyToggle(
                value: _fullScreen,
                onChanged: (value) {
                  SoundEffectService.instance.playThemeSelect();
                  setState(() => _fullScreen = value);
                  AppPreferences.setFullScreen(value);
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            context.l10n.settings.languageTitle,
            style: const TextStyle(
              fontFamily: 'momo',
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              _buildLanguageButton(context, const Locale('pt', 'BR'), 'Português'),
              const SizedBox(width: 16),
              _buildLanguageButton(context, const Locale('en', 'US'), 'English'),
            ],
          ),
        ],
      ),
    );
  }
}
