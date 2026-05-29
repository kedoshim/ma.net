import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:manet_desktop/services/host_api_service.dart';
import 'package:manet_desktop/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:manet_desktop/theme/app_colors.dart';

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
    'ui_more_connections': 'Outras formas de conectar',
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

  Future<void> _showConnectionsSheet(BuildContext context) async {
    final connections =
        widget.connectionSnapshot?.connections ?? const <ConnectionInfo>[];
    if (connections.isEmpty) return;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.screenBackground,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(widget.scale.quarter),
        ),
        side: const BorderSide(color: AppColors.textPrimary, width: 4),
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
      backgroundColor: AppColors.screenBackground,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(widget.scale.quarter),
        ),
        side: const BorderSide(color: AppColors.textPrimary, width: 4),
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

  Widget _buildNetworkInfoSimple(ConnectionInfo? connection, UIScale scale) {
    if (connection == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Rede atual',
            style: AppTheme.bodyMedium.copyWith(
              fontSize: scale.eighth * 0.55,
              color: AppColors.textPrimary.withValues(alpha: 0.5),
              height: 1.0,
            ),
          ),
          Text(
            QRCodePanel.t('ui_connection_fallback'),
            style: AppTheme.bodyMedium.copyWith(
              fontFamily: 'momo',
              fontSize: scale.eighth * 0.9,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
              height: 1.0,
            ),
          ),
        ],
      );
    }

    final kind = connection.kind;
    final parts = connection.displayNameKey.split('__');
    String networkName = parts.length > 1 ? parts.sublist(1).join('__') : '';
    if (int.tryParse(networkName) != null) {
      networkName = '';
    }

    String subtitle;
    if (kind == 'wifi' || kind == 'hotspot') {
      subtitle = networkName.isNotEmpty ? networkName : 'Mesma rede do PC';
    } else if (kind == 'ethernet') {
      subtitle = 'Rede Local (Cabo)';
    } else {
      subtitle = QRCodePanel.t('ui_connection_fallback');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Rede atual',
          style: AppTheme.bodyMedium.copyWith(
            fontSize: scale.eighth * 0.55,
            color: AppColors.textPrimary.withValues(alpha: 0.5),
            height: 1.0,
          ),
        ),
        SizedBox(height: scale.eighth * 0.25),
        Text(
          subtitle,
          overflow: TextOverflow.ellipsis,
          style: AppTheme.bodyMedium.copyWith(
            fontFamily:
                (kind == 'wifi' || kind == 'hotspot') && networkName.isNotEmpty
                ? 'monomaniac'
                : 'momo',
            fontSize: scale.eighth * 0.9,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
            height: 1.0,
          ),
        ),
      ],
    );
  }

  Future<void> _showFaqSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.screenBackground,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(widget.scale.quarter),
        ),
        side: const BorderSide(color: AppColors.textPrimary, width: 4),
      ),
      builder: (context) {
        return _FaqSheet(
          scale: widget.scale,
          selectedConnection: _selectedConnection,
        );
      },
    );
  }

  Widget _buildTitle() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Entra aí :)',
          style: AppTheme.titleMedium.copyWith(
            fontFamily: 'momo',
            fontSize: widget.scale.eighth * 0.9,
            color: AppColors.textPrimary,
          ),
        ),
        Container(
          width: widget.scale.eighth * 1.5,
          height: widget.scale.eighth / 4,
          decoration: BoxDecoration(
            color: AppColors.highlightColor,
            borderRadius: BorderRadius.circular(widget.scale.eighth / 8),
          ),
        ),
      ],
    );
  }


  Widget _buildEncoragementText() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Entra aí :)',
          style: AppTheme.titleMedium.copyWith(
            fontFamily: 'momo',
            fontSize: widget.scale.eighth * 0.9,
            color: AppColors.textPrimary,
          ),
        ),
        Container(
          width: widget.scale.eighth * 1.5,
          height: widget.scale.eighth / 4,
          decoration: BoxDecoration(
            color: AppColors.highlightColor,
            borderRadius: BorderRadius.circular(widget.scale.eighth / 8),
          ),
        ),
      ],
    );
  }

  Widget _buildQR() {
    return ClipRRect(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        switchInCurve: Curves.easeInOut,
        switchOutCurve: Curves.easeInOut,
        child: widget.qrImage != null
            ? Image(
                key: ValueKey(widget.qrEndpointUrl ?? 'qr_image'),
                image: widget.qrImage!,
                width: double.infinity,
                fit: BoxFit.contain,
              )
            : Container(
                key: const ValueKey('qr_placeholder'),
                width: double.infinity,
                color: AppColors.textPrimary.withValues(alpha: 0.06),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Center(
                    child: Text(
                      widget.isLoadingConnection ? 'Criando QR...' : 'Sem QR',
                      textAlign: TextAlign.center,
                      style: AppTheme.bodyMedium.copyWith(
                        fontFamily: 'momo',
                        fontSize: widget.scale.eighth * 0.8,
                        color: AppColors.textPrimary.withValues(alpha: 0.44),
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildLink(
    String connectionUrl, {
    MainAxisAlignment alignment = MainAxisAlignment.center,
  }) {
    return Row(
      mainAxisAlignment: alignment,
      children: [
        Flexible(
          child: InkWell(
            onTap: _openLink,
            borderRadius: BorderRadius.circular(widget.scale.eighth / 2),
            child: Text(
              connectionUrl.replaceAll('http://', ''),
              overflow: TextOverflow.ellipsis,
              style: AppTheme.bodyMedium.copyWith(
                fontFamily: 'monomaniac',
                fontSize: widget.scale.eighth * 0.7,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        _CopyLinkButton(
          url: connectionUrl,
          iconSize: widget.scale.eighth * 0.7,
        ),
      ],
    );
  }

  Widget _buildNetworkInfoRow(ConnectionInfo? selectedConnection) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: _buildNetworkInfoSimple(selectedConnection, widget.scale),
        ),
        IconButton(
          icon: Icon(
            Icons.more_horiz,
            color: AppColors.textPrimary.withValues(alpha: 0.7),
          ),
          onPressed: () => _showConnectionsSheet(context),
          tooltip: 'Outras formas de conectar',
          splashRadius: widget.scale.eighth,
        ),
      ],
    );
  }

  Widget _buildHelpButton({bool isHorizontal = false}) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.highlightColor,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        padding: EdgeInsets.symmetric(
          horizontal: isHorizontal ? widget.scale.eighth * 1.25 : 16.0,
          vertical: widget.scale.eighth * (isHorizontal ? 0.6 : 0.6),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(widget.scale.eighth * 0.8),
          side: BorderSide(
            color: AppColors.textPrimary,
            width: widget.scale.eighth / 5,
          ),
        ),
      ),
      onPressed: () => _showFaqSheet(context),
      icon: Icon(Icons.help_outline_rounded, size: widget.scale.eighth * 0.9),
      label: Text(
        'Ajuda',
        style: AppTheme.bodyMedium.copyWith(
          fontFamily: 'momo',
          fontSize: widget.scale.eighth * 0.8,
          fontWeight: FontWeight.w600,
        ),
      ),
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

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.screenBackground,
        borderRadius: BorderRadius.circular(widget.scale.eighth * 1.5),
        border: Border.all(color: AppColors.textPrimary, width: 5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.scale.eighth * 1.5 - 5),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isHorizontal =
                constraints.maxWidth > constraints.maxHeight * 1.25;

            if (isHorizontal) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 4,
                    child: Padding(
                      padding: EdgeInsets.all(widget.scale.eighth),
                      child: _buildQR(),
                    ),
                  ),
                  VerticalDivider(
                    width: 1,
                    thickness: AppColors.borderThickness,
                    color: AppColors.textPrimary,
                  ),
                  Expanded(
                    flex: 7,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.textPrimary.withValues(alpha: 0.05),
                      ),
                      padding: EdgeInsets.all(widget.scale.eighth),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildNetworkInfoRow(selectedConnection),
                          SizedBox(height: widget.scale.eighth),
                          Row(
                            children: [
                              Expanded(
                                child: _buildLink(
                                  connectionUrl,
                                  alignment: MainAxisAlignment.start,
                                ),
                              ),
                              SizedBox(width: widget.scale.eighth),
                              _buildHelpButton(isHorizontal: true),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }

            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: widget.scale.eighth,
                            vertical: widget.scale.eighth * 0.5,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildEncoragementText(),
                              SizedBox(height: widget.scale.eighth),
                              _buildQR(),
                              SizedBox(height: widget.scale.eighth * 0.25),
                              _buildLink(connectionUrl),
                            ],
                          ),
                        ),
                      ),
                      Divider(
                        height: 1,
                        thickness: widget.scale.eighth / 4,
                        color: AppColors.textPrimary,
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.textPrimary.withValues(alpha: 0.05),
                        ),
                        padding: EdgeInsets.fromLTRB(
                          widget.scale.eighth,
                          widget.scale.eighth * 0.5,
                          widget.scale.eighth,
                          widget.scale.eighth * 0.5,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildNetworkInfoRow(selectedConnection),
                            SizedBox(height: widget.scale.eighth * 0.5),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [Expanded(child: _buildHelpButton())],
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
      ),
    );
  }
}

class _CopyLinkButton extends StatefulWidget {
  final String url;
  final double iconSize;

  const _CopyLinkButton({required this.url, required this.iconSize});

  @override
  State<_CopyLinkButton> createState() => _CopyLinkButtonState();
}

class _CopyLinkButtonState extends State<_CopyLinkButton> {
  bool _copied = false;

  void _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.url));
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      iconSize: widget.iconSize,
      splashRadius: widget.iconSize * 1.2,
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        transitionBuilder: (Widget child, Animation<double> animation) {
          return ScaleTransition(scale: animation, child: child);
        },
        child: _copied
            ? Icon(
                Icons.check_circle_rounded,
                key: const ValueKey('check'),
                color: Colors.green,
              )
            : Icon(
                FontAwesomeIcons.copy,
                key: const ValueKey('copy'),
                color: AppColors.textPrimary.withValues(alpha: 0.7),
              ),
      ),
      onPressed: _copied ? null : _copy,
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
        : AppColors.textPrimary.withValues(alpha: 0.6);

    final bgColor = _attention
        ? const Color(0xFFE5A43B).withValues(alpha: 0.15)
        : AppColors.textPrimary.withValues(alpha: 0.05);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final pulse = 1 + (_controller.value * 0.08);

        return Transform.scale(
          scale: pulse,
          child: Tooltip(
            message: QRCodePanel.t('diag_button_label'),
            child: Material(
              color: bgColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(widget.scale.eighth * 0.8),
                side: _attention
                    ? BorderSide(
                        color: const Color(0xFFE5A43B).withValues(alpha: 0.5),
                        width: 1.5,
                      )
                    : BorderSide.none,
              ),
              child: InkWell(
                onTap: widget.onPressed,
                borderRadius: BorderRadius.circular(widget.scale.eighth * 0.8),
                child: Container(
                  width: widget.scale.eighth * 2.2,
                  height: widget.scale.eighth * 2.1,
                  alignment: Alignment.center,
                  child: widget.isLoading
                      ? SizedBox(
                          width: widget.scale.eighth * 0.9,
                          height: widget.scale.eighth * 0.9,
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
                                  : Icons.monitor_heart_outlined,
                              size: widget.scale.eighth * 0.9,
                              color: baseColor,
                            ),
                            if ((widget.snapshot?.attentionCount ?? 0) > 0)
                              Positioned(
                                right: -widget.scale.eighth / 4,
                                top: -widget.scale.eighth / 4,
                                child: Container(
                                  width: widget.scale.eighth / 1.8,
                                  height: widget.scale.eighth / 1.8,
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
        color: AppColors.textPrimary.withValues(alpha: 0.05),
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
                color: AppColors.textPrimary.withValues(alpha: 0.82),
              ),
              SizedBox(width: scale.eighth / 2),
              Expanded(
                child: Text(
                  QRCodePanel.t('diag_tip_title'),
                  style: AppTheme.bodyMedium.copyWith(
                    fontFamily: 'momo',
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
                  fontFamily: 'momo',
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
            color: AppColors.textPrimary.withValues(alpha: 0.72),
          ),
          SizedBox(width: scale.eighth / 2),
          Expanded(
            child: Text(
              text,
              style: AppTheme.bodyMedium.copyWith(
                fontSize: scale.eighth * 0.68,
                color: AppColors.textPrimary.withValues(alpha: 0.82),
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
                    color: AppColors.textPrimary.withValues(alpha: 0.2),
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
                        fontFamily: 'momo',
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
                              color: AppColors.textPrimary,
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
                      color: AppColors.textPrimary,
                    ),
                    SizedBox(width: widget.scale.eighth / 2),
                    Expanded(
                      child: Text(
                        (snapshot?.attentionNeeded ?? false)
                            ? QRCodePanel.t('diag_sheet_attention')
                            : QRCodePanel.t('diag_sheet_healthy'),
                        style: AppTheme.bodyMedium.copyWith(
                          fontFamily: 'momo',
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
        color: AppColors.lightColor,
        borderRadius: BorderRadius.circular(scale.eighth),
        border: Border.all(
          color: isWarn ? const Color(0xFFEAB454) : AppColors.textPrimary,
          width: 3,
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
                  color: AppColors.textPrimary,
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
                        fontFamily: 'momo',
                        fontSize: scale.eighth * 0.78,
                      ),
                    ),
                    SizedBox(height: scale.eighth / 4),
                    Text(
                      QRCodePanel.t(check.bodyKey),
                      style: AppTheme.bodyMedium.copyWith(
                        fontSize: scale.eighth * 0.68,
                        color: AppColors.textPrimary.withValues(alpha: 0.72),
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
          color: AppColors.textPrimary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(scale.eighth),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: scale.eighth * 0.68, color: AppColors.textPrimary),
            SizedBox(width: scale.eighth / 3),
            Text(
              label,
              style: AppTheme.bodyMedium.copyWith(
                fontFamily: 'momo',
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
                    color: AppColors.textPrimary.withValues(alpha: 0.2),
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
                        fontFamily: 'momo',
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
                          color: AppColors.textPrimary,
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
                      color: AppColors.textPrimary,
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
                          'Nenhuma rede alternativa encontrada.',
                          style: AppTheme.bodyMedium.copyWith(
                            fontFamily: 'momo',
                          ),
                        ),
                      ),
                    )
                  : Column(
                      children: _connections
                          .map(
                            (connection) => Padding(
                              padding: EdgeInsets.only(
                                bottom: widget.scale.eighth * 0.5,
                              ),
                              child: _CompactConnectionCard(
                                connection: connection,
                                scale: widget.scale,
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

class _CompactConnectionCard extends StatelessWidget {
  final ConnectionInfo connection;
  final UIScale scale;
  final Future<void> Function() onUse;

  const _CompactConnectionCard({
    required this.connection,
    required this.scale,
    required this.onUse,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(scale.eighth * 0.8),
      decoration: BoxDecoration(
        color: AppColors.lightColor,
        borderRadius: BorderRadius.circular(scale.eighth * 0.8),
        border: Border.all(
          color: connection.selected
              ? AppColors.highlightColor
              : AppColors.textPrimary,
          width: connection.selected ? 5 : 3,
        ),
      ),
      child: Row(
        children: [
          Icon(
            _getIconForKind(connection.kind),
            size: scale.eighth * 1.2,
            color: AppColors.textPrimary.withValues(alpha: 0.7),
          ),
          SizedBox(width: scale.eighth * 0.8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  QRCodePanel.displayName(connection),
                  style: AppTheme.bodyMedium.copyWith(
                    fontFamily: 'momo',
                    fontSize: scale.eighth * 0.85,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: scale.eighth / 2),
                Text(
                  connection.url.replaceAll('http://', ''),
                  style: AppTheme.bodyMedium.copyWith(
                    fontFamily: 'monomaniac',
                    fontSize: scale.eighth * 0.75,
                    color: AppColors.textPrimary.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          if (!connection.selected)
            ElevatedButton(
              style:
                  ElevatedButton.styleFrom(
                    backgroundColor: AppColors.textPrimary.withValues(
                      alpha: 0.15,
                    ),
                    foregroundColor: AppColors.textPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(scale.eighth * 0.6),
                    ),
                    padding: EdgeInsets.symmetric(
                      horizontal: scale.eighth * 0.8,
                      vertical: scale.eighth * 0.4,
                    ),
                    elevation: 0,
                  ).copyWith(
                    backgroundColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.hovered)) {
                        return AppColors.highlightColor;
                      }
                      return AppColors.textPrimary.withValues(alpha: 0.15);
                    }),
                  ),
              onPressed: onUse,
              child: Text(
                'Usar',
                style: AppTheme.bodyMedium.copyWith(
                  fontFamily: 'momo',
                  fontSize: scale.eighth * 0.7,
                  color: AppColors.textPrimary,
                ),
              ),
            )
          else
            Padding(
              padding: EdgeInsets.only(right: scale.eighth * 0.4),
              child: Icon(
                Icons.check_circle_rounded,
                color: AppColors.highlightColor,
              ),
            ),
        ],
      ),
    );
  }

  IconData _getIconForKind(String kind) {
    switch (kind) {
      case 'wifi':
      case 'hotspot':
        return Icons.wifi_rounded;
      case 'ethernet':
        return Icons.settings_ethernet_rounded;
      default:
        return Icons.route_rounded;
    }
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

class _FaqSheet extends StatelessWidget {
  final UIScale scale;
  final ConnectionInfo? selectedConnection;

  const _FaqSheet({required this.scale, this.selectedConnection});

  @override
  Widget build(BuildContext context) {
    String wifiSolution =
        '• Verifique se ambos estão no mesmo Wi-Fi\n• Veja se o Firewall do Windows está bloqueando\n• Tente recarregar a página do celular';

    if (selectedConnection != null) {
      final kind = selectedConnection!.kind;
      final parts = selectedConnection!.displayNameKey.split('__');
      String networkName = parts.length > 1 ? parts.sublist(1).join('__') : '';
      if (int.tryParse(networkName) != null) {
        networkName =
            ''; // Ignora números soltos (ex: '__2') para redes não nomeadas
      }

      if ((kind == 'wifi' || kind == 'hotspot') && networkName.isNotEmpty) {
        wifiSolution =
            '• Verifique se o celular está conectado na rede:\n  "$networkName"\n• Veja se o Firewall do Windows está bloqueando\n• Tente recarregar a página';
      } else if (kind == 'ethernet') {
        wifiSolution =
            '• O PC está no cabo. Certifique-se que o celular está no Wi-Fi da rede local\n• Veja se o Firewall do Windows está bloqueando\n• Tente recarregar a página';
      }
    }

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            scale.eighth * 1.25,
            scale.eighth * 1.25,
            scale.eighth * 1.25,
            scale.eighth * 1.5,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: scale.quarter * 1.2,
                  height: scale.eighth / 2,
                  decoration: BoxDecoration(
                    color: AppColors.textPrimary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(scale.eighth),
                  ),
                ),
              ),
              SizedBox(height: scale.eighth),
              Text(
                'Ajuda e Problemas Comuns',
                style: AppTheme.bodyMedium.copyWith(
                  fontFamily: 'momo',
                  fontSize: scale.eighth * 1.05,
                ),
              ),
              SizedBox(height: scale.eighth),
              _FaqItem(
                scale: scale,
                icon: Icons.wifi_off_rounded,
                title: 'O celular não conecta',
                description: 'O celular e o PC podem não estar se comunicando.',
                solution: wifiSolution,
              ),
              SizedBox(height: scale.eighth),
              _FaqItem(
                scale: scale,
                icon: Icons.videogame_asset_off_rounded,
                title: 'O controle não funciona no jogo',
                description:
                    'Alguns jogos só reconhecem tipos específicos de controles.',
                solution:
                    '• Tente trocar entre XInput e DInput nas configurações\n• Alguns jogos funcionam melhor com modos diferentes',
              ),
              SizedBox(height: scale.eighth),
              _FaqItem(
                scale: scale,
                icon: Icons.group_off_rounded,
                title: 'Mais de 4 jogadores não funcionam',
                description:
                    'O Windows limita controles XInput a no máximo 4 jogadores.',
                solution:
                    '• Sugerimos trocar o modo do servidor para DInput para jogar com mais pessoas',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FaqItem extends StatelessWidget {
  final UIScale scale;
  final IconData icon;
  final String title;
  final String description;
  final String solution;

  const _FaqItem({
    required this.scale,
    required this.icon,
    required this.title,
    required this.description,
    required this.solution,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(scale.eighth * 0.85),
      decoration: BoxDecoration(
        color: AppColors.lightColor,
        borderRadius: BorderRadius.circular(scale.eighth),
        border: Border.all(color: AppColors.textPrimary, width: 3),
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
                  color: AppColors.highlightColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(scale.eighth / 2),
                ),
                child: Icon(
                  icon,
                  size: scale.eighth * 0.82,
                  color: AppColors.highlightColor,
                ),
              ),
              SizedBox(width: scale.eighth * 0.65),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTheme.bodyMedium.copyWith(
                        fontFamily: 'momo',
                        fontSize: scale.eighth * 0.78,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: scale.eighth / 4),
                    Text(
                      description,
                      style: AppTheme.bodyMedium.copyWith(
                        fontSize: scale.eighth * 0.68,
                        color: AppColors.textPrimary.withValues(alpha: 0.72),
                      ),
                    ),
                    SizedBox(height: scale.eighth / 2),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(scale.eighth * 0.6),
                      decoration: BoxDecoration(
                        color: AppColors.highlightColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(scale.eighth / 2),
                        border: Border.all(
                          color: AppColors.highlightColor.withValues(
                            alpha: 0.3,
                          ),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        solution,
                        style: AppTheme.bodyMedium.copyWith(
                          fontSize: scale.eighth * 0.65,
                          color: AppColors.textPrimary.withValues(alpha: 0.85),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
