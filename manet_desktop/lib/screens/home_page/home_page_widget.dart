import 'package:flutter/foundation.dart' show ValueListenable, ValueNotifier;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:manet_desktop/screens/home_page/gamepad_state.dart';
import 'package:manet_desktop/screens/home_page/gamepad_handler_widget.dart';
import '../../l10n/app_localizations.dart';

import '../../models/controller_branding.dart';
import '../../theme/app_theme.dart';
import '../../services/host_api_service.dart';
import '../../services/host_window_service.dart';
import '../../services/server_process_service.dart';
import '../../services/sound_effect_service.dart';
import '../../services/startup_connection_pipeline.dart';
import '../start_page/start_page_widget.dart';
import '../start_page/mode_selection_dialog.dart';
import '../../theme/app_colors.dart';
import '../../widgets/server_options_popup.dart';
import '../../widgets/app_error_widget.dart';
import 'lobby_toolbar.dart';
import 'server_alerts.dart';
import 'onboarding_overlay.dart';
import 'qr_code_container.dart';
import '../../widgets/juicy_widgets.dart';

class HomePageScreen extends StatelessWidget {
  final String host;
  final int port;
  final String? initialControllerMode;

  const HomePageScreen({
    super.key,
    required this.host,
    required this.port,
    this.initialControllerMode,
  });

  @override
  Widget build(BuildContext context) {
    return HomePageWidget(
      host: host,
      port: port,
      initialControllerMode: initialControllerMode,
    );
  }
}

class HomePageWidget extends StatefulWidget {
  final String host;
  final int port;
  final String? initialControllerMode;

  const HomePageWidget({
    super.key,
    required this.host,
    required this.port,
    this.initialControllerMode,
  });

  @override
  State<HomePageWidget> createState() => _HomePageWidgetState();
}

class _HomePageWidgetState extends State<HomePageWidget> {
  final scaffoldKey = GlobalKey<ScaffoldState>();

  late final HostApiService _api;
  late final HostWindowService _hostWindowService;

  late final StartupConnectionPipeline _startupPipeline;
  ColorTheme _currentTheme = ColorTheme.blue;
  PresetCatalog? _presetCatalog;

  int _slots = 4;
  bool _locked = true;
  String _controllerMode = 'x360';
  late final ValueNotifier<ControllerBrandingMode> _brandingModeNotifier;
  bool _isShowingNoNetworkDialog = false;
  int _reservationTimeoutMinutes = 5;

  String get _xinput4PlusAlertMsg => context.l10n.alerts.xinputLimitWarning;

  void _syncAlerts({bool notify = true}) {
    final hasXinputAlert = _alerts.any(
      (a) => a.message == _xinput4PlusAlertMsg,
    );

    if (_controllerMode == 'x360' && _slots > 4) {
      if (!hasXinputAlert) {
        if (notify) {
          _addAlert(_xinput4PlusAlertMsg);
        } else {
          _alerts.insert(
            0,
            ServerAlert(message: _xinput4PlusAlertMsg, isError: false),
          );
        }
      }
    } else if (hasXinputAlert) {
      if (notify) {
        setState(
          () => _alerts.removeWhere((a) => a.message == _xinput4PlusAlertMsg),
        );
      } else {
        _alerts.removeWhere((a) => a.message == _xinput4PlusAlertMsg);
      }
    }
  }

  // 2. Variável de estado para a animação do botão de modo
  ModeChangeState _modeChangeState = ModeChangeState.idle;

  List<ServerAlert> _alerts = [];

  void _addAlert(String message, {bool isError = false}) {
    setState(() {
      _alerts.insert(0, ServerAlert(message: message, isError: isError));
    });
  }

  void _markAlertsSeen() {
    bool changed = false;
    for (var alert in _alerts) {
      if (!alert.isSeen) {
        alert.isSeen = true;
        changed = true;
      }
    }
    if (changed) setState(() {});
  }

  void _dismissAlert(String id) {
    setState(() => _alerts.removeWhere((a) => a.id == id));
  }

  @override
  void initState() {
    super.initState();
    SoundEffectService.instance.init();
    _api = HostApiService(host: widget.host, port: widget.port);
    _hostWindowService = HostWindowService(api: _api);
    _hostWindowService.start();
    _startupPipeline = StartupConnectionPipeline(
      api: _api,
      onNetworkChanged: _handleNetworkChanged,
      onPresetUpdated: (catalog) {
        if (mounted) {
          setState(() {
            _presetCatalog = catalog;
          });
        }
      },
    );
    _startupPipeline.state.addListener(_handlePipelineUpdate);
    _startupPipeline.initialize();
    _loadTheme();
    _loadReservationTimeout();
    _loadPresets();
    _controllerMode = widget.initialControllerMode ?? _controllerMode;
    _brandingModeNotifier = ValueNotifier(
      ControllerBranding.modeFromWire(_controllerMode),
    );
    _syncAlerts(notify: false);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      OnboardingOverlay.checkAndShow(context);
    });
  }

  Future<void> _loadPresets() async {
    try {
      final catalog = await _api.fetchPresets();
      if (mounted) {
        setState(() {
          _presetCatalog = catalog;
        });
      }
    } catch (e, st) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (c) => AppErrorWidget(
          title: context.l10n.error.loadPresetsErrorTitle,
          message: context.l10n.error.loadPresetsErrorMessage(e.toString()),
          logs: st.toString(),
          onRetry: _loadPresets,
        ),
      );
    }
  }

  Future<void> _selectPreset(String presetId) async {
    try {
      await _api.selectPreset(presetId);
      await _loadPresets();
    } catch (e, st) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (c) => AppErrorWidget(
          title: context.l10n.error.selectPresetErrorTitle,
          message: context.l10n.error.selectPresetErrorMessage(e.toString()),
          logs: st.toString(),
          onRetry: () => _selectPreset(presetId),
        ),
      );
    }
  }

  Future<void> _loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeName = prefs.getString('selected_theme');
      if (themeName != null) {
        final theme = ColorTheme.values.firstWhere(
          (e) => e.name == themeName,
          orElse: () => ColorTheme.blue,
        );
        if (mounted) {
          setState(() {
            _currentTheme = theme;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _loadReservationTimeout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timeout = prefs.getInt('reservation_timeout_minutes');
      if (timeout != null && mounted) {
        setState(() {
          _reservationTimeoutMinutes = timeout;
        });
        await _api.resetControllers(
          reservationTimeout: timeout * 60,
        );
      }
    } catch (_) {}
  }

  void _handlePipelineUpdate() {
    if (!mounted) return;

    final state = _startupPipeline.state.value;
    final hasNoConnections =
        !state.isLoadingConnections &&
        state.connectionSnapshot?.connections.isEmpty == true;

    if (hasNoConnections && !_isShowingNoNetworkDialog) {
      _isShowingNoNetworkDialog = true;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => PopScope(
          canPop: false,
          child: AlertDialog(
            backgroundColor: AppColors.screenBackground,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.wifi_off_rounded,
                  size: 64,
                  color: AppColors.textPrimary.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 24),
                Text(
                  context.l10n.home.wifiOffTitle,
                  textAlign: TextAlign.center,
                  style: AppTheme.titleSmall.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  context.l10n.home.wifiOffBody,
                  textAlign: TextAlign.center,
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppColors.textPrimary.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ),
      ).then((_) {
        _isShowingNoNetworkDialog = false;
      });
    } else if (!hasNoConnections && _isShowingNoNetworkDialog) {
      Navigator.of(context).pop();
      _isShowingNoNetworkDialog = false;
    }

    setState(() {});
  }

  void _handleNetworkChanged(ConnectionInfo oldConn, ConnectionInfo newConn) {
    if (!mounted) return;

    final parts = newConn.displayNameKey.split('__');
    String networkName = parts.length > 1 ? parts.sublist(1).join('__') : '';
    if (int.tryParse(networkName) != null) {
      networkName = '';
    }

    String kindName = '';
    if (newConn.kind == 'wifi') {
      kindName = '${context.l10n.home.wifi}${networkName.isNotEmpty ? " ($networkName)" : ""}';
    } else if (newConn.kind == 'ethernet') {
      kindName = context.l10n.home.ethernet;
    } else if (newConn.kind == 'hotspot') {
      kindName = '${context.l10n.home.hotspot}${networkName.isNotEmpty ? " ($networkName)" : ""}';
    } else {
      kindName = context.l10n.home.newNetwork;
    }

    _addAlert(context.l10n.alerts.networkChangedAlert(kindName, newConn.url.replaceAll("http://", "")));

    SoundEffectService.instance.playHover();

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 7),
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.screenBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.textPrimary, width: 4),
            boxShadow: const [
              BoxShadow(
                color: AppColors.textPrimary,
                offset: Offset(4, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.highlightColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.wifi_tethering_rounded,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      context.l10n.alerts.networkChangedTitle,
                      style: AppTheme.bodyMedium.copyWith(
                        fontFamily: 'momo',
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.l10n.alerts.networkChangedBody(kindName),
                      style: AppTheme.bodyMedium.copyWith(
                        fontSize: 13,
                        color: AppColors.textPrimary.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  _showConnectionsSheet(context);
                },
                child: Text(
                  context.l10n.alerts.view,
                  style: AppTheme.bodyMedium.copyWith(
                    fontFamily: 'momo',
                    fontWeight: FontWeight.bold,
                    color: AppColors.highlightColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showConnectionsSheet(BuildContext context) async {
    final snapshot = _startupPipeline.state.value.connectionSnapshot;
    final connections = snapshot?.connections ?? const <ConnectionInfo>[];
    if (connections.isEmpty) return;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.screenBackground,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
        side: BorderSide(color: AppColors.textPrimary, width: 4),
      ),
      builder: (context) {
        return ConnectionsSheet(
          initialSnapshot: snapshot,
          api: _api,
          scale: const UIScale(200.0),
          onSelectConnection: _selectConnection,
        );
      },
    );
  }

  Future<void> _selectConnection(String connectionId) async {
    await _startupPipeline.selectConnection(connectionId);
  }

  Future<void> _refreshDiagnostics() async {
    await _startupPipeline.refreshDiagnostics();
  }

  Future<void> _openModeSettings() async {
    final chosen = await showGeneralDialog<String?>(
      context: context,
      barrierDismissible: true,
      barrierLabel: context.l10n.home.selectModeBarrierLabel,
      transitionDuration: const Duration(milliseconds: 450),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Center(
          child: Dialog(
            elevation: 0,
            backgroundColor: AppColors.screenBackground,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
              side: const BorderSide(
                color: AppColors.textPrimary,
                width: AppColors.borderThickness,
              ),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900, maxHeight: 600),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: ModeSelectionContent(
                  isMandatory: false,
                  initialMode: _controllerMode,
                  showHeader: false,
                  showConfirmButton: false,
                ),
              ),
            ),
          ),
        );
      },
    );

    if (chosen != null && chosen != _controllerMode) {
      // 3. Modificado de SnackBar para controle de estado do widget
      setState(() {
        _modeChangeState = ModeChangeState.loading;
      });

      try {
        await _api.resetControllers(mode: chosen, reservationTimeout: _reservationTimeoutMinutes * 60);

        if (!mounted) return;
        setState(() {
          _controllerMode = chosen;
          _modeChangeState = ModeChangeState.success;
        });
        _syncAlerts();
        _brandingModeNotifier.value = ControllerBranding.modeFromWire(chosen);

        // Aguarda 2 segundos para exibir o check de sucesso antes de sumir
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          setState(() {
            _modeChangeState = ModeChangeState.idle;
          });
        }
      } catch (e, st) {
        if (!mounted) return;
        setState(() {
          _modeChangeState = ModeChangeState.idle;
        });
        showDialog(
          context: context,
          builder: (c) => AppErrorWidget(
            title: context.l10n.error.applyModeErrorTitle,
            message: context.l10n.error.applyModeErrorBody(e.toString()),
            logs: st.toString(),
            onRetry: _openModeSettings,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _startupPipeline.state.removeListener(_handlePipelineUpdate);
    _brandingModeNotifier.dispose();
    _hostWindowService.dispose();
    _startupPipeline.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final isCompact = screenWidth < screenHeight * 1.35;

    int columns = _slots > 12
            ? 8
            : (_slots > 8 ? 6 : (_slots > 6 ? 4 : (_slots > 4 ? 6 : 4)));
        
    int rows = (_slots > 0 ? (_slots / columns).ceil() : 1);

    double dynamicHorizontalPadding = 50.0;
    int extraRows = rows - 1;

    if (extraRows > 0) {
      double paddingPerRow = columns == 8 ? 15.0 : (columns == 6 ? 25.0 : 40.0);
      double extraPadding = extraRows * paddingPerRow;

      double maxPadding = screenWidth * 0.25;
      dynamicHorizontalPadding = (50.0 + extraPadding).clamp(50.0, maxPadding);
    }

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: AppColors.screenBackground,
        body: SafeArea(
          top: true,
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              Align(
                alignment: AlignmentDirectional(-1.0, 0.0),
                child: Container(
                  decoration: BoxDecoration(),
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: dynamicHorizontalPadding,
                      top: 40.0,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.max,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(
                            10.0,
                            0.0,
                            0.0,
                            0.0,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'ma•net',
                                style: AppTheme.bodyMedium.copyWith(
                                  fontFamily: 'momo',
                                  fontSize: 40.0,
                                  letterSpacing: 0.0,
                                ),
                              ),
                              Container(
                                width: 32,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: AppColors.highlightColor,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        if (_alerts.isNotEmpty) ...[
                          AlertIcon(
                            alerts: _alerts,
                            onTap: () {
                              _markAlertsSeen();
                              showDialog(
                                context: context,
                                builder: (c) => ServerAlertsDialog(
                                  alerts: _alerts,
                                  onDismiss: _dismissAlert,
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 8),
                        ],
                        JuicyIconButton(
                          size: 48,
                          borderRadius: 14,
                          icon: const Icon(
                            Icons.settings,
                          ),
                          onTap: () {
                            SoundEffectService.instance.playOptionsButton();
                            showDialog(
                              context: context,
                              builder: (context) => ServerOptionsPopup(
                                currentTheme: _currentTheme,
                                currentTimeoutMinutes: _reservationTimeoutMinutes,
                                onThemeChanged: (theme) async {
                                  setState(() => _currentTheme = theme);
                                  try {
                                    final prefs =
                                        await SharedPreferences.getInstance();
                                    await prefs.setString(
                                      'selected_theme',
                                      theme.name,
                                    );
                                  } catch (_) {}
                                },
                                onTimeoutChanged: (timeoutMinutes) async {
                                  setState(() => _reservationTimeoutMinutes = timeoutMinutes);
                                  try {
                                    final prefs = await SharedPreferences.getInstance();
                                    await prefs.setInt('reservation_timeout_minutes', timeoutMinutes);
                                    await _api.resetControllers(
                                      reservationTimeout: timeoutMinutes * 60,
                                    );
                                  } catch (e) {
                                    debugPrint('Failed to save or apply reservation timeout: $e');
                                  }
                                },
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 8),
                        JuicyIconButton(
                          size: 48,
                          borderRadius: 14,
                          icon: const Icon(
                            Icons.power_settings_new_rounded,
                          ),
                          onTap: () async {
                            print('Turning off ...');

                            await ServerProcessService.instance.stopServer();

                            if (!mounted) return;

                            Navigator.of(context).pushAndRemoveUntil(
                              PageRouteBuilder(
                                pageBuilder:
                                    (context, animation, secondaryAnimation) =>
                                        const StartPageWidget(),
                                transitionsBuilder:
                                    (
                                      context,
                                      animation,
                                      secondaryAnimation,
                                      child,
                                    ) {
                                      const begin = Offset(-1.0, 0.0);
                                      const end = Offset.zero;
                                      const curve = Curves.easeInOutCubic;
                                      var tween = Tween(
                                        begin: begin,
                                        end: end,
                                      ).chain(CurveTween(curve: curve));
                                      return SlideTransition(
                                        position: animation.drive(tween),
                                        child: child,
                                      );
                                    },
                              ),
                              (route) => false,
                            );
                          },
                        ),
                        SizedBox(width: dynamicHorizontalPadding),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  width: MediaQuery.sizeOf(context).width * 1.0,
                  decoration: BoxDecoration(),
                  child: Column(
                    mainAxisSize: MainAxisSize.max,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: dynamicHorizontalPadding,
                            vertical: isCompact ? 16.0 : 50.0,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.max,
                            children: [
                              Expanded(
                                child: ChangeNotifierProvider(
                                  create: (_) => GamepadState(
                                    _api,
                                    onSlotsUpdated: (newCount) {
                                      if (_slots != newCount) {
                                        WidgetsBinding.instance
                                            .addPostFrameCallback((_) {
                                              if (mounted)
                                                setState(
                                                  () => _slots = newCount,
                                                );
                                            });
                                      }
                                    },
                                    onControllerModeChanged: (newMode) {
                                      if (_controllerMode != newMode) {
                                        WidgetsBinding.instance
                                            .addPostFrameCallback((_) {
                                              if (mounted) {
                                                setState(() {
                                                  _controllerMode = newMode;
                                                });
                                                _syncAlerts();
                                                _brandingModeNotifier.value =
                                                    ControllerBranding.modeFromWire(newMode);
                                              }
                                            });
                                      }
                                    },
                                    onGamepadLimitReached: (message) {
                                      if (mounted) {
                                        _addAlert(message, isError: false);
                                        ScaffoldMessenger.of(context).clearSnackBars();
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            backgroundColor: Colors.transparent,
                                            elevation: 0,
                                            behavior: SnackBarBehavior.floating,
                                            duration: const Duration(seconds: 8),
                                            content: Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 16,
                                                vertical: 12,
                                              ),
                                              decoration: BoxDecoration(
                                                color: AppColors.screenBackground,
                                                borderRadius: BorderRadius.circular(16),
                                                border: Border.all(
                                                  color: AppColors.textPrimary,
                                                  width: 4,
                                                ),
                                                boxShadow: const [
                                                  BoxShadow(
                                                    color: AppColors.textPrimary,
                                                    offset: Offset(4, 4),
                                                  ),
                                                ],
                                              ),
                                              child: Row(
                                                children: [
                                                  Container(
                                                    width: 40,
                                                    height: 40,
                                                    decoration: BoxDecoration(
                                                      color: AppColors.highlightColor,
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: const Icon(
                                                      Icons.warning_amber_rounded,
                                                      color: AppColors.textPrimary,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Text(
                                                      message,
                                                      style: AppTheme.bodyMedium.copyWith(
                                                        fontFamily: 'momo',
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 14,
                                                        color: AppColors.textPrimary,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                      }
                                    },
                                  )..initialize(),
                                  child: AdaptiveStageLayout(
                                    lobbyToolbar: LobbyToolbar(
                                      serverSlots: _slots,
                                      serverLocked: _locked,
                                      controllerMode: _controllerMode,
                                      layoutCatalog: _presetCatalog,
                                      layoutApi: _api,
                                      brandingModeListenable:
                                          _brandingModeNotifier,
                                      modeChangeState: _modeChangeState,
                                      onLayoutCatalogChanged: (catalog) {
                                        setState(() {
                                          _presetCatalog = catalog;
                                        });
                                      },
                                      onApply: (newSlots, newLocked) async {
                                        final slotsChanged = newSlots != _slots;
                                        final lockedChanged =
                                            newLocked != _locked;

                                        if (!slotsChanged && !lockedChanged)
                                          return;

                                        try {
                                          if (slotsChanged) {
                                            final assigned = await _api
                                                .fetchSlots();
                                            final active = assigned.slots
                                                .where((s) => s.device != null)
                                                .length;
                                            if (newSlots <
                                                    assigned.slots.length &&
                                                active > 0) {
                                              final ok = await showDialog<bool>(
                                                context: context,
                                                builder: (c) => AlertDialog(
                                                  backgroundColor: AppColors
                                                      .screenBackground,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          24,
                                                        ),
                                                    side: const BorderSide(
                                                      color:
                                                          AppColors.textPrimary,
                                                      width: 4,
                                                    ),
                                                  ),
                                                  title: Text(
                                                    context.l10n.home.removeControllersTitle,
                                                    style: AppTheme.titleSmall
                                                        .copyWith(
                                                          color: AppColors
                                                              .textPrimary,
                                                          fontFamily: 'momo',
                                                          fontWeight:
                                                              FontWeight.w900,
                                                        ),
                                                  ),
                                                  content: Text(
                                                    context.l10n.home.removeControllersBody,
                                                    style: AppTheme.bodyMedium
                                                        .copyWith(
                                                          color: AppColors
                                                              .textPrimary,
                                                        ),
                                                  ),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () =>
                                                          Navigator.of(
                                                            c,
                                                          ).pop(false),
                                                      style: TextButton.styleFrom(
                                                        foregroundColor:
                                                          AppColors
                                                              .textPrimary,
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 20,
                                                              vertical: 12,
                                                            ),
                                                      ),
                                                      child: Text(
                                                        context.l10n.common.cancel,
                                                        style: const TextStyle(
                                                          fontFamily: 'momo',
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                    ElevatedButton(
                                                      onPressed: () =>
                                                          Navigator.of(
                                                            c,
                                                          ).pop(true),
                                                      style: ElevatedButton.styleFrom(
                                                        backgroundColor:
                                                          AppColors
                                                              .highlightColor,
                                                        foregroundColor:
                                                          AppColors
                                                              .textPrimary,
                                                        elevation: 0,
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 20,
                                                              vertical: 12,
                                                            ),
                                                        shape: RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                12,
                                                              ),
                                                          side: const BorderSide(
                                                            color: AppColors
                                                                .textPrimary,
                                                            width: 3,
                                                          ),
                                                        ),
                                                      ),
                                                      child: Text(
                                                        context.l10n.common.confirm,
                                                        style: const TextStyle(
                                                          fontFamily: 'momo',
                                                          fontWeight:
                                                              FontWeight.w900,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                              if (ok != true) return;
                                            }
                                          }
                                        } catch (e) {
                                          if (!mounted) return;
                                          showDialog(
                                            context: context,
                                            barrierDismissible: false,
                                            builder: (context) => AppErrorWidget(
                                              title: context.l10n.error.connectionErrorTitle,
                                              message: context.l10n.error.connectionErrorMessage,
                                              logs: e.toString(),
                                              onRetry: () =>
                                                  Navigator.of(
                                                    context,
                                                  ).pushReplacementNamed(
                                                    '/',
                                                  ), // Return to start
                                            ),
                                          );
                                        }

                                        setState(() {
                                          _slots = newSlots;
                                          _locked = newLocked;
                                        });

                                        _syncAlerts();

                                        try {
                                          await _api.resetControllers(
                                            slots: slotsChanged ? _slots : null,
                                            fixed: lockedChanged
                                                ? _locked
                                                : null,
                                            reservationTimeout: _reservationTimeoutMinutes * 60,
                                          );
                                        } catch (e, st) {
                                          if (mounted) {
                                            showDialog(
                                              context: context,
                                              builder: (c) => AppErrorWidget(
                                                title:
                                                    context.l10n.error.applyConfigErrorTitle,
                                                message:
                                                    context.l10n.error.applyConfigErrorMessage(e.toString()),
                                                logs: st.toString(),
                                                onRetry: () async {
                                                  Navigator.of(c).pop();
                                                  try {
                                                    await _api.resetControllers(
                                                      slots: slotsChanged
                                                          ? _slots
                                                          : null,
                                                      fixed: lockedChanged
                                                          ? _locked
                                                          : null,
                                                      reservationTimeout: _reservationTimeoutMinutes * 60,
                                                    );
                                                  } catch (_) {}
                                                },
                                              ),
                                            );
                                          }
                                        }
                                      },
                                      onOpenSettings: _openModeSettings,
                                    ),
                                    connectionSnapshot: _startupPipeline
                                        .state
                                        .value
                                        .connectionSnapshot,
                                    diagnosticsSnapshot: _startupPipeline
                                        .state
                                        .value
                                        .diagnosticsSnapshot,
                                    selectedConnection: _startupPipeline
                                        .state
                                        .value
                                        .selectedConnection,
                                    qrEndpointUrl: _startupPipeline
                                        .state
                                        .value
                                        .qrEndpointUrl,
                                    qrImage:
                                        _startupPipeline.state.value.qrImage,
                                    api: _api,
                                    isLoadingConnections: _startupPipeline
                                        .state
                                        .value
                                        .isLoadingConnections,
                                    isLoadingDiagnostics: _startupPipeline
                                        .state
                                        .value
                                        .isLoadingDiagnostics,
                                    onSelectConnection: _selectConnection,
                                    onRefreshDiagnostics: _refreshDiagnostics,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
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
