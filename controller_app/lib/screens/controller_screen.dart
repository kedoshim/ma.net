import 'dart:convert';

import 'package:flutter/material.dart';
import '../services/websocket_service.dart';
import '../widgets/joystick.dart';
import '../widgets/action_buttons.dart';
import '../widgets/control_button.dart';
import '../widgets/options_popup.dart';
import '../theme/app_colors.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ControllerScreen extends StatefulWidget {
  const ControllerScreen({super.key});

  @override
  State<ControllerScreen> createState() => _ControllerScreenState();
}

class _ControllerScreenState extends State<ControllerScreen> {
  WebSocketService? ws;
  String status = 'Conectando...';
  int playerIndex = 0;
  bool dpadMode = false;
  bool editMode = false;
  Color? playerColor;

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

  Future<void> _connectWebSocket() async {
    ws = await WebSocketService.connect('192.168.100.80');

    ws!.channel.stream.listen(
      _handleWebSocketMessage,
      onDone: () {
        if (mounted) {
          setState(() => status = 'Desconectado');
        }
      },
      onError: (_) {
        if (mounted) {
          setState(() => status = 'Erro');
        }
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _loadInitialTheme();
    _connectWebSocket();
  }

  @override
  void dispose() {
    ws?.dispose();
    super.dispose();
  }

  void _updatePlayerSlot(dynamic slotValue, {String? colorHex}) {
    setState(() {
      playerIndex = (slotValue as num).toInt() + 1;
      status = 'Conectado';

      if (colorHex != null) {
        playerColor = colorFromHex(colorHex);
      }
    });
  }

  void _send(Map<String, dynamic> obj) {
    ws?.send(obj);
  }

  void _handleWebSocketMessage(dynamic message) {
    if (message is String) {
      try {
        final dynamic data = jsonDecode(message);
        if (data is Map<String, dynamic>) {
          if (data['type'] == 'assigned' && data['slot'] != null) {
            _updatePlayerSlot(
              data['slot'],
              colorHex: data['color'],
            );
          }
          if (data['type'] == 'slot_changed' && data['slot'] != null) {
            _updatePlayerSlot(
              data['slot'],
              colorHex: data['color'],
            );
          }
          if (data['type'] == 'toggle_btn' && data['btn'] != null) {
            final id = 'btn${(data['btn'] as String).toUpperCase()}';
            final visible = data['visible'] != false;
            setState(() {
              visibleButtons[id] = visible;
            });
          }
        }
      } catch (_) {
        // ignore errors
      }
    }
  }

  Widget _buildPlayerIndicator() {
    final selectedIndex = playerIndex - 1;
    return LayoutBuilder(
      builder: (context, constraints) {
        final squareSize = ((constraints.maxWidth - 32) / 4).clamp(12.0, 22.0);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildIndicatorRow(selectedIndex, 0, squareSize),
            const SizedBox(height: 6),
            _buildIndicatorRow(selectedIndex, 4, squareSize),
          ],
        );
      },
    );
  }

  Widget _buildIndicatorRow(int selectedIndex, int offset, double squareSize) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (index) {
        final position = offset + index;
        final isActive = selectedIndex == position;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: SizedBox(
            width: squareSize,
            height: squareSize,
            child: Container(
              decoration: BoxDecoration(
                color: (isActive && status == 'Conectado') ? AppColors.textPrimary : Colors.transparent,
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
          onDpadModeChanged: (value) => setState(() => dpadMode = value),
          buttonVisibility: visibleButtons,
          onButtonVisibilityChanged: _toggleButtonVisibility,
          editMode: editMode,
          onEditModeChanged: (value) => setState(() => editMode = value),
          onThemeChanged: _onThemeChanged,
        );
      },
    );
  }

  void _toggleButtonVisibility(String buttonKey) {
    setState(() {
      visibleButtons[buttonKey] = !(visibleButtons[buttonKey] ?? true);
    });
  }

  Future<void> _loadInitialTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeIndex = prefs.getInt('selectedTheme') ?? 0;
      final theme = ColorTheme.values[themeIndex];
      AppColors.setTheme(theme);
      setState(() {});
    } catch (e) {
      AppColors.setTheme(ColorTheme.blue);
    }
  }

  void _onThemeChanged(ColorTheme theme) {
    setState(() {});
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: AppColors.screenBackground,
        child: SafeArea(
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
                              children: [
                                if (playerColor != null && status == 'Conectado')
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
                                    fontWeight: FontWeight.normal,
                                    color: AppColors.textPrimary,
                                    fontFamily: 'pico',
                                  ),
                                ),
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
      ),
    );
  }
}
