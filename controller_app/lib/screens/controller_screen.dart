import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/player_face.dart';
import '../services/haptics_manager.dart';
import '../services/network_discovery_service.dart';
import '../services/preferences_service.dart';
import '../services/websocket_service.dart';
import '../theme/app_colors.dart';
import '../widgets/action_buttons.dart';
import '../widgets/control_button.dart';
import '../widgets/joystick.dart';
import '../widgets/options_popup.dart';
import '../widgets/player_face_indicator.dart';
import 'qr_scanner_screen.dart';

enum ControllerConnectionState {
  searching,
  connected,
  disconnected,
  multipleHostsFound,
}

class ControllerScreen extends StatefulWidget {
  const ControllerScreen({super.key});

  @override
  State<ControllerScreen> createState() => _ControllerScreenState();
}

class ConnectionManager {
  ConnectionManager._();
  static final ConnectionManager instance = ConnectionManager._();

  WebSocketService? ws;

  void disconnect() {
    ws?.channel.sink.close();
    ws = null;
  }

  Future<WebSocketService> getConnection() async {
    ws ??= await _createConnection();
    return ws!;
  }

  Future<WebSocketService> _createConnection() async {
    final prefs = PreferencesService.instance;

    final deviceId = await prefs.getDeviceId();
    final playerFace = await prefs.getOrCreatePlayerFace();
    final bool isHttps =
        await prefs.getServerHttps() ?? (Uri.base.scheme == 'https');

    final wsUri = Uri(
      scheme: isHttps ? 'wss' : 'ws',
      host: await prefs.getServerHost() ?? Uri.base.host,
      port: await prefs.getServerPort() ?? Uri.base.port,
      path: '/ws',
      queryParameters: {
        'deviceId': deviceId,
        ...playerFace.toJson().map(
          (key, value) => MapEntry(key, value?.toString() ?? ''),
        ),
      },
    );

    return WebSocketService.connectUri(wsUri);
  }
}

class _ControllerScreenState extends State<ControllerScreen>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  static const Map<String, String> _serverCodeText = {
    'missing_device_id': 'Missing device id',
    'mouse_mode_in_use': 'Mouse mode already in use',
  };

  static const List<String> _editableButtons = [
    'btnA',
    'btnB',
    'btnX',
    'btnY',
    'btnLB',
    'btnRB',
    'btnLT',
    'btnRT',
    'btnLS',
    'btnRS',
  ];

  WebSocketService? ws;

  ControllerConnectionState _connectionState =
      ControllerConnectionState.searching;
  late NetworkDiscoveryService _discoveryService;
  StreamSubscription? _discoverySubscription;
  List<DiscoveredHost> _discoveredHosts = [];
  bool _autoConnectEnabled = true;

  String status = 'Conectando...';
  int? playerIndex;
  bool dpadMode = false;
  bool editMode = false;
  bool _mouseModeRequested = false;
  bool _mouseModeOwned = false;
  String? _mouseModeOwnerName;
  bool _centerPulseExpanded = false;
  Color? playerColor;
  int totalSlots = 4;
  ColorTheme _currentTheme = ColorTheme.blue;
  PlayerFaceData _playerFace = PlayerFaceData.random();

  bool _listenerAttached = false;

  final Map<String, bool> visibleButtons = {
    'btnA': true,
    'btnB': true,
    'btnX': true,
    'btnY': true,
    'btnRB': false,
    'btnRT': false,
    'btnRS': false,
    'btnLB': false,
    'btnLT': false,
    'btnLS': false,
  };

  bool get _isMouseModeVisible => _mouseModeRequested;
  bool get _isEditModeActive => editMode;
  bool get _isTemporaryModeActive => _isMouseModeVisible || _isEditModeActive;

  Future<void> _checkSetupRequired() async {
    await _loadInitialPreferences();

    if (kIsWeb) {
      _connectWebSocket();
      return;
    }

    final host = await PreferencesService.instance.getServerHost();
    if (host != null) {
      _connectWebSocket();
    } else {
      _startDiscovery();
    }
  }

  void _startDiscovery() {
    setState(() => _connectionState = ControllerConnectionState.searching);

    _discoveryService.startScanning();
    _discoverySubscription?.cancel();
    _discoverySubscription = _discoveryService.discoveredHosts.listen((hosts) {
      if (_connectionState == ControllerConnectionState.connected) return;

      if (hosts.length == 1 && _autoConnectEnabled) {
        _connectToHost(hosts.first);
      } else if (hosts.length > 1) {
        setState(() {
          _connectionState = ControllerConnectionState.multipleHostsFound;
          _discoveredHosts = hosts;
        });
      }
    });

    Future.delayed(const Duration(seconds: 4), () {
      if (mounted && _connectionState == ControllerConnectionState.searching) {
        setState(
          () => _connectionState = ControllerConnectionState.disconnected,
        );
      }
    });
  }

  Future<void> _connectWebSocket() async {
    if (ws != null || _listenerAttached) return;

    setState(() => _connectionState = ControllerConnectionState.searching);

    try {
      _listenerAttached = true;
      ws = await ConnectionManager.instance.getConnection();

      setState(() {
        _connectionState = ControllerConnectionState.connected;
        status = 'Conectado';
      });

      ws!.channel.stream.listen(
        _handleWebSocketMessage,
        onDone: _handleDisconnect,
        onError: (_) => _handleDisconnect(),
      );
      _send({'type': 'face_update', ..._playerFace.toJson()});
      if (_mouseModeRequested) {
        _send({'type': 'set_mouse_mode', 'active': true});
      }
    } catch (_) {
      _handleDisconnect();
    }
  }

  void _handleDisconnect() {
    if (!mounted) return;
    ConnectionManager.instance.disconnect();
    _listenerAttached = false;
    ws = null;
    setState(() {
      _connectionState = ControllerConnectionState.disconnected;
      _mouseModeRequested = false;
      _mouseModeOwned = false;
      _mouseModeOwnerName = null;
      editMode = false;
    });
    _clearPlayerSlot();
    _autoConnectEnabled = false;
  }

  Future<void> _connectToHost(DiscoveredHost host) async {
    _discoveryService.stopScanning();
    await PreferencesService.instance.saveConnection(host.ip, host.port, false);
    _connectWebSocket();
  }

  void _openQRScanner() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QRScannerScreen(
          onConnected: () {
            _autoConnectEnabled = true;
            _connectWebSocket();
          },
        ),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _discoveryService = NetworkDiscoveryService();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
    ]);
    HapticsManager.instance.init();
    _checkSetupRequired();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ConnectionManager.instance.disconnect();
    _discoveryService.stopScanning();
    _discoverySubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.detached) {
      ConnectionManager.instance.disconnect();
    }
  }

  void _resetConnection() async {
    ConnectionManager.instance.disconnect();
    await PreferencesService.instance.clearConnection();
    _autoConnectEnabled = false;
    _handleDisconnect();
  }

  void _updatePlayerSlot(dynamic slotValue, {String? colorHex}) {
    final slot = (slotValue as num).toInt();
    PreferencesService.instance.setLastKnownSlot(slot);

    setState(() {
      playerIndex = slot + 1;
      status = 'Conectado';

      if (colorHex != null) {
        final parsedColor = colorFromHex(colorHex);
        playerColor = parsedColor;
        _playerFace = _playerFace.copyWith(color: parsedColor);
      }
    });
  }

  void _send(Map<String, dynamic> obj) {
    if (_connectionState != ControllerConnectionState.connected) return;
    ws?.send(obj);
  }

  void _handleWebSocketMessage(dynamic message) {
    if (message is! String) return;

    try {
      final dynamic data = jsonDecode(message);
      if (data is! Map<String, dynamic>) return;

      if (data.containsKey('total_slots')) {
        setState(() {
          totalSlots = data['total_slots'];
        });
      }

      switch (data['type']) {
        case 'assigned':
          _updatePlayerSlot(data['slot'], colorHex: data['color']);
          _ingestFaceData(data);
          HapticsManager.instance.connectionPulse();
          break;
        case 'slot_changed':
          _updatePlayerSlot(data['slot'], colorHex: data['color']);
          _ingestFaceData(data);
          break;
        case 'mouse_mode_status':
          setState(() {
            _mouseModeOwned = data['owner'] == true;
            _mouseModeOwnerName = data['ownerName'] as String?;
            if (data['active'] != true) {
              _mouseModeOwnerName = null;
              _mouseModeOwned = false;
            }
          });
          break;
        case 'error':
          final code = data['code'] as String?;
          if (code == 'mouse_mode_in_use') {
            unawaited(_exitMouseMode(send: false));
            _mouseModeOwnerName = data['ownerName'] as String?;
          }
          if (code != null && mounted) {
            final baseMessage = _serverCodeText[code] ?? code;
            final ownerName = data['ownerName'] as String?;
            final text = ownerName != null && ownerName.isNotEmpty
                ? '$baseMessage ($ownerName)'
                : baseMessage;
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(text)));
          }
          break;
        case 'unassigned':
          _clearPlayerSlot();
          break;
        case 'rumble':
          try {
            final weak = (data['weak'] as num?)?.toDouble() ?? 0;
            final strong = (data['strong'] as num?)?.toDouble() ?? 0;
            HapticsManager.instance.onRumble(weak, strong);
          } catch (_) {}
          break;
        case 'toggle_btn':
          if (data['btn'] != null) {
            final id = 'btn${(data['btn'] as String).toUpperCase()}';
            final visible = data['visible'] != false;
            setState(() {
              visibleButtons[id] = visible;
            });
          }
          break;
      }
    } catch (_) {}
  }

  void _clearPlayerSlot() {
    setState(() {
      playerIndex = null;
      status = 'Em espera';
    });
  }

  void _ingestFaceData(Map<String, dynamic> data) {
    if (!data.containsKey('faceText') && !data.containsKey('faceRotation')) {
      return;
    }

    final nextFace = PlayerFaceData.fromJson({
      ..._playerFace.toJson(),
      ...data,
    });

    setState(() {
      _playerFace = nextFace;
      playerColor = nextFace.color;
    });

    PreferencesService.instance.savePlayerFace(nextFace);
  }

  Future<void> _updatePlayerFace(PlayerFaceData nextFace) async {
    setState(() {
      _playerFace = nextFace;
      playerColor = nextFace.color;
    });
    await PreferencesService.instance.savePlayerFace(nextFace);
    _send({'type': 'face_update', ...nextFace.toJson()});
  }

  Future<void> _enterMouseMode() async {
    setState(() {
      editMode = false;
      _mouseModeRequested = true;
      _mouseModeOwnerName = null;
    });
    _send({'type': 'set_mouse_mode', 'active': true});
  }

  Future<void> _exitMouseMode({bool send = true}) async {
    setState(() {
      _mouseModeRequested = false;
      _mouseModeOwned = false;
      _mouseModeOwnerName = null;
    });
    if (send) {
      _send({'type': 'set_mouse_mode', 'active': false});
    }
  }

  void _enterEditMode() {
    setState(() {
      editMode = true;
      _mouseModeRequested = false;
      _mouseModeOwned = false;
      _mouseModeOwnerName = null;
    });
    _send({'type': 'set_mouse_mode', 'active': false});
  }

  void _exitEditMode() {
    setState(() {
      editMode = false;
    });
  }

  void _exitTemporaryMode() {
    if (_isMouseModeVisible) {
      _exitMouseMode();
      return;
    }
    if (_isEditModeActive) {
      _exitEditMode();
    }
  }

  Widget _buildPlayerIndicator() {
    final selectedIndex = playerIndex != null ? playerIndex! - 1 : null;
    return LayoutBuilder(
      builder: (context, constraints) {
        final int columns = totalSlots <= 4
            ? (totalSlots > 0 ? totalSlots : 1)
            : 4;
        final int rows = (totalSlots / columns).ceil();
        final double squareSize =
            ((constraints.maxWidth - (columns * 8)) / columns).clamp(
              12.0,
              22.0,
            );

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(rows, (rowIndex) {
            final rowItemCount = (rowIndex == rows - 1)
                ? totalSlots - (rowIndex * columns)
                : columns;
            return Padding(
              padding: EdgeInsets.only(bottom: rowIndex < rows - 1 ? 6.0 : 0),
              child: _buildIndicatorRow(
                selectedIndex,
                rowIndex * columns,
                rowItemCount,
                squareSize,
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildIndicatorRow(
    int? selectedIndex,
    int offset,
    int count,
    double squareSize,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final position = offset + index;
        final isActive = selectedIndex == position;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: AnimatedOpacity(
            opacity: isActive && status == 'Conectado' ? 1 : 0.4,
            duration: const Duration(milliseconds: 180),
            child: isActive && status == 'Conectado'
                ? PlayerFaceIndicator(
                    face: _playerFace,
                    size: squareSize,
                    roundedSquare: true,
                    borderColor: AppColors.textPrimary,
                  )
                : Container(
                    width: squareSize,
                    height: squareSize,
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      border: Border.all(
                        color: AppColors.textPrimary,
                        width: AppColors.borderThickness,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
          ),
        );
      }),
    );
  }

  void _onStickChanged(double x, double y) {
    _send({'type': 'stick', 'x': x, 'y': y});
  }

  void _onStickRelease() {
    _send({'type': 'stick', 'x': 0, 'y': 0});
    Future.delayed(const Duration(milliseconds: 40), () {
      _send({'type': 'stick', 'x': 0, 'y': 0});
    });
    Future.delayed(const Duration(milliseconds: 100), () {
      _send({'type': 'stick', 'x': 0, 'y': 0});
    });
  }

  void _onMouseStickChanged(double x, double y) {
    if (!_mouseModeOwned) return;
    _send({'type': 'mouse_move', 'x': x, 'y': y});
  }

  void _onMouseStickRelease() {
    if (!_mouseModeOwned) return;
    _send({'type': 'mouse_move', 'x': 0, 'y': 0});
  }

  void _sendButton(String xinputId, String state) {
    _send({'type': 'button', 'id': xinputId, 'state': state});
  }

  void _sendMouseButton(String button, String state) {
    if (!_mouseModeOwned) return;
    _send({'type': 'mouse_${button}_$state'});
    if (state == 'down') {
      HapticsManager.instance.softTap();
    }
  }

  void _sendMouseScroll(double delta) {
    if (!_mouseModeOwned) return;
    _send({'type': 'mouse_scroll', 'delta': delta.clamp(-1.3, 1.3)});
  }

  void _toggleWindowVisibility() {
    if (!_mouseModeOwned) return;
    _send({'type': 'toggle_window_visibility'});
    HapticsManager.instance.softTap();
  }

  void _showOptionsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return OptionsPopup(
          dpadMode: dpadMode,
          onDpadModeChanged: (value) {
            setState(() => dpadMode = value);
            PreferencesService.instance.setDpadMode(value);
          },
          onEnterMouseMode: _enterMouseMode,
          onEnterEditMode: _enterEditMode,
          currentTheme: _currentTheme,
          onThemeChanged: _onThemeChanged,
          onDisconnectRequested: _resetConnection,
          onRumbleTest: _onRumbleTest,
          playerFace: _playerFace,
          onPlayerFaceChanged: _updatePlayerFace,
        );
      },
    );
  }

  void _toggleButtonVisibility(String buttonKey) {
    setState(() {
      visibleButtons[buttonKey] = !(visibleButtons[buttonKey] ?? true);
    });
    PreferencesService.instance.setButtonVisibility(visibleButtons);
  }

  Future<void> _loadInitialPreferences() async {
    try {
      final prefs = PreferencesService.instance;

      final themeIndex = await prefs.getSelectedTheme();
      _currentTheme = ColorTheme.values[themeIndex];
      AppColors.setTheme(_currentTheme);
      _playerFace = await prefs.getOrCreatePlayerFace();
      playerColor = _playerFace.color;
      dpadMode = await prefs.getDpadMode();

      final savedVisibility = await prefs.getButtonVisibility();
      if (savedVisibility != null) {
        visibleButtons.addAll(savedVisibility);
      }
    } catch (_) {
      AppColors.setTheme(ColorTheme.blue);
    }
    if (mounted) setState(() {});
  }

  void _onRumbleTest() {
    try {
      HapticsManager.instance.onRumble(0.3, 0.7);
    } catch (_) {}
    _send({'type': 'rumble_test'});
  }

  void _onThemeChanged(ColorTheme theme) {
    setState(() => _currentTheme = theme);
    PreferencesService.instance.setSelectedTheme(theme.index);
  }

  Widget _buildDpad() {
    return SizedBox(
      width: 240,
      height: 258,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _gridButton('up', 'UP'),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _gridButton('left', 'LEFT'),
              _gridButton('right', 'RIGHT'),
            ],
          ),
          _gridButton('down', 'DOWN'),
        ],
      ),
    );
  }

  Widget _gridButton(String action, String label) {
    return ControlButton(
      label: label,
      onStateChange: (state) => _sendButton(action.toUpperCase(), state),
    );
  }

  Widget _buildCenterAction() {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: ControlButton(
              label: '',
              onStateChange: (state) => _sendButton('SELECT', state),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 56,
            height: 56,
            child: ControlButton(
              label: '',
              onStateChange: (state) => _sendButton('START', state),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCenterStatus() {
    if (_connectionState == ControllerConnectionState.searching) {
      return const Text(
        'procurando...',
        style: TextStyle(
          fontSize: 18,
          color: AppColors.textPrimary,
          fontFamily: 'pico',
        ),
      );
    } else if (_connectionState == ControllerConnectionState.disconnected) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'desconectado',
            style: TextStyle(
              fontSize: 18,
              color: AppColors.textPrimary,
              fontFamily: 'pico',
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: () {
              if (kIsWeb) {
                _connectWebSocket();
              } else {
                _autoConnectEnabled = true;
                _startDiscovery();
              }
            },
            child: const Icon(
              Icons.refresh,
              color: AppColors.textPrimary,
              size: 24,
            ),
          ),
          if (!kIsWeb) ...[
            const SizedBox(width: 8),
            InkWell(
              onTap: _openQRScanner,
              child: const Icon(
                Icons.qr_code_scanner,
                color: AppColors.textPrimary,
                size: 24,
              ),
            ),
          ],
        ],
      );
    } else if (_connectionState ==
        ControllerConnectionState.multipleHostsFound) {
      return const Text(
        'selecionar host',
        style: TextStyle(
          fontSize: 18,
          color: AppColors.textPrimary,
          fontFamily: 'pico',
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (playerColor != null)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: PlayerFaceIndicator(
              face: _playerFace,
              size: 20,
              roundedSquare: true,
              borderColor: AppColors.textPrimary,
            ),
          ),
        Text(
          status,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 18,
            color: AppColors.textPrimary,
            fontFamily: 'pico',
          ),
        ),
      ],
    );
  }

  Widget _buildModeHub({
    required IconData icon,
    required String title,
    required String subtitle,
    bool pulse = false,
    VoidCallback? onTap,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 22,
            color: AppColors.textPrimary,
            fontFamily: 'pico',
          ),
        ),
        const SizedBox(height: 12),
        TweenAnimationBuilder<double>(
          tween: Tween<double>(
            begin: 1,
            end: pulse && _centerPulseExpanded ? 1.08 : 0.96,
          ),
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeInOut,
          onEnd: () {
            if (!mounted || !pulse) return;
            setState(() => _centerPulseExpanded = !_centerPulseExpanded);
          },
          builder: (context, scale, child) {
            return Transform.scale(scale: scale, child: child);
          },
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(26),
            child: Ink(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                color: AppColors.highlightColor.withValues(alpha: 0.26),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: AppColors.textPrimary,
                  width: AppColors.borderThickness,
                ),
              ),
              child: Icon(icon, color: AppColors.textPrimary, size: 36),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textPrimary.withValues(alpha: 0.75),
            fontFamily: 'pico',
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(width: 96, child: _buildPlayerIndicator()),
      ],
    );
  }

  Widget _buildMouseLayout() {
    final subtitle = _mouseModeOwned
        ? 'toque para voltar ao controle'
        : (_mouseModeOwnerName == null
              ? 'pedindo acesso ao host...'
              : 'ocupado por ${_mouseModeOwnerName!}');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 4,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'cursor',
                  style: TextStyle(
                    fontFamily: 'pico',
                    fontSize: 16,
                    color: AppColors.textPrimary.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 10),
                Joystick(
                  size: 250,
                  onChanged: _onMouseStickChanged,
                  onReleased: _onMouseStickRelease,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.center, 
          children: [
            Expanded(
              flex: 2,
              child: _buildModeHub(
                icon: Icons.mouse_outlined,
                title: 'mouse mode',
                subtitle: subtitle,
                pulse: true,
                onTap: _exitTemporaryMode,
              )
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.center,
              child: ControlButton(
                label: '',
                width: 84,
                height: 58,
                icon: const Icon(
                  Icons.fullscreen_exit_rounded,
                  color: AppColors.textPrimary,
                ),
                onStateChange: (state) {
                  if (state == 'up') {
                    _toggleWindowVisibility();
                  }
                },
              ),
            ),
          ]
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 4,
          child: Column(
            children: [
              Expanded(
                flex: 5,
                child: _MouseScrollStrip(onScroll: _sendMouseScroll),
              ),
              const SizedBox(height: 16),
              Expanded(
                flex: 4,
                child: Row(
                  children: [
                    Expanded(
                      child: ControlButton(
                        label: 'LEFT',
                        width: double.infinity,
                        height: double.infinity,
                        borderRadius: BorderRadius.circular(28),
                        onStateChange: (state) =>
                            _sendMouseButton('left', state),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ControlButton(
                        label: 'RIGHT',
                        width: double.infinity,
                        height: double.infinity,
                        borderRadius: BorderRadius.circular(28),
                        onStateChange: (state) =>
                            _sendMouseButton('right', state),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEditControlsPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.backgroundColor.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: AppColors.textPrimary,
          width: AppColors.borderThickness,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'edit controls',
            style: TextStyle(
              fontFamily: 'pico',
              fontSize: 22,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Mostre, esconda e depois arraste os botoes no painel da direita.',
            style: TextStyle(
              fontFamily: 'pico',
              fontSize: 12,
              color: AppColors.textPrimary.withValues(alpha: 0.72),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _editableButtons.map(_buildEditToggleTile).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditToggleTile(String buttonKey) {
    final visible = visibleButtons[buttonKey] ?? true;
    final label = buttonKey.replaceFirst('btn', '');

    return GestureDetector(
      onTap: () => _toggleButtonVisibility(buttonKey),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 96,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: visible
              ? AppColors.highlightColor.withValues(alpha: 0.34)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.textPrimary,
            width: visible ? 3 : 2,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'pico',
                fontSize: 18,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              visible ? 'on' : 'off',
              style: TextStyle(
                fontFamily: 'pico',
                fontSize: 11,
                color: AppColors.textPrimary.withValues(alpha: 0.72),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(flex: 3, child: _buildEditControlsPanel()),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: _buildModeHub(
            icon: Icons.tune_rounded,
            title: 'edit mode',
            subtitle: 'toque para voltar ao jogo',
            onTap: _exitTemporaryMode,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 3,
          child: ActionButtons(
            visibleButtons: visibleButtons,
            onButtonStateChanged: _sendButton,
            editMode: true,
          ),
        ),
      ],
    );
  }

  Widget _buildDefaultLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 3,
          child: Align(
            alignment: Alignment.centerLeft,
            child: dpadMode
                ? _buildDpad()
                : Joystick(
                    size: 220,
                    onChanged: _onStickChanged,
                    onReleased: _onStickRelease,
                  ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Text(
                'ma•net',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.normal,
                  color: AppColors.textPrimary,
                  fontFamily: 'pico',
                ),
              ),
              const SizedBox(height: 10),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [_buildCenterStatus()],
                    ),
                    const SizedBox(height: 8),
                    _buildPlayerIndicator(),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              IconButton(
                icon: const Icon(Icons.settings, size: 32),
                onPressed: _showOptionsDialog,
                tooltip: 'Options',
              ),
              const SizedBox(height: 18),
              _buildCenterAction(),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 3,
          child: ActionButtons(
            visibleButtons: visibleButtons,
            onButtonStateChanged: _sendButton,
            editMode: false,
          ),
        ),
      ],
    );
  }

  Widget _buildMultipleHostsOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black54,
        child: Center(
          child: Container(
            width: 320,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.screenBackground,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.textPrimary,
                width: AppColors.borderThickness,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Varios Hosts Encontrados',
                  style: TextStyle(
                    fontFamily: 'pico',
                    color: AppColors.textPrimary,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 16),
                ..._discoveredHosts.map(
                  (host) => Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.highlightColor,
                        foregroundColor: AppColors.textPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(
                            color: AppColors.textPrimary,
                            width: 2,
                          ),
                        ),
                      ),
                      onPressed: () {
                        _autoConnectEnabled = true;
                        _connectToHost(host);
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              host.name,
                              style: const TextStyle(
                                fontFamily: 'pico',
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              host.ip,
                              style: TextStyle(
                                fontFamily: 'pico',
                                fontSize: 10,
                                color: AppColors.textPrimary.withValues(
                                  alpha: 0.7,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (!kIsWeb) ...[
                  const SizedBox(height: 8),
                  TextButton.icon(
                    icon: const Icon(
                      Icons.qr_code_scanner,
                      color: AppColors.textPrimary,
                    ),
                    label: const Text(
                      'Escanear QR em vez disso',
                      style: TextStyle(
                        fontFamily: 'pico',
                        color: AppColors.textPrimary,
                      ),
                    ),
                    onPressed: _openQRScanner,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final body = _isMouseModeVisible
        ? _buildMouseLayout()
        : (_isEditModeActive ? _buildEditLayout() : _buildDefaultLayout());

    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        decoration: BoxDecoration(
          color: AppColors.screenBackground,
          gradient: _isTemporaryModeActive
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.screenBackground,
                    AppColors.highlightColor.withValues(alpha: 0.18),
                    AppColors.screenBackground,
                  ],
                )
              : null,
        ),
        child: Stack(
          children: [
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 240),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  child: KeyedSubtree(
                    key: ValueKey<String>(
                      _isMouseModeVisible
                          ? 'mouse'
                          : (_isEditModeActive ? 'edit' : 'normal'),
                    ),
                    child: body,
                  ),
                ),
              ),
            ),
            if (_connectionState ==
                ControllerConnectionState.multipleHostsFound)
              _buildMultipleHostsOverlay(),
          ],
        ),
      ),
    );
  }
}

class _MouseScrollStrip extends StatelessWidget {
  const _MouseScrollStrip({required this.onScroll});

  final ValueChanged<double> onScroll;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragUpdate: (details) {
        final dragDelta = details.primaryDelta ?? 0;
        if (dragDelta.abs() < 1) return;
        onScroll((-dragDelta / 32).clamp(-1.2, 1.2));
      },
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.backgroundColor.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: AppColors.textPrimary,
            width: AppColors.borderThickness,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            const Icon(
              Icons.keyboard_arrow_up_rounded,
              color: AppColors.textPrimary,
              size: 34,
            ),
            Text(
              'scroll',
              style: TextStyle(
                fontFamily: 'pico',
                fontSize: 16,
                color: AppColors.textPrimary.withValues(alpha: 0.85),
              ),
            ),
            Container(
              width: 56,
              height: 98,
              decoration: BoxDecoration(
                color: AppColors.highlightColor.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: AppColors.textPrimary.withValues(alpha: 0.25),
                  width: 1.5,
                ),
              ),
              child: const Icon(
                Icons.swap_vert_rounded,
                color: AppColors.textPrimary,
                size: 30,
              ),
            ),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AppColors.textPrimary,
              size: 34,
            ),
          ],
        ),
      ),
    );
  }
}
