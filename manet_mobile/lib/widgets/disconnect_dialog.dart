import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../services/connection_diagnostics_service.dart';
import 'juicy_widgets.dart';

class DisconnectDialog extends StatefulWidget {
  final String hostIp;
  final int port;
  final String? expectedSsid;
  final bool isHttps;
  final VoidCallback onReconnect;
  final VoidCallback onClose;

  const DisconnectDialog({
    super.key,
    required this.hostIp,
    required this.port,
    required this.expectedSsid,
    required this.isHttps,
    required this.onReconnect,
    required this.onClose,
  });

  @override
  State<DisconnectDialog> createState() => _DisconnectDialogState();
}

class _DisconnectDialogState extends State<DisconnectDialog>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  ConnectionDiagnosticResult _result = ConnectionDiagnosticResult.unknown;
  String? _currentSsid;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    _runDiagnostics();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _runDiagnostics() async {
    debugPrint('[DisconnectDialog] Running diagnostics...');
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    final result = await ConnectionDiagnosticsService.instance.diagnoseDisconnection(
      hostIp: widget.hostIp,
      port: widget.port,
      expectedSsid: widget.expectedSsid,
      isHttps: widget.isHttps,
    );

    debugPrint('[DisconnectDialog] Diagnostics result received: $result');

    String? currentSsid;
    if (result == ConnectionDiagnosticResult.wifiChanged) {
      currentSsid = await ConnectionDiagnosticsService.instance.getCurrentWifiSsid();
      debugPrint('[DisconnectDialog] Current SSID: $currentSsid, Expected: ${widget.expectedSsid}');
    }

    if (mounted) {
      setState(() {
        _result = result;
        _currentSsid = currentSsid;
        _isLoading = false;
      });
      debugPrint('[DisconnectDialog] Dialog state updated: result=$_result, ssid=$_currentSsid');
    }
  }

  String _getFaceMascot() {
    if (_isLoading) return 'o_o';
    switch (_result) {
      case ConnectionDiagnosticResult.noInternet:
        return ':(';
      case ConnectionDiagnosticResult.noWifi:
        return ':o';
      case ConnectionDiagnosticResult.wifiChanged:
        return 'o_o';
      case ConnectionDiagnosticResult.hostOffline:
        return 'X(';
      case ConnectionDiagnosticResult.unknown:
        return 'X(';
    }
  }

  String _getDiagnosticMessage(BuildContext context) {
    if (_isLoading) {
      return context.l10n.disconnect.diagnosing;
    }
    switch (_result) {
      case ConnectionDiagnosticResult.hostOffline:
        return context.l10n.disconnect.hostOffline;
      case ConnectionDiagnosticResult.wifiChanged:
        return context.l10n.disconnect.wifiChanged(widget.expectedSsid ?? '');
      case ConnectionDiagnosticResult.noWifi:
        return context.l10n.disconnect.noWifi;
      case ConnectionDiagnosticResult.noInternet:
        return context.l10n.disconnect.noInternet;
      case ConnectionDiagnosticResult.unknown:
        return context.l10n.disconnect.unknown;
    }
  }

  List<Widget> _buildActions(BuildContext context) {
    final styleText = const TextStyle(
      fontFamily: 'momo',
      fontSize: 14,
      fontWeight: FontWeight.bold,
      color: AppColors.textPrimary,
    );

    if (_isLoading) {
      return [];
    }

    switch (_result) {
      case ConnectionDiagnosticResult.hostOffline:
      case ConnectionDiagnosticResult.wifiChanged:
      case ConnectionDiagnosticResult.noWifi:
        return [
          Expanded(
            child: JuicyButton(
              onTap: widget.onClose,
              backgroundColor: AppColors.highlightColor,
              child: Center(
                child: Text(
                  _result == ConnectionDiagnosticResult.hostOffline
                      ? context.l10n.common.close
                      : context.l10n.connectionTips.gotIt,
                  style: styleText,
                ),
              ),
            ),
          ),
        ];

      case ConnectionDiagnosticResult.noInternet:
        return [
          Expanded(
            child: JuicyButton(
              onTap: () {
                _runDiagnostics();
                widget.onReconnect();
              },
              backgroundColor: AppColors.highlightColor,
              child: Center(
                child: Text(
                  context.l10n.disconnect.tryAgain,
                  style: styleText,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: JuicyButton(
              onTap: widget.onClose,
              backgroundColor: AppColors.lightColor,
              child: Center(
                child: Text(
                  context.l10n.common.close,
                  style: styleText,
                ),
              ),
            ),
          ),
        ];

      case ConnectionDiagnosticResult.unknown:
        return [
          Expanded(
            child: JuicyButton(
              onTap: widget.onReconnect,
              backgroundColor: AppColors.highlightColor,
              child: Center(
                child: Text(
                  context.l10n.disconnect.reconnect,
                  style: styleText,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: JuicyButton(
              onTap: widget.onClose,
              backgroundColor: AppColors.lightColor,
              child: Center(
                child: Text(
                  context.l10n.common.close,
                  style: styleText,
                ),
              ),
            ),
          ),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return PopScope(
      canPop: false, // Prevent dismissing with Android back gesture
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0.4, end: 1.0),
        duration: const Duration(milliseconds: 500),
        curve: Curves.elasticOut,
        builder: (context, scale, child) {
          return Transform.scale(
            scale: scale,
            alignment: Alignment.center,
            child: child,
          );
        },
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 360),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.screenBackground,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppColors.textPrimary,
                width: AppColors.borderThickness,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 12,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Playful Mascot Face Container
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    final scaleFactor = _isLoading
                        ? 1.0 + (_pulseController.value * 0.08)
                        : 1.0;
                    return Transform.scale(
                      scale: scaleFactor,
                      child: child,
                    );
                  },
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.highlightColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.textPrimary,
                        width: AppColors.borderThickness,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _getFaceMascot(),
                      style: const TextStyle(
                        fontFamily: 'monomaniac',
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Title
                Text(
                  l10n.disconnect.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'momo',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),

                // Subtitle
                Text(
                  l10n.disconnect.subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textPrimary.withValues(alpha: 0.75),
                  ),
                ),
                const SizedBox(height: 18),

                // Diagnosis detail card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.textPrimary,
                      width: AppColors.borderThickness / 2,
                    ),
                  ),
                  child: Column(
                    children: [
                      if (_isLoading) ...[
                        const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      Text(
                        _getDiagnosticMessage(context),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                      if (!_isLoading &&
                          _result == ConnectionDiagnosticResult.wifiChanged &&
                          _currentSsid != null) ...[
                        const SizedBox(height: 12),
                        const Divider(
                          color: AppColors.textPrimary,
                          thickness: 1,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          l10n.disconnect.currentNetwork(_currentSsid!),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.disconnect.expectedNetwork(
                            widget.expectedSsid ?? '',
                          ),
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textPrimary.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Actions buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: _buildActions(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
