import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/access_service.dart';
import '../services/host_api_service.dart';
import '../services/network_mode_service.dart';
import '../services/online_service.dart';
import '../services/sound_effect_service.dart';
import '../theme/app_colors.dart';
import 'access_widgets.dart';
import 'juicy_widgets.dart';

String networkModeLabel(BuildContext context, NetworkMode mode) {
  final strings = context.l10n.network;
  return switch (mode) {
    NetworkMode.local => strings.modeLocal,
    NetworkMode.both => strings.modeBoth,
    NetworkMode.online => strings.modeOnline,
  };
}

IconData networkModeIcon(NetworkMode mode) => switch (mode) {
  NetworkMode.local => Icons.wifi_rounded,
  NetworkMode.both => Icons.hub_rounded,
  NetworkMode.online => Icons.public_rounded,
};

/// A row of pill segments with one picked, drawn like the other juicy
/// controls. Used for the network mode and for the QR switch.
class JuicySegmented<T> extends StatelessWidget {
  final List<T> values;
  final T selected;
  final String Function(T) label;
  final IconData Function(T)? icon;

  /// Extra widget after a segment's label (the tunnel status dot).
  final Widget? Function(T)? trailing;
  final ValueChanged<T> onSelected;
  final double height;
  final double fontSize;

  const JuicySegmented({
    super.key,
    required this.values,
    required this.selected,
    required this.label,
    required this.onSelected,
    this.icon,
    this.trailing,
    this.height = 48,
    this.fontSize = 15,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.lightColor,
        borderRadius: BorderRadius.circular(height / 2),
        border: Border.all(color: AppColors.textPrimary, width: 3),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final value in values)
            _Segment(
              key: ValueKey(value),
              selected: value == selected,
              radius: height / 2,
              onTap: () {
                if (value == selected) return;
                SoundEffectService.instance.playThemeSelect();
                onSelected(value);
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(
                      icon!(value),
                      size: fontSize + 3,
                      color: AppColors.textPrimary,
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    label(value),
                    style: accessLabelStyle.copyWith(fontSize: fontSize),
                  ),
                  if (trailing?.call(value) case final Widget extra) ...[
                    const SizedBox(width: 6),
                    extra,
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  final bool selected;
  final double radius;
  final VoidCallback onTap;
  final Widget child;

  const _Segment({
    super.key,
    required this.selected,
    required this.radius,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutBack,
          // Scales with the control, so small switches stay in proportion.
          padding: EdgeInsets.symmetric(horizontal: radius * 0.6),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.highlightColor : Colors.transparent,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: selected ? AppColors.textPrimary : Colors.transparent,
              width: 2,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Small dot (or spinner) with the tunnel's state, for segments that use it.
class TunnelDot extends StatelessWidget {
  final OnlineStatus status;
  final double size;

  const TunnelDot({super.key, required this.status, this.size = 10});

  @override
  Widget build(BuildContext context) {
    if (status.isBusy) {
      return SizedBox(
        width: size + 2,
        height: size + 2,
        child: const CircularProgressIndicator(
          strokeWidth: 2.5,
          color: busyAmber,
        ),
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: onlineStateColor(status.state),
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.textPrimary, width: 1.5),
      ),
    );
  }
}

/// Header control: Local | Both | Online, plus a gear for the options.
/// Picking a mode applies it and opens the options right away.
class NetworkModeChip extends StatefulWidget {
  final HostApiService api;

  const NetworkModeChip({super.key, required this.api});

  @override
  State<NetworkModeChip> createState() => _NetworkModeChipState();
}

class _NetworkModeChipState extends State<NetworkModeChip> {
  late final NetworkModeService _network = NetworkModeService.of(widget.api);
  late OnlineState _lastState = _network.online.value.state;

  @override
  void initState() {
    super.initState();
    _network.addListener(_onChanged);
  }

  @override
  void dispose() {
    _network.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    final state = _network.online.value.state;
    final wasBusy =
        _lastState == OnlineState.starting ||
        _lastState == OnlineState.verifying;
    _lastState = state;
    if (!mounted) return;
    setState(() {});
    if (wasBusy && state == OnlineState.online) {
      showNetworkToast(context, context.l10n.online.nowOnline);
    } else if (wasBusy && state == OnlineState.error) {
      showNetworkToast(context, context.l10n.online.failedToast);
    }
  }

  void _openOptions() {
    showDialog(
      context: context,
      builder: (_) => NetworkOptionsPanel(api: widget.api),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mode = _network.value.mode;
    final online = _network.online.value;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Tooltip(
          message: context.l10n.network.chipTooltip,
          child: JuicySegmented<NetworkMode>(
            values: NetworkMode.values,
            selected: mode,
            label: (m) => networkModeLabel(context, m),
            icon: networkModeIcon,
            trailing: (m) => m != NetworkMode.local && m == mode
                ? TunnelDot(status: online)
                : null,
            onSelected: (m) {
              _network.setMode(m);
              _openOptions();
            },
          ),
        ),
        const SizedBox(width: 8),
        Tooltip(
          message: context.l10n.network.optionsTooltip,
          child: JuicyIconButton(
            size: 48,
            borderRadius: 14,
            icon: const Icon(Icons.tune_rounded),
            onTap: () {
              SoundEffectService.instance.playOptionsButton();
              _openOptions();
            },
          ),
        ),
      ],
    );
  }
}

/// Network mode on top, then a column per network that is in use: local
/// (the global rule and the hotspot) and internet (tunnel and its rule).
class NetworkOptionsPanel extends StatefulWidget {
  final HostApiService api;

  const NetworkOptionsPanel({super.key, required this.api});

  @override
  State<NetworkOptionsPanel> createState() => _NetworkOptionsPanelState();
}

class _NetworkOptionsPanelState extends State<NetworkOptionsPanel> {
  late final NetworkModeService _network = NetworkModeService.of(widget.api);
  late final AccessService _access = AccessService.of(widget.api);
  final TextEditingController _password = TextEditingController();
  final TextEditingController _onlinePassword = TextEditingController();
  AccessMode _mode = AccessMode.open;
  AccessMode _onlineMode = AccessMode.approval;
  bool _override = true;
  bool _passwordMissing = false;
  bool _onlinePasswordMissing = false;

  @override
  void initState() {
    super.initState();
    AccessRules.load().then((rules) {
      if (!mounted) return;
      setState(() {
        _mode = rules.mode;
        _password.text = rules.password;
        _override = rules.onlineOverride;
        _onlineMode = rules.onlineMode;
        _onlinePassword.text = rules.onlinePassword;
      });
    });
  }

  @override
  void dispose() {
    _password.dispose();
    _onlinePassword.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final state = _network.value;
    // Only rules that apply right now must be complete.
    final globalUsed = state.usesLan || !_override;
    final onlineUsed = state.usesTunnel && _override;
    final globalMissing =
        globalUsed &&
        _mode == AccessMode.password &&
        _password.text.trim().isEmpty;
    final onlineMissing =
        onlineUsed &&
        _onlineMode == AccessMode.password &&
        _onlinePassword.text.trim().isEmpty;
    if (globalMissing || onlineMissing) {
      setState(() {
        _passwordMissing = globalMissing;
        _onlinePasswordMissing = onlineMissing;
      });
      return;
    }
    await _access.configure(
      mode: _mode,
      password: _password.text.trim(),
      onlineOverride: _override,
      onlineMode: _onlineMode,
      onlinePassword: _onlinePassword.text.trim(),
    );
    if (mounted) Navigator.of(context).pop();
  }

  Widget _globalRule({required String title, required String hint}) =>
      _RuleEditor(
        title: title,
        hint: hint,
        mode: _mode,
        controller: _password,
        passwordMissing: _passwordMissing,
        onModeChanged: (mode) => setState(() {
          _mode = mode;
          _passwordMissing = false;
        }),
        onPasswordChanged: () {
          if (_passwordMissing) setState(() => _passwordMissing = false);
        },
      );

  Widget _localColumn(NetworkState state) {
    final strings = context.l10n.network;
    final hotspot = state.hotspot;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ColumnHeader(icon: Icons.wifi_rounded, title: strings.localColumn),
        const SizedBox(height: 12),
        _globalRule(
          title: context.l10n.access.whoCanJoin,
          hint: strings.localHint,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Icon(
              Icons.wifi_tethering_rounded,
              size: 18,
              color: hotspot.active
                  ? onlineGreen
                  : AppColors.textPrimary.withValues(alpha: 0.4),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                !hotspot.active
                    ? strings.hotspotOff
                    : hotspot.ssid == null
                    ? strings.hotspotOnUnknown
                    : strings.hotspotOn(hotspot.ssid!),
                style: accessLabelStyle,
              ),
            ),
          ],
        ),
        if (hotspot.active) ...[
          const SizedBox(height: 4),
          Text(strings.hotspotHint, style: accessHintStyle),
        ],
      ],
    );
  }

  Widget _onlineColumn(NetworkState state, OnlineStatus online) {
    final strings = context.l10n.network;
    final onlineOnly = state.mode == NetworkMode.online;
    final effectiveMode = _override ? _onlineMode : _mode;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ColumnHeader(icon: Icons.public_rounded, title: strings.onlineColumn),
        const SizedBox(height: 12),
        if (online.state == OnlineState.off)
          Text(context.l10n.online.subtitle, style: accessHintStyle)
        else
          OnlineStatusSection(status: online),
        if (online.state == OnlineState.error) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: JuicyButton(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              onPressed: _network.retryTunnel,
              child: Text(context.l10n.online.retry, style: accessLabelStyle),
            ),
          ),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Text(strings.ownOnlineRule, style: accessTitleStyle),
            ),
            JuicyToggle(
              value: _override,
              onChanged: (value) {
                SoundEffectService.instance.playThemeSelect();
                setState(() => _override = value);
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_override)
          _RuleEditor(
            title: context.l10n.access.whoCanJoin,
            mode: _onlineMode,
            controller: _onlinePassword,
            passwordMissing: _onlinePasswordMissing,
            onModeChanged: (mode) => setState(() {
              _onlineMode = mode;
              _onlinePasswordMissing = false;
            }),
            onPasswordChanged: () {
              if (_onlinePasswordMissing)
                setState(() => _onlinePasswordMissing = false);
            },
          )
        else if (onlineOnly)
          _globalRule(
            title: strings.defaultRule,
            hint: strings.ownOnlineRuleOffDefault,
          )
        else
          Text(strings.ownOnlineRuleOff, style: accessHintStyle),
        if (effectiveMode == AccessMode.open) ...[
          const SizedBox(height: 8),
          Text(context.l10n.online.openWarning, style: accessHintStyle),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.l10n.network;
    return ListenableBuilder(
      listenable: _network,
      builder: (context, _) {
        final state = _network.value;
        final online = _network.online.value;
        final hint = switch (state.mode) {
          NetworkMode.local => strings.modeLocalHint,
          NetworkMode.both => strings.modeBothHint,
          NetworkMode.online => strings.modeOnlineHint,
        };
        final columns = [
          if (state.usesLan) _localColumn(state),
          if (state.usesTunnel) _onlineColumn(state, online),
        ];
        return JuicyDialog(
          title: strings.panelTitle,
          maxWidth: columns.length > 1 ? 900 : 520,
          actions: [
            JuicyButton(
              onPressed: _save,
              backgroundColor: AppColors.highlightColor,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              child: Text(strings.done, style: accessLabelStyle),
            ),
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: JuicySegmented<NetworkMode>(
                  values: NetworkMode.values,
                  selected: state.mode,
                  label: (m) => networkModeLabel(context, m),
                  icon: networkModeIcon,
                  trailing: (m) => m != NetworkMode.local && m == state.mode
                      ? TunnelDot(status: online)
                      : null,
                  onSelected: _network.setMode,
                ),
              ),
              const SizedBox(height: 8),
              Text(hint, style: accessHintStyle, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              if (columns.length == 1)
                columns.single
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: columns[0]),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.only(left: 20),
                        decoration: BoxDecoration(
                          border: Border(
                            left: BorderSide(
                              color: AppColors.textPrimary.withValues(
                                alpha: 0.15,
                              ),
                              width: 3,
                            ),
                          ),
                        ),
                        child: columns[1],
                      ),
                    ),
                  ],
                ),
              UnbanAllButton(access: _access),
            ],
          ),
        );
      },
    );
  }
}

class _ColumnHeader extends StatelessWidget {
  final IconData icon;
  final String title;

  const _ColumnHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 22, color: AppColors.textPrimary),
        const SizedBox(width: 8),
        Text(title, style: accessTitleStyle.copyWith(fontSize: 18)),
      ],
    );
  }
}

/// Picker for one join rule plus its password field.
class _RuleEditor extends StatefulWidget {
  final String title;
  final String? hint;
  final AccessMode mode;
  final TextEditingController controller;
  final bool passwordMissing;
  final ValueChanged<AccessMode> onModeChanged;
  final VoidCallback onPasswordChanged;

  const _RuleEditor({
    required this.title,
    this.hint,
    required this.mode,
    required this.controller,
    required this.passwordMissing,
    required this.onModeChanged,
    required this.onPasswordChanged,
  });

  @override
  State<_RuleEditor> createState() => _RuleEditorState();
}

class _RuleEditorState extends State<_RuleEditor> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(widget.title, style: accessTitleStyle),
        if (widget.hint != null) Text(widget.hint!, style: accessHintStyle),
        const SizedBox(height: 10),
        AccessModePicker(value: widget.mode, onChanged: widget.onModeChanged),
        if (widget.mode == AccessMode.password) ...[
          const SizedBox(height: 4),
          RoomPasswordField(
            controller: widget.controller,
            visible: _visible,
            error: widget.passwordMissing
                ? context.l10n.access.passwordRequired
                : null,
            onToggleVisible: () => setState(() => _visible = !_visible),
            onChanged: (_) => widget.onPasswordChanged(),
          ),
        ],
      ],
    );
  }
}

/// Local | Online switch over a QR code, shown only in "both" once the
/// tunnel is up. Lobby and overlay share the choice.
class QrTargetSwitch extends StatelessWidget {
  final HostApiService api;
  final double height;
  final double fontSize;
  final EdgeInsetsGeometry padding;

  const QrTargetSwitch({
    super.key,
    required this.api,
    this.height = 40,
    this.fontSize = 14,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    final network = NetworkModeService.of(api);
    return ListenableBuilder(
      listenable: network,
      builder: (context, _) {
        if (!network.value.canSwitchQr || !network.online.value.isOnline) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: padding,
          child: Center(
            // Never wider than the QR card: shrink instead of overflowing.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Tooltip(
                message: context.l10n.network.qrSwitchLabel,
                child: JuicySegmented<QrTarget>(
                  key: const ValueKey('qr-target-switch'),
                  values: QrTarget.values,
                  selected: network.effectiveTarget,
                  height: height,
                  fontSize: fontSize,
                  label: (t) => t == QrTarget.local
                      ? context.l10n.network.modeLocal
                      : context.l10n.network.modeOnline,
                  icon: (t) => t == QrTarget.local
                      ? Icons.wifi_rounded
                      : Icons.public_rounded,
                  onSelected: network.setQrTarget,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
