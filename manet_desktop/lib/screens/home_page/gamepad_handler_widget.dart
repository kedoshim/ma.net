import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:manet_desktop/screens/home_page/gamepad_state.dart';
import 'package:manet_desktop/services/host_api_service.dart';
import 'package:manet_desktop/theme/app_theme.dart';
import 'package:manet_desktop/theme/app_colors.dart';
import 'package:manet_desktop/widgets/player_face_indicator.dart';
import 'package:manet_desktop/services/sound_effect_service.dart';
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

void _playHoverSound() => SoundEffectService.instance.playHover();

class AdaptiveStageLayout extends StatelessWidget {
  final ConnectionSnapshot? connectionSnapshot;
  final DiagnosticsSnapshot? diagnosticsSnapshot;
  final ConnectionInfo? selectedConnection;
  final String? qrEndpointUrl;
  final ImageProvider? qrImage;
  final HostApiService api;
  final bool isLoadingConnections;
  final bool isLoadingDiagnostics;
  final Future<void> Function(String connectionId) onSelectConnection;
  final Future<void> Function() onRefreshDiagnostics;
  final Widget? lobbyToolbar;

  const AdaptiveStageLayout({
    super.key,
    required this.connectionSnapshot,
    required this.diagnosticsSnapshot,
    required this.selectedConnection,
    required this.qrEndpointUrl,
    required this.qrImage,
    required this.api,
    required this.isLoadingConnections,
    required this.isLoadingDiagnostics,
    required this.onSelectConnection,
    required this.onRefreshDiagnostics,
    this.lobbyToolbar,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > constraints.maxHeight * 1.35;
        if (isWide) {
          return WideStageLayout(
            connectionSnapshot: connectionSnapshot,
            diagnosticsSnapshot: diagnosticsSnapshot,
            selectedConnection: selectedConnection,
            qrEndpointUrl: qrEndpointUrl,
            qrImage: qrImage,
            api: api,
            isLoadingConnections: isLoadingConnections,
            isLoadingDiagnostics: isLoadingDiagnostics,
            onSelectConnection: onSelectConnection,
            onRefreshDiagnostics: onRefreshDiagnostics,
            lobbyToolbar: lobbyToolbar,
          );
        } else {
          return CompactStageLayout(
            connectionSnapshot: connectionSnapshot,
            diagnosticsSnapshot: diagnosticsSnapshot,
            selectedConnection: selectedConnection,
            qrEndpointUrl: qrEndpointUrl,
            qrImage: qrImage,
            api: api,
            isLoadingConnections: isLoadingConnections,
            isLoadingDiagnostics: isLoadingDiagnostics,
            onSelectConnection: onSelectConnection,
            onRefreshDiagnostics: onRefreshDiagnostics,
            lobbyToolbar: lobbyToolbar,
          );
        }
      },
    );
  }
}

class WideStageLayout extends StatelessWidget {
  final ConnectionSnapshot? connectionSnapshot;
  final DiagnosticsSnapshot? diagnosticsSnapshot;
  final ConnectionInfo? selectedConnection;
  final String? qrEndpointUrl;
  final ImageProvider? qrImage;
  final HostApiService api;
  final bool isLoadingConnections;
  final bool isLoadingDiagnostics;
  final Future<void> Function(String connectionId) onSelectConnection;
  final Future<void> Function() onRefreshDiagnostics;
  final Widget? lobbyToolbar;

  const WideStageLayout({
    super.key,
    required this.connectionSnapshot,
    required this.diagnosticsSnapshot,
    required this.selectedConnection,
    required this.qrEndpointUrl,
    required this.qrImage,
    required this.api,
    required this.isLoadingConnections,
    required this.isLoadingDiagnostics,
    required this.onSelectConnection,
    required this.onRefreshDiagnostics,
    this.lobbyToolbar,
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

        final columns = state.slots.length > 12
            ? 8
            : (state.slots.length > 8 ? 6 : (state.slots.length > 4 ? 6 : 4));
        final rows = (math.max(columns, state.slots.length) / columns).ceil();

        final widthFactor = columns + (columns - 1) / 8.0;
        // +1.35 logic reserves ample room vertically for the DevicePoolArea and toolbar
        // and prevents small vertical overflows at the bottom.
        final heightFactor = rows + (rows - 1) / 8.0 + 1.35;

        final slotSize = math
            .min(leftWidth / widthFactor, totalHeight / heightFactor)
            .clamp(40.0, 400.0);
        final scale = UIScale(slotSize);

        // Stable, independent scale for the QR panel, decoupled from slot counts
        final qrScaleSize = math
            .min(rightWidth, totalHeight * 0.4)
            .clamp(180.0, 260.0);
        final qrScale = UIScale(qrScaleSize);

        // Add a 2.0px epsilon to prevent premature wrapping due to float rounding
        final contentWidth =
            scale.slot * columns + scale.eighth / 2 * (columns - 1) + 2.0;
        final gridHeight =
            scale.slot * rows + scale.eighth / 2 * (rows - 1) + 2.0;

        return Row(
          children: [
            SizedBox(
              width: leftWidth,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: contentWidth,
                    child: DevicePoolArea(scale: scale),
                  ),
                  if (lobbyToolbar != null) ...[
                    SizedBox(height: scale.eighth / 3),
                    SizedBox(
                      width: contentWidth,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: lobbyToolbar!,
                      ),
                    ),
                    SizedBox(height: scale.eighth / 3),
                  ] else
                    SizedBox(height: scale.eighth),
                  SizedBox(
                    height: gridHeight,
                    width: contentWidth,
                    child: ControllerSlotsGrid(scale: scale),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: rightWidth,
              child: Padding(
                padding: const EdgeInsets.only(left: 24.0),
                child: QRCodePanel(
                  connectionSnapshot: connectionSnapshot,
                  diagnosticsSnapshot: diagnosticsSnapshot,
                  selectedConnection: selectedConnection,
                  qrEndpointUrl: qrEndpointUrl,
                  qrImage: qrImage,
                  api: api,
                  isLoadingConnection: isLoadingConnections,
                  isLoadingDiagnostics: isLoadingDiagnostics,
                  scale: qrScale,
                  onSelectConnection: onSelectConnection,
                  onRefreshDiagnostics: onRefreshDiagnostics,
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
  final ConnectionSnapshot? connectionSnapshot;
  final DiagnosticsSnapshot? diagnosticsSnapshot;
  final ConnectionInfo? selectedConnection;
  final String? qrEndpointUrl;
  final ImageProvider? qrImage;
  final HostApiService api;
  final bool isLoadingConnections;
  final bool isLoadingDiagnostics;
  final Future<void> Function(String connectionId) onSelectConnection;
  final Future<void> Function() onRefreshDiagnostics;
  final Widget? lobbyToolbar;

  const CompactStageLayout({
    super.key,
    required this.connectionSnapshot,
    required this.diagnosticsSnapshot,
    required this.selectedConnection,
    required this.qrEndpointUrl,
    required this.qrImage,
    required this.api,
    required this.isLoadingConnections,
    required this.isLoadingDiagnostics,
    required this.onSelectConnection,
    required this.onRefreshDiagnostics,
    this.lobbyToolbar,
  });

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<GamepadState>(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final totalHeight = constraints.maxHeight;

        final columns = state.slots.length > 16
            ? 8
            : (state.slots.length > 8 ? 6 : 4);
        final rows = (math.max(columns, state.slots.length) / columns).ceil();

        final widthFactor = columns + (columns - 1) / 8.0;
        // +1.75 logic reserves ample room vertically for the DevicePoolArea and toolbar
        // and prevents small vertical overflows at the bottom.
        final heightFactor = rows + (rows - 1) / 8.0 + 1.75;

        final availableHeight =
            totalHeight * 0.7; // Lower 70% available for interactive slots/pool
        final slotSize = math
            .min(totalWidth / widthFactor, availableHeight / heightFactor)
            .clamp(40.0, 400.0);
        final scale = UIScale(slotSize);

        // Stable, independent scale for the QR panel, decoupled from slot counts
        final qrScaleSize = math
            .min(totalWidth, totalHeight * 0.3)
            .clamp(160.0, 240.0);
        final qrScale = UIScale(qrScaleSize);

        // Add a 2.0px epsilon to prevent premature wrapping due to float rounding
        final contentWidth =
            scale.slot * columns + scale.eighth / 2 * (columns - 1) + 2.0;
        final gridHeight =
            scale.slot * rows + scale.eighth / 2 * (rows - 1) + 2.0;

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: totalHeight * 0.3,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 24.0),
                child: QRCodePanel(
                  connectionSnapshot: connectionSnapshot,
                  diagnosticsSnapshot: diagnosticsSnapshot,
                  selectedConnection: selectedConnection,
                  qrEndpointUrl: qrEndpointUrl,
                  qrImage: qrImage,
                  api: api,
                  isLoadingConnection: isLoadingConnections,
                  isLoadingDiagnostics: isLoadingDiagnostics,
                  scale: qrScale,
                  onSelectConnection: onSelectConnection,
                  onRefreshDiagnostics: onRefreshDiagnostics,
                ),
              ),
            ),
            SizedBox(
              width: contentWidth,
              child: DevicePoolArea(scale: scale),
            ),
            if (lobbyToolbar != null) ...[
              SizedBox(height: scale.eighth / 2),
              SizedBox(
                width: contentWidth,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: lobbyToolbar!,
                ),
              ),
              SizedBox(height: scale.eighth / 2),
            ] else
              SizedBox(height: scale.quarter),
            SizedBox(
              height: gridHeight,
              width: contentWidth,
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

        SoundEffectService.instance.playDropPlayer();
      },
      builder: (context, candidateData, rejectedData) {
        final isHovered = candidateData.isNotEmpty;

        return AnimatedScale(
          scale: isHovered ? 1.06 : 1.0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.elasticOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: scale.slot,
            height: scale.slot,
            decoration: BoxDecoration(
              color: AppColors.lightColor,
              borderRadius: BorderRadius.circular(scale.eighth),
              border: Border.all(
                color: isHovered
                    ? AppColors.highlightColor
                    : AppTheme.primaryText,
                width: isHovered ? scale.eighth / 3 : scale.eighth / 4,
              ),
              boxShadow: isHovered
                  ? [
                      BoxShadow(
                        color: AppColors.textPrimary.withValues(alpha: 0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [],
            ),
            child: Stack(
              children: [
                if (slotModel.device != null)
                  Positioned.fill(
                    child: slotModel.device!.connected
                        ? Draggable<DragData>(
                            dragAnchorStrategy: (draggable, context, position) =>
                                const Offset(28.0, 28.0),
                            data: DragData(
                              device: slotModel.device,
                              source: DragSource.slot,
                              slotIndex: index,
                            ),
                            feedback: MouseRegion(
                              cursor: SystemMouseCursors.grab,
                              child: _buildDragFeedback(
                                slotModel.device!,
                                56.0,
                                false,
                              ),
                            ),
                            childWhenDragging: const SizedBox.expand(),
                            child: MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: Center(
                                child: DeviceJoinPopEffect(
                                  device: slotModel.device!,
                                  child: DropBounceEffect(
                                    key: ValueKey('drop_${slotModel.device!.id}'),
                                    child: DeviceInputIndicator(
                                      device: slotModel.device!,
                                      input:
                                          state.getInputState(
                                            slotModel.device!.id,
                                          ) ??
                                          DeviceInputState.idle(),
                                      size: scale.half,
                                      isOnPool: false,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          )
                        : Center(
                            child: DeviceJoinPopEffect(
                              device: slotModel.device!,
                              child: DropBounceEffect(
                                key: ValueKey('drop_${slotModel.device!.id}'),
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
                          fontFamily: 'momo',
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
                              fontFamily: 'momo',
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
          ),
        );
      },
    );
  }
}

class DevicePoolArea extends StatefulWidget {
  final UIScale scale;
  const DevicePoolArea({super.key, required this.scale});

  @override
  State<DevicePoolArea> createState() => _DevicePoolAreaState();
}

class _DevicePoolAreaState extends State<DevicePoolArea> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

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
          SoundEffectService.instance.playDropPlayer();
        }
      },
      builder: (context, candidateData, rejectedData) {
        final isHovered = candidateData.isNotEmpty;

        return AnimatedScale(
          scale: isHovered ? 1.02 : 1.0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.elasticOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: double.infinity,
            decoration: BoxDecoration(
              color: isHovered ? AppColors.highlightColor.withValues(alpha: 0.05) : Colors.transparent,
              borderRadius: BorderRadius.circular(widget.scale.eighth),
              border: Border.all(
                color: isHovered ? AppColors.highlightColor : Colors.transparent,
                width: widget.scale.eighth / 4,
              ),
            ),
            child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 160.0,
                width: double.infinity,
                padding: EdgeInsets.symmetric(horizontal: widget.scale.eighth, vertical: 10.0),
                decoration: BoxDecoration(
                  color: AppTheme.primaryText.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(widget.scale.eighth),
                ),
                child: state.pool.isEmpty
                    ? Center(
                        child: Text(
                          'banco de reservas',
                          style: TextStyle(
                            fontFamily: 'momo',
                            fontSize: 20.0,
                            color: AppTheme.primaryText.withValues(alpha: 0.3),
                          ),
                        ),
                      )
                    : Listener(
                        onPointerSignal: (pointerSignal) {
                          if (pointerSignal is PointerScrollEvent) {
                            final double delta = pointerSignal.scrollDelta.dy;
                            if (_scrollController.hasClients) {
                              final target = (_scrollController.offset + delta).clamp(
                                0.0,
                                _scrollController.position.maxScrollExtent,
                              );
                              _scrollController.jumpTo(target);
                            }
                          }
                        },
                        child: Scrollbar(
                          controller: _scrollController,
                          thumbVisibility: null,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 4.0),
                            child: ListView.separated(
                              controller: _scrollController,
                              scrollDirection: Axis.horizontal,
                              itemCount: state.pool.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 12.0),
                              itemBuilder: (context, index) {
                                final device = state.pool[index];
                                final inputState =
                                    state.getInputState(device.id) ??
                                    DeviceInputState.idle();

                                return Draggable<DragData>(
                                  dragAnchorStrategy:
                                      (draggable, context, position) => const Offset(28.0, 28.0),
                                  data: DragData(
                                    device: device,
                                    source: DragSource.pool,
                                  ),
                                  feedback: MouseRegion(
                                    cursor: SystemMouseCursors.move,
                                    child: _buildDragFeedback(
                                      device,
                                      56.0,
                                      true,
                                    ),
                                  ),
                                  childWhenDragging: Opacity(
                                    opacity: 0.5,
                                    child: DeviceInputIndicator(
                                      device: device,
                                      input: inputState,
                                      size: 56.0,
                                      isOnPool: true,
                                    ),
                                  ),
                                  child: MouseRegion(
                                    cursor: SystemMouseCursors.click,
                                    child: DeviceJoinPopEffect(
                                      device: device,
                                      child: DropBounceEffect(
                                        key: ValueKey('drop_${device.id}'),
                                        child: DeviceInputIndicator(
                                          device: device,
                                          input: inputState,
                                          size: 56.0,
                                          isOnPool: true,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
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
  }
}

class DynamicDragFeedback extends StatefulWidget {
  final DeviceModel device;
  final double size;
  final bool isOnPool;

  const DynamicDragFeedback({
    super.key,
    required this.device,
    required this.size,
    required this.isOnPool,
  });

  @override
  State<DynamicDragFeedback> createState() => _DynamicDragFeedbackState();
}

class _DynamicDragFeedbackState extends State<DynamicDragFeedback>
    with SingleTickerProviderStateMixin {
  Offset _lastPosition = Offset.zero;
  Offset _faceOffset = Offset.zero;
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
    _controller.addListener(_onTick);
  }

  void _onTick() {
    if (!mounted) return;
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox != null && renderBox.hasSize) {
      final position = renderBox.localToGlobal(Offset.zero);
      if (_lastPosition != Offset.zero) {
        final delta = position - _lastPosition;

        final targetX = -delta.dx * 1.5;
        final targetY = -delta.dy * 1.5;

        _faceOffset = Offset(
          _faceOffset.dx + (targetX - _faceOffset.dx) * 0.25,
          _faceOffset.dy + (targetY - _faceOffset.dy) * 0.25,
        );

        final maxOffset = widget.size * 0.35;
        if (_faceOffset.distance > maxOffset) {
          _faceOffset = Offset.fromDirection(_faceOffset.direction, maxOffset);
        }

        setState(() {});
      }
      _lastPosition = position;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0.75, end: 1.15),
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        builder: (context, scale, child) {
          return Transform.scale(
            scale: scale,
            alignment: Alignment.center,
            child: child,
          );
        },
        child: Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: widget.size * 0.2,
                spreadRadius: widget.size * 0.05,
              ),
            ],
          ),
          child: PlayerFaceIndicator(
            face: widget.device.face,
            size: widget.size,
            roundedSquare: true,
            faceTranslateX: _faceOffset.dx,
            faceTranslateY: _faceOffset.dy,
          ),
        ),
      ),
    );
  }
}

Widget _buildDragFeedback(DeviceModel device, double size, bool isOnPool) {
  return DynamicDragFeedback(device: device, size: size, isOnPool: isOnPool);
}

class DropBounceEffect extends StatelessWidget {
  final Widget child;

  const DropBounceEffect({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.4, end: 1.0),
      duration: const Duration(milliseconds: 800),
      curve: Curves.elasticOut,
      builder: (context, scale, child) {
        final rotation = (1.0 - scale) * 0.4;
        return Transform.scale(
          scale: scale,
          alignment: Alignment.center,
          child: Transform.rotate(
            angle: rotation,
            child: child,
          ),
        );
      },
      child: child,
    );
  }
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
    SoundEffectService.instance.playPlayerJoinPop();
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
    double targetTx = isOnPool ? 0 : stickX * maxOffset;
    double targetTy = isOnPool ? 0 : stickY * maxOffset;

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
            begin: Offset(targetTx, targetTy),
            end: Offset(targetTx, targetTy),
          ),
          duration: isCentered
              ? const Duration(milliseconds: 350)
              : const Duration(milliseconds: 100),
          curve: isCentered ? Curves.elasticOut : Curves.easeOutCubic,
          builder: (context, fastStick, child) {
            return TweenAnimationBuilder<Offset>(
              tween: Tween(
                begin: Offset(targetTx, targetTy),
                end: Offset(targetTx, targetTy),
              ),
              duration: isCentered
                  ? const Duration(milliseconds: 450)
                  : const Duration(milliseconds: 250),
              curve: isCentered ? Curves.elasticOut : Curves.easeOutCubic,
              builder: (context, slowStick, child) {
                double faceTx = (slowStick.dx - fastStick.dx) * 0.9;
                double faceTy = (slowStick.dy - fastStick.dy) * 0.9;

                return Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..translate(fastStick.dx, fastStick.dy)
                    ..rotateZ(angle)
                    ..scaleByDouble(stretch, squash, 1, 1)
                    ..rotateZ(-angle),
                  child: PlayerFaceIndicator(
                    face: device.face,
                    size: size,
                    roundedSquare: isOnPool,
                    scale: baseScale,
                    opacity: indicatorOpacity,
                    translateX: 0,
                    translateY: 0,
                    faceTranslateX: faceTx,
                    faceTranslateY: faceTy,
                    pressed: isPressed,
                    borderColor: borderColor,
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
