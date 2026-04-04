import 'dart:convert';

import 'package:flutter/material.dart';
import '../services/websocket_service.dart';
import '../widgets/joystick.dart';
import '../widgets/action_buttons.dart';
import '../widgets/control_button.dart';
import '../widgets/options_popup.dart';

class ControllerScreen extends StatefulWidget {
  const ControllerScreen({super.key});

  @override
  State<ControllerScreen> createState() => _ControllerScreenState();
}

class _ControllerScreenState extends State<ControllerScreen> {
  late WebSocketService ws;
  String status = 'Conectando...';
  int playerIndex = 0;
  bool dpadMode = false;
  bool editMode = false;

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

  @override
  void initState() {
    super.initState();
    ws = WebSocketService('192.168.100.80');
    ws.channel.stream.listen(
      _handleWebSocketMessage,
      onDone: () => setState(() => status = 'Desconectado'),
      onError: (error) => setState(() => status = 'Error'),
    );
  }

  @override
  void dispose() {
    ws.dispose();
    super.dispose();
  }

  void _send(Map<String, dynamic> obj) {
    ws.send(obj);
  }

  void _handleWebSocketMessage(dynamic message) {
    if (message is String) {
      try {
        final dynamic data = jsonDecode(message);
        if (data is Map<String, dynamic>) {
          if (data['type'] == 'assigned' && data['slot'] != null) {
            setState(() {
              playerIndex = (data['slot'] as num).toInt() + 1;
              status = 'Conectado';
            });
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildIndicatorRow(selectedIndex, 0),
        const SizedBox(height: 6),
        _buildIndicatorRow(selectedIndex, 4),
      ],
    );
  }

  Widget _buildIndicatorRow(int selectedIndex, int offset) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (index) {
        final position = offset + index;
        final isActive = selectedIndex == position;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: isActive
                  ? const Color.fromRGBO(34, 34, 34, 1)
                  : Colors.transparent,
              border: Border.all(
                color: const Color.fromRGBO(34, 34, 34, 1),
                width: 2,
              ),
              borderRadius: BorderRadius.circular(8),
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
        );
      },
    );
  }

  void _toggleButtonVisibility(String buttonKey) {
    setState(() {
      visibleButtons[buttonKey] = !(visibleButtons[buttonKey] ?? true);
    });
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
              const SizedBox(width: 24),
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ControlButton(
          label: '',
          onStateChange: (state) => _sendButton('SELECT', state),
        ),
        const SizedBox(height: 12),
        ControlButton(
          label: '',
          onStateChange: (state) => _sendButton('START', state),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: const Color(0xFFF3E5C8),
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
                          color: Color.fromRGBO(34, 34, 34, 1),
                          fontFamily: 'pico',
                        ),
                      ),
                      const SizedBox(height: 10),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            status,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.normal,
                              color: Color.fromRGBO(34, 34, 34, 1),
                              fontFamily: 'pico',
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildPlayerIndicator(),
                        ],
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
