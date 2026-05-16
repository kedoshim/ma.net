import 'package:flutter/material.dart';
import 'package:server_app/screens/home_page/gamepad_state.dart';
import 'package:server_app/services/host_api_service.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:server_app/theme/app_theme.dart';
import 'package:server_app/theme/app_colors.dart';
import 'package:server_app/widgets/player_face_indicator.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import 'qr_code_container.dart';

class UIScale {
  final double slot;
  const UIScale(this.slot);

  double get half => slot / 2;
  double get quarter => slot / 4;
  double get eighth => slot / 8;
}

enum DragSource { pool, slot }

class DragData {
  final DeviceModel? device;
  final DragSource source;
  final int? slotIndex;

  DragData({required this.device, required this.source, this.slotIndex});
}

class _AudioEffectService {
  static final _AudioEffectService instance = _AudioEffectService._();
  _AudioEffectService._();

  final AudioPlayer _hoverPlayer = AudioPlayer()..setReleaseMode(ReleaseMode.stop);
  final List<AudioPlayer> _popPlayers = List.generate(4, (_) => AudioPlayer()..setReleaseMode(ReleaseMode.stop));

  DateTime _lastHoverSoundTime = DateTime.now();

  void playHover() async {
    final now = DateTime.now();
    if (now.difference(_lastHoverSoundTime).inMilliseconds < 100) return;
    _lastHoverSoundTime = now;

    try {
      if (_hoverPlayer.state == PlayerState.playing) {
        await _hoverPlayer.stop();
      }
      await _hoverPlayer.play(AssetSource('audio/slot-click.mp3'), volume: 0.3);
    } catch (_) {}
  }

  void playPop() async {
    try {
      final variantIdx = math.Random().nextInt(4);
      final p = _popPlayers[variantIdx];
      
      if (p.state == PlayerState.playing) {
        await p.stop();
      }
      await p.play(AssetSource('audio/bubble_pop/bubble_pop${variantIdx + 1}.mp3'), volume: 0.4);
    } catch (_) {}
  }
}

void _playHoverSound() => _AudioEffectService.instance.playHover();

class AdaptiveStageLayout extends StatelessWidget {
  final ConnectionInfo? connectionInfo;
  final String qrCodeUrl;
  final bool isLoadingConnection;

  const AdaptiveStageLayout({
    super.key,
    required this.connectionInfo,
    required this.qrCodeUrl,
    required this.isLoadingConnection,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth / constraints.maxHeight > 1.2;
        if (isWide) {
          return WideStageLayout(
            connectionInfo: connectionInfo,
            qrCodeUrl: qrCodeUrl,
            isLoadingConnection: isLoadingConnection,
          );
        } else {
          return CompactStageLayout(
            connectionInfo: connectionInfo,
            qrCodeUrl: qrCodeUrl,
            isLoadingConnection: isLoadingConnection,
          );
        }
      },
    );
  }
}

class WideStageLayout extends StatelessWidget {
  final ConnectionInfo? connectionInfo;
  final String qrCodeUrl;
  final bool isLoadingConnection;

  const WideStageLayout({
    super.key,
    required this.connectionInfo,
    required this.qrCodeUrl,
    required this.isLoadingConnection,
  });

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<GamepadState>(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final totalHeight = constraints.maxHeight;

        final leftWidth = totalWidth * 0.75;
        final rightWidth = totalWidth * 0.25;

        const columns = 4;
        final rows = (math.max(4, state.slots.length) / columns).ceil();

        final widthFactor = columns + (columns - 1) / 8.0;
        // +1.5 logic reserves ample room vertically for the DevicePoolArea
        final heightFactor = rows + (rows - 1) / 8.0 + 0.95;

        final slotSize = math
            .min(leftWidth / widthFactor, totalHeight / heightFactor)
            .clamp(40.0, 400.0);
        final scale = UIScale(slotSize);

        return Row(
          children: [
            SizedBox(
              width: leftWidth,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: scale.slot * columns + scale.eighth / 2 * (columns - 1),
                    child: DevicePoolArea(scale: scale),
                  ),
                  SizedBox(height: scale.eighth),
                  SizedBox(
                    height: scale.slot * rows + scale.eighth / 2 * (rows - 1),
                    width:
                        scale.slot * columns + scale.eighth / 2 * (columns - 1),
                    child: ControllerSlotsGrid(scale: scale),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: rightWidth,
              child: Padding(
                padding: EdgeInsets.only(left: scale.eighth),
                child: QRCodePanel(
                  connectionInfo: connectionInfo,
                  qrCodeUrl: qrCodeUrl,
                  isLoadingConnection: isLoadingConnection,
                  scale: scale,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class CompactStageLayout extends StatelessWidget {
  final ConnectionInfo? connectionInfo;
  final String qrCodeUrl;
  final bool isLoadingConnection;

  const CompactStageLayout({
    super.key,
    required this.connectionInfo,
    required this.qrCodeUrl,
    required this.isLoadingConnection,
  });

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<GamepadState>(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final totalHeight = constraints.maxHeight;

        const columns = 4;
        final rows = (math.max(4, state.slots.length) / columns).ceil();

        final widthFactor = columns + (columns - 1) / 8.0;
        final heightFactor = rows + (rows - 1) / 8.0 + 1.5;

        final availableHeight =
            totalHeight * 0.7; // Lower 70% available for interactive slots/pool
        final slotSize = math
            .min(totalWidth / widthFactor, availableHeight / heightFactor)
            .clamp(40.0, 400.0);
        final scale = UIScale(slotSize);

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: totalHeight * 0.3,
              child: Padding(
                padding: EdgeInsets.only(bottom: scale.quarter),
                child: QRCodePanel(
                  connectionInfo: connectionInfo,
                  qrCodeUrl: qrCodeUrl,
                  isLoadingConnection: isLoadingConnection,
                  scale: scale,
                ),
              ),
            ),
            SizedBox(
              width: scale.slot * columns + scale.eighth / 2 * (columns - 1),
              child: DevicePoolArea(scale: scale),
            ),
            SizedBox(height: scale.quarter),
            SizedBox(
              height: scale.slot * rows + scale.eighth / 2 * (rows - 1),
              width: scale.slot * columns + scale.eighth / 2 * (columns - 1),
              child: ControllerSlotsGrid(scale: scale),
            ),
          ],
        );
      },
    );
  }
}

class ControllerSlotsGrid extends StatelessWidget {
  final UIScale scale;
  const ControllerSlotsGrid({super.key, required this.scale});

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<GamepadState>(context);
    return Wrap(
      spacing: scale.eighth / 2,
      runSpacing: scale.eighth / 2,
      children: List.generate(state.slots.length, (index) {
        return ControllerSlotWidget(
          index: index,
          slotModel: state.slots[index],
          scale: scale,
        );
      }),
    );
  }
}

class ControllerSlotWidget extends StatelessWidget {
  final int index;
  final SlotModel slotModel;
  final UIScale scale;

  const ControllerSlotWidget({
    super.key,
    required this.index,
    required this.slotModel,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<GamepadState>(context, listen: false);

    return DragTarget<DragData>(
      onWillAcceptWithDetails: (details) {
        _playHoverSound();
        return true;
      },
      onAcceptWithDetails: (details) {
        final data = details.data;
        if (data.source == DragSource.pool) {
          if (slotModel.device == null) {
            state.assignDevice(data.device!, index);
          } else {
            state.replaceSlotDevice(data.device!, index);
          }
        } else if (data.source == DragSource.slot) {
          if (data.slotIndex == index) return;
          if (slotModel.device == null) {
            state.moveDevice(data.slotIndex!, index);
          } else {
            state.swapDevices(data.slotIndex!, index);
          }
        }
      },
      builder: (context, candidateData, rejectedData) {
        final isHovered = candidateData.isNotEmpty;

        return Container(
          width: scale.slot,
          height: scale.slot,
          decoration: BoxDecoration(
            color: AppColors.lightColor,
            borderRadius: BorderRadius.circular(scale.eighth),
            border: Border.all(
              color: isHovered ? AppColors.highlightColor : AppTheme.primaryText,
              width: isHovered ? scale.eighth / 3 : scale.eighth / 4,
            ),
          ),
          child: Stack(
            children: [
              if (slotModel.device != null)
                Positioned.fill(
                  child: slotModel.device!.connected
                      ? Draggable<DragData>(
                          dragAnchorStrategy: (draggable, context, position) =>
                              Offset(scale.quarter / 2, scale.quarter / 2),
                          data: DragData(
                            device: slotModel.device,
                            source: DragSource.slot,
                            slotIndex: index,
                          ),
                          feedback: MouseRegion(
                            cursor: SystemMouseCursors.grab,
                            child: _buildDragFeedback(
                              slotModel.device!,
                              scale.quarter,
                            ),
                          ),
                          childWhenDragging: const SizedBox.expand(),
                          child: MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: Center(
                              child: DeviceJoinPopEffect(
                                device: slotModel.device!,
                                child: DeviceInputIndicator(
                                  device: slotModel.device!,
                                  input:
                                      state.getInputState(slotModel.device!.id) ??
                                      DeviceInputState.idle(),
                                  size: scale.half,
                                  isOnPool: false,
                                ),
                              ),
                            ),
                          ),
                        )
                      : Center(
                          child: DeviceJoinPopEffect(
                            device: slotModel.device!,
                            child: DeviceInputIndicator(
                              device: slotModel.device!,
                              input:
                                  state.getInputState(slotModel.device!.id) ??
                                  DeviceInputState.idle(),
                              size: scale.half,
                              isOnPool: false,
                            ),
                          ),
                        ),
                ),
              Positioned(
                top: scale.eighth / 2,
                right: scale.eighth / 2,
                child: Text(
                  slotModel.type ?? 'x360',
                  style: AppTheme.bodyMedium.copyWith(
                    fontFamily: 'pico',
                    fontSize: scale.eighth,
                  ),
                ),
              ),
              Positioned(
                top: scale.eighth / 2,
                left: scale.eighth / 2,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'p${index + 1}',
                      style: AppTheme.bodyMedium.copyWith(
                        fontFamily: 'pico',
                        fontSize: scale.eighth,
                      ),
                    ),
                    if (slotModel.device != null &&
                        !slotModel.device!.connected)
                      Padding(
                        padding: EdgeInsets.only(left: scale.eighth / 3),
                        child: Text(
                          'offline',
                          style: AppTheme.bodyMedium.copyWith(
                            fontFamily: 'pico',
                            fontSize: scale.eighth * 0.7,
                            color: AppTheme.primaryText.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class DevicePoolArea extends StatelessWidget {
  final UIScale scale;
  const DevicePoolArea({super.key, required this.scale});

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<GamepadState>(context);

    return DragTarget<DragData>(
      onWillAcceptWithDetails: (details) {
        _playHoverSound();
        return true;
      },
      onAcceptWithDetails: (details) {
        if (details.data.source == DragSource.slot) {
          state.unassignDevice(details.data.slotIndex!);
        }
      },
      builder: (context, candidateData, rejectedData) {
        final isHovered = candidateData.isNotEmpty;

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(scale.eighth),
            border: Border.all(
              color: isHovered ? AppColors.highlightColor : Colors.transparent,
              width: scale.eighth / 4,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: scale.slot * 0.8,
                width: double.infinity,
                padding: EdgeInsets.all(scale.eighth),
                decoration: BoxDecoration(
                  color: AppTheme.primaryText.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(scale.eighth),
                ),
                child: state.pool.isEmpty
                    ? Center(
                        child: Text(
                          'banco de reservas',
                          style: TextStyle(
                            fontFamily: 'pico',
                            fontSize: scale.eighth,
                            color: AppTheme.primaryText.withValues(alpha: 0.3),
                          ),
                        ),
                      )
                    : ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: state.pool.length,
                        separatorBuilder: (_, __) =>
                            SizedBox(width: scale.eighth),
                        itemBuilder: (context, index) {
                          final device = state.pool[index];
                          final inputState =
                              state.getInputState(device.id) ??
                              DeviceInputState.idle();

                          return Draggable<DragData>(
                            dragAnchorStrategy: (draggable, context, position) =>
                                Offset(scale.quarter / 2, scale.quarter / 2),
                            data: DragData(
                              device: device,
                              source: DragSource.pool,
                            ),
                            feedback: MouseRegion(
                              cursor: SystemMouseCursors.move,
                              child: _buildDragFeedback(device, scale.quarter),
                            ),
                            childWhenDragging: Opacity(
                              opacity: 0.5,
                              child: DeviceInputIndicator(
                                device: device,
                                input: inputState,
                                size: scale.half,
                                isOnPool: true,
                              ),
                            ),
                            child: MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: DeviceJoinPopEffect(
                                device: device,
                                child: DeviceInputIndicator(
                                  device: device,
                                  input: inputState,
                                  size: scale.half,
                                  isOnPool: true,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

Widget _buildDragFeedback(DeviceModel device, double size) {
  return Material(
    color: Colors.transparent,
    child: Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: size * 0.2,
            spreadRadius: size * 0.05,
          ),
        ],
      ),
      child: PlayerFaceIndicator(
        face: device.face,
        size: size,
        roundedSquare: true,
      ),
    ),
  );
}

class DeviceJoinPopEffect extends StatefulWidget {
  final DeviceModel device;
  final Widget child;
  const DeviceJoinPopEffect({
    super.key,
    required this.device,
    required this.child,
  });

  @override
  State<DeviceJoinPopEffect> createState() => _DeviceJoinPopEffectState();
}

class _DeviceJoinPopEffectState extends State<DeviceJoinPopEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  static final Set<String> _connectedDevices = {};

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _checkAndPop();
  }

  @override
  void didUpdateWidget(DeviceJoinPopEffect oldWidget) {
    super.didUpdateWidget(oldWidget);
    _checkAndPop();
  }

  void _checkAndPop() {
    if (widget.device.connected &&
        !_connectedDevices.contains(widget.device.id)) {
      _connectedDevices.add(widget.device.id);
      _triggerPop();
    } else if (!widget.device.connected) {
      _connectedDevices.remove(widget.device.id);
      _scaleAnimation = Tween<double>(
        begin: 1.0,
        end: 1.0,
      ).animate(_controller);
    } else if (!_controller.isAnimating) {
      _scaleAnimation = Tween<double>(
        begin: 1.0,
        end: 1.0,
      ).animate(_controller);
    }
  }

  void _triggerPop() {
    _scaleAnimation = Tween<double>(
      begin: 0.2,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));
    _controller.forward(from: 0.0);
    _playSound();
  }

  void _playSound() {
    _AudioEffectService.instance.playPop();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: widget.child,
        );
      },
    );
  }
}

class DeviceInputIndicator extends StatelessWidget {
  final DeviceModel device;
  final DeviceInputState input;
  final double size;
  final bool isOnPool;

  const DeviceInputIndicator({
    super.key,
    required this.device,
    required this.input,
    required this.size,
    this.isOnPool = false,
  });

  @override
  Widget build(BuildContext context) {
    double stickX = input.stickX;
    double stickY = input.stickY;
    double magnitude = math.sqrt(stickX * stickX + stickY * stickY);
    if (magnitude > 1.0) magnitude = 1.0;

    // Subtle elastic deformation: stretch in direction of movement, squash perpendicular
    double stretch = 1;
    double squash = 1;
    double angle = (stickX == 0 && stickY == 0)
        ? 0.0
        : math.atan2(stickY, stickX);

    double maxOffset = size * 0.65;
    double translateX = isOnPool ? 0 : stickX * maxOffset;
    double translateY = isOnPool ? 0 : stickY * maxOffset;

    final isCentered = stickX == 0 && stickY == 0;
    final isPressed = input.buttonPressed;

    double baseScale = isOnPool ? 0.6 : 0.9;
    final indicatorOpacity = device.connected ? 1.0 : 0.55;
    final borderColor = device.connected
        ? null
        : AppTheme.primaryText.withValues(alpha: 0.25);

    return Center(
      child: SizedBox(
        width: size,
        height: size,
        child: TweenAnimationBuilder<Offset>(
          tween: Tween(
            begin: Offset(stickX, stickY),
            end: Offset(stickX, stickY),
          ),
          duration: isCentered
              ? const Duration(milliseconds: 350)
              : const Duration(milliseconds: 150),
          curve: isCentered ? Curves.elasticOut : Curves.easeOutCubic,
          builder: (context, laggedStick, child) {
            double faceTx = isOnPool
                ? 0
                : (laggedStick.dx - stickX) * maxOffset * 0.6;
            double faceTy = isOnPool
                ? 0
                : (laggedStick.dy - stickY) * maxOffset * 0.6;

            return AnimatedContainer(
              duration: isCentered
                  ? const Duration(milliseconds: 400)
                  : const Duration(milliseconds: 100),
              curve: isCentered ? Curves.elasticOut : Curves.easeOutCubic,
              transformAlignment: Alignment.center,
              transform: Matrix4.identity()
                ..rotateZ(angle)
                ..scaleByDouble(stretch, squash, 1, 1)
                ..rotateZ(-angle),
              child: PlayerFaceIndicator(
                face: device.face,
                size: size,
                roundedSquare: isOnPool,
                scale: baseScale,
                opacity: indicatorOpacity,
                translateX: translateX,
                translateY: translateY,
                faceTranslateX: faceTx,
                faceTranslateY: faceTy,
                pressed: isPressed,
                borderColor: borderColor,
              ),
            );
          },
        ),
      ),
    );
  }
}
