import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../models/controller_layout_preset.dart';
import '../models/controller_branding.dart';
import '../models/player_face.dart';
import '../services/controller_connection_manager.dart';
import '../services/haptics_manager.dart';
import '../services/network_discovery_service.dart';
import '../services/preferences_service.dart';
import '../services/websocket_service.dart';
import '../theme/app_colors.dart';
import '../widgets/options_popup.dart';
import '../widgets/player_face_indicator.dart';
import 'controller_screen/controller_default_view.dart';
import 'controller_screen/controller_face_view.dart';
import 'controller_screen/controller_mouse_view.dart';
import 'controller_screen/controller_screen_types.dart';
import 'controller_screen/controller_screen_widgets.dart';
import 'qr_scanner_screen.dart';
import '../services/gamepad_input_engine.dart';
import '../services/connection_diagnostics_service.dart';
import '../widgets/disconnect_dialog.dart';
import '../utils/platform_detector.dart';
import '../widgets/android_onboarding_dialog.dart';

class ControllerScreen extends StatefulWidget {
  const ControllerScreen({super.key});

  @override
  State<ControllerScreen> createState() => _ControllerScreenState();
}

class _ControllerScreenState extends State<ControllerScreen>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  static const Map<String, String> _serverCodeText = {
    'missing_device_id': 'Missing device id',
    'mouse_mode_in_use': 'Mouse mode already in use',
  };

  static const List<String> _editableButtons = [
    'A',
    'B',
    'X',
    'Y',
    'LB',
    'RB',
    'LT',
    'RT',
    'L',
    'R',
  ];

  static const List<String> _defaultButtonOrder = [
    'Y',
    'B',
    'X',
    'A',
    'RB',
    'RT',
    'LB',
    'LT',
    'R',
    'L',
    'RS_BUTTON',
    'RS_FIXED',
    'RS_SWIPE',
  ];

  final Map<String, bool> visibleButtons = {
    'A': true,
    'B': true,
    'X': true,
    'Y': true,
    'RB': false,
    'RT': false,
    'R': false,
    'LB': false,
    'LT': false,
    'L': false,
    'RS_BUTTON': false,
    'RS_FIXED': false,
    'RS_SWIPE': false,
  };
  List<String> _buttonOrder = List<String>.from(_defaultButtonOrder);
  Map<String, int> _buttonSizes = const {};

  WebSocketService? ws;
  final GlobalKey<NavigatorState> _controllerNavigatorKey =
      GlobalKey<NavigatorState>();
  final GlobalKey<ScaffoldMessengerState> _controllerMessengerKey =
      GlobalKey<ScaffoldMessengerState>();
  late final NetworkDiscoveryService _discoveryService;
  StreamSubscription? _discoverySubscription;
  late final TextEditingController _faceController;
  Completer<String>? _randomNameCompleter;

  ControllerConnectionState _connectionState =
      ControllerConnectionState.searching;
  ControllerScreenMode _activeMode = ControllerScreenMode.gameplay;
  bool _isPanelExpanded = false;
  ControllerPanelMode _panelMode = ControllerPanelMode.use;
  List<DiscoveredHost> _discoveredHosts = [];

  String get status {
    if (_connectionState == ControllerConnectionState.searching) {
      return context.l10n.status.searching;
    }
    if (_connectionState == ControllerConnectionState.disconnected) {
      return context.l10n.status.disconnected;
    }
    if (_connectionState == ControllerConnectionState.multipleHostsFound) {
      return context.l10n.status.multipleHostsFound;
    }
    return playerIndex != null
        ? context.l10n.status.connected
        : context.l10n.status.connectedWaiting;
  }
  int? playerIndex;
  MovementMode _movementMode = MovementMode.fixedJoystick;
  String _rightLayoutMode = 'columns';
  bool _mouseModeOwned = false;
  String? _mouseModeOwnerName;
  bool _centerPulseExpanded = false;
  bool _autoConnectEnabled = true;
  bool _listenerAttached = false;
  bool tapHapticsEnabled = true;
  int totalSlots = 4;
  int _connectionFailedCount = 0;
  bool _hasReceivedMessage = false;
  bool _showDialogOnFail = false;
  Color? playerColor;
  ColorTheme _currentTheme = ColorTheme.blue;
  PlayerFaceData _playerFace = PlayerFaceData.random();
  ControllerBrandingMode _brandingMode = ControllerBrandingMode.xinput;
  bool _hasVacantSlot = false;
  String? playerName;
  double leftStickSensitivity = 1.0;
  double rightStickSensitivity = 1.0;
  double swipeAccelerationIntensity = 0.0;
  double rightStickAntiDeadzone = 0.10;
  double rightStickResponseCurve = 0.5;

  Offset? _lastSentLeftStick;
  Offset? _lastSentRightStick;

  bool _isDisconnectModalOpen = false;
  BuildContext? _disconnectDialogContext;
  bool _intentionalDisconnect = false;
  Timer? _backgroundReconnectTimer;
  bool _pulseOptionsButton = false;

  bool get _isTemporaryModeActive =>
      _activeMode != ControllerScreenMode.gameplay;

  bool get _isMouseModeVisible => _activeMode == ControllerScreenMode.mouse;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _faceController = TextEditingController(text: _playerFace.faceText);
    _discoveryService = NetworkDiscoveryService();

    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
    ]);
    HapticsManager.instance.init();
    _checkSetupRequired();
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        _checkAndShowAndroidOnboarding();
      }
    });
  }

  @override
  void dispose() {
    _backgroundReconnectTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _faceController.dispose();
    ControllerConnectionManager.instance.disconnect();
    _discoveryService.stopScanning();
    _discoverySubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.detached) {
      ControllerConnectionManager.instance.disconnect();
    }
  }

  void _handleConnectionFailure() {
    if (!mounted) return;
    _connectionFailedCount++;
    if (_connectionFailedCount >= 3) {
      _connectionFailedCount = 0;
      _showConnectionTipsDialog();
    }
  }

  Future<void> _checkSetupRequired() async {
    await _loadInitialPreferences();

    if (kIsWeb) {
      await _connectWebSocket();
      return;
    }

    final host = await PreferencesService.instance.getServerHost();
    if (host != null) {
      await _connectWebSocket();
    } else {
      _startDiscovery();
    }
  }

  void _startDiscovery() {
    setState(() => _connectionState = ControllerConnectionState.searching);

    _discoveryService.startScanning();
    _discoverySubscription?.cancel();
    _discoverySubscription = _discoveryService.discoveredHosts.listen((hosts) {
      if (_connectionState == ControllerConnectionState.connected) {
        return;
      }

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
        _handleConnectionFailure();
      }
    });
  }

  Future<void> _recordSuccessfulConnection() async {
    try {
      final prefs = PreferencesService.instance;
      final host = await prefs.getServerHost() ?? Uri.base.host;
      await prefs.setLastKnownHostIp(host);
      await prefs.setHasEverConnected(true);

      // Fetch and save SSID if Wi-Fi name is available
      final ssid = await ConnectionDiagnosticsService.instance.getCurrentWifiSsid();
      if (ssid != null) {
        await prefs.setLastKnownSsid(ssid);
      }
    } catch (_) {}
  }

  void _startBackgroundReconnection() {
    _backgroundReconnectTimer?.cancel();
    _backgroundReconnectTimer = Timer.periodic(const Duration(seconds: 4), (timer) async {
      if (_connectionState == ControllerConnectionState.connected ||
          ws != null ||
          _listenerAttached) {
        return;
      }

      final prefs = PreferencesService.instance;
      final host = await prefs.getServerHost();
      if (host != null) {
        await _connectWebSocket();
      } else {
        _retryConnection();
      }
    });
  }

  void _stopBackgroundReconnection() {
    _backgroundReconnectTimer?.cancel();
    _backgroundReconnectTimer = null;
  }

  Future<void> _showDisconnectDialog() async {
    if (_isDisconnectModalOpen) return;
    _isDisconnectModalOpen = true;

    final prefs = PreferencesService.instance;
    final lastHost = await prefs.getLastKnownHostIp() ?? await prefs.getServerHost();
    final lastPort = await prefs.getServerPort();
    final expectedSsid = await prefs.getLastKnownSsid();
    final isHttps = await prefs.getServerHttps() ?? (Uri.base.scheme == 'https');

    final dialogContext = _controllerNavigatorKey.currentContext ?? context;
    if (!dialogContext.mounted) {
      _isDisconnectModalOpen = false;
      return;
    }

    _startBackgroundReconnection();

    await showDialog(
      context: dialogContext,
      barrierDismissible: false,
      useRootNavigator: false,
      builder: (dialogContext) {
        _disconnectDialogContext = dialogContext;
        return DisconnectDialog(
          hostIp: lastHost ?? Uri.base.host,
          port: lastPort ?? Uri.base.port,
          expectedSsid: expectedSsid,
          isHttps: isHttps,
          onReconnect: () {
            if (_isDisconnectModalOpen) {
              try {
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
              } catch (_) {}
              _isDisconnectModalOpen = false;
              _disconnectDialogContext = null;
            }
            _stopBackgroundReconnection();
            _retryConnection();
          },
          onClose: () {
            if (_isDisconnectModalOpen) {
              try {
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
              } catch (_) {}
              _isDisconnectModalOpen = false;
              _disconnectDialogContext = null;
            }
            _stopBackgroundReconnection();
          },
        );
      },
    );
  }

  Future<void> _checkAndShowAndroidOnboarding() async {
    if (!kIsWeb) return;
    final isAndroidBrowser = getIsAndroidBrowser();
    final isStandalone = getIsStandalonePwa();
    if (isAndroidBrowser && !isStandalone) {
      final hasSeen = await PreferencesService.instance.getHasSeenAndroidOnboarding();
      if (!hasSeen && mounted) {
        final dialogContext = _controllerNavigatorKey.currentContext ?? context;
        if (!dialogContext.mounted) return;

        final wasDownloaded = await showDialog<bool>(
          context: dialogContext,
          barrierDismissible: true,
          useRootNavigator: false,
          builder: (dialogContext) {
            return AndroidOnboardingDialog(
              onDownloadClicked: () {
                PreferencesService.instance.setHasSeenAndroidOnboarding(true);
              },
              onDismissClicked: () {
                PreferencesService.instance.setHasSeenAndroidOnboarding(true);
              },
            );
          },
        );

        if (wasDownloaded != true && mounted) {
          setState(() {
            _pulseOptionsButton = true;
          });
        }
      }
    }
  }

  Future<bool> _connectWebSocket() async {
    if (ws != null || _listenerAttached) {
      return true;
    }

    setState(() => _connectionState = ControllerConnectionState.searching);

    try {
      _listenerAttached = true;
      _hasReceivedMessage = false;
      ws = await ControllerConnectionManager.instance.getConnection().timeout(
        const Duration(seconds: 4),
      );

      setState(() {
        _connectionState = ControllerConnectionState.connected;
      });

      unawaited(_recordSuccessfulConnection());

      if (_isDisconnectModalOpen) {
        final dCtx = _disconnectDialogContext;
        try {
          if (dCtx != null && dCtx.mounted) {
            Navigator.of(dCtx).pop();
          }
        } catch (_) {}
        _isDisconnectModalOpen = false;
        _disconnectDialogContext = null;
        _stopBackgroundReconnection();
      }

      GamepadInputEngine.instance.init(_send);

      ws!.channel.stream.listen(
        _handleWebSocketMessage,
        onDone: _handleDisconnect,
        onError: (_) => _handleDisconnect(),
      );

      _send({'type': 'face_update', ..._playerFace.toJson()});
      if (_isMouseModeVisible) {
        _send({'type': 'set_mouse_mode', 'active': true});
      }
      return true;
    } catch (_) {
      _handleDisconnect();
      return false;
    }
  }

  void _handleDisconnect() {
    if (!mounted) {
      return;
    }

    final bool wasConnected = _hasReceivedMessage;
    bool failedToConnect = !_hasReceivedMessage && _listenerAttached;
    bool shouldShowDialog = _showDialogOnFail;
    _showDialogOnFail = false;

    ControllerConnectionManager.instance.disconnect();
    _listenerAttached = false;
    ws = null;
    _hasReceivedMessage = false;

    setState(() {
      _connectionState = ControllerConnectionState.disconnected;
      _activeMode = ControllerScreenMode.gameplay;
      _isPanelExpanded = false;
      _panelMode = ControllerPanelMode.use;
      _mouseModeOwned = false;
      _mouseModeOwnerName = null;
      _hasVacantSlot = false;
    });

    _clearPlayerSlot();
    _autoConnectEnabled = false;
    _lastSentLeftStick = null;
    _lastSentRightStick = null;

    GamepadInputEngine.instance.dispose();

    if (failedToConnect) {
      if (shouldShowDialog) {
        _showConnectionTipsDialog();
        _connectionFailedCount = 0;
      } else {
        _handleConnectionFailure();
      }
    }

    if (wasConnected && !_intentionalDisconnect) {
      unawaited(_showDisconnectDialog());
    }
    _intentionalDisconnect = false;
  }

  Future<void> _connectToHost(DiscoveredHost host) async {
    _discoveryService.stopScanning();
    await PreferencesService.instance.saveConnection(host.ip, host.port, false);
    await _connectWebSocket();
  }

  void _openQRScanner() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QRScannerScreen(
          onConnected: () async {
            _autoConnectEnabled = true;
            _showDialogOnFail = true;
            await _connectWebSocket();
          },
        ),
      ),
    );
  }

  void _showConnectionTipsDialog() {
    final dialogContext = _controllerNavigatorKey.currentContext ?? context;

    showDialog(
      context: dialogContext,
      useRootNavigator: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.screenBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const SizedBox(width: 8),
            Text(
              context.l10n.connectionTips.title,
              style: const TextStyle(
                fontFamily: 'momo',
                color: AppColors.textPrimary,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.connectionTips.subtitle,
                style: TextStyle(
                  color: AppColors.textPrimary.withValues(alpha: 0.8),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              _buildTipRow(
                Icons.wifi_rounded,
                context.l10n.connectionTips.wifiSame,
              ),
              const SizedBox(height: 12),
              _buildTipRow(
                Icons.shield_outlined,
                context.l10n.connectionTips.firewall,
              ),
              const SizedBox(height: 12),
              _buildTipRow(
                Icons.portable_wifi_off_outlined,
                context.l10n.connectionTips.hotspot,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              context.l10n.connectionTips.gotIt,
              style: TextStyle(
                fontFamily: 'momo',
                color: AppColors.highlightColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.textPrimary),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
          ),
        ),
      ],
    );
  }

  Future<void> _resetConnection() async {
    _intentionalDisconnect = true;
    ControllerConnectionManager.instance.disconnect();
    await PreferencesService.instance.clearConnection();
    _autoConnectEnabled = false;
    _handleDisconnect();
  }

  void _retryConnection() {
    if (kIsWeb) {
      _connectWebSocket();
      return;
    }

    _autoConnectEnabled = true;
    _startDiscovery();
  }

  void _updatePlayerSlot(dynamic slotValue, {String? colorHex}) {
    final slot = (slotValue as num).toInt();
    PreferencesService.instance.setLastKnownSlot(slot);

    setState(() {
      playerIndex = slot + 1;

      if (colorHex != null) {
        final parsedColor = colorFromHex(colorHex);
        playerColor = parsedColor;
        _playerFace = _playerFace.copyWith(color: parsedColor);
      }
    });
  }

  void _send(Map<String, dynamic> payload) {
    if (_connectionState != ControllerConnectionState.connected) {
      return;
    }
    ws?.send(payload);
  }

  void _sendQuickAction(String actionId) {
    _send({'type': 'quick_action', 'action': actionId});
  }

  void _handleWebSocketMessage(dynamic message) {
    _hasReceivedMessage = true;
    _connectionFailedCount = 0;
    _showDialogOnFail = false;

    PreferencesService.instance.setLastValidCommunicationTimestamp(
      DateTime.now().millisecondsSinceEpoch,
    );

    if (message is! String) {
      return;
    }

    try {
      final data = jsonDecode(message);
      if (data is! Map<String, dynamic>) {
        return;
      }

      if (data.containsKey('total_slots')) {
        setState(() {
          totalSlots = data['total_slots'];
        });
      }

      switch (data['type']) {
        case 'assigned':
          _updatePlayerSlot(data['slot'], colorHex: data['color']);
          _ingestFaceData(data);
          _ingestNameData(data['name']);
          HapticsManager.instance.connectionPulse();
          break;
        case 'slot_changed':
          _updatePlayerSlot(data['slot'], colorHex: data['color']);
          _ingestFaceData(data);
          _ingestNameData(data['name']);
          break;
        case 'slot_status':
          setState(() {
            _hasVacantSlot = data['has_vacant_slot'] == true;
          });
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
          _handleServerError(data);
          break;
        case 'unassigned':
          _clearPlayerSlot();
          _ingestNameData(data['name']);
          break;
        case 'rumble':
          _handleRumble(data);
          break;
        case 'toggle_btn':
          _handleButtonVisibilityUpdate(data);
          break;
        case 'layout_preset':
          _handleLayoutPresetUpdate(data);
          break;
        case 'random_name_response':
          final newName = data['name'] as String?;
          if (newName != null && _randomNameCompleter != null && !_randomNameCompleter!.isCompleted) {
            _randomNameCompleter!.complete(newName);
          }
          break;
      }
    } catch (_) {}
  }

  void _handleServerError(Map<String, dynamic> data) {
    final code = data['code'] as String?;
    if (code == 'mouse_mode_in_use') {
      unawaited(_exitMouseMode(send: false));
      _mouseModeOwnerName = data['ownerName'] as String?;
    }

    if (code == null || !mounted) {
      return;
    }

    final baseMessage = _serverCodeText[code] ?? code;
    final ownerName = data['ownerName'] as String?;
    final text = ownerName != null && ownerName.isNotEmpty
        ? '$baseMessage ($ownerName)'
        : baseMessage;

    _showControllerSnackBar(SnackBar(content: Text(text)));
  }

  void _handleRumble(Map<String, dynamic> data) {
    try {
      final weak = (data['weak'] as num?)?.toDouble() ?? 0;
      final strong = (data['strong'] as num?)?.toDouble() ?? 0;
      HapticsManager.instance.onRumble(weak, strong);
    } catch (_) {}
  }

  void _handleButtonVisibilityUpdate(Map<String, dynamic> data) {
    if (data['btn'] == null) {
      return;
    }

    final id = ControllerBranding.normalizeCanonicalId('${data['btn']}');
    final visible = data['visible'] != false;
    setState(() {
      visibleButtons[id] = visible;
    });
  }

  void _handleLayoutPresetUpdate(Map<String, dynamic> data) {
    final presetData = data['preset'];
    if (presetData is! Map<String, dynamic>) {
      return;
    }

    final preset = ControllerLayoutPreset.fromJson(presetData);
    final nextVisibility = Map<String, bool>.from(visibleButtons)
      ..addAll(preset.visibleButtons);

    setState(() {
      _movementMode = preset.movementMode;
      _rightLayoutMode = preset.rightLayoutMode;
      _brandingMode = ControllerBranding.modeFromWire(
        data['controllerMode'] as String?,
      );
      visibleButtons
        ..clear()
        ..addAll(nextVisibility);
      if (preset.buttonOrder.isNotEmpty) {
        _buttonOrder = ControllerBranding.normalizeCanonicalOrder(
          preset.buttonOrder,
        );
      }
      _buttonSizes = Map<String, int>.from(preset.buttonSizes);
    });

    PreferencesService.instance.setMovementMode(_movementMode.index);
    PreferencesService.instance.setRightLayoutMode(_rightLayoutMode);
    PreferencesService.instance.setButtonVisibility(visibleButtons);
    PreferencesService.instance.setButtonOrder(_buttonOrder);
    PreferencesService.instance.setButtonSizes(_buttonSizes);
  }

  void _clearPlayerSlot() {
    setState(() {
      playerIndex = null;
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
      if (_faceController.text != nextFace.faceText) {
        _faceController.text = nextFace.faceText;
      }
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

  void _ingestNameData(String? name) {
    if (name == null || name.isEmpty) return;
    if (playerName == null || playerName!.isEmpty) {
      setState(() {
        playerName = name;
      });
      PreferencesService.instance.savePlayerName(name);
    }
  }

  Future<void> _updatePlayerName(String name) async {
    setState(() {
      playerName = name;
    });
    await PreferencesService.instance.savePlayerName(name);
    _send({'type': 'name_update', 'name': name});
  }

  Future<String> _requestRandomName() {
    _randomNameCompleter = Completer<String>();
    _send({'type': 'request_random_name'});
    return _randomNameCompleter!.future.timeout(
      const Duration(seconds: 2),
      onTimeout: () => '',
    );
  }

  void _handleFaceTextChanged(String value) {
    final sanitized = sanitizeFaceText(value);
    if (sanitized != value) {
      _faceController.value = TextEditingValue(
        text: sanitized,
        selection: TextSelection.collapsed(offset: sanitized.length),
      );
    }

    _updatePlayerFace(
      _playerFace.copyWith(faceText: sanitized, clearPreset: true),
    );
  }

  void _handleFacePresetSelected(PlayerFacePreset preset) {
    final nextFace = _playerFace.applyPreset(preset);
    _faceController.text = nextFace.faceText;
    _faceController.selection = TextSelection.collapsed(
      offset: nextFace.faceText.length,
    );
    _updatePlayerFace(nextFace);
  }

  Future<void> _enterMouseMode() async {
    setState(() {
      _activeMode = ControllerScreenMode.mouse;
      _mouseModeOwnerName = null;
    });
    _send({'type': 'set_mouse_mode', 'active': true});
  }

  Future<void> _exitMouseMode({bool send = true}) async {
    setState(() {
      _activeMode = ControllerScreenMode.gameplay;
      _mouseModeOwned = false;
      _mouseModeOwnerName = null;
    });
    if (send) {
      _send({'type': 'set_mouse_mode', 'active': false});
    }
  }

  void _enterEditMode() {
    setState(() {
      _activeMode = ControllerScreenMode.gameplay;
      _isPanelExpanded = true;
      _panelMode = ControllerPanelMode.edit;
      _mouseModeOwned = false;
      _mouseModeOwnerName = null;
    });
    _send({'type': 'set_mouse_mode', 'active': false});
  }

  void _enterFaceMode() {
    setState(() {
      _activeMode = ControllerScreenMode.face;
      _mouseModeOwned = false;
      _mouseModeOwnerName = null;
    });
    _send({'type': 'set_mouse_mode', 'active': false});
  }

  void _showFaceTextEditDialog() {
    final dialogContext = _controllerNavigatorKey.currentContext ?? context;

    showDialog(
      context: dialogContext,
      useRootNavigator: false,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (context) {
        final mediaQuery = MediaQuery.of(context);
        final isLandscape = mediaQuery.size.width > mediaQuery.size.height;

        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              insetPadding: EdgeInsets.symmetric(
                horizontal: isLandscape ? 16 : 40,
                vertical: isLandscape ? 8 : 24,
              ),
              child: Container(
                width: isLandscape ? 400 : 280,
                padding: EdgeInsets.all(isLandscape ? 14 : 20),
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
                child: isLandscape
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          PlayerFaceIndicator(
                            face: _playerFace,
                            size: 72,
                            roundedSquare: true,
                            borderColor: AppColors.textPrimary,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.textPrimary.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.textPrimary.withValues(alpha: 0.2),
                                  width: 2,
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                              child: TextField(
                                controller: _faceController,
                                maxLength: 3,
                                textAlign: TextAlign.center,
                                autofocus: true,
                                style: const TextStyle(
                                  fontFamily: 'monomaniac',
                                  fontSize: 28,
                                  color: AppColors.textPrimary,
                                ),
                                decoration: const InputDecoration(
                                  counterText: '',
                                  border: InputBorder.none,
                                  hintText: ':-)',
                                  isDense: true,
                                ),
                                textInputAction: TextInputAction.done,
                                onChanged: (val) {
                                  setState(() {});
                                  _handleFaceTextChanged(val);
                                },
                                onSubmitted: (_) {
                                  Navigator.of(context).pop();
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: () => Navigator.of(context).pop(),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.highlightColor,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.textPrimary,
                                  width: AppColors.borderThickness / 2,
                                ),
                              ),
                              child: const Icon(
                                Icons.check,
                                color: AppColors.textPrimary,
                                size: 28,
                              ),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            context.l10n.presets.editFaceTitle,
                            style: const TextStyle(
                              fontFamily: 'momo',
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          PlayerFaceIndicator(
                            face: _playerFace,
                            size: 100,
                            roundedSquare: true,
                            borderColor: AppColors.textPrimary,
                          ),
                          const SizedBox(height: 16),
                          Container(
                            decoration: BoxDecoration(
                              color: AppColors.textPrimary.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.textPrimary.withValues(alpha: 0.2),
                                width: 2,
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            child: TextField(
                              controller: _faceController,
                              maxLength: 3,
                              textAlign: TextAlign.center,
                              autofocus: true,
                              style: const TextStyle(
                                fontFamily: 'monomaniac',
                                fontSize: 32,
                                color: AppColors.textPrimary,
                              ),
                              decoration: const InputDecoration(
                                counterText: '',
                                border: InputBorder.none,
                                hintText: ':-)',
                                isDense: true,
                              ),
                              textInputAction: TextInputAction.done,
                              onChanged: (val) {
                                setState(() {});
                                _handleFaceTextChanged(val);
                              },
                              onSubmitted: (_) {
                                Navigator.of(context).pop();
                              },
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.highlightColor,
                                foregroundColor: AppColors.textPrimary,
                                elevation: 0,
                                side: const BorderSide(
                                  color: AppColors.textPrimary,
                                  width: AppColors.borderThickness / 2,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              onPressed: () => Navigator.of(context).pop(),
                              child: Text(
                                context.l10n.common.save,
                                style: const TextStyle(
                                  fontFamily: 'momo',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            );
          },
        );
      },
    );
  }

  void _exitTemporaryMode() {
    switch (_activeMode) {
      case ControllerScreenMode.mouse:
        _exitMouseMode();
        break;
      case ControllerScreenMode.edit:
      case ControllerScreenMode.face:
        setState(() => _activeMode = ControllerScreenMode.gameplay);
        break;
      case ControllerScreenMode.gameplay:
        break;
    }
  }

  void _toggleCenterPulse() {
    if (!mounted) {
      return;
    }
    setState(() => _centerPulseExpanded = !_centerPulseExpanded);
  }

  void _onStickChanged(Offset offset) {
    if (_lastSentLeftStick == offset) {
      return;
    }
    _lastSentLeftStick = offset;
    _send({'type': 'stick', 'x': offset.dx, 'y': offset.dy});
  }

  void _onStickRelease() {
    _lastSentLeftStick = Offset.zero;
    _send({'type': 'stick', 'x': 0, 'y': 0});
    Future.delayed(const Duration(milliseconds: 40), () {
      _send({'type': 'stick', 'x': 0, 'y': 0});
    });
    Future.delayed(const Duration(milliseconds: 100), () {
      _send({'type': 'stick', 'x': 0, 'y': 0});
    });
  }

  void _onRightStickChanged(Offset offset) {
    if (_lastSentRightStick == offset) {
      return;
    }
    _lastSentRightStick = offset;
    _send({'type': 'rstick', 'x': offset.dx, 'y': offset.dy});
  }

  void _onRightStickRelease() {
    _lastSentRightStick = Offset.zero;
    _send({'type': 'rstick', 'x': 0, 'y': 0});
    Future.delayed(const Duration(milliseconds: 40), () {
      _send({'type': 'rstick', 'x': 0, 'y': 0});
    });
    Future.delayed(const Duration(milliseconds: 100), () {
      _send({'type': 'rstick', 'x': 0, 'y': 0});
    });
  }

  void _onMouseStickChanged(Offset offset) {
    if (!_mouseModeOwned) {
      return;
    }
    _send({'type': 'mouse_move', 'x': offset.dx, 'y': offset.dy});
  }

  void _onMouseStickRelease() {
    if (!_mouseModeOwned) {
      return;
    }
    _send({'type': 'mouse_move', 'x': 0, 'y': 0});
  }

  void _sendButton(String xinputId, String state) {
    GamepadInputEngine.instance.updateButtonState(xinputId, state, tapHapticsEnabled);
  }

  void _sendMouseButton(String button, String state) {
    if (!_mouseModeOwned) {
      return;
    }
    _send({'type': 'mouse_${button}_$state'});
    if (state == 'down' && tapHapticsEnabled) {
      HapticsManager.instance.softTap();
    }
  }

  void _sendMouseScroll(double delta) {
    if (!_mouseModeOwned) {
      return;
    }
    _send({'type': 'mouse_scroll', 'delta': delta.clamp(-1.3, 1.3)});
  }

  void _toggleWindowVisibility() {
    if (!_mouseModeOwned) {
      return;
    }
    _send({'type': 'toggle_window_visibility'});
    if (tapHapticsEnabled) {
      HapticsManager.instance.softTap();
    }
  }

  void _showOptionsDialog() {
    final dialogContext = _controllerNavigatorKey.currentContext ?? context;

    showDialog(
      context: dialogContext,
      useRootNavigator: false,
      builder: (context) {
        return OptionsPopup(
          playerFace: _playerFace,
          onEnterMouseMode: () {
            unawaited(_enterMouseMode());
          },
          currentTheme: _currentTheme,
          onThemeChanged: _onThemeChanged,
          onDisconnectRequested: _resetConnection,
          onRumbleTest: _onRumbleTest,
        );
      },
    ).then((_) {
      _loadInitialPreferences();
    });
  }

  void _showControllerSnackBar(SnackBar snackBar) {
    final messenger = _controllerMessengerKey.currentState;
    if (messenger != null) {
      messenger
        ..clearSnackBars()
        ..showSnackBar(snackBar);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  void _setButtonVisibility(String buttonKey, bool visible) {
    setState(() {
      visibleButtons[buttonKey] = visible;
    });
    PreferencesService.instance.setButtonVisibility(visibleButtons);
  }

  void _setButtonOrder(List<String> order) {
    setState(() {
      _buttonOrder = List<String>.from(order);
    });
    PreferencesService.instance.setButtonOrder(_buttonOrder);
  }

  void _setButtonSizes(Map<String, int> sizes) {
    setState(() {
      _buttonSizes = sizes;
    });
    PreferencesService.instance.setButtonSizes(_buttonSizes);
  }

  void _toggleTapHaptics() {
    setState(() => tapHapticsEnabled = !tapHapticsEnabled);
    PreferencesService.instance.setTapHapticsEnabled(tapHapticsEnabled);
    if (tapHapticsEnabled) {
      HapticsManager.instance.softTap();
    }
  }

  Future<void> _loadInitialPreferences() async {
    try {
      final prefs = PreferencesService.instance;

      final themeIndex = await prefs.getSelectedTheme();
      _currentTheme = ColorTheme.values[themeIndex];
      AppColors.setTheme(_currentTheme);
      _playerFace = await prefs.getOrCreatePlayerFace();
      _faceController.text = _playerFace.faceText;
      playerColor = _playerFace.color;
      playerName = await prefs.getPlayerName();
      final modeIndex = await prefs.getMovementMode();
      _movementMode = MovementMode.values[modeIndex];
      _rightLayoutMode = await prefs.getRightLayoutMode();
      tapHapticsEnabled = await prefs.getTapHapticsEnabled();

      leftStickSensitivity = await prefs.getLeftStickSensitivity();
      rightStickSensitivity = await prefs.getRightStickSensitivity();
      swipeAccelerationIntensity = await prefs.getSwipeAccelerationIntensity();
      rightStickAntiDeadzone = await prefs.getRightStickAntiDeadzone();
      rightStickResponseCurve = await prefs.getRightStickResponseCurve();

      final savedVisibility = await prefs.getButtonVisibility();
      if (savedVisibility != null) {
        visibleButtons.addAll(
          ControllerBranding.normalizeVisibility(savedVisibility),
        );
      }
      final savedOrder = await prefs.getButtonOrder();
      if (savedOrder != null && savedOrder.isNotEmpty) {
        _buttonOrder = ControllerBranding.normalizeCanonicalOrder(savedOrder);
      }
      final savedSizes = await prefs.getButtonSizes();
      if (savedSizes != null) {
        _buttonSizes = Map<String, int>.from(savedSizes);
      }
    } catch (_) {
      AppColors.setTheme(ColorTheme.blue);
    }

    if (mounted) {
      setState(() {});
    }
  }

  void _onRumbleTest() {
    try {
      HapticsManager.instance.connectionPulse();
    } catch (_) {}
    _send({'type': 'rumble_test'});
  }

  void _onThemeChanged(ColorTheme theme) {
    setState(() => _currentTheme = theme);
    PreferencesService.instance.setSelectedTheme(theme.index);
  }

  Widget _buildCurrentView() {
    switch (_activeMode) {
      case ControllerScreenMode.mouse:
        return ControllerMouseView(
          mouseModeOwned: _mouseModeOwned,
          mouseModeOwnerName: _mouseModeOwnerName,
          onPointerMoved: _onMouseStickChanged,
          onPointerReleased: _onMouseStickRelease,
          onMouseButtonStateChanged: _sendMouseButton,
          onScroll: _sendMouseScroll,
          onToggleWindowVisibility: _toggleWindowVisibility,
          onExit: _exitTemporaryMode,
          onQuickAction: _sendQuickAction,
          totalSlots: totalSlots,
          playerIndex: playerIndex,
          isConnected: _connectionState == ControllerConnectionState.connected,
          playerFace: _playerFace,
          centerPulseExpanded: _centerPulseExpanded,
          onPulseCycleEnd: _toggleCenterPulse,
        );
      case ControllerScreenMode.edit:
        return ControllerDefaultView(
          brandingMode: _brandingMode,
          movementMode: _movementMode,
          playerName: playerName,
          onNameChanged: _updatePlayerName,
          onRequestRandomName: _requestRandomName,
          onStickChanged: _onStickChanged,
          onStickRelease: _onStickRelease,
          onButtonStateChanged: _sendButton,
          onOpenOptions: _showOptionsDialog,
          onOpenFaceEditor: _enterFaceMode,
          onOpenEditControls: _enterEditMode,
          onRetryConnection: _retryConnection,
          onOpenQrScanner: kIsWeb ? null : _openQRScanner,
          onMovementModeChanged: (value) {
            setState(() => _movementMode = value);
            PreferencesService.instance.setMovementMode(value.index);
          },
          connectionState: _connectionState,
          status: status,
          playerFace: _playerFace,
          playerColor: playerColor,
          playerIndex: playerIndex,
          totalSlots: totalSlots,
          visibleButtons: visibleButtons,
          buttonOrder: _buttonOrder,
          hasVacantSlot: _hasVacantSlot,
          onJoinGame: () {
            _send({'type': 'request_slot'});
          },
          onRightStickChanged: _onRightStickChanged,
          onRightStickRelease: _onRightStickRelease,
          buttonSizes: _buttonSizes,
          rightLayoutMode: _rightLayoutMode,
          leftStickSensitivity: leftStickSensitivity,
          rightStickSensitivity: rightStickSensitivity,
          swipeAccelerationIntensity: swipeAccelerationIntensity,
          rightStickAntiDeadzone: rightStickAntiDeadzone,
          rightStickResponseCurve: rightStickResponseCurve,
          isPanelExpanded: true,
          panelMode: ControllerPanelMode.edit,
          onPanelExpandedChanged: (expanded) {
            setState(() {
              _isPanelExpanded = expanded;
            });
          },
          onPanelModeChanged: (mode) {
            setState(() {
              _panelMode = mode;
            });
          },
          editableButtons: _editableButtons,
          onSetButtonVisibility: _setButtonVisibility,
          onButtonOrderChanged: _setButtonOrder,
          onButtonSizesChanged: _setButtonSizes,
          onRightLayoutModeChanged: (mode) {
            setState(() {
              _rightLayoutMode = mode;
            });
            PreferencesService.instance.setRightLayoutMode(mode);
          },
          tapHapticsEnabled: tapHapticsEnabled,
          onTapHapticsToggled: _toggleTapHaptics,
          pulseOptionsButton: _pulseOptionsButton,
          onResetOptionsPulse: () => setState(() => _pulseOptionsButton = false),
        );
      case ControllerScreenMode.face:
        return ControllerFaceView(
          playerFace: _playerFace,
          onEditFaceText: _showFaceTextEditDialog,
          onColorSelected: (color) {
            _updatePlayerFace(
              _playerFace.copyWith(color: color, clearPreset: true),
            );
          },
          onRotationSelected: (rotation) {
            _updatePlayerFace(
              _playerFace.copyWith(rotation: rotation, clearPreset: true),
            );
          },
          onPresetSelected: _handleFacePresetSelected,
          onExit: _exitTemporaryMode,
          totalSlots: totalSlots,
          playerIndex: playerIndex,
          isConnected: _connectionState == ControllerConnectionState.connected,
          centerPulseExpanded: _centerPulseExpanded,
          onPulseCycleEnd: _toggleCenterPulse,
        );
      case ControllerScreenMode.gameplay:
        return ControllerDefaultView(
          brandingMode: _brandingMode,
          movementMode: _movementMode,
          playerName: playerName,
          onNameChanged: _updatePlayerName,
          onRequestRandomName: _requestRandomName,
          onStickChanged: _onStickChanged,
          onStickRelease: _onStickRelease,
          onButtonStateChanged: _sendButton,
          onOpenOptions: _showOptionsDialog,
          onOpenFaceEditor: _enterFaceMode,
          onOpenEditControls: _enterEditMode,
          onRetryConnection: _retryConnection,
          onOpenQrScanner: kIsWeb ? null : _openQRScanner,
          onMovementModeChanged: (value) {
            setState(() => _movementMode = value);
            PreferencesService.instance.setMovementMode(value.index);
          },
          connectionState: _connectionState,
          status: status,
          playerFace: _playerFace,
          playerColor: playerColor,
          playerIndex: playerIndex,
          totalSlots: totalSlots,
          visibleButtons: visibleButtons,
          buttonOrder: _buttonOrder,
          hasVacantSlot: _hasVacantSlot,
          onJoinGame: () {
            _send({'type': 'request_slot'});
          },
          onRightStickChanged: _onRightStickChanged,
          onRightStickRelease: _onRightStickRelease,
          buttonSizes: _buttonSizes,
          rightLayoutMode: _rightLayoutMode,
          leftStickSensitivity: leftStickSensitivity,
          rightStickSensitivity: rightStickSensitivity,
          swipeAccelerationIntensity: swipeAccelerationIntensity,
          rightStickAntiDeadzone: rightStickAntiDeadzone,
          rightStickResponseCurve: rightStickResponseCurve,
          isPanelExpanded: _isPanelExpanded,
          panelMode: _panelMode,
          onPanelExpandedChanged: (expanded) {
            setState(() {
              _isPanelExpanded = expanded;
            });
          },
          onPanelModeChanged: (mode) {
            setState(() {
              _panelMode = mode;
            });
          },
          editableButtons: _editableButtons,
          onSetButtonVisibility: _setButtonVisibility,
          onButtonOrderChanged: _setButtonOrder,
          onButtonSizesChanged: _setButtonSizes,
          onRightLayoutModeChanged: (mode) {
            setState(() {
              _rightLayoutMode = mode;
            });
            PreferencesService.instance.setRightLayoutMode(mode);
          },
          tapHapticsEnabled: tapHapticsEnabled,
          onTapHapticsToggled: _toggleTapHaptics,
          pulseOptionsButton: _pulseOptionsButton,
          onResetOptionsPulse: () => setState(() => _pulseOptionsButton = false),
        );
    }
  }

  Widget _buildControllerSurface() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 240),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: KeyedSubtree(
        key: ValueKey(_activeMode.name),
        child: _buildCurrentView(),
      ),
    );
  }

  Widget _buildControllerCanvas() {
    final minimumPadding = kIsWeb ? 8.0 : 12.0;

    return ScaffoldMessenger(
      key: _controllerMessengerKey,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(minimumPadding),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final height = constraints.maxHeight;
                final width = constraints.maxWidth;
                final targetHeight = 380.0;

                if (height < targetHeight && height > 0) {
                  final scale = height / targetHeight;
                  final targetWidth = width / scale;

                  return FittedBox(
                    fit: BoxFit.contain,
                    child: SizedBox(
                      width: targetWidth,
                      height: targetHeight,
                      child: Stack(
                        children: [
                          _buildControllerSurface(),
                          if (_connectionState ==
                              ControllerConnectionState.multipleHostsFound)
                            MultipleHostsOverlay(
                              hosts: _discoveredHosts,
                              onHostSelected: (host) {
                                _autoConnectEnabled = true;
                                _connectToHost(host);
                              },
                              onOpenQrScanner: kIsWeb ? null : _openQRScanner,
                            ),
                        ],
                      ),
                    ),
                  );
                }

                return Stack(
                  children: [
                    _buildControllerSurface(),
                    if (_connectionState ==
                        ControllerConnectionState.multipleHostsFound)
                      MultipleHostsOverlay(
                        hosts: _discoveredHosts,
                        onHostSelected: (host) {
                          _autoConnectEnabled = true;
                          _connectToHost(host);
                        },
                        onOpenQrScanner: kIsWeb ? null : _openQRScanner,
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControllerNavigator() {
    return Navigator(
      key: _controllerNavigatorKey,
      initialRoute: '/',
      onGenerateRoute: (settings) {
        return MaterialPageRoute(
          settings: settings,
          builder: (context) => _buildControllerCanvas(),
        );
      },
    );
  }

  Widget _buildResponsiveControllerFrame() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final isPortrait = size.height > size.width;

        if (!kIsWeb || !isPortrait) {
          return _buildControllerNavigator();
        }

        return _RotatedLandscapeViewport(
          mediaQuery: MediaQuery.of(context),
          viewportSize: size,
          child: _buildControllerNavigator(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return PopScope(
      canPop: _activeMode == ControllerScreenMode.gameplay && !_isPanelExpanded,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_isPanelExpanded) {
          setState(() {
            _isPanelExpanded = false;
          });
        } else {
          _exitTemporaryMode();
        }
      },
      child: Scaffold(
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
          child: Stack(children: [_buildResponsiveControllerFrame()]),
        ),
      ),
    );
  }
}

class _RotatedLandscapeViewport extends StatelessWidget {
  const _RotatedLandscapeViewport({
    required this.mediaQuery,
    required this.viewportSize,
    required this.child,
  });

  final MediaQueryData mediaQuery;
  final Size viewportSize;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final landscapeWidth = viewportSize.height;
    final landscapeHeight = viewportSize.width;
    final landscapeMediaQuery = mediaQuery.copyWith(
      size: Size(landscapeWidth, landscapeHeight),
      padding: EdgeInsets.zero,
      viewPadding: EdgeInsets.zero,
      viewInsets: _rotateInsetsClockwise(mediaQuery.viewInsets),
      systemGestureInsets: EdgeInsets.zero,
    );

    return SizedBox(
      width: viewportSize.width,
      height: viewportSize.height,
      child: ClipRect(
        child: RotatedBox(
          quarterTurns: 1,
          child: MediaQuery(
            data: landscapeMediaQuery,
            child: SizedBox.expand(child: child),
          ),
        ),
      ),
    );
  }

  EdgeInsets _rotateInsetsClockwise(EdgeInsets insets) {
    return EdgeInsets.fromLTRB(
      insets.bottom,
      insets.left,
      insets.top,
      insets.right,
    );
  }
}
