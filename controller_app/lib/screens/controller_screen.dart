import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/controller_layout_preset.dart';
import '../models/player_face.dart';
import '../services/controller_connection_manager.dart';
import '../services/haptics_manager.dart';
import '../services/network_discovery_service.dart';
import '../services/preferences_service.dart';
import '../services/websocket_service.dart';
import '../theme/app_colors.dart';
import '../widgets/options_popup.dart';
import 'controller_screen/controller_default_view.dart';
import 'controller_screen/controller_edit_view.dart';
import 'controller_screen/controller_face_view.dart';
import 'controller_screen/controller_mouse_view.dart';
import 'controller_screen/controller_screen_types.dart';
import 'controller_screen/controller_screen_widgets.dart';
import 'qr_scanner_screen.dart';

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

  static const List<String> _defaultButtonOrder = [
    'btnY',
    'btnB',
    'btnX',
    'btnA',
    'btnRB',
    'btnRT',
    'btnLB',
    'btnLT',
    'btnRS',
    'btnLS',
  ];

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
  List<String> _buttonOrder = List<String>.from(_defaultButtonOrder);

  WebSocketService? ws;
  final GlobalKey<NavigatorState> _controllerNavigatorKey =
      GlobalKey<NavigatorState>();
  final GlobalKey<ScaffoldMessengerState> _controllerMessengerKey =
      GlobalKey<ScaffoldMessengerState>();
  late final NetworkDiscoveryService _discoveryService;
  StreamSubscription? _discoverySubscription;
  late final TextEditingController _faceController;
  late final FocusNode _faceFocusNode;

  ControllerConnectionState _connectionState =
      ControllerConnectionState.searching;
  ControllerScreenMode _activeMode = ControllerScreenMode.gameplay;
  List<DiscoveredHost> _discoveredHosts = [];

  String status = 'Conectando...';
  int? playerIndex;
  MovementMode _movementMode = MovementMode.fixedJoystick;
  bool _mouseModeOwned = false;
  String? _mouseModeOwnerName;
  bool _centerPulseExpanded = false;
  bool _autoConnectEnabled = true;
  bool _listenerAttached = false;
  bool tapHapticsEnabled = true;
  int totalSlots = 4;
  Color? playerColor;
  ColorTheme _currentTheme = ColorTheme.blue;
  PlayerFaceData _playerFace = PlayerFaceData.random();

  bool get _isTemporaryModeActive =>
      _activeMode != ControllerScreenMode.gameplay;

  bool get _isMouseModeVisible => _activeMode == ControllerScreenMode.mouse;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _faceController = TextEditingController(text: _playerFace.faceText);
    _faceFocusNode = FocusNode()..addListener(_handleFaceFocusChanged);
    _discoveryService = NetworkDiscoveryService();

    WidgetsBinding.instance.addObserver(this);
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
    _faceFocusNode
      ..removeListener(_handleFaceFocusChanged)
      ..dispose();
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

  void _handleFaceFocusChanged() {
    if (mounted) {
      setState(() {});
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
      }
    });
  }

  Future<void> _connectWebSocket() async {
    if (ws != null || _listenerAttached) {
      return;
    }

    setState(() => _connectionState = ControllerConnectionState.searching);

    try {
      _listenerAttached = true;
      ws = await ControllerConnectionManager.instance.getConnection();

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
      if (_isMouseModeVisible) {
        _send({'type': 'set_mouse_mode', 'active': true});
      }
    } catch (_) {
      _handleDisconnect();
    }
  }

  void _handleDisconnect() {
    if (!mounted) {
      return;
    }

    ControllerConnectionManager.instance.disconnect();
    _listenerAttached = false;
    ws = null;

    setState(() {
      _connectionState = ControllerConnectionState.disconnected;
      _activeMode = ControllerScreenMode.gameplay;
      _mouseModeOwned = false;
      _mouseModeOwnerName = null;
    });

    _clearPlayerSlot();
    _autoConnectEnabled = false;
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
          onConnected: () {
            _autoConnectEnabled = true;
            _connectWebSocket();
          },
        ),
      ),
    );
  }

  Future<void> _resetConnection() async {
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
      status = 'Conectado';

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
          _handleServerError(data);
          break;
        case 'unassigned':
          _clearPlayerSlot();
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

    final id = 'btn${(data['btn'] as String).toUpperCase()}';
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
    final nextVisibility = Map<String, bool>.from(visibleButtons);
    nextVisibility.addAll(preset.visibleButtons);

    setState(() {
      _movementMode = preset.movementMode;
      visibleButtons
        ..clear()
        ..addAll(nextVisibility);
      if (preset.buttonOrder.isNotEmpty) {
        _buttonOrder = List<String>.from(preset.buttonOrder);
      }
    });

    PreferencesService.instance.setMovementMode(_movementMode.index);
    PreferencesService.instance.setButtonVisibility(visibleButtons);
    PreferencesService.instance.setButtonOrder(_buttonOrder);
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
      _activeMode = ControllerScreenMode.edit;
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
    _send({'type': 'stick', 'x': offset.dx, 'y': offset.dy});
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
    if (state == 'down' && tapHapticsEnabled) {
      HapticsManager.instance.softTap();
    }
    _send({'type': 'button', 'id': xinputId, 'state': state});
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
          movementMode: _movementMode,
          onMovementModeChanged: (value) {
            setState(() => _movementMode = value);
            PreferencesService.instance.setMovementMode(value.index);
          },
          onEnterMouseMode: () {
            unawaited(_enterMouseMode());
          },
          onEnterEditMode: _enterEditMode,
          onEnterFaceMode: _enterFaceMode,
          currentTheme: _currentTheme,
          onThemeChanged: _onThemeChanged,
          onDisconnectRequested: _resetConnection,
          onRumbleTest: _onRumbleTest,
        );
      },
    );
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
      final modeIndex = await prefs.getMovementMode();
      _movementMode = MovementMode.values[modeIndex];
      tapHapticsEnabled = await prefs.getTapHapticsEnabled();

      final savedVisibility = await prefs.getButtonVisibility();
      if (savedVisibility != null) {
        visibleButtons.addAll(savedVisibility);
      }
      final savedOrder = await prefs.getButtonOrder();
      if (savedOrder != null && savedOrder.isNotEmpty) {
        _buttonOrder = List<String>.from(savedOrder);
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
          status: status,
          playerFace: _playerFace,
          centerPulseExpanded: _centerPulseExpanded,
          onPulseCycleEnd: _toggleCenterPulse,
        );
      case ControllerScreenMode.edit:
        return ControllerEditView(
          tapHapticsEnabled: tapHapticsEnabled,
          onTapHapticsToggled: _toggleTapHaptics,
          editableButtons: _editableButtons,
          visibleButtons: visibleButtons,
          buttonOrder: _buttonOrder,
          onSetButtonVisibility: _setButtonVisibility,
          onButtonOrderChanged: _setButtonOrder,
          onGameButtonStateChanged: _sendButton,
          onExit: _exitTemporaryMode,
          totalSlots: totalSlots,
          playerIndex: playerIndex,
          status: status,
          playerFace: _playerFace,
          centerPulseExpanded: _centerPulseExpanded,
          onPulseCycleEnd: _toggleCenterPulse,
        );
      case ControllerScreenMode.face:
        return ControllerFaceView(
          playerFace: _playerFace,
          faceController: _faceController,
          faceFocusNode: _faceFocusNode,
          onFaceChanged: _handleFaceTextChanged,
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
          status: status,
          centerPulseExpanded: _centerPulseExpanded,
          onPulseCycleEnd: _toggleCenterPulse,
        );
      case ControllerScreenMode.gameplay:
        return ControllerDefaultView(
          movementMode: _movementMode,
          onStickChanged: _onStickChanged,
          onStickRelease: _onStickRelease,
          onButtonStateChanged: _sendButton,
          onOpenOptions: _showOptionsDialog,
          onRetryConnection: _retryConnection,
          onOpenQrScanner: kIsWeb ? null : _openQRScanner,
          connectionState: _connectionState,
          status: status,
          playerFace: _playerFace,
          playerColor: playerColor,
          playerIndex: playerIndex,
          totalSlots: totalSlots,
          visibleButtons: visibleButtons,
          buttonOrder: _buttonOrder,
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
    return ScaffoldMessenger(
      key: _controllerMessengerKey,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
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

  Widget _buildControllerNavigator() {
    return Navigator(
      key: _controllerNavigatorKey,
      onDidRemovePage: (page) {},
      pages: [
        MaterialPage<void>(
          key: const ValueKey('controller-canvas'),
          child: _buildControllerCanvas(),
        ),
      ],
    );
  }

  Widget _buildResponsiveControllerFrame() {
    final minimumPadding = kIsWeb ? 8.0 : 12.0;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(minimumPadding),
        child: LayoutBuilder(
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
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

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
          children: [_buildResponsiveControllerFrame()],
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
