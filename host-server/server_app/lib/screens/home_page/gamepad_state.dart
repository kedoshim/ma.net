import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/host_api_service.dart';

class DeviceInputState {
  final double stickX;
  final double stickY;
  final bool buttonPressed;
  final DateTime? lastActivity;

  const DeviceInputState({
    this.stickX = 0.0,
    this.stickY = 0.0,
    this.buttonPressed = false,
    this.lastActivity,
  });

  factory DeviceInputState.idle() => const DeviceInputState();

  DeviceInputState copyWith({
    double? stickX,
    double? stickY,
    bool? buttonPressed,
    DateTime? lastActivity,
  }) {
    return DeviceInputState(
      stickX: stickX ?? this.stickX,
      stickY: stickY ?? this.stickY,
      buttonPressed: buttonPressed ?? this.buttonPressed,
      lastActivity: lastActivity ?? this.lastActivity,
    );
  }
}

class GamepadState extends ChangeNotifier {
  final HostApiService _api;
  List<DeviceModel> pool = [];
  List<SlotModel> slots = [];
  StreamSubscription? _subscription;
  final Map<String, DeviceInputState> _inputStates = {};

  GamepadState(this._api);

  void _log(String action) {
    debugPrint(
      '[GAMEPAD STATE] $action | pool=${pool.length} slots=${slots.length}',
    );
  }

  void initialize() {
    fetchSlots();
    _subscription = _api.connectAdminSocket().listen((data) {
      if (data['type'] == 'slot_update') {
        final state = AssignementStat.fromJson(data['data']);
        pool = state.pool;
        slots = state.slots;
        notifyListeners();
      } else if (data['type'] == 'input_event') {
        final deviceId = data['deviceId'];
        if (data['event'] == 'stick') {
          updateJoystick(
            deviceId,
            (data['x'] as num).toDouble(),
            (data['y'] as num).toDouble(),
          );
        } else if (data['event'] == 'button') {
          updateButton(deviceId, data['state'] == 'down');
        }
      }
    });
  }

  Future<void> fetchSlots() async {
    try {
      final state = await _api.fetchSlots();

      pool = state.pool;
      slots = state.slots;
      for (int i = 0; i < slots.length; i++) {
        final slot = slots[i];
        print('Slot ${slot.slot} - ${slot.type}');
      }
      notifyListeners();
    } catch (e, stack) {
      debugPrint('fetchSlots error: $e');
      debugPrintStack(stackTrace: stack);
    }
  }

  Future<void> assignDevice(DeviceModel device, int slotIndex) async {
    // optimistic update
    pool.remove(device);
    slots[slotIndex].device = device;
    notifyListeners();

    try {
      await _api.assignDevice(device.id, slotIndex);
      // await fetchSlots();
    } catch (e) {
      // revert
      pool.add(device);
      slots[slotIndex].device = null;
      notifyListeners();
    }
  }

  Future<void> moveDevice(int fromIndex, int toIndex) async {
    final device = slots[fromIndex].device;
    if (device != null && slots[toIndex].device == null) {
      slots[fromIndex].device = null;
      slots[toIndex].device = device;
      notifyListeners();

      try {
        await _api.moveDevice(fromIndex, toIndex);
        // await fetchSlots();
      } catch (e) {
        slots[fromIndex].device = device;
        slots[toIndex].device = null;
        notifyListeners();
      }
    }
  }

  Future<void> swapDevices(int a, int b) async {
    final deviceA = slots[a].device;
    final deviceB = slots[b].device;

    slots[a].device = deviceB;
    slots[b].device = deviceA;
    notifyListeners();

    try {
      await _api.swapDevices(a, b);
      // await fetchSlots();
    } catch (e) {
      slots[a].device = deviceA;
      slots[b].device = deviceB;
      notifyListeners();
    }
  }

  Future<void> unassignDevice(int slotIndex) async {
    final device = slots[slotIndex].device;
    if (device != null) {
      pool.add(device);
      slots[slotIndex].device = null;
      notifyListeners();

      try {
        await _api.unassignDevice(slotIndex);
        // await fetchSlots();
      } catch (e) {
        pool.remove(device);
        slots[slotIndex].device = device;
        notifyListeners();
      }
    }
  }

  Future<void> replaceSlotDevice(DeviceModel device, int slotIndex) async {
    final oldDevice = slots[slotIndex].device;
    if (oldDevice != null) {
      pool.add(oldDevice);
    }
    pool.remove(device);
    slots[slotIndex].device = device;
    notifyListeners();

    try {
      await _api.assignDevice(device.id, slotIndex);
      await fetchSlots();
    } catch (e) {
      if (oldDevice != null) {
        pool.remove(oldDevice);
      }
      pool.add(device);
      slots[slotIndex].device = oldDevice;
      notifyListeners();
    }
  }

  DeviceInputState? getInputState(String deviceId) {
    return _inputStates[deviceId];
  }

  void updateJoystick(String deviceId, double x, double y) {
    final current = _inputStates[deviceId] ?? DeviceInputState.idle();
    _inputStates[deviceId] = current.copyWith(
      stickX: x,
      stickY: -y,
      lastActivity: DateTime.now(),
    );
    notifyListeners();
  }

  void updateButton(String deviceId, bool isPressed) {
    final current = _inputStates[deviceId] ?? DeviceInputState.idle();
    _inputStates[deviceId] = current.copyWith(
      buttonPressed: isPressed,
      lastActivity: DateTime.now(),
    );
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
