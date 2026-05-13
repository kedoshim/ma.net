import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/host_api_service.dart';

class DeviceInputState {
  final double x;
  final double y;
  final bool isButtonPressed;
  final DateTime? lastActivity;

  const DeviceInputState({
    this.x = 0,
    this.y = 0,
    this.isButtonPressed = false,
    this.lastActivity,
  });
}

class GamepadState extends ChangeNotifier {
  final HostApiService _api;
  List<DeviceModel> pool = [];
  List<SlotModel> slots = [];
  StreamSubscription? _subscription;
  final Map<int, DeviceInputState> slotInputs = {};

  GamepadState(this._api);

  void _log(String action) {
    debugPrint(
      '[GAMEPAD STATE] $action | pool=${pool.length} slots=${slots.length}',
    );
  }

  void initialize() {
    fetchSlots();
    _subscription = _api.connectAdminSocket().listen((state) {
      pool = state.pool;
      slots = state.slots;
      notifyListeners();
    });
  }

  Future<void> fetchSlots() async {
    try {
      final state = await _api.fetchSlots();

      pool = state.pool;
      slots = state.slots;
      for (int i = 0; i < slots.length; i++) {
        final slot = slots[i];
        print('Slot ${slot?.slot} - ${slot?.type}');
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

  void updateSlotInput(int slot, double x, double y, bool pressed) {
    slotInputs[slot] = DeviceInputState(
      x: x,
      y: y,
      isButtonPressed: pressed,
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
