import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import '../services/websocket_service.dart';
import '../widgets/joystick.dart';
import '../widgets/action_buttons.dart';
import '../widgets/control_button.dart';
import '../widgets/options_popup.dart';
import '../theme/app_colors.dart';
import '../services/preferences_service.dart';
import '../services/network_discovery_service.dart';
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
    // If your WebSocketService has a close method, invoke it here safely
    ws = null;
  }

  Future<WebSocketService> getConnection() async {
    ws ??= await _createConnection();
    return ws!;
  }

  Future<WebSocketService> _createConnection() async {
    final prefs = PreferencesService.instance;

    final deviceId = await prefs.getDeviceId();
    final bool isHttps =
        await prefs.getServerHttps() ?? (Uri.base.scheme == 'https');

    final wsUri = Uri(
      scheme: isHttps ? 'wss' : 'ws',
      host: await prefs.getServerHost() ?? Uri.base.host,
      port: await prefs.getServerPort() ?? Uri.base.port,
      path: '/ws',
      queryParameters: {'deviceId': deviceId},
    );

    return WebSocketService.connectUri(wsUri);
  }
}

class _ControllerScreenState extends State<ControllerScreen>
    with AutomaticKeepAliveClientMixin {
  WebSocketService? ws;
  
  ControllerConnectionState _connectionState = ControllerConnectionState.searching;
  late NetworkDiscoveryService _discoveryService;
  StreamSubscription? _discoverySubscription;
  List<DiscoveredHost> _discoveredHosts = [];
  bool _autoConnectEnabled = true;

  String status = 'Conectando...';
  int? playerIndex;
  bool dpadMode = false;
  bool editMode = false;
  Color? playerColor;
  int totalSlots = 4;
  ColorTheme _currentTheme = ColorTheme.blue;

  bool _listenerAttached = false;

  Color colorFromHex(String hex) {
    final cleaned = hex.replaceAll('#', '');
    return Color(int.parse('FF$cleaned', radix: 16));
  }

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

    // Timeout to disconnected state if nothing is found
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted && _connectionState == ControllerConnectionState.searching) {
        setState(() => _connectionState = ControllerConnectionState.disconnected);
      }
    });
  }

  Future<void> _connectWebSocket() async {
    if (ws != null) return;
    if (_listenerAttached) return;

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
    } catch (e) {
      _handleDisconnect();
    }
  }

  void _handleDisconnect() {
    if (!mounted) return;
    _listenerAttached = false;
    ws = null;
    setState(() => _connectionState = ControllerConnectionState.disconnected);
    _clearPlayerSlot();
    _autoConnectEnabled = false; // Prevent endless auto-reconnect loops to a dead host
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
    _discoveryService = NetworkDiscoveryService();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
    ]);
    _checkSetupRequired();
  }

  @override
  void dispose() {
    _discoveryService.stopScanning();
    _discoverySubscription?.cancel();
    super.dispose();
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
        playerColor = colorFromHex(colorHex);
      }
    });
  }

  void _send(Map<String, dynamic> obj) {
    if (_connectionState != ControllerConnectionState.connected) return;
    ws?.send(obj);
  }

  void _handleWebSocketMessage(dynamic message) {
    if (message is String) {
      try {
        final dynamic data = jsonDecode(message);

        if (data is Map<String, dynamic>) {
          if (data.containsKey('total_slots')) {
            setState(() {
              totalSlots = data['total_slots'];
            });
          }

          if (data['type'] == 'assigned') {
            _updatePlayerSlot(data['slot'], colorHex: data['color']);
          }

          if (data['type'] == 'slot_changed') {
            _updatePlayerSlot(data['slot'], colorHex: data['color']);
          }

          if (data['type'] == 'unassigned') {
            _clearPlayerSlot();
          }

          if (data['type'] == 'toggle_btn' && data['btn'] != null) {
            final id = 'btn${(data['btn'] as String).toUpperCase()}';
            final visible = data['visible'] != false;

            setState(() {
              visibleButtons[id] = visible;
            });
          }
        }
      } catch (_) {}
    }
  }

  void _clearPlayerSlot() {
    debugPrint('Player unassigned');
    setState(() {
      playerIndex = null;
      status = 'Em espera';
    });
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
            int rowItemCount = (rowIndex == rows - 1)
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
          child: SizedBox(
            width: squareSize,
            height: squareSize,
            child: Container(
              decoration: BoxDecoration(
                color: (isActive && status == 'Conectado')
                    ? AppColors.textPrimary
                    : Colors.transparent,
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

  void _sendButton(String xinputId, String state) {
    _send({'type': 'button', 'id': xinputId, 'state': state});
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
          buttonVisibility: visibleButtons,
          onButtonVisibilityChanged: _toggleButtonVisibility,
          editMode: editMode,
          onEditModeChanged: (value) => setState(() => editMode = value),
          currentTheme: _currentTheme,
          onThemeChanged: _onThemeChanged,
          onRescanRequested: _resetConnection,
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

      dpadMode = await prefs.getDpadMode();

      final savedVisibility = await prefs.getButtonVisibility();
      if (savedVisibility != null) {
        visibleButtons.addAll(savedVisibility);
      }
    } catch (e) {
      AppColors.setTheme(ColorTheme.blue);
    }
    if (mounted) setState(() {});
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
        'searching...',
        style: TextStyle(fontSize: 18, color: AppColors.textPrimary, fontFamily: 'pico'),
      );
    } else if (_connectionState == ControllerConnectionState.disconnected) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'disconnected',
            style: TextStyle(fontSize: 18, color: AppColors.textPrimary, fontFamily: 'pico'),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: () {
              _autoConnectEnabled = true;
              _startDiscovery();
            },
            child: const Icon(Icons.refresh, color: AppColors.textPrimary, size: 24),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: _openQRScanner,
            child: const Icon(Icons.qr_code_scanner, color: AppColors.textPrimary, size: 24),
          ),
        ],
      );
    } else if (_connectionState == ControllerConnectionState.multipleHostsFound) {
      return const Text(
        'select host',
        style: TextStyle(fontSize: 18, color: AppColors.textPrimary, fontFamily: 'pico'),
      );
    } else if (_connectionState == ControllerConnectionState.connected) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (playerColor != null)
            Container(
              width: 16,
              height: 16,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: playerColor,
                borderRadius: BorderRadius.circular(4),
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
    return const SizedBox.shrink();
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
              border: Border.all(color: AppColors.textPrimary, width: AppColors.borderThickness),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Multiple Hosts Found', style: TextStyle(fontFamily: 'pico', color: AppColors.textPrimary, fontSize: 16)),
                const SizedBox(height: 16),
                ..._discoveredHosts.map((host) => Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.highlightColor,
                      foregroundColor: AppColors.textPrimary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppColors.textPrimary, width: 2)),
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
                          Text(host.name, style: const TextStyle(fontFamily: 'pico', fontSize: 14)),
                          Text(host.ip, style: TextStyle(fontFamily: 'pico', fontSize: 10, color: AppColors.textPrimary.withOpacity(0.7))),
                        ],
                      ),
                    ),
                  ),
                )),
                const SizedBox(height: 8),
                TextButton.icon(
                  icon: const Icon(Icons.qr_code_scanner, color: AppColors.textPrimary),
                  label: const Text('Scan QR Instead', style: TextStyle(fontFamily: 'pico', color: AppColors.textPrimary)),
                  onPressed: _openQRScanner,
                ),
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

    return Scaffold(
      body: Container(
        color: AppColors.screenBackground,
        child: Stack(
          children: [
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
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
                                  children: [
                                    _buildCenterStatus(),
                                  ],
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
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Expanded(
                            child: ActionButtons(
                              visibleButtons: visibleButtons,
                              onButtonStateChanged: _sendButton,
                              editMode: editMode,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        )
      )
    );
  }
}
