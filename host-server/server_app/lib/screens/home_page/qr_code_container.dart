import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:server_app/services/host_api_service.dart';
import 'package:server_app/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'gamepad_handler_widget.dart';

class QRCodePanel extends StatefulWidget {
  final ConnectionSnapshot? connectionSnapshot;
  final DiagnosticsSnapshot? diagnosticsSnapshot;
  final ConnectionInfo? selectedConnection;
  final String? qrEndpointUrl;
  final ImageProvider? qrImage;
  final HostApiService api;
  final bool isLoadingConnection;
  final bool isLoadingDiagnostics;
  final UIScale scale;
  final Future<void> Function(String connectionId) onSelectConnection;
  final Future<void> Function() onRefreshDiagnostics;

  const QRCodePanel({
    super.key,
    required this.connectionSnapshot,
    required this.diagnosticsSnapshot,
    required this.selectedConnection,
    required this.qrEndpointUrl,
    required this.qrImage,
    required this.api,
    required this.isLoadingConnection,
    required this.isLoadingDiagnostics,
    required this.scale,
    required this.onSelectConnection,
    required this.onRefreshDiagnostics,
  });

  @override
  State<QRCodePanel> createState() => _QRCodePanelState();

  static const Map<String, String> text = {
    'connection_label_this_device': 'This device',
    'connection_label_wifi': 'Wi-Fi',
    'connection_label_ethernet': 'Cable',
    'connection_label_hotspot': 'Hotspot',
    'connection_label_backup': 'Extra',
    'ui_more_connections': 'More ways',
    'ui_more': 'More',
    'ui_copied': 'Link copied',
    'ui_chip_selected': 'On screen',
    'ui_chip_recommended': 'Best pick',
    'ui_chip_preferred': 'Saved',
    'ui_chip_last_success': 'Worked',
    'ui_use_this': 'Use this',
    'ui_showing': 'Showing',
    'ui_connection_fallback': 'Connection',
    'ui_connection_hint_wifi': 'Phones join through the same Wi-Fi.',
    'ui_connection_hint_hotspot': 'Good when your computer shares the signal.',
    'ui_connection_hint_ethernet': 'Helpful when the PC is on cable internet.',
    'ui_connection_hint_backup': 'Worth a try if the first one does not work.',
    'diag_button_label': 'Help',
    'diag_sheet_title': 'Connection helper',
    'diag_sheet_healthy': 'Everything looks ready to play.',
    'diag_sheet_attention': 'A few things may be getting in the way.',
    'diag_action_refresh': 'Refresh',
    'diag_action_copy_link': 'Copy link',
    'diag_action_firewall': 'Open Firewall',
    'diag_action_firewall_advanced': 'Advanced Firewall',
    'diag_title_server_started': 'Server started',
    'diag_body_server_started': 'Your game room is up and waiting.',
    'diag_title_qr_ready': 'QR code ready',
    'diag_body_qr_ready': 'Friends can scan this code to join.',
    'diag_title_no_network': 'No local network found',
    'diag_body_no_network':
        'This computer does not look connected to a phone-friendly network yet.',
    'diag_title_local_only': 'This code stays on this computer',
    'diag_body_local_only':
        'Phones may not reach this room yet. Try refreshing the network choice.',
    'diag_title_multiple_networks': 'More than one network found',
    'diag_body_multiple_networks':
        'If one code does not work, try switching to another network source.',
    'diag_title_hotspot_permission': 'Hotspot may need permission',
    'diag_body_hotspot_permission':
        'Using hotspot mode? Windows may need Public network access allowed.',
    'diag_title_reachability': 'Phones may have trouble reaching this room',
    'diag_body_reachability':
        'Try refreshing the network source or switching to another one.',
    'diag_title_firewall_hint': 'Firewall may be blocking phones',
    'diag_body_firewall_hint':
        'If nobody can join after scanning, Windows Firewall is a common reason.',
    'diag_title_hotspot_waiting': 'Hotspot still waiting for players',
    'diag_body_hotspot_waiting':
        'If phones see the hotspot but cannot join, try allowing Public access.',
    'diag_tip_title': 'If phones cannot join',
    'diag_tip_line_1': '1. Put everyone on the same network',
    'diag_tip_line_2': '2. Allow Windows Firewall access',
    'diag_tip_line_3': '3. Try Hotspot if Wi-Fi fails',
    'diag_tip_got_it': 'Got it',
    'diag_action_done': 'Opened helper',
  };

  static String t(String key) => text[key] ?? key;

  static String displayName(ConnectionInfo connection) {
    final key = connection.displayNameKey.split('__').first;
    return t(key);
  }

  static String kindSubtitle(String kind) {
    switch (kind) {
      case 'wifi':
        return t('ui_connection_hint_wifi');
      case 'hotspot':
        return t('ui_connection_hint_hotspot');
      case 'ethernet':
        return t('ui_connection_hint_ethernet');
      default:
        return t('ui_connection_hint_backup');
    }
  }
}

class _QRCodePanelState extends State<QRCodePanel> {
  static const _tipPrefsKey = 'host_diagnostics_tip_dismissed';

  bool _showTip = false;

  ConnectionInfo? get _selectedConnection =>
      widget.selectedConnection ??
      widget.connectionSnapshot?.selectedConnection;

  DiagnosticsSnapshot? get _diagnostics => widget.diagnosticsSnapshot;

  @override
  void initState() {
    super.initState();
    _loadTipState();
  }

  Future<void> _loadTipState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dismissed = prefs.getBool(_tipPrefsKey) ?? false;
      if (!mounted) return;
      setState(() {
        _showTip = !dismissed;
      });
    } catch (_) {}
  }

  Future<void> _dismissTip() async {
    setState(() {
      _showTip = false;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_tipPrefsKey, true);
    } catch (_) {}
  }

  Future<void> _openLink() async {
    if (_selectedConnection == null) return;
    final connectionUrl = _selectedConnection!.url;
    final safeUrl = connectionUrl.startsWith('http')
        ? connectionUrl
        : 'http://$connectionUrl';

    final uri = Uri.parse(safeUrl);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _copyLink(BuildContext context, String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(QRCodePanel.t('ui_copied'))));
    }
  }

  Future<void> _showConnectionsSheet(BuildContext context) async {
    final connections =
        widget.connectionSnapshot?.connections ?? const <ConnectionInfo>[];
    if (connections.isEmpty) return;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFFFFFCF5),
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(widget.scale.quarter),
        ),
      ),
      builder: (context) {
        return _ConnectionsSheet(
          initialSnapshot: widget.connectionSnapshot,
          api: widget.api,
          scale: widget.scale,
          onSelectConnection: widget.onSelectConnection,
        );
      },
    );
  }

  Future<void> _showDiagnosticsSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFFFFFBF4),
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(widget.scale.quarter),
        ),
      ),
      builder: (context) {
        return _DiagnosticsSheet(
          initialDiagnostics: widget.diagnosticsSnapshot,
          currentUrl: _selectedConnection?.url ?? '',
          api: widget.api,
          scale: widget.scale,
          onRefreshDiagnostics: widget.onRefreshDiagnostics,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedConnection = _selectedConnection;
    final connectionUrl =
        selectedConnection?.url ??
        (widget.isLoadingConnection
            ? 'Scanning local network...'
            : 'Unavailable');
    final diagnostics = _diagnostics;

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.scale.eighth),
        border: Border.all(
          color: AppTheme.primaryText,
          width: widget.scale.eighth / 4,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.all(widget.scale.eighth),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(
                            widget.scale.eighth * 0.85,
                          ),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 280),
                            switchInCurve: Curves.easeInOut,
                            switchOutCurve: Curves.easeInOut,
                            child: widget.qrImage != null
                                ? Image(
                                    key: ValueKey(
                                      widget.qrEndpointUrl ?? 'qr_image',
                                    ),
                                    image: widget.qrImage!,
                                    width: double.infinity,
                                    fit: BoxFit.contain,
                                  )
                                : Container(
                                    key: const ValueKey('qr_placeholder'),
                                    width: double.infinity,
                                    color: AppTheme.primaryText.withOpacity(
                                      0.06,
                                    ),
                                    child: Center(
                                      child: Text(
                                        widget.isLoadingConnection
                                            ? 'Getting your room ready...'
                                            : 'No QR yet',
                                        textAlign: TextAlign.center,
                                        style: AppTheme.bodyMedium.copyWith(
                                          fontFamily: 'pico',
                                          fontSize: widget.scale.eighth * 0.9,
                                          color: AppTheme.primaryText
                                              .withOpacity(0.44),
                                        ),
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                    if (_showTip)
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          widget.scale.eighth,
                          0,
                          widget.scale.eighth,
                          widget.scale.eighth * 0.7,
                        ),
                        child: _OnboardingTip(
                          scale: widget.scale,
                          onDismiss: _dismissTip,
                        ),
                      ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        widget.scale.eighth,
                        0,
                        widget.scale.eighth / 2,
                        widget.scale.eighth / 2,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              selectedConnection != null
                                  ? QRCodePanel.displayName(selectedConnection)
                                  : QRCodePanel.t('ui_connection_fallback'),
                              overflow: TextOverflow.ellipsis,
                              style: AppTheme.bodyMedium.copyWith(
                                fontFamily: 'pico',
                                fontSize: widget.scale.eighth * 0.9,
                              ),
                            ),
                          ),
                          _DiagnosticsButton(
                            scale: widget.scale,
                            snapshot: diagnostics,
                            isLoading: widget.isLoadingDiagnostics,
                            onPressed: () => _showDiagnosticsSheet(context),
                          ),
                          SizedBox(width: widget.scale.eighth / 6),
                          TextButton.icon(
                            onPressed: () => _showConnectionsSheet(context),
                            style: TextButton.styleFrom(
                              foregroundColor: AppTheme.primaryText.withValues(
                                alpha: 0.72,
                              ),
                              padding: EdgeInsets.symmetric(
                                horizontal: widget.scale.eighth * 0.55,
                                vertical: 0,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            icon: Icon(
                              Icons.more_horiz,
                              size: widget.scale.eighth,
                            ),
                            label: Text(
                              QRCodePanel.t('ui_more'),
                              style: AppTheme.bodyMedium.copyWith(
                                fontFamily: 'pico',
                                fontSize: widget.scale.eighth * 0.78,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        widget.scale.eighth,
                        0,
                        widget.scale.eighth / 3,
                        widget.scale.eighth,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: _openLink,
                              child: Text(
                                connectionUrl.replaceAll('http://', ''),
                                overflow: TextOverflow.ellipsis,
                                style: AppTheme.bodyMedium.copyWith(
                                  fontFamily: 'monomaniac',
                                  fontSize: widget.scale.eighth * 0.7,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            iconSize: widget.scale.eighth,
                            icon: Icon(
                              FontAwesomeIcons.copy,
                              color: AppTheme.primaryText,
                            ),
                            onPressed: () => _copyLink(context, connectionUrl),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DiagnosticsButton extends StatefulWidget {
  final UIScale scale;
  final DiagnosticsSnapshot? snapshot;
  final bool isLoading;
  final VoidCallback onPressed;

  const _DiagnosticsButton({
    required this.scale,
    required this.snapshot,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  State<_DiagnosticsButton> createState() => _DiagnosticsButtonState();
}

class _DiagnosticsButtonState extends State<_DiagnosticsButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  bool get _attention => widget.snapshot?.attentionNeeded == true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant _DiagnosticsButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncAnimation();
  }

  void _syncAnimation() {
    if (_attention) {
      _controller.repeat(reverse: true);
    } else {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = _attention
        ? const Color(0xFFE5A43B)
        : AppTheme.primaryText.withValues(alpha: 0.52);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final pulse = 1 + (_controller.value * 0.08);
        final glow = _attention ? 0.18 + (_controller.value * 0.18) : 0.0;

        return Transform.scale(
          scale: pulse,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                if (_attention)
                  BoxShadow(
                    color: baseColor.withValues(alpha: glow),
                    blurRadius: widget.scale.eighth * 1.8,
                    spreadRadius: widget.scale.eighth / 6,
                  ),
              ],
            ),
            child: IconButton(
              tooltip: QRCodePanel.t('diag_button_label'),
              visualDensity: VisualDensity.compact,
              splashRadius: widget.scale.eighth * 1.15,
              onPressed: widget.onPressed,
              icon: widget.isLoading
                  ? SizedBox(
                      width: widget.scale.eighth * 0.86,
                      height: widget.scale.eighth * 0.86,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: baseColor,
                      ),
                    )
                  : Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(
                          _attention
                              ? Icons.warning_amber_rounded
                              : Icons.info_outline_rounded,
                          size: widget.scale.eighth,
                          color: baseColor,
                        ),
                        if ((widget.snapshot?.attentionCount ?? 0) > 0)
                          Positioned(
                            right: -widget.scale.eighth / 5,
                            top: -widget.scale.eighth / 5,
                            child: Container(
                              width: widget.scale.eighth / 2,
                              height: widget.scale.eighth / 2,
                              decoration: const BoxDecoration(
                                color: Color(0xFFE5A43B),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }
}

class _OnboardingTip extends StatelessWidget {
  final UIScale scale;
  final Future<void> Function() onDismiss;

  const _OnboardingTip({required this.scale, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(scale.eighth * 0.78),
      decoration: BoxDecoration(
        color: AppTheme.primaryText.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(scale.eighth),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.tips_and_updates_outlined,
                size: scale.eighth * 0.9,
                color: AppTheme.primaryText.withValues(alpha: 0.82),
              ),
              SizedBox(width: scale.eighth / 2),
              Expanded(
                child: Text(
                  QRCodePanel.t('diag_tip_title'),
                  style: AppTheme.bodyMedium.copyWith(
                    fontFamily: 'pico',
                    fontSize: scale.eighth * 0.78,
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                splashRadius: scale.eighth,
                onPressed: () {
                  onDismiss();
                },
                icon: Icon(Icons.close, size: scale.eighth * 0.85),
              ),
            ],
          ),
          _TipLine(
            scale: scale,
            icon: Icons.wifi_rounded,
            text: QRCodePanel.t('diag_tip_line_1'),
          ),
          _TipLine(
            scale: scale,
            icon: Icons.shield_outlined,
            text: QRCodePanel.t('diag_tip_line_2'),
          ),
          _TipLine(
            scale: scale,
            icon: Icons.portable_wifi_off_outlined,
            text: QRCodePanel.t('diag_tip_line_3'),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                onDismiss();
              },
              child: Text(
                QRCodePanel.t('diag_tip_got_it'),
                style: AppTheme.bodyMedium.copyWith(
                  fontFamily: 'pico',
                  fontSize: scale.eighth * 0.72,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TipLine extends StatelessWidget {
  final UIScale scale;
  final IconData icon;
  final String text;

  const _TipLine({required this.scale, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: scale.eighth / 3),
      child: Row(
        children: [
          Icon(
            icon,
            size: scale.eighth * 0.72,
            color: AppTheme.primaryText.withValues(alpha: 0.72),
          ),
          SizedBox(width: scale.eighth / 2),
          Expanded(
            child: Text(
              text,
              style: AppTheme.bodyMedium.copyWith(
                fontSize: scale.eighth * 0.68,
                color: AppTheme.primaryText.withValues(alpha: 0.82),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DiagnosticsSheet extends StatefulWidget {
  final DiagnosticsSnapshot? initialDiagnostics;
  final String currentUrl;
  final HostApiService api;
  final UIScale scale;
  final Future<void> Function() onRefreshDiagnostics;

  const _DiagnosticsSheet({
    required this.initialDiagnostics,
    required this.currentUrl,
    required this.api,
    required this.scale,
    required this.onRefreshDiagnostics,
  });

  @override
  State<_DiagnosticsSheet> createState() => _DiagnosticsSheetState();
}

class _DiagnosticsSheetState extends State<_DiagnosticsSheet> {
  DiagnosticsSnapshot? _snapshot;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _snapshot = widget.initialDiagnostics;
  }

  Future<void> _refresh() async {
    setState(() {
      _busy = true;
    });
    try {
      final snapshot = await widget.api.fetchDiagnostics();
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
      });
      await widget.onRefreshDiagnostics();
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _runAction(DiagnosticQuickAction action) async {
    if (action.id == 'copy_server_url') {
      await Clipboard.setData(ClipboardData(text: widget.currentUrl));
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(QRCodePanel.t('ui_copied'))));
      }
      return;
    }

    setState(() {
      _busy = true;
    });
    try {
      await widget.api.runDiagnosticsAction(action.id);
      await _refresh();
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  DiagnosticQuickAction? _findAction(String id) {
    for (final action
        in _snapshot?.quickActions ?? const <DiagnosticQuickAction>[]) {
      if (action.id == id) return action;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    final checks = snapshot?.checks ?? const <DiagnosticCheck>[];

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            widget.scale.eighth * 1.25,
            widget.scale.eighth * 1.25,
            widget.scale.eighth * 1.25,
            widget.scale.eighth * 1.5,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: widget.scale.quarter * 1.2,
                  height: widget.scale.eighth / 2,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryText.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(widget.scale.eighth),
                  ),
                ),
              ),
              SizedBox(height: widget.scale.eighth),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      QRCodePanel.t('diag_sheet_title'),
                      style: AppTheme.bodyMedium.copyWith(
                        fontFamily: 'pico',
                        fontSize: widget.scale.eighth * 1.05,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: _busy
                        ? SizedBox(
                            width: widget.scale.eighth,
                            height: widget.scale.eighth,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppTheme.primaryText,
                            ),
                          )
                        : Icon(Icons.refresh, size: widget.scale.eighth * 1.12),
                    onPressed: _busy ? null : _refresh,
                  ),
                ],
              ),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(widget.scale.eighth * 0.85),
                decoration: BoxDecoration(
                  color: (snapshot?.attentionNeeded ?? false)
                      ? const Color(0xFFFFF3D8)
                      : const Color(0xFFF3F9EE),
                  borderRadius: BorderRadius.circular(widget.scale.eighth),
                ),
                child: Row(
                  children: [
                    Icon(
                      (snapshot?.attentionNeeded ?? false)
                          ? Icons.health_and_safety_outlined
                          : Icons.check_circle_outline_rounded,
                      size: widget.scale.eighth,
                      color: AppTheme.primaryText,
                    ),
                    SizedBox(width: widget.scale.eighth / 2),
                    Expanded(
                      child: Text(
                        (snapshot?.attentionNeeded ?? false)
                            ? QRCodePanel.t('diag_sheet_attention')
                            : QRCodePanel.t('diag_sheet_healthy'),
                        style: AppTheme.bodyMedium.copyWith(
                          fontFamily: 'pico',
                          fontSize: widget.scale.eighth * 0.72,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: widget.scale.eighth),
              Wrap(
                spacing: widget.scale.eighth / 2,
                runSpacing: widget.scale.eighth / 2,
                children: [
                  for (final action
                      in snapshot?.quickActions ??
                          const <DiagnosticQuickAction>[])
                    _ActionChip(
                      scale: widget.scale,
                      icon: _iconForName(action.icon),
                      label: QRCodePanel.t(action.labelKey),
                      onTap: _busy ? null : () => _runAction(action),
                    ),
                ],
              ),
              SizedBox(height: widget.scale.eighth),
              Column(
                children: checks
                    .map(
                      (check) => Padding(
                        padding: EdgeInsets.only(bottom: widget.scale.eighth),
                        child: _DiagnosticCard(
                          scale: widget.scale,
                          check: check,
                          actions: check.actionIds
                              .map(_findAction)
                              .whereType<DiagnosticQuickAction>()
                              .toList(),
                          onActionTap: (action) => _runAction(action),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DiagnosticCard extends StatelessWidget {
  final UIScale scale;
  final DiagnosticCheck check;
  final List<DiagnosticQuickAction> actions;
  final Future<void> Function(DiagnosticQuickAction action) onActionTap;

  const _DiagnosticCard({
    required this.scale,
    required this.check,
    required this.actions,
    required this.onActionTap,
  });

  @override
  Widget build(BuildContext context) {
    final isWarn = check.level == 'warn';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(scale.eighth * 0.85),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(scale.eighth),
        border: Border.all(
          color: isWarn
              ? const Color(0xFFEAB454).withValues(alpha: 0.45)
              : AppTheme.primaryText.withValues(alpha: 0.12),
          width: scale.eighth / 5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: scale.eighth * 1.4,
                height: scale.eighth * 1.4,
                decoration: BoxDecoration(
                  color: isWarn
                      ? const Color(0xFFFFF2D6)
                      : const Color(0xFFF2F8EE),
                  borderRadius: BorderRadius.circular(scale.eighth / 2),
                ),
                child: Icon(
                  _iconForName(check.icon),
                  size: scale.eighth * 0.82,
                  color: AppTheme.primaryText,
                ),
              ),
              SizedBox(width: scale.eighth * 0.65),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      QRCodePanel.t(check.titleKey),
                      style: AppTheme.bodyMedium.copyWith(
                        fontFamily: 'pico',
                        fontSize: scale.eighth * 0.78,
                      ),
                    ),
                    SizedBox(height: scale.eighth / 4),
                    Text(
                      QRCodePanel.t(check.bodyKey),
                      style: AppTheme.bodyMedium.copyWith(
                        fontSize: scale.eighth * 0.68,
                        color: AppTheme.primaryText.withValues(alpha: 0.72),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (actions.isNotEmpty) ...[
            SizedBox(height: scale.eighth * 0.7),
            Wrap(
              spacing: scale.eighth / 2,
              runSpacing: scale.eighth / 2,
              children: [
                for (final action in actions)
                  _ActionChip(
                    scale: scale,
                    icon: _iconForName(action.icon),
                    label: QRCodePanel.t(action.labelKey),
                    onTap: () => onActionTap(action),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final UIScale scale;
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _ActionChip({
    required this.scale,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(scale.eighth),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: scale.eighth * 0.6,
          vertical: scale.eighth * 0.42,
        ),
        decoration: BoxDecoration(
          color: AppTheme.primaryText.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(scale.eighth),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: scale.eighth * 0.68, color: AppTheme.primaryText),
            SizedBox(width: scale.eighth / 3),
            Text(
              label,
              style: AppTheme.bodyMedium.copyWith(
                fontFamily: 'pico',
                fontSize: scale.eighth * 0.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectionsSheet extends StatefulWidget {
  final ConnectionSnapshot? initialSnapshot;
  final HostApiService api;
  final UIScale scale;
  final Future<void> Function(String connectionId) onSelectConnection;

  const _ConnectionsSheet({
    required this.initialSnapshot,
    required this.api,
    required this.scale,
    required this.onSelectConnection,
  });

  @override
  State<_ConnectionsSheet> createState() => _ConnectionsSheetState();
}

class _ConnectionsSheetState extends State<_ConnectionsSheet> {
  late List<ConnectionInfo> _connections;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _connections = widget.initialSnapshot?.connections ?? [];
  }

  Future<void> _refresh() async {
    setState(() {
      _isRefreshing = true;
    });
    try {
      final snapshot = await widget.api.fetchConnections();
      if (!mounted) return;
      setState(() {
        _connections = snapshot.connections;
      });
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            widget.scale.eighth * 1.25,
            widget.scale.eighth * 1.25,
            widget.scale.eighth * 1.25,
            widget.scale.eighth * 1.5,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: widget.scale.quarter * 1.2,
                  height: widget.scale.eighth / 2,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryText.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(widget.scale.eighth),
                  ),
                ),
              ),
              SizedBox(height: widget.scale.eighth),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      QRCodePanel.t('ui_more_connections'),
                      style: AppTheme.bodyMedium.copyWith(
                        fontFamily: 'pico',
                        fontSize: widget.scale.eighth * 1.05,
                      ),
                    ),
                  ),
                  if (_isRefreshing)
                    Padding(
                      padding: EdgeInsets.all(widget.scale.eighth / 2),
                      child: SizedBox(
                        width: widget.scale.eighth,
                        height: widget.scale.eighth,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.primaryText,
                        ),
                      ),
                    )
                  else
                    IconButton(
                      icon: Icon(
                        Icons.refresh,
                        size: widget.scale.eighth * 1.2,
                      ),
                      onPressed: _refresh,
                      color: AppTheme.primaryText,
                      tooltip: QRCodePanel.t('diag_action_refresh'),
                    ),
                ],
              ),
              SizedBox(height: widget.scale.eighth),
              _connections.isEmpty
                  ? Center(
                      child: Padding(
                        padding: EdgeInsets.all(widget.scale.eighth),
                        child: Text(
                          'No extra connection found.',
                          style: AppTheme.bodyMedium.copyWith(
                            fontFamily: 'pico',
                          ),
                        ),
                      ),
                    )
                  : Column(
                      children: _connections
                          .map(
                            (connection) => Padding(
                              padding: EdgeInsets.only(
                                bottom: widget.scale.eighth,
                              ),
                              child: _ConnectionCard(
                                connection: connection,
                                qrCodeUrl: widget.api.getQrCodeUrl(
                                  connection.id,
                                ),
                                scale: widget.scale,
                                subtitle: QRCodePanel.kindSubtitle(
                                  connection.kind,
                                ),
                                onCopy: () async {
                                  await Clipboard.setData(
                                    ClipboardData(text: connection.url),
                                  );
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          QRCodePanel.t('ui_copied'),
                                        ),
                                      ),
                                    );
                                  }
                                },
                                onUse: () async {
                                  Navigator.of(context).pop();
                                  await widget.onSelectConnection(
                                    connection.id,
                                  );
                                },
                              ),
                            ),
                          )
                          .toList(),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConnectionCard extends StatelessWidget {
  final ConnectionInfo connection;
  final String qrCodeUrl;
  final UIScale scale;
  final String subtitle;
  final Future<void> Function() onCopy;
  final Future<void> Function() onUse;

  const _ConnectionCard({
    required this.connection,
    required this.qrCodeUrl,
    required this.scale,
    required this.subtitle,
    required this.onCopy,
    required this.onUse,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(scale.eighth),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(scale.eighth),
        border: Border.all(
          color: connection.selected
              ? AppTheme.primaryText
              : AppTheme.primaryText.withValues(alpha: 0.15),
          width: connection.selected ? scale.eighth / 4 : scale.eighth / 5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(scale.eighth * 0.75),
            child: Image.network(
              qrCodeUrl,
              width: scale.slot * 0.95,
              height: scale.slot * 0.95,
              fit: BoxFit.cover,
            ),
          ),
          SizedBox(width: scale.eighth),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  QRCodePanel.displayName(connection),
                  style: AppTheme.bodyMedium.copyWith(
                    fontFamily: 'pico',
                    fontSize: scale.eighth,
                  ),
                ),
                SizedBox(height: scale.eighth / 3),
                Wrap(
                  spacing: scale.eighth / 3,
                  runSpacing: scale.eighth / 3,
                  children: [
                    if (connection.selected)
                      _StatusChip(
                        label: QRCodePanel.t('ui_chip_selected'),
                        scale: scale,
                      ),
                    if (connection.recommended)
                      _StatusChip(
                        label: QRCodePanel.t('ui_chip_recommended'),
                        scale: scale,
                      ),
                    if (connection.preferred)
                      _StatusChip(
                        label: QRCodePanel.t('ui_chip_preferred'),
                        scale: scale,
                      ),
                    if (connection.lastSuccessful)
                      _StatusChip(
                        label: QRCodePanel.t('ui_chip_last_success'),
                        scale: scale,
                      ),
                  ],
                ),
                SizedBox(height: scale.eighth / 2),
                Text(
                  subtitle,
                  style: AppTheme.bodyMedium.copyWith(
                    fontSize: scale.eighth * 0.72,
                    color: AppTheme.primaryText.withValues(alpha: 0.65),
                  ),
                ),
                SizedBox(height: scale.eighth / 2),
                Text(
                  connection.url.replaceAll('http://', ''),
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.bodyMedium.copyWith(
                    fontFamily: 'monomaniac',
                    fontSize: scale.eighth,
                  ),
                ),
                SizedBox(height: scale.eighth / 3),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        onUse();
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.primaryText,
                        padding: EdgeInsets.symmetric(
                          horizontal: scale.eighth * 0.6,
                          vertical: scale.eighth / 4,
                        ),
                      ),
                      icon: Icon(
                        Icons.qr_code_rounded,
                        size: scale.eighth * 0.9,
                      ),
                      label: Text(
                        connection.selected
                            ? QRCodePanel.t('ui_showing')
                            : QRCodePanel.t('ui_use_this'),
                        style: AppTheme.bodyMedium.copyWith(
                          fontFamily: 'pico',
                          fontSize: scale.eighth * 0.72,
                        ),
                      ),
                    ),
                    SizedBox(width: scale.eighth / 4),
                    IconButton(
                      onPressed: () {
                        onCopy();
                      },
                      iconSize: scale.eighth * 0.9,
                      icon: const Icon(FontAwesomeIcons.copy),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final UIScale scale;

  const _StatusChip({required this.label, required this.scale});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: scale.eighth / 2,
        vertical: scale.eighth / 5,
      ),
      decoration: BoxDecoration(
        color: AppTheme.primaryText.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(scale.eighth),
      ),
      child: Text(
        label,
        style: AppTheme.bodyMedium.copyWith(
          fontFamily: 'pico',
          fontSize: scale.eighth * 0.58,
        ),
      ),
    );
  }
}

IconData _iconForName(String name) {
  switch (name) {
    case 'play_circle':
      return Icons.play_circle_outline;
    case 'qr_code_2':
      return Icons.qr_code_2;
    case 'wifi_off':
      return Icons.wifi_off;
    case 'route':
      return Icons.route;
    case 'hub':
      return Icons.device_hub;
    case 'portable_wifi_off':
      return Icons.portable_wifi_off;
    case 'devices':
      return Icons.devices;
    case 'shield':
      return Icons.shield_outlined;
    case 'wifi_tethering':
      return Icons.wifi_tethering;
    case 'refresh':
      return Icons.refresh;
    case 'content_copy':
      return Icons.content_copy;
    case 'admin_panel_settings':
      return Icons.admin_panel_settings;
    default:
      return Icons.info_outline;
  }
}
