import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../models/controller_branding.dart';
import '../../models/player_face.dart';
import '../../widgets/player_face_indicator.dart';
import '../../theme/app_colors.dart';
import '../../widgets/action_buttons.dart';
import '../../widgets/control_button.dart' hide ButtonStateCallback;
import '../../services/haptics_manager.dart';
import '../../widgets/joystick.dart';
import '../../services/preferences_service.dart';
import 'controller_screen_types.dart';
import 'controller_screen_widgets.dart';

typedef ControllerButtonStateCallback = void Function(String id, String state);

class ControllerDefaultView extends StatefulWidget {
  const ControllerDefaultView({
    super.key,
    required this.brandingMode,
    required this.movementMode,
    required this.onMovementModeChanged,
    required this.onStickChanged,
    required this.onStickRelease,
    required this.onButtonStateChanged,
    required this.onOpenOptions,
    required this.onOpenFaceEditor,
    required this.onOpenEditControls,
    required this.onRetryConnection,
    required this.onOpenQrScanner,
    required this.connectionState,
    required this.status,
    required this.playerFace,
    required this.playerColor,
    required this.playerIndex,
    required this.totalSlots,
    required this.visibleButtons,
    required this.buttonOrder,
    required this.hasVacantSlot,
    required this.onJoinGame,
    required this.playerName,
    required this.onNameChanged,
  });

  final String? playerName;
  final ValueChanged<String> onNameChanged;

  final ControllerBrandingMode brandingMode;
  final MovementMode movementMode;
  final ValueChanged<MovementMode> onMovementModeChanged;
  final ValueChanged<Offset> onStickChanged;
  final VoidCallback onStickRelease;
  final ControllerButtonStateCallback onButtonStateChanged;
  final VoidCallback onOpenOptions;
  final VoidCallback onOpenFaceEditor;
  final VoidCallback onOpenEditControls;
  final VoidCallback onRetryConnection;
  final VoidCallback? onOpenQrScanner;
  final ControllerConnectionState connectionState;
  final String status;
  final PlayerFaceData playerFace;
  final Color? playerColor;
  final int? playerIndex;
  final int totalSlots;
  final Map<String, bool> visibleButtons;
  final List<String> buttonOrder;
  final bool hasVacantSlot;
  final VoidCallback? onJoinGame;

  @override
  State<ControllerDefaultView> createState() => _ControllerDefaultViewState();
}

class _ControllerDefaultViewState extends State<ControllerDefaultView> {
  void _toggleMovementMode() {
    final nextIndex =
        (widget.movementMode.index + 1) % MovementMode.values.length;
    final nextMode = MovementMode.values[nextIndex];
    widget.onMovementModeChanged(nextMode);
  }

  IconData _getNextModeIcon(MovementMode mode) {
    switch (mode) {
      case MovementMode.dpad:
        return Icons.control_camera_rounded;
      case MovementMode.fixedJoystick:
        return Icons.touch_app_rounded;
      case MovementMode.floatingJoystick:
        return Icons.gamepad_outlined;
    }
  }

  String _getNextModeLabel(MovementMode mode) {
    switch (mode) {
      case MovementMode.dpad:
        return 'Mudar para Joystick Fixo';
      case MovementMode.fixedJoystick:
        return 'Mudar para Joystick Flutuante';
      case MovementMode.floatingJoystick:
        return 'Mudar para D-Pad';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          //Left side (movement controls)
          Expanded(
            flex: 12,
            child: widget.movementMode == MovementMode.dpad
                ? _ControllerDpad(
                    onButtonStateChanged: widget.onButtonStateChanged,
                  )
                : widget.movementMode == MovementMode.floatingJoystick
                ? AdaptiveJoystick(
                    onChanged: (x, y) => widget.onStickChanged(Offset(x, y)),
                    onReleased: widget.onStickRelease,
                  )
                : Joystick(
                    size: 220,
                    onChanged: (x, y) => widget.onStickChanged(Offset(x, y)),
                    onReleased: widget.onStickRelease,
                  ),
          ),
          //Center (player info, status, and central buttons)
          Expanded(
            flex: 7,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 0),
                        child: Container(
                          alignment: Alignment.topCenter,
                          child: SizedBox(
                            width: 32,
                            height: 48,
                            child: Material(
                              color: AppColors.backgroundColor.withValues(
                                alpha: 0.05,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: BorderSide(
                                  color: Colors.transparent,
                                  width: AppColors.borderThickness,
                                ),
                              ),
                              child: IconButton(
                                icon: Icon(
                                  _getNextModeIcon(widget.movementMode),
                                  size: 18,
                                ),
                                splashRadius: 10,
                                onPressed: _toggleMovementMode,
                                tooltip: _getNextModeLabel(widget.movementMode),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'ma•net',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.normal,
                              fontFamily: 'momo',
                            ),
                          ),
                          const SizedBox(height: 10),
                          InkWell(
                            onTap: widget.onOpenFaceEditor,
                            borderRadius: BorderRadius.circular(24),
                            child: PlayerFaceIndicator(
                              face: widget.playerFace,
                              size: 64,
                              roundedSquare: true,
                              borderColor: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          _PlayerNameWidget(
                            name: widget.playerName,
                            onNameChanged: widget.onNameChanged,
                          ),
                        ],
                      ),
                      const SizedBox(width: 14),
                      Padding(
                        padding: const EdgeInsets.only(top: 0, right: 4),
                        child: Container(
                          alignment: Alignment.topCenter,
                          child: SizedBox(
                            width: 32,
                            height: 48,
                            child: Material(
                              color: AppColors.backgroundColor.withValues(
                                alpha: 0.05,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: BorderSide(
                                  color: Colors.transparent,
                                  width: AppColors.borderThickness,
                                ),
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.edit, size: 15),
                                splashRadius: 10,
                                onPressed: widget.onOpenEditControls,
                                tooltip: 'Editar controles',
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ControllerCenterStatus(
                        connectionState: widget.connectionState,
                        status: widget.status,
                        playerFace: widget.playerFace,
                        playerColor: null,
                      ),
                      const SizedBox(height: 8),
                      if (widget.connectionState ==
                          ControllerConnectionState.disconnected)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            InkWell(
                              onTap: widget.onRetryConnection,
                              child: const Icon(
                                Icons.refresh,
                                color: AppColors.textPrimary,
                                size: 24,
                              ),
                            ),
                            if (!kIsWeb && widget.onOpenQrScanner != null) ...[
                              const SizedBox(width: 8),
                              InkWell(
                                onTap: widget.onOpenQrScanner,
                                child: const Icon(
                                  Icons.qr_code_scanner,
                                  color: AppColors.textPrimary,
                                  size: 24,
                                ),
                              ),
                            ],
                          ],
                        )
                      else
                        ControllerPlayerIndicator(
                          totalSlots: widget.totalSlots,
                          selectedPlayerIndex: widget.playerIndex,
                          status: widget.status,
                          playerFace: widget.playerFace,
                          hasVacantSlot: widget.hasVacantSlot,
                          onJoinGame: widget.onJoinGame,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                IconButton(
                  icon: const Icon(Icons.more_horiz, size: 32),
                  onPressed: widget.onOpenOptions,
                  tooltip: 'Opções',
                ),
                _CenterAction(
                  onButtonStateChanged: widget.onButtonStateChanged,
                ),
              ],
            ),
          ),
          //Edit button
          //Right side (movement controls)
          Expanded(
            flex: 12,
            child: ActionButtons(
              brandingMode: widget.brandingMode,
              visibleButtons: widget.visibleButtons,
              buttonOrder: widget.buttonOrder,
              onButtonStateChanged: widget.onButtonStateChanged,
              editMode: false,
            ),
          ),
        ],
      ),
    );
  }
}

class _ControllerDpad extends StatefulWidget {
  const _ControllerDpad({required this.onButtonStateChanged});

  final ControllerButtonStateCallback onButtonStateChanged;

  @override
  State<_ControllerDpad> createState() => _ControllerDpadState();
}

class _ControllerDpadState extends State<_ControllerDpad> {
  List<String> _activeDirections = [];

  void _updateDirection(Offset localPosition, Size size) {
    final center = Offset(144.0, size.height - 137.0);
    final delta = localPosition - center;

    if (delta.distance < 30) {
      _releaseDirection();
      return;
    }

    String newDir;
    if (delta.dx.abs() > delta.dy.abs()) {
      newDir = delta.dx > 0 ? 'RIGHT' : 'LEFT';
    } else {
      newDir = delta.dy > 0 ? 'DOWN' : 'UP';
    }

    if (!_activeDirections.contains(newDir) || _activeDirections.length > 1) {
      _releaseDirection();

      _activeDirections = [newDir];
      // Trigger vibration strictly when a new cardinal direction is established
      HapticsManager.instance.softTap();

      widget.onButtonStateChanged(newDir, 'down');
      setState(() {});
    }
  }

  void _releaseDirection() {
    for (var d in _activeDirections) {
      widget.onButtonStateChanged(d, 'up');
    }
    if (_activeDirections.isNotEmpty) {
      setState(() {
        _activeDirections = [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanDown: (details) {
        final RenderBox box = context.findRenderObject() as RenderBox;
        _updateDirection(details.localPosition, box.size);
      },
      onPanUpdate: (details) {
        final RenderBox box = context.findRenderObject() as RenderBox;
        _updateDirection(details.localPosition, box.size);
      },
      onPanEnd: (_) => _releaseDirection(),
      onPanCancel: () => _releaseDirection(),
      child: Container(
        width: double.infinity,
        height: double.infinity,
        alignment: Alignment.bottomLeft,
        padding: const EdgeInsets.only(left: 24.0, bottom: 8.0),
        child: SizedBox(
          width: 240,
          height: 258,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _DPadButton(
                label: '',
                isActive: _activeDirections.contains('UP'),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _DPadButton(
                    label: '',
                    isActive: _activeDirections.contains('LEFT'),
                  ),
                  _DPadButton(
                    label: '',
                    isActive: _activeDirections.contains('RIGHT'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _DPadButton(
                label: '',
                isActive: _activeDirections.contains('DOWN'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DPadButton extends StatefulWidget {
  final String label;
  final bool isActive;

  const _DPadButton({required this.label, required this.isActive});

  @override
  State<_DPadButton> createState() => _DPadButtonState();
}

class _DPadButtonState extends State<_DPadButton> with SingleTickerProviderStateMixin {
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    if (widget.isActive) {
      _animController.value = 0.6;
    }
  }

  @override
  void didUpdateWidget(covariant _DPadButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive != widget.isActive) {
      if (widget.isActive) {
        _animController.animateTo(0.6,
            duration: const Duration(milliseconds: 50),
            curve: Curves.easeOutQuad);
      } else {
        _animController.forward(from: 0.6);
      }
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final background = widget.isActive
        ? AppColors.highlightColor
        : AppColors.backgroundColor;

    return AnimatedBuilder(
      animation: _animController,
      builder: (context, child) {
        double value = _animController.value;
        double scaleX = 1.0;
        double scaleY = 1.0;
        double translateY = 0.0;

        if (widget.isActive) {
          scaleX = 1.0 + (value * 0.08);
          scaleY = 1.0 - (value * 0.08);
          translateY = value * 4.0;
        } else if (_animController.isAnimating) {
          double t = (value - 0.6) / 0.4;
          if (t > 0) {
            double spring = math.sin(t * math.pi * 2.5) * (1.0 - t) * 0.12;
            scaleX = 1.0 - spring;
            scaleY = 1.0 + spring;
            translateY = spring * -4.0;
          }
        }

        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..translate(0.0, translateY)
            ..scale(scaleX, scaleY),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 80),
            width: 76,
            height: 76,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.textPrimary,
                width: AppColors.borderThickness,
              ),
            ),
            child: Text(
              widget.label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
                fontFamily: 'momo',
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CenterAction extends StatelessWidget {
  const _CenterAction({required this.onButtonStateChanged});

  final ControllerButtonStateCallback onButtonStateChanged;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: ControlButton(
              label: '⧉',
              onStateChange: (state) => onButtonStateChanged('SELECT', state),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 56,
            height: 56,
            child: ControlButton(
              label: '≡',
              onStateChange: (state) => onButtonStateChanged('START', state),
            ),
          ),
        ],
      ),
    );
  }
}

void _showEditNameDialog(BuildContext context, String currentName, ValueChanged<String> onNameChanged) {
  final controller = TextEditingController(text: currentName == 'Sem Nome' ? '' : currentName);

  showDialog(
    context: context,
    useRootNavigator: false,
    barrierDismissible: true,
    barrierColor: Colors.black54,
    builder: (context) {
      return Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          width: 320,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.screenBackground,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.textPrimary,
              width: AppColors.borderThickness,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Editar Apelido',
                style: TextStyle(
                  fontFamily: 'momo',
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.textPrimary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.textPrimary.withValues(alpha: 0.2),
                    width: 2,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: TextField(
                  controller: controller,
                  maxLength: 20,
                  textAlign: TextAlign.center,
                  autofocus: true,
                  style: const TextStyle(
                    fontFamily: 'momo_sans',
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  decoration: const InputDecoration(
                    counterText: '',
                    border: InputBorder.none,
                    hintText: 'Digite o apelido...',
                    isDense: true,
                  ),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (value) {
                    final trimmed = value.trim();
                    if (trimmed.isNotEmpty) {
                      onNameChanged(trimmed);
                    }
                    Navigator.of(context).pop();
                  },
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Cancelar',
                      style: TextStyle(
                        fontFamily: 'momo',
                        color: AppColors.textPrimary.withValues(alpha: 0.6),
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.highlightColor,
                      foregroundColor: AppColors.textPrimary,
                      elevation: 0,
                      side: BorderSide(
                        color: AppColors.textPrimary,
                        width: AppColors.borderThickness / 2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    ),
                    onPressed: () {
                      final trimmed = controller.text.trim();
                      if (trimmed.isNotEmpty) {
                        onNameChanged(trimmed);
                      }
                      Navigator.of(context).pop();
                    },
                    child: const Text(
                      'Salvar',
                      style: TextStyle(
                        fontFamily: 'momo',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _PlayerNameWidget extends StatelessWidget {
  final String? name;
  final ValueChanged<String> onNameChanged;

  const _PlayerNameWidget({
    super.key,
    required this.name,
    required this.onNameChanged,
  });

  @override
  Widget build(BuildContext context) {
    final displayName = name ?? 'Sem Nome';

    return GestureDetector(
      onTap: () => _showEditNameDialog(context, displayName, onNameChanged),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.textPrimary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: 'momo_sans',
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
            decoration: TextDecoration.underline,
            decorationStyle: TextDecorationStyle.dashed,
          ),
        ),
      ),
    );
  }
}
