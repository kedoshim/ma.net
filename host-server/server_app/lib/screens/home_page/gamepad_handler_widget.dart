import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:server_app/screens/home_page/gamepad_state.dart';
import 'package:server_app/services/host_api_service.dart';
import 'package:server_app/theme/app_theme.dart';
import 'package:styled_divider/styled_divider.dart';
import 'package:google_fonts/google_fonts.dart';
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
                  DevicePoolArea(scale: scale),
                  SizedBox(height: scale.eighth),
                  SizedBox(
                    height: scale.slot * rows + scale.eighth/2 * (rows - 1),
                    width: scale.slot * columns + scale.eighth/2 * (columns - 1),
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

        final availableHeight = totalHeight * 0.7; // Lower 70% available for interactive slots/pool
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
            DevicePoolArea(scale: scale),
            SizedBox(height: scale.quarter),
            SizedBox(
              height: scale.slot * rows + scale.eighth * (rows - 1),
              width: scale.slot * columns + scale.eighth * (columns - 1),
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
      spacing: scale.eighth/2,
      runSpacing: scale.eighth/2,
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
            color: AppTheme.primaryBackground,
            borderRadius: BorderRadius.circular(scale.eighth),
            border: Border.all(
              color: isHovered ? Colors.green : AppTheme.primaryText,
              width: isHovered ? scale.eighth / 3 : scale.eighth / 4,
            ),
          ),
          child: Stack(
            children: [
              if (slotModel.device != null)
                Positioned.fill(
                  child: Draggable<DragData>(
                    dragAnchorStrategy: pointerDragAnchorStrategy,
                    data: DragData(
                      device: slotModel.device,
                      source: DragSource.slot,
                      slotIndex: index,
                    ),
                    feedback: _buildDragFeedback(slotModel.device!, scale.quarter),
                    childWhenDragging: const SizedBox.expand(),
                    child: Center(
                      child: DeviceInputIndicator(
                        device: slotModel.device!,
                        input: state.getInputState(slotModel.device!.id) ??
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
                child: Text(
                  'p${index + 1}',
                  style: AppTheme.bodyMedium.copyWith(
                    fontFamily: 'pico',
                    fontSize: scale.eighth,
                  ),
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
              color: isHovered ? Colors.green : Colors.transparent,
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
                          'players',
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
                            dragAnchorStrategy: pointerDragAnchorStrategy,
                            data: DragData(
                              device: device,
                              source: DragSource.pool,
                            ),
                            feedback: _buildDragFeedback(device, scale.quarter),
                            childWhenDragging: Opacity(
                              opacity: 0.5,
                              child: DeviceInputIndicator(
                                device: device,
                                input: inputState,
                                size: scale.half,
                                isOnPool: true,
                              ),
                            ),
                            child: DeviceInputIndicator(
                              device: device,
                              input: inputState,
                              size: scale.half,
                              isOnPool: true,
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
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: device.color,
        shape: BoxShape.rectangle,
        borderRadius: BorderRadius.circular(size * 0.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: size * 0.2,
            spreadRadius: size * 0.05,
          ),
        ],
      ),
    ),
  );
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
    final shape = isOnPool ? BoxShape.rectangle : BoxShape.circle;
    final borderRadius = isOnPool ? BorderRadius.circular(size * 0.1) : null;

    double stickX = input.stickX;
    double stickY = input.stickY;
    double magnitude = math.sqrt(stickX * stickX + stickY * stickY);
    if (magnitude > 1.0) magnitude = 1.0;

    // Subtle elastic deformation: stretch in direction of movement, squash perpendicular
    double stretch = 1;
    double squash = 1;
    double angle = (stickX == 0 && stickY == 0) ? 0.0 : math.atan2(stickY, stickX);

    double maxOffset = size * 0.65;
    double translateX = isOnPool ? 0 : stickX * maxOffset;
    double translateY = isOnPool ? 0 : stickY * maxOffset;

    final isCentered = stickX == 0 && stickY == 0;
    final isPressed = input.buttonPressed;

    double baseScale = isOnPool ? 0.6 : 0.9;
    double targetScale = baseScale * (isPressed ? 0.75 : 1.0);

    return Center(
      child: SizedBox(
        width: size,
        height: size,
        child: AnimatedScale(
          scale: targetScale,
          duration: Duration(milliseconds: isPressed ? 50 : 400),
          curve: isPressed ? Curves.easeOut : Curves.elasticOut,
          child: AnimatedContainer(
            duration: isCentered
                ? const Duration(milliseconds: 400)
                : const Duration(milliseconds: 100),
            curve: isCentered ? Curves.elasticOut : Curves.easeOutCubic,
            transformAlignment: Alignment.center,
            transform: Matrix4.identity()
              ..translate(translateX, translateY)
              ..rotateZ(angle)
              ..scale(stretch, squash)
              ..rotateZ(-angle),
            decoration: BoxDecoration(
              color: device.color,
              shape: shape,
              borderRadius: borderRadius,
            ),
          ),
        ),
      )
    );
  }
}
