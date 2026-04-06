import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:server_app/screens/home_page/gamepad_state.dart';
import 'package:server_app/services/host_api_service.dart';
import 'package:server_app/theme/app_theme.dart';
import 'package:styled_divider/styled_divider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

enum DragSource { pool, slot }

class DragData {
  final DeviceModel device;
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
                              child: ListView(
                                padding: EdgeInsets.zero,
                                shrinkWrap: true,
                                scrollDirection: Axis.horizontal,
                                children: state.pool.map((device) {
                                  return Draggable<DragData>(
                                    data: DragData(
                                      device: device,
                                      source: DragSource.pool,
                                    ),
                                    feedback: _buildDeviceWidget(
                                      device,
                                      isDragging: true,
                                    ),
                                    childWhenDragging: Opacity(
                                      opacity: 0.5,
                                      child: _buildDeviceWidget(device),
                                    ),
                                    child: _buildDeviceWidget(device),
                                  );
                                }).toList(),
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
          Container(
            width: MediaQuery.sizeOf(context).width * 1.0,
            height: MediaQuery.sizeOf(context).height * 0.45,
            decoration: BoxDecoration(),
            child: GridView.builder(
              padding: EdgeInsets.zero,
              scrollDirection: Axis.vertical,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 15.0,
                mainAxisSpacing: 15.0,
                childAspectRatio: 1.0,
              ),
              itemCount: state.slots.length,
              itemBuilder: (context, index) {
                return DragTarget<DragData>(
                  onAcceptWithDetails: (details) {
                    final data = details.data;
                    if (data.source == DragSource.pool) {
                      if (state.slots[index] == null) {
                        state.assignDevice(data.device, index);
                      } else {
                        state.replaceSlotDevice(data.device, index);
                      }
                    } else if (data.source == DragSource.slot) {
                      if (data.slotIndex == index) return; // same slot
                      if (state.slots[index] == null) {
                        state.moveDevice(data.slotIndex!, index);
                      } else {
                        state.swapDevices(data.slotIndex!, index);
                      }
                    }
                  },
                  builder: (context, candidateData, rejectedData) {
                    return Container(
                      width: 200.0,
                      height: 200.0,
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
                          if (state.slots[index] != null)
                            Draggable<DragData>(
                              data: DragData(
                                device: state.slots[index]!,
                                source: DragSource.slot,
                                slotIndex: index,
                              ),
                              feedback: _buildDeviceWidget(
                                state.slots[index]!,
                                isDragging: true,
                              ),
                              childWhenDragging:
                                  Container(), // empty when dragging
                              child: Center(
                                child: _buildDeviceWidget(
                                  state.slots[index]!,
                                  isOnPool: true,
                                ),
                              ),
                            ),
                          Align(
                            alignment: AlignmentDirectional(1.0, -1.0),
                            child: Padding(
                              padding: EdgeInsetsDirectional.fromSTEB(
                                0.0,
                                5.0,
                                10.0,
                                0.0,
                              ),
                              child: Text(
                                'x360',
                                style: AppTheme.bodyMedium.copyWith(
                                  fontFamily: 'pico',
                                  fontSize: 12.0,
                                  letterSpacing: 0.0,
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                              10.0,
                              0.0,
                              0.0,
                              0.0,
                            ),
                            child: Text(
                              'p${index + 1}',
                              style: AppTheme.bodyMedium.copyWith(
                                fontFamily: 'pico',
                                fontSize: 20.0,
                                letterSpacing: 0.0,
                              ),
                            ),
                          ),
                        ],
                      ),
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

Widget _buildDeviceWidget(
  DeviceModel device, {
  bool isDragging = false,
  bool isOnPool = false,
}) {
  return Container(
    width: 100.0,
    height: 120.0,
    decoration: BoxDecoration(),
    child: Padding(
      padding: EdgeInsets.all(5.0),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Container(width: 100.0, height: isOnPool ? 15.0 : 0.0),
          Container(
            width: isDragging ? 110.0 : 100.0,
            height: isDragging ? 110.0 : 100.0,
            decoration: BoxDecoration(
              color: device.color,
              shape: BoxShape.circle,
            ),
          ),
          // Text(
          //   device.name,
          //   style: AppTheme.bodyMedium.copyWith(
          //     fontFamily: 'pico',
          //     letterSpacing: 0.0,
          //   ),
          // ),
        ],
      ),
    ),
  );
}
