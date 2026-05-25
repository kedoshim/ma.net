import 'package:flutter/foundation.dart' show ValueListenable, ValueNotifier;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:server_app/screens/home_page/gamepad_state.dart';
import 'package:server_app/screens/home_page/gamepad_handler_widget.dart';

import '../../models/controller_branding.dart';
import '../../theme/app_theme.dart';
import '../../services/host_api_service.dart';
import '../../services/host_window_service.dart';
import '../../services/server_process_service.dart';
import '../../services/sound_effect_service.dart';
import '../../services/startup_connection_pipeline.dart';
import '../start_page/start_page_widget.dart';
import '../../theme/app_colors.dart';
import '../../widgets/layout_selector_widget.dart';
import '../../widgets/server_options_popup.dart';

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
    _startupPipeline = StartupConnectionPipeline(api: _api);
    _startupPipeline.state.addListener(_handlePipelineUpdate);
    _startupPipeline.initialize();
    _loadTheme();
    _loadPresets();
    _controllerMode = widget.initialControllerMode ?? _controllerMode;
    _brandingModeNotifier = ValueNotifier(
      ControllerBranding.modeFromWire(_controllerMode),
    );
  }

  Future<void> _loadPresets() async {
    try {
      final catalog = await _api.fetchPresets();
      if (mounted) {
        setState(() {
          _presetCatalog = catalog;
        });
      }
    } catch (_) {}
  }

  Future<void> _selectPreset(String presetId) async {
    try {
      await _api.selectPreset(presetId);
      await _loadPresets();
    } catch (_) {}
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

  void _handlePipelineUpdate() {
    if (!mounted) return;
    setState(() {});
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
      barrierLabel: 'Selecao de modo',
      transitionDuration: const Duration(milliseconds: 450),
      pageBuilder: (context, animation, secondaryAnimation) {
        return SafeArea(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Material(
                  color: AppColors.screenBackground,
                  borderRadius: BorderRadius.circular(24),
                  clipBehavior: Clip.antiAlias,
                  child: Container(
                    width: MediaQuery.sizeOf(context).width * 0.85,
                    height: MediaQuery.sizeOf(context).height * 0.85,
                    constraints: const BoxConstraints(
                      maxWidth: 1000,
                      maxHeight: 750,
                    ),
                    padding: const EdgeInsets.all(32),
                    child: ModeSelectionContent(
                      isMandatory: false,
                      initialMode: _controllerMode,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    if (chosen != null && chosen != _controllerMode) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Aplicando novo modo...')));
      try {
        await _api.resetControllers(mode: chosen);
        setState(() {
          _controllerMode = chosen;
        });
        _brandingModeNotifier.value = ControllerBranding.modeFromWire(chosen);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Modo aplicado com sucesso')),
        );
      } catch (e) {
        _addAlert('Falha ao aplicar modo: $e', isError: true);
      }
    }
  }

  // ignore: unused_element
  Widget _buildPresetTooltip(
    String presetId,
    String label,
    PresetCatalog catalog,
  ) {
    ControllerPreset? preset;
    final allPresets = [
      ...catalog.builtInPresets,
      ...catalog.gamePresets,
      ...catalog.customPresets,
    ];
    try {
      preset = allPresets.firstWhere((p) => p.id == presetId);
    } catch (_) {}

    String tooltipText = label;
    if (preset != null && preset.description.isNotEmpty) {
      tooltipText = '${preset.name}\n${preset.description}';
      if (preset.pros.isNotEmpty) tooltipText += '\n\nPrós: ${preset.pros}';
      if (preset.cons.isNotEmpty) tooltipText += '\nContras: ${preset.cons}';
    }

    return Tooltip(
      message: tooltipText,
      waitDuration: const Duration(milliseconds: 300),
      textStyle: AppTheme.bodySmall.copyWith(color: AppColors.screenBackground),
      decoration: BoxDecoration(
        color: AppColors.textPrimary.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: _PresetChip(
        label: label,
        isSelected: catalog.activePresetId == presetId,
        onTap: () => _selectPreset(presetId),
      ),
    );
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

    // Base layout pressure on actual row count, not raw player count,
    // so horizontal clustering only updates when a new row is formed.
    int columns = _slots > 12 ? 8 : (_slots > 8 ? 6 : (_slots > 4 ? 6 : 4));
    int rows = (_slots > 0 ? (_slots / columns).ceil() : 1);

    double dynamicHorizontalPadding = 50.0;
    int extraRows = rows - 1;

    if (extraRows > 0) {
      // Different column tiers compress horizontally at different rates
      double paddingPerRow = columns == 8 ? 15.0 : (columns == 6 ? 25.0 : 40.0);
      double extraPadding = extraRows * paddingPerRow;

      double maxPadding =
          screenWidth *
          0.25; // Compress up to 25% of the screen width to avoid excessive squishing
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
                          child: Text(
                            'ma•net',
                            style: AppTheme.bodyMedium.copyWith(
                              fontFamily: 'momo',
                              fontSize: 40.0,
                              letterSpacing: 0.0,
                            ),
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          iconSize: 30.0,
                          icon: const Icon(
                            Icons.settings,
                            color: AppColors.textPrimary,
                          ),
                          onPressed: () {
                            SoundEffectService.instance.playOptionsButton();
                            showDialog(
                              context: context,
                              builder: (context) => ServerOptionsPopup(
                                currentTheme: _currentTheme,
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
                              ),
                            );
                          },
                        ),
                        IconButton(
                          iconSize: 30.0,
                          icon: const Icon(
                            Icons.power_settings_new_rounded,
                            color: AppColors.textPrimary,
                          ),
                          onPressed: () async {
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
                            vertical: 50.0,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.max,
                            children: [
                              Expanded(
                                child: ChangeNotifierProvider(
                                  create: (_) =>
                                      GamepadState(_api)..initialize(),
                                  child: AdaptiveStageLayout(
                                    lobbyToolbar: _LobbyToolbar(
                                      serverSlots: _slots,
                                      serverLocked: _locked,
                                      controllerMode: _controllerMode,
                                      layoutCatalog: _presetCatalog,
                                      layoutApi: _api,
                                      brandingModeListenable:
                                          _brandingModeNotifier,
                                      alerts: _alerts,
                                      onOpenAlerts: () {
                                        _markAlertsSeen();
                                        showDialog(
                                          context: context,
                                          builder: (c) => ServerAlertsDialog(
                                            alerts: _alerts,
                                            onDismiss: _dismissAlert,
                                          ),
                                        );
                                      },
                                      onLayoutCatalogChanged: (catalog) {
                                        setState(() {
                                          _presetCatalog = catalog;
                                        });
                                      },
                                      onApply: (newSlots, newLocked) async {
                                        final assigned = await _api
                                            .fetchSlots();
                                        final active = assigned.slots
                                            .where((s) => s.device != null)
                                            .length;
                                        if (newSlots < assigned.slots.length &&
                                            active > 0) {
                                          final ok = await showDialog<bool>(
                                            context: context,
                                            builder: (c) => AlertDialog(
                                              backgroundColor:
                                                  AppColors.screenBackground,
                                              title: Text(
                                                'Remover controles?',
                                                style: AppTheme.titleSmall
                                                    .copyWith(
                                                      color:
                                                          AppColors.textPrimary,
                                                    ),
                                              ),
                                              content: Text(
                                                'Remover controles pode desconectar jogadores atuais',
                                                style: AppTheme.bodyMedium
                                                    .copyWith(
                                                      color:
                                                          AppColors.textPrimary,
                                                    ),
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.of(
                                                    c,
                                                  ).pop(false),
                                                  child: const Text('Cancelar'),
                                                ),
                                                ElevatedButton(
                                                  onPressed: () =>
                                                      Navigator.of(c).pop(true),
                                                  child: const Text(
                                                    'Confirmar',
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                          if (ok != true) return;
                                        }

                                        if (_controllerMode == 'x360' &&
                                            newSlots > 4) {
                                          _addAlert(
                                            'Alguns jogos podem não suportar mais de 4 controles x•input. Se tiver problemas, tente d•input.',
                                            isError: false,
                                          );
                                        }

                                        setState(() {
                                          _slots = newSlots;
                                          _locked = newLocked;
                                        });

                                        try {
                                          await _api.resetControllers(
                                            mode: _controllerMode,
                                            slots: _slots,
                                            fixed: _locked,
                                          );
                                        } catch (e) {
                                          if (mounted) {
                                            _addAlert(
                                              'Aviso: Falha ao aplicar no servidor ($e)',
                                              isError: true,
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

class _PresetChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _PresetChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.highlightColor.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? AppColors.highlightColor : Colors.transparent,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(fontFamily: 'momo', color: AppColors.textPrimary),
          ),
        ),
      ),
    );
  }
}

class _LobbyToolbar extends StatefulWidget {
  final int serverSlots;
  final bool serverLocked;
  final String controllerMode;
  final PresetCatalog? layoutCatalog;
  final HostApiService layoutApi;
  final ValueListenable<ControllerBrandingMode> brandingModeListenable;
  final List<ServerAlert> alerts;
  final VoidCallback onOpenAlerts;
  final ValueChanged<PresetCatalog> onLayoutCatalogChanged;
  final Future<void> Function(int slots, bool locked) onApply;
  final VoidCallback onOpenSettings;

  const _LobbyToolbar({
    required this.serverSlots,
    required this.serverLocked,
    required this.controllerMode,
    required this.layoutCatalog,
    required this.layoutApi,
    required this.brandingModeListenable,
    required this.alerts,
    required this.onOpenAlerts,
    required this.onLayoutCatalogChanged,
    required this.onApply,
    required this.onOpenSettings,
  });

  @override
  State<_LobbyToolbar> createState() => _LobbyToolbarState();
}

class _LobbyToolbarState extends State<_LobbyToolbar> {
  late int _draftSlots;
  late bool _draftLocked;
  bool _isApplying = false;

  @override
  void initState() {
    super.initState();
    _draftSlots = widget.serverSlots;
    _draftLocked = widget.serverLocked;
  }

  @override
  void didUpdateWidget(covariant _LobbyToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.serverSlots != widget.serverSlots ||
        oldWidget.serverLocked != widget.serverLocked) {
      _draftSlots = widget.serverSlots;
      _draftLocked = widget.serverLocked;
    }
  }

  bool get _hasChanges =>
      _draftSlots != widget.serverSlots || _draftLocked != widget.serverLocked;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(24)),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // LEFT SIDE: Session size controls
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Lock Icon
              GestureDetector(
                onTap: () {
                  if (_isApplying) return;
                  setState(() {
                    _draftLocked = !_draftLocked;
                  });
                },
                child: Tooltip(
                  message: _draftLocked
                      ? 'Limite fixo de jogadores'
                      : 'Criar novos controles automaticamente',
                  child: Icon(
                    _draftLocked ? Icons.lock_rounded : Icons.lock_open_rounded,
                    color: AppColors.textPrimary.withValues(alpha: 0.8),
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 24),

              // Minus
              InkWell(
                onTap: () => setState(
                  () => _draftSlots = (_draftSlots - 1).clamp(1, 64),
                ),
                borderRadius: BorderRadius.circular(16),
                child: Icon(
                  Icons.remove_circle_rounded,
                  color: AppColors.highlightColor,
                  size: 28,
                ),
              ),

              // Slots count
              SizedBox(
                width: 40,
                child: Center(
                  child: Text(
                    '$_draftSlots',
                    style: AppTheme.titleLarge.copyWith(
                      color: AppColors.textPrimary,
                      fontFamily: 'monomaniac',
                      fontSize: 22,
                    ),
                  ),
                ),
              ),

              // Plus
              InkWell(
                onTap: () => setState(
                  () => _draftSlots = (_draftSlots + 1).clamp(1, 64),
                ),
                borderRadius: BorderRadius.circular(16),
                child: Icon(
                  Icons.add_circle_rounded,
                  color: AppColors.highlightColor,
                  size: 28,
                ),
              ),

              if (_hasChanges) ...[
                const SizedBox(width: 16),
                _isApplying
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : InkWell(
                        onTap: () async {
                          setState(() => _isApplying = true);
                          await widget.onApply(_draftSlots, _draftLocked);
                          if (mounted) setState(() => _isApplying = false);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
              ],
            ],
          ),
          if (widget.layoutCatalog != null) ...[
            const SizedBox(width: 18),
            LayoutSelectorWidget(
              api: widget.layoutApi,
              catalog: widget.layoutCatalog!,
              brandingModeListenable: widget.brandingModeListenable,
              onCatalogChanged: widget.onLayoutCatalogChanged,
            ),
          ],

          // RIGHT SIDE: Input mode controls
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.alerts.isNotEmpty) ...[
                _AlertIcon(alerts: widget.alerts, onTap: widget.onOpenAlerts),
                const SizedBox(width: 12),
              ],
              InkWell(
                onTap: widget.onOpenSettings,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.textPrimary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.settings_rounded,
                        color: AppColors.textPrimary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.controllerMode.toLowerCase() == 'x360'
                            ? 'x•input'
                            : 'd•input',
                        style: AppTheme.bodyMedium.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ServerAlert {
  final String id;
  final String message;
  final bool isError;
  bool isSeen;

  ServerAlert({
    required this.message,
    this.isError = false,
    this.isSeen = false,
  }) : id = '${DateTime.now().microsecondsSinceEpoch}_${message.hashCode}';
}

class _AlertIcon extends StatelessWidget {
  final List<ServerAlert> alerts;
  final VoidCallback onTap;

  const _AlertIcon({required this.alerts, required this.onTap});

  @override
  Widget build(BuildContext context) {
    bool hasUnseenError = alerts.any((a) => !a.isSeen && a.isError);
    bool hasUnseenWarning = alerts.any((a) => !a.isSeen && !a.isError);

    Color iconColor;
    if (hasUnseenError) {
      iconColor = Colors.red;
    } else if (hasUnseenWarning) {
      iconColor = Colors.amber;
    } else {
      iconColor = AppColors.textPrimary.withValues(alpha: 0.4);
    }

    return IconButton(
      onPressed: onTap,
      icon: Icon(
        hasUnseenError
            ? Icons.error_outline_rounded
            : Icons.warning_amber_rounded,
        color: iconColor,
      ),
      tooltip: 'Avisos e Erros',
    );
  }
}

class ServerAlertsDialog extends StatefulWidget {
  final List<ServerAlert> alerts;
  final Function(String) onDismiss;

  const ServerAlertsDialog({
    super.key,
    required this.alerts,
    required this.onDismiss,
  });

  @override
  State<ServerAlertsDialog> createState() => _ServerAlertsDialogState();
}

class _ServerAlertsDialogState extends State<ServerAlertsDialog> {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.screenBackground,
      title: Text(
        'Avisos e Erros',
        style: AppTheme.titleSmall.copyWith(color: AppColors.textPrimary),
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 300,
        child: widget.alerts.isEmpty
            ? Center(
                child: Text(
                  'Nenhum alerta.',
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              )
            : ListView.builder(
                itemCount: widget.alerts.length,
                itemBuilder: (context, index) {
                  final alert = widget.alerts[index];
                  return Card(
                    color: AppColors.screenBackground,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: alert.isError ? Colors.red : Colors.amber,
                        width: 1.5,
                      ),
                    ),
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Icon(
                        alert.isError
                            ? Icons.error_outline
                            : Icons.warning_amber_rounded,
                        color: alert.isError ? Colors.red : Colors.amber,
                      ),
                      title: SelectableText(
                        alert.message,
                        style: AppTheme.bodyMedium.copyWith(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                        ),
                      ),
                      trailing: IconButton(
                        icon: const Icon(
                          Icons.close,
                          color: AppColors.textPrimary,
                        ),
                        onPressed: () {
                          widget.onDismiss(alert.id);
                          setState(() {});
                        },
                      ),
                    ),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Fechar'),
        ),
      ],
    );
  }
}
