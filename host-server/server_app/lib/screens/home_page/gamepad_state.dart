import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/host_api_service.dart';

class GamepadState extends ChangeNotifier {
  final HostApiService _api;
  List<DeviceModel> pool = [];
  List<DeviceModel?> slots = [];
  StreamSubscription? _subscription;

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
      notifyListeners();
    } catch (e, stack) {
      debugPrint('fetchSlots error: $e');
      debugPrintStack(stackTrace: stack);
    }
  }

  Future<void> assignDevice(DeviceModel device, int slotIndex) async {
    // optimistic update
    pool.remove(device);
    slots[slotIndex] = device;
    notifyListeners();

    try {
      await _api.assignDevice(device.id, slotIndex);
      // await fetchSlots();
    } catch (e) {
      // revert
      pool.add(device);
      slots[slotIndex] = null;
      notifyListeners();
    }
  }

  Future<void> moveDevice(int fromIndex, int toIndex) async {
    final device = slots[fromIndex];
    if (device != null && slots[toIndex] == null) {
      slots[fromIndex] = null;
      slots[toIndex] = device;
      notifyListeners();

      try {
        await _api.moveDevice(fromIndex, toIndex);
        // await fetchSlots();
      } catch (e) {
        slots[fromIndex] = device;
        slots[toIndex] = null;
        notifyListeners();
      }
    }
  }

  Future<void> swapDevices(int a, int b) async {
    final deviceA = slots[a];
    final deviceB = slots[b];

    slots[a] = deviceB;
    slots[b] = deviceA;
    notifyListeners();

    try {
      await _api.swapDevices(a, b);
      // await fetchSlots();
    } catch (e) {
      slots[a] = deviceA;
      slots[b] = deviceB;
      notifyListeners();
    }
  }

  Future<void> unassignDevice(int slotIndex) async {
    final device = slots[slotIndex];
    if (device != null) {
      pool.add(device);
      slots[slotIndex] = null;
      notifyListeners();

      try {
        await _api.unassignDevice(slotIndex);
        // await fetchSlots();
      } catch (e) {
        pool.remove(device);
        slots[slotIndex] = device;
        notifyListeners();
      }
    }
  }

  Future<void> replaceSlotDevice(DeviceModel device, int slotIndex) async {
    final oldDevice = slots[slotIndex];
    if (oldDevice != null) {
      pool.add(oldDevice);
    }
    pool.remove(device);
    slots[slotIndex] = device;
    notifyListeners();

    try {
      await _api.assignDevice(device.id, slotIndex);
      await fetchSlots();
    } catch (e) {
      if (oldDevice != null) {
        pool.remove(oldDevice);
      }
      pool.add(device);
      slots[slotIndex] = oldDevice;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
