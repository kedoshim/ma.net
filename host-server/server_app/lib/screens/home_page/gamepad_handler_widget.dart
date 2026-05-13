import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:server_app/screens/home_page/gamepad_state.dart';
import 'package:server_app/services/host_api_service.dart';
import 'package:server_app/theme/app_theme.dart';
import 'package:styled_divider/styled_divider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;

enum DragSource { pool, slot }

class DragData {
  final DeviceModel? device;
  final DragSource source;
  final int? slotIndex;

  DragData({required this.device, required this.source, this.slotIndex});
}

Expanded gamepadHandlerWidget(BuildContext context) {
  final state = Provider.of<GamepadState>(context);

  return Expanded(
    flex: 40,
    child: Container(
      decoration: BoxDecoration(),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Device Pool Area
          Flexible(
            child: Container(
              width: MediaQuery.sizeOf(context).width * 1.0,
              height: 200.0,
              decoration: BoxDecoration(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Padding(
                    padding: EdgeInsetsDirectional.fromSTEB(
                      0.0,
                      0.0,
                      0.0,
                      10.0,
                    ),
                    child: Text(
                      'conectados:',
                      style: AppTheme.titleLarge.copyWith(
                        fontFamily: 'pico',
                        letterSpacing: 0.0,
                      ),
                    ),
                  ),
                  StyledDivider(
                    thickness: 2.0,
                    indent: 15.0,
                    endIndent: 15.0,
                    color: AppTheme.primaryText,
                    lineStyle: DividerLineStyle.dashed,
                  ),
                  Flexible(
                    child: Container(
                      width: MediaQuery.sizeOf(context).width * 1.0,
                      height: 130.0,
                      decoration: BoxDecoration(),
                      child: Padding(
                        padding: EdgeInsets.all(15.0),
                        child: DragTarget<DragData>(
                          onAcceptWithDetails: (data) {
                            if (data.data.source == DragSource.slot) {
                              state.unassignDevice(data.data.slotIndex!);
                            }
                          },
                          builder: (context, candidateData, rejectedData) {
                            return Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16.0),
                                border: candidateData.isNotEmpty
                                    ? Border.all(color: Colors.green, width: 2)
                                    : Border.all(
                                        color: Colors.transparent,
                                        width: 2,
                                      ),
                              ),
                              clipBehavior: Clip.hardEdge,
                              child: SizedBox(
                                width: double.infinity,
                                height: double.infinity,
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16.0),
                                    border: candidateData.isNotEmpty
                                        ? Border.all(
                                            color: Colors.green,
                                            width: 2,
                                          )
                                        : Border.all(
                                            color: Colors.transparent,
                                            width: 2,
                                          ),
                                  ),
                                  child: state.pool.isEmpty
                                      ? const SizedBox.expand()
                                      : ListView(
                                          padding: EdgeInsets.zero,
                                          scrollDirection: Axis.horizontal,
                                          children: state.pool.map((device) {
                                            final inputState =
                                                state.getInputState(
                                                  device.id,
                                                ) ??
                                                DeviceInputState.idle();
                                            return Draggable<DragData>(
                                              dragAnchorStrategy:
                                                  pointerDragAnchorStrategy,
                                              data: DragData(
                                                device: device,
                                                source: DragSource.pool,
                                              ),
                                              feedback: _buildDragFeedback(
                                                device,
                                              ),
                                              childWhenDragging: Opacity(
                                                opacity: 0.5,
                                                child: SizedBox(
                                                  width: 100,
                                                  height: double.infinity,
                                                  child: LayoutBuilder(
                                                    builder:
                                                        (context, constraints) {
                                                          final minDimension =
                                                              math.min(
                                                                constraints
                                                                    .maxWidth,
                                                                constraints
                                                                    .maxHeight,
                                                              );
                                                          return DeviceInputIndicator(
                                                            device: device,
                                                            input: inputState,
                                                            size: minDimension,
                                                            isOnPool: true,
                                                          );
                                                        },
                                                  ),
                                                ),
                                              ),
                                              child: SizedBox(
                                                width: 100,
                                                height: double.infinity,
                                                child: LayoutBuilder(
                                                  builder: (context, constraints) {
                                                    final minDimension = math
                                                        .min(
                                                          constraints.maxWidth,
                                                          constraints.maxHeight,
                                                        );
                                                    return DeviceInputIndicator(
                                                      device: device,
                                                      input: inputState,
                                                      size: minDimension,
                                                      isOnPool: true,
                                                    );
                                                  },
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  StyledDivider(
                    thickness: 2.0,
                    indent: 15.0,
                    endIndent: 15.0,
                    color: AppTheme.primaryText,
                    lineStyle: DividerLineStyle.dashed,
                  ),
                ],
              ),
            ),
          ),
          // Controller Slots Area
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                const int columns = 4;
                final int itemCount = state.slots.length;

                final int rows = (itemCount / columns).ceil();

                final double totalSpacingX = (columns - 1) * 15.0;
                final double totalSpacingY = (rows - 1) * 15.0;

                final double cellWidth =
                    (constraints.maxWidth - totalSpacingX) / columns;

                final double cellHeight =
                    (constraints.maxHeight - totalSpacingY) / rows;

                return GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  itemCount: itemCount,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: 15.0,
                    mainAxisSpacing: 15.0,
                    childAspectRatio: cellWidth / cellHeight > 0
                        ? cellWidth / cellHeight
                        : 1.0,
                  ),
                  itemBuilder: (context, index) {
                    return DragTarget<DragData>(
                      onAcceptWithDetails: (details) {
                        final data = details.data;

                        if (data.source == DragSource.pool) {
                          if (state.slots[index].device == null) {
                            state.assignDevice(data.device!, index);
                          } else {
                            state.replaceSlotDevice(data.device!, index);
                          }
                        } else if (data.source == DragSource.slot) {
                          if (data.slotIndex == index) return;

                          if (state.slots[index].device == null) {
                            state.moveDevice(data.slotIndex!, index);
                          } else {
                            state.swapDevices(data.slotIndex!, index);
                          }
                        }
                      },
                      builder: (context, candidateData, rejectedData) {
                        return Container(
                          decoration: BoxDecoration(
                            color: AppTheme.primaryBackground,
                            borderRadius: BorderRadius.circular(16.0),
                            border: Border.all(
                              color: candidateData.isNotEmpty
                                  ? Colors.green
                                  : AppTheme.primaryText,
                              width: candidateData.isNotEmpty ? 7.0 : 5.0,
                            ),
                          ),
                          child: Stack(
                            children: [
                              if (state.slots[index].device != null)
                                Draggable<DragData>(
                                  dragAnchorStrategy: pointerDragAnchorStrategy,
                                  data: DragData(
                                    device: state.slots[index].device,
                                    source: DragSource.slot,
                                    slotIndex: index,
                                  ),
                                  feedback: _buildDragFeedback(
                                    state.slots[index].device!,
                                  ),
                                  childWhenDragging: const SizedBox.expand(),
                                  child: Center(
                                    child: LayoutBuilder(
                                      builder: (context, constraints) {
                                        final minDimension = math.min(
                                          constraints.maxWidth,
                                          constraints.maxHeight,
                                        );
                                        final inputState =
                                            state.getInputState(
                                              state.slots[index].device!.id,
                                            ) ??
                                            DeviceInputState.idle();
                                        return DeviceInputIndicator(
                                          device: state.slots[index].device!,
                                          input: inputState,
                                          size: minDimension,
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              Positioned(
                                top: 5,
                                right: 10,
                                child: Text(
                                  state.slots[index]?.type ?? 'xx360',
                                  style: AppTheme.bodyMedium.copyWith(
                                    fontFamily: 'pico',
                                    fontSize: 12.0,
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 0,
                                left: 10,
                                child: Text(
                                  'p${index + 1}',
                                  style: AppTheme.bodyMedium.copyWith(
                                    fontFamily: 'pico',
                                    fontSize: 20.0,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _buildDragFeedback(DeviceModel device) {
  return Material(
    color: Colors.transparent,
    child: SizedBox(
      width: 80,
      height: 80,
      child: Center(
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: device.color,
            shape: BoxShape.circle,
          ),
        ),
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
    // AnimatedSlide uses fractional offsets relative to the child's size.
    // Moving up to 40% of its size keeps it well contained within the indicator area.
    final stickOffset = isOnPool
        ? Offset.zero
        : Offset(input.stickX * 0.4, input.stickY * 0.4);

    return Center(
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Outer glow / ripple effect for button presses
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOutCubic,
              width: input.buttonPressed
                  ? size * 0.9
                  : size * (isOnPool ? 0.8 : 0.5),
              height: input.buttonPressed
                  ? size * 0.9
                  : size * (isOnPool ? 0.8 : 0.5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: device.color.withValues(
                    alpha: input.buttonPressed ? 0.5 : 0.0,
                  ),
                  width: input.buttonPressed ? 6 : 0,
                ),
              ),
            ),

            // Inner joystick visualizer
            AnimatedSlide(
              offset: stickOffset,
              duration: const Duration(milliseconds: 100),
              curve: Curves.easeOutQuad,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 100),
                width: size * (isOnPool ? 0.8 : 0.5),
                height: size * (isOnPool ? 0.8 : 0.5),
                decoration: BoxDecoration(
                  color: device.color,
                  shape: BoxShape.circle,
                  boxShadow: input.buttonPressed
                      ? [
                          BoxShadow(
                            color: device.color.withValues(alpha: 0.6),
                            blurRadius: 15,
                            spreadRadius: 2,
                          ),
                        ]
                      : [],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
