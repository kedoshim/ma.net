import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../services/access_service.dart';
import '../services/host_api_service.dart';
import '../services/online_service.dart';
import '../services/sound_effect_service.dart';
import '../theme/app_colors.dart';
import '../utils/app_preferences.dart';
import 'juicy_widgets.dart';

const _onlineGreen = Color(0xFF10B981);
const _busyAmber = Color(0xFFF59E0B);
const _errorRed = Color(0xFFEF4444);

const TextStyle _titleStyle = TextStyle(
  fontFamily: 'momo',
  fontWeight: FontWeight.bold,
  fontSize: 16,
  color: AppColors.textPrimary,
);
const TextStyle _labelStyle = TextStyle(
  fontFamily: 'momo',
  fontWeight: FontWeight.bold,
  fontSize: 14,
  color: AppColors.textPrimary,
);
const TextStyle _bodyStyle = TextStyle(
  fontFamily: 'momo',
  fontSize: 14,
  color: AppColors.textPrimary,
);
TextStyle get _hintStyle => TextStyle(
  fontFamily: 'momo',
  fontSize: 12,
  color: AppColors.textPrimary.withValues(alpha: 0.7),
);

Color _stateColor(OnlineState state) => switch (state) {
  OnlineState.online => _onlineGreen,
  OnlineState.starting || OnlineState.verifying => _busyAmber,
  OnlineState.error => _errorRed,
  OnlineState.off => AppColors.textPrimary.withValues(alpha: 0.35),
};

void _toast(BuildContext context, String message) {
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
    SnackBar(
      content: Text(message, style: _labelStyle.copyWith(color: Colors.white)),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

/// Toolbar button for "Play online". Its color follows the tunnel; since
/// the panel closes right after "Activate", the outcome arrives as a toast.
class OnlinePlayButton extends StatefulWidget {
  final HostApiService api;

  const OnlinePlayButton({super.key, required this.api});

  @override
  State<OnlinePlayButton> createState() => _OnlinePlayButtonState();
}

class _OnlinePlayButtonState extends State<OnlinePlayButton> {
  late final OnlineService _online = OnlineService.of(widget.api);
  late OnlineState _lastState = _online.value.state;

  @override
  void initState() {
    super.initState();
    _online.addListener(_onChanged);
  }

  @override
  void dispose() {
    _online.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    final state = _online.value.state;
    final wasBusy = _lastState == OnlineState.starting || _lastState == OnlineState.verifying;
    _lastState = state;
    if (!mounted) return;
    setState(() {});
    if (wasBusy && state == OnlineState.online) {
      _toast(context, context.l10n.online.nowOnline);
    } else if (wasBusy && state == OnlineState.error) {
      _toast(context, context.l10n.online.failedToast);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _online.value;
    final active = status.state != OnlineState.off;
    return Tooltip(
      message: context.l10n.online.buttonTooltip,
      child: JuicyIconButton(
        size: 48,
        borderRadius: 14,
        backgroundColor: active ? _stateColor(status.state) : null,
        iconColor: active ? Colors.white : null,
        icon: status.isBusy
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
              )
            : const Icon(Icons.public_rounded),
        onTap: () {
          SoundEffectService.instance.playOptionsButton();
          showDialog(
            context: context,
            builder: (_) => OnlinePlayPanel(api: widget.api),
          );
        },
      ),
    );
  }
}

/// One screen: pick who can join, activate, back to the lobby.
class OnlinePlayPanel extends StatefulWidget {
  final HostApiService api;

  const OnlinePlayPanel({super.key, required this.api});

  @override
  State<OnlinePlayPanel> createState() => _OnlinePlayPanelState();
}

class _OnlinePlayPanelState extends State<OnlinePlayPanel> {
  late final OnlineService _online = OnlineService.of(widget.api);
  late final AccessService _access = AccessService.of(widget.api);
  final TextEditingController _password = TextEditingController();
  late AccessMode _mode = _access.value.onlineMode;
  bool _showPassword = false;
  bool _passwordMissing = false;

  @override
  void initState() {
    super.initState();
    AppPreferences.roomPassword().then((value) {
      if (mounted && _password.text.isEmpty) _password.text = value;
    });
    AppPreferences.accessModeOnline().then((mode) {
      if (mounted) setState(() => _mode = mode);
    });
  }

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<bool> _saveRules() async {
    final password = _password.text.trim();
    if (_mode == AccessMode.password && password.isEmpty) {
      setState(() => _passwordMissing = true);
      return false;
    }
    await _access.configure(onlineMode: _mode, password: password);
    return true;
  }

  Future<void> _activate() async {
    if (!await _saveRules()) return;
    await _online.start();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _save() async {
    if (!await _saveRules()) return;
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _stop() async {
    await _online.stop();
    if (mounted) Navigator.of(context).pop();
  }

  Widget _button(String label, VoidCallback onPressed, {bool primary = false}) {
    return JuicyButton(
      onPressed: onPressed,
      backgroundColor: primary ? AppColors.highlightColor : null,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      child: Text(label, style: _labelStyle),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.l10n.online;
    return ValueListenableBuilder<OnlineStatus>(
      valueListenable: _online,
      builder: (context, status, _) {
        final running = status.state != OnlineState.off && status.state != OnlineState.error;
        return JuicyDialog(
          title: strings.title,
          maxWidth: 520,
          actions: [
            if (running) ...[
              _button(strings.stop, _stop),
              _button(strings.save, _save, primary: true),
            ] else
              _button(
                status.state == OnlineState.error ? strings.retry : strings.activate,
                _activate,
                primary: true,
              ),
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (status.state == OnlineState.off)
                Text(strings.subtitle, style: _hintStyle)
              else
                _StatusSection(status: status),
              const SizedBox(height: 20),
              Text(context.l10n.access.whoCanJoin, style: _titleStyle),
              const SizedBox(height: 10),
              AccessModePicker(
                value: _mode,
                onChanged: (mode) => setState(() {
                  _mode = mode;
                  _passwordMissing = false;
                }),
              ),
              if (_mode == AccessMode.password) ...[
                const SizedBox(height: 12),
                RoomPasswordField(
                  controller: _password,
                  visible: _showPassword,
                  error: _passwordMissing ? context.l10n.access.passwordRequired : null,
                  onToggleVisible: () => setState(() => _showPassword = !_showPassword),
                  onChanged: (_) {
                    if (_passwordMissing) setState(() => _passwordMissing = false);
                  },
                ),
              ],
              if (_mode == AccessMode.open) ...[
                const SizedBox(height: 12),
                Text(strings.openWarning, style: _hintStyle),
              ],
              UnbanAllButton(access: _access),
            ],
          ),
        );
      },
    );
  }
}

class _StatusSection extends StatelessWidget {
  final OnlineStatus status;

  const _StatusSection({required this.status});

  @override
  Widget build(BuildContext context) {
    final strings = context.l10n.online;
    final label = switch (status.state) {
      OnlineState.off => strings.stateOff,
      OnlineState.starting => strings.stateStarting,
      OnlineState.verifying => strings.stateVerifying,
      OnlineState.online => strings.stateOnline,
      OnlineState.error => strings.stateError,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (status.isBusy)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: _busyAmber),
              )
            else
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: _stateColor(status.state),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.textPrimary, width: 2),
                ),
              ),
            const SizedBox(width: 10),
            Text(label, style: _titleStyle),
          ],
        ),
        if (status.state == OnlineState.error) ...[
          const SizedBox(height: 6),
          Text(strings.errorDetail(status.error), style: _hintStyle),
        ],
        if (status.isOnline) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: SelectableText(
                  status.url!.replaceFirst('https://', ''),
                  style: _bodyStyle.copyWith(fontFamily: 'monomaniac'),
                ),
              ),
              const SizedBox(width: 8),
              JuicyButton(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: status.url!));
                  if (context.mounted) _toast(context, strings.linkCopied);
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.copy_rounded, size: 16, color: AppColors.textPrimary),
                    const SizedBox(width: 6),
                    Text(strings.copyLink, style: _labelStyle),
                  ],
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Lifts every ban of this session; hidden when nobody is banned.
class UnbanAllButton extends StatelessWidget {
  final AccessService access;

  const UnbanAllButton({super.key, required this.access});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AccessStatus>(
      valueListenable: access,
      builder: (context, status, _) {
        if (status.bannedCount == 0) return const SizedBox.shrink();
        return Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: JuicyButton(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              onPressed: access.unbanAll,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.undo_rounded, size: 16, color: AppColors.textPrimary),
                  const SizedBox(width: 6),
                  Text(context.l10n.access.unbanAll(status.bannedCount), style: _labelStyle),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The three join rules as cards (also used for the local network rule).
class AccessModePicker extends StatelessWidget {
  final AccessMode value;
  final ValueChanged<AccessMode> onChanged;

  const AccessModePicker({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final strings = context.l10n.access;
    final options = [
      (AccessMode.open, Icons.lock_open_rounded, strings.modeOpen, strings.modeOpenHint),
      (AccessMode.password, Icons.password_rounded, strings.modePassword, strings.modePasswordHint),
      (AccessMode.approval, Icons.how_to_reg_rounded, strings.modeApproval, strings.modeApprovalHint),
    ];
    return Column(
      children: [
        for (final (mode, icon, label, hint) in options)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: JuicyCard(
              isSelected: value == mode,
              selectedColor: AppColors.highlightColor,
              backgroundColor: AppColors.lightColor,
              borderRadius: 12,
              borderThickness: 3.0,
              onTap: () {
                SoundEffectService.instance.playThemeSelect();
                onChanged(mode);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    Icon(icon, color: AppColors.textPrimary, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(label, style: _labelStyle),
                          Text(hint, style: _hintStyle),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class RoomPasswordField extends StatelessWidget {
  final TextEditingController controller;
  final bool visible;
  final String? error;
  final VoidCallback onToggleVisible;
  final ValueChanged<String> onChanged;

  const RoomPasswordField({
    super.key,
    required this.controller,
    required this.visible,
    required this.error,
    required this.onToggleVisible,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.textPrimary, width: 2),
    );
    return TextField(
      controller: controller,
      obscureText: !visible,
      onChanged: onChanged,
      maxLength: 64,
      style: _bodyStyle,
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: AppColors.lightColor,
        labelText: context.l10n.access.passwordLabel,
        labelStyle: _hintStyle,
        errorText: error,
        errorStyle: _hintStyle.copyWith(color: _errorRed),
        counterText: '',
        suffixIcon: IconButton(
          icon: Icon(
            visible ? Icons.visibility_off_rounded : Icons.visibility_rounded,
            color: AppColors.textPrimary,
          ),
          onPressed: onToggleVisible,
        ),
        border: border,
        enabledBorder: border,
        focusedBorder: border,
      ),
    );
  }
}
