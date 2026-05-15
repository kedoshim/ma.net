import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';
import '../models/player_face.dart';
import 'player_face_indicator.dart';

class OptionsPopup extends StatefulWidget {
  final bool dpadMode;
  final ValueChanged<bool> onDpadModeChanged;
  final Map<String, bool> buttonVisibility;
  final ValueChanged<String> onButtonVisibilityChanged;
  final bool editMode;
  final ValueChanged<bool> onEditModeChanged;
  final ColorTheme currentTheme;
  final ValueChanged<ColorTheme> onThemeChanged;
  final VoidCallback? onDisconnectRequested;
  final PlayerFaceData playerFace;
  final ValueChanged<PlayerFaceData> onPlayerFaceChanged;

  const OptionsPopup({
    super.key,
    required this.dpadMode,
    required this.onDpadModeChanged,
    required this.buttonVisibility,
    required this.onButtonVisibilityChanged,
    required this.editMode,
    required this.onEditModeChanged,
    required this.currentTheme,
    required this.onThemeChanged,
    this.onDisconnectRequested,
    required this.playerFace,
    required this.onPlayerFaceChanged,
  });

  @override
  State<OptionsPopup> createState() => _OptionsPopupState();
}

class _OptionsPopupState extends State<OptionsPopup> {
  late bool _dpadMode;
  late bool _editMode;
  late ColorTheme _selectedTheme;
  late PlayerFaceData _playerFace;
  late TextEditingController _faceController;
  late FocusNode _faceFocusNode;

  @override
  void initState() {
    super.initState();
    _dpadMode = widget.dpadMode;
    _editMode = widget.editMode;
    _selectedTheme = widget.currentTheme;
    _playerFace = widget.playerFace;
    _faceController = TextEditingController(text: widget.playerFace.faceText);
    _faceFocusNode = FocusNode();
    _faceFocusNode.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _faceController.dispose();
    _faceFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isTypingFace = _faceFocusNode.hasFocus;

    return AlertDialog(
      backgroundColor: AppColors.screenBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: AppColors.textPrimary,
          width: AppColors.borderThickness,
        ),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      titlePadding: isTypingFace ? EdgeInsets.zero : null,
      title: isTypingFace
          ? const SizedBox.shrink()
          : Row(
              children: [
                const Text(
                  'Opcoes',
                  style: TextStyle(
                    fontFamily: 'pico',
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                if (kIsWeb)
                  TextButton.icon(
                    onPressed: () async {
                      final url = Uri.base.resolve('/apk');
                      try {
                        await launchUrl(url, webOnlyWindowName: '_blank');
                      } catch (e) {
                        debugPrint('Could not launch download URL: $e');
                      }
                    },
                    icon: const Icon(
                      Icons.android,
                      size: 18,
                      color: AppColors.textPrimary,
                    ),
                    label: const Text(
                      'Baixar App Android',
                      style: TextStyle(
                        fontFamily: 'pico',
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(40, 40),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'X',
                    style: TextStyle(
                      fontFamily: 'pico',
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 920,
          child: Row(
            crossAxisAlignment: isTypingFace
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            children: [
              if (!isTypingFace) ...[
                Expanded(
                  key: const ValueKey('settings'),
                  child: _buildSettingsColumn(),
                ),
                const SizedBox(width: 20),
                Container(
                  width: 1,
                  height: 540,
                  color: AppColors.textPrimary.withValues(alpha: 0.12),
                ),
                const SizedBox(width: 20),
              ],
              Expanded(
                key: const ValueKey('face'),
                child: _buildFaceColumn(isTypingFace),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsColumn() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Controle',
          style: TextStyle(
            fontFamily: 'pico',
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          title: const Text('Modo D-Pad', style: TextStyle(fontFamily: 'pico')),
          value: _dpadMode,
          onChanged: (value) {
            setState(() => _dpadMode = value);
            widget.onDpadModeChanged(value);
          },
          activeThumbColor: AppColors.switchActiveThumb,
          activeTrackColor: AppColors.highlightColor,
        ),
        const Divider(),
        SwitchListTile(
          title: const Text(
            'Modo de Edicao',
            style: TextStyle(fontFamily: 'pico'),
          ),
          subtitle: const Text(
            'Reordenar botoes arrastando',
            style: TextStyle(fontFamily: 'pico', fontSize: 12),
          ),
          value: _editMode,
          onChanged: (value) {
            setState(() => _editMode = value);
            widget.onEditModeChanged(value);
          },
          activeThumbColor: AppColors.switchActiveThumb,
          activeTrackColor: AppColors.highlightColor,
        ),
        const Divider(),
        const Text(
          'Tema de Cores',
          style: TextStyle(
            fontFamily: 'pico',
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        _buildThemeSelector(),
        const Divider(),
        const Text(
          'Botoes Visiveis',
          style: TextStyle(
            fontFamily: 'pico',
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        ..._buildButtonToggles(),
        const Divider(),
        if (!kIsWeb)
          ListTile(
            leading: const Icon(Icons.link_off, color: AppColors.textPrimary),
            title: const Text(
              'Desconectar',
              style: TextStyle(
                fontFamily: 'pico',
                color: AppColors.textPrimary,
              ),
            ),
            onTap: () {
              Navigator.of(context).pop();
              widget.onDisconnectRequested?.call();
            },
          ),
      ],
    );
  }

  Widget _buildFaceColumn(bool isTypingFace) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isTypingFace) ...[
          const Text(
            'Rostinhos',
            style: TextStyle(
              fontFamily: 'pico',
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Deixe com a sua cara :)',
            style: TextStyle(
              fontFamily: 'pico',
              fontSize: 12,
              color: AppColors.textPrimary.withValues(alpha: 0.65),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.highlightColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: AppColors.textPrimary.withValues(alpha: 0.2),
                width: 2,
              ),
            ),
            child: Column(
              children: [
                PlayerFaceIndicator(
                  face: _playerFace,
                  size: 120,
                  roundedSquare: true,
                  borderColor: AppColors.textPrimary,
                ),
                const SizedBox(height: 10),
                Text(
                  _playerFace.presetId ?? 'custom',
                  style: const TextStyle(
                    fontFamily: 'pico',
                    fontSize: 12,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Cores',
            style: TextStyle(
              fontFamily: 'pico',
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: playerFacePalette.map(_buildColorSwatch).toList(),
          ),
          const SizedBox(height: 14),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              key: const ValueKey('faceInput'),
              child: Column(
                crossAxisAlignment: isTypingFace
                    ? CrossAxisAlignment.center
                    : CrossAxisAlignment.start,
                children: [
                  if (!isTypingFace) ...[
                    const Text(
                      'Rosto',
                      style: TextStyle(
                        fontFamily: 'pico',
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  SizedBox(
                    width: isTypingFace ? 240 : null,
                    child: TextField(
                      focusNode: _faceFocusNode,
                      controller: _faceController,
                      textAlign: TextAlign.center,
                      inputFormatters: [
                        FilteringTextInputFormatter.deny(RegExp(r'[\r\n\t]')),
                      ],
                      style: TextStyle(
                        fontFamily: 'monomaniac',
                        fontSize: isTypingFace ? 48 : 22,
                        color: AppColors.textPrimary,
                      ),
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _faceFocusNode.unfocus(),
                      onTapOutside: (_) => _faceFocusNode.unfocus(),
                      decoration: InputDecoration(
                        counterText: '',
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: isTypingFace ? 20 : 12,
                          vertical: isTypingFace ? 24 : 12,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            isTypingFace ? 20 : 14,
                          ),
                          borderSide: BorderSide(
                            color: AppColors.textPrimary,
                            width: isTypingFace ? 3 : 2,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            isTypingFace ? 20 : 14,
                          ),
                          borderSide: BorderSide(
                            color: isTypingFace
                                ? AppColors.highlightColor
                                : AppColors.textPrimary,
                            width: isTypingFace ? 4 : 2,
                          ),
                        ),
                      ),
                      onChanged: (value) {
                        final sanitized = sanitizeFaceText(value);
                        if (sanitized != value) {
                          _faceController.value = TextEditingValue(
                            text: sanitized,
                            selection: TextSelection.collapsed(
                              offset: sanitized.length,
                            ),
                          );
                        }
                        _updateFace(
                          _playerFace.copyWith(
                            faceText: sanitized,
                            clearPreset: true,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            if (!isTypingFace) ...[
              const SizedBox(width: 14),
              Expanded(
                key: const ValueKey('spinInput'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Rotacao',
                      style: TextStyle(
                        fontFamily: 'pico',
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: PlayerFaceRotation.values
                          .map(_buildRotationButton)
                          .toList(),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        const Text(
          'Presets',
          style: TextStyle(
            fontFamily: 'pico',
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: playerFacePresets.map(_buildPresetChip).toList(),
        ),
        const SizedBox(height: 14),
      ],
    );
  }

  List<Widget> _buildButtonToggles() {
    const buttons = ['A', 'B', 'X', 'Y', 'RB', 'RT', 'RS', 'LB', 'LT', 'LS'];

    return buttons.map((button) {
      final buttonKey = 'btn$button';
      return SwitchListTile(
        title: Text(button, style: const TextStyle(fontFamily: 'pico')),
        value: widget.buttonVisibility[buttonKey] ?? true,
        onChanged: (value) {
          widget.onButtonVisibilityChanged(buttonKey);
          setState(() {});
        },
        dense: true,
        activeThumbColor: AppColors.switchActiveThumb,
        activeTrackColor: AppColors.highlightColor,
      );
    }).toList();
  }

  Widget _buildThemeSelector() {
    final themes = ColorTheme.values;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(themes.length, (index) {
        final theme = themes[index];
        final themeColor = AppColors.getTheme(theme);
        final isSelected = _selectedTheme == theme;

        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedTheme = theme;
            });
            AppColors.setTheme(theme);
            widget.onThemeChanged(theme);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: themeColor.background,
                  border: Border.all(
                    color: AppColors.textPrimary,
                    width: isSelected ? 3 : AppColors.borderThickness,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 4),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildPresetChip(PlayerFacePreset preset) {
    final isSelected = _playerFace.presetId == preset.id;
    return GestureDetector(
      onTap: () {
        final nextFace = _playerFace.applyPreset(preset);
        _faceController.text = nextFace.faceText;
        _faceController.selection = TextSelection.collapsed(
          offset: nextFace.faceText.length,
        );
        _updateFace(nextFace);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? preset.color.withValues(alpha: 0.35)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? AppColors.textPrimary
                : AppColors.textPrimary.withValues(alpha: 0.25),
            width: 2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PlayerFaceIndicator(
              face: _playerFace.applyPreset(preset),
              size: 28,
              roundedSquare: true,
            ),
            const SizedBox(width: 8),
            Text(
              preset.label,
              style: const TextStyle(
                fontFamily: 'pico',
                fontSize: 12,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorSwatch(Color color) {
    final isSelected = color.toARGB32() == _playerFace.color.toARGB32();
    return GestureDetector(
      onTap: () =>
          _updateFace(_playerFace.copyWith(color: color, clearPreset: true)),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.textPrimary,
            width: isSelected ? 3 : 1.5,
          ),
        ),
        child: isSelected
            ? const Icon(Icons.check, size: 18, color: Colors.black87)
            : null,
      ),
    );
  }

  Widget _buildRotationButton(PlayerFaceRotation rotation) {
    final isSelected = _playerFace.rotation == rotation;

    return GestureDetector(
      onTap: () => _updateFace(
        _playerFace.copyWith(rotation: rotation, clearPreset: true),
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.highlightColor.withValues(alpha: 0.35)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppColors.textPrimary
                : AppColors.textPrimary.withValues(alpha: 0.25),
            width: 2,
          ),
        ),
        child: Center(
          child: PlayerFaceIndicator(
            face: _playerFace.copyWith(rotation: rotation),
            size: 34,
            roundedSquare: true,
            borderColor: Colors.transparent,
          ),
        ),
      ),
    );
  }

  void _updateFace(PlayerFaceData nextFace) {
    setState(() {
      _playerFace = nextFace;
    });
    widget.onPlayerFaceChanged(nextFace);
  }
}
