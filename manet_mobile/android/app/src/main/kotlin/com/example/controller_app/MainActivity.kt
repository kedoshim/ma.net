package com.kedoshim.manet_mobile

import android.content.Context
import android.hardware.input.InputManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.VibrationEffect
import android.view.InputDevice
import android.view.KeyEvent
import android.view.MotionEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import kotlin.math.abs
import kotlin.math.max

/**
 * Reads physical gamepads (Bluetooth / USB) attached to the phone and streams
 * their state to Dart, which relays it to MaNet. Flutter itself only sees
 * gamepad buttons as key events and never the sticks, hence the native side.
 */
class MainActivity : FlutterActivity(), InputManager.InputDeviceListener {
    private class PadState(val name: String) {
        val buttons = mutableSetOf<String>()
        var lx = 0f
        var ly = 0f
        var rx = 0f
        var ry = 0f
        var lt = 0f
        var rt = 0f
        // Pads that report the d-pad as a hat axis instead of key events.
        val hat = mutableSetOf<String>()
    }

    private val pads = mutableMapOf<Int, PadState>()
    private var events: EventChannel.EventSink? = null
    // While relaying, pad input is consumed so Flutter doesn't also treat it
    // as navigation (B would go "back", the d-pad would move focus).
    private var capturing = false
    private var inputManager: InputManager? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        EventChannel(messenger, "manet/gamepad/events").setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
                    events = sink
                    refreshDevices()
                }

                override fun onCancel(arguments: Any?) {
                    events = null
                }
            },
        )

        MethodChannel(messenger, "manet/gamepad").setMethodCallHandler { call, result ->
            when (call.method) {
                "setCapture" -> {
                    capturing = call.argument<Boolean>("active") == true
                    result.success(null)
                }
                "rumble" -> {
                    rumble(
                        call.argument<Int>("id") ?: -1,
                        call.argument<Double>("weak") ?: 0.0,
                        call.argument<Double>("strong") ?: 0.0,
                    )
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        inputManager = (getSystemService(Context.INPUT_SERVICE) as InputManager).also {
            it.registerInputDeviceListener(this, mainHandler)
        }
    }

    override fun onDestroy() {
        inputManager?.unregisterInputDeviceListener(this)
        super.onDestroy()
    }

    private fun isGamepad(device: InputDevice?): Boolean {
        if (device == null || device.isVirtual) return false
        val sources = device.sources
        return sources and InputDevice.SOURCE_GAMEPAD == InputDevice.SOURCE_GAMEPAD ||
            sources and InputDevice.SOURCE_JOYSTICK == InputDevice.SOURCE_JOYSTICK
    }

    private fun refreshDevices() {
        val seen = mutableSetOf<Int>()
        for (id in InputDevice.getDeviceIds()) {
            val device = InputDevice.getDevice(id)
            if (!isGamepad(device)) continue
            seen.add(id)
            if (!pads.containsKey(id)) pads[id] = PadState(device!!.name ?: "Gamepad")
        }
        pads.keys.retainAll(seen)
        sendDevices()
    }

    private fun sendDevices() {
        events?.success(
            mapOf(
                "event" to "devices",
                "pads" to pads.map { (id, pad) -> mapOf("id" to id.toString(), "name" to pad.name) },
            ),
        )
    }

    private fun sendState(id: Int, pad: PadState) {
        events?.success(
            mapOf(
                "event" to "state",
                "id" to id.toString(),
                "buttons" to (pad.buttons + pad.hat).toList(),
                "lx" to pad.lx.toDouble(),
                "ly" to pad.ly.toDouble(),
                "rx" to pad.rx.toDouble(),
                "ry" to pad.ry.toDouble(),
                "lt" to pad.lt.toDouble(),
                "rt" to pad.rt.toDouble(),
            ),
        )
    }

    private fun padFor(device: InputDevice?): Pair<Int, PadState>? {
        if (!isGamepad(device)) return null
        val id = device!!.id
        val pad = pads[id] ?: PadState(device.name ?: "Gamepad").also {
            pads[id] = it
            sendDevices()
        }
        return id to pad
    }

    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        val name = KEY_NAMES[event.keyCode]
        val entry = if (name != null) padFor(event.device) else null
        if (name == null || entry == null) return super.dispatchKeyEvent(event)

        val (id, pad) = entry
        val changed = when (event.action) {
            KeyEvent.ACTION_DOWN -> pad.buttons.add(name)
            KeyEvent.ACTION_UP -> pad.buttons.remove(name)
            else -> false
        }
        if (changed) sendState(id, pad)
        return if (capturing) true else super.dispatchKeyEvent(event)
    }

    override fun dispatchGenericMotionEvent(event: MotionEvent): Boolean {
        if (event.source and InputDevice.SOURCE_JOYSTICK != InputDevice.SOURCE_JOYSTICK ||
            event.action != MotionEvent.ACTION_MOVE
        ) {
            return super.dispatchGenericMotionEvent(event)
        }
        val entry = padFor(event.device) ?: return super.dispatchGenericMotionEvent(event)
        val (id, pad) = entry
        val device = event.device

        pad.lx = axis(event, device, MotionEvent.AXIS_X)
        pad.ly = -axis(event, device, MotionEvent.AXIS_Y)
        // Most pads put the right stick on Z/RZ; some on RX/RY.
        if (device.getMotionRange(MotionEvent.AXIS_Z, event.source) != null) {
            pad.rx = axis(event, device, MotionEvent.AXIS_Z)
            pad.ry = -axis(event, device, MotionEvent.AXIS_RZ)
        } else {
            pad.rx = axis(event, device, MotionEvent.AXIS_RX)
            pad.ry = -axis(event, device, MotionEvent.AXIS_RY)
        }
        pad.lt = max(event.getAxisValue(MotionEvent.AXIS_LTRIGGER), event.getAxisValue(MotionEvent.AXIS_BRAKE))
        pad.rt = max(event.getAxisValue(MotionEvent.AXIS_RTRIGGER), event.getAxisValue(MotionEvent.AXIS_GAS))

        val hatX = event.getAxisValue(MotionEvent.AXIS_HAT_X)
        val hatY = event.getAxisValue(MotionEvent.AXIS_HAT_Y)
        pad.hat.clear()
        if (hatX < -0.5f) pad.hat.add("LEFT")
        if (hatX > 0.5f) pad.hat.add("RIGHT")
        if (hatY < -0.5f) pad.hat.add("UP")
        if (hatY > 0.5f) pad.hat.add("DOWN")

        sendState(id, pad)
        return if (capturing) true else super.dispatchGenericMotionEvent(event)
    }

    /** Axis value with the device's own flat (dead) zone removed. */
    private fun axis(event: MotionEvent, device: InputDevice, axis: Int): Float {
        val value = event.getAxisValue(axis)
        val flat = device.getMotionRange(axis, event.source)?.flat ?: 0f
        return if (abs(value) > flat) value else 0f
    }

    private fun rumble(id: Int, weak: Double, strong: Double) {
        val device = InputDevice.getDevice(id) ?: return
        val amplitude = (max(weak, strong) * 255).toInt().coerceIn(0, 255)
        try {
            val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                device.vibratorManager.defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                device.vibrator
            }
            if (!vibrator.hasVibrator()) return
            if (amplitude == 0) {
                vibrator.cancel()
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                // Held until the next rumble update (the server sends a stop).
                vibrator.vibrate(VibrationEffect.createOneShot(2000, amplitude))
            } else {
                @Suppress("DEPRECATION")
                vibrator.vibrate(2000)
            }
        } catch (_: Exception) {
        }
    }

    override fun onInputDeviceAdded(deviceId: Int) = refreshDevices()

    override fun onInputDeviceRemoved(deviceId: Int) = refreshDevices()

    override fun onInputDeviceChanged(deviceId: Int) = refreshDevices()

    companion object {
        // Android keycodes -> MaNet (XInput-style) button ids.
        private val KEY_NAMES = mapOf(
            KeyEvent.KEYCODE_BUTTON_A to "A",
            KeyEvent.KEYCODE_BUTTON_B to "B",
            KeyEvent.KEYCODE_BUTTON_X to "X",
            KeyEvent.KEYCODE_BUTTON_Y to "Y",
            KeyEvent.KEYCODE_BUTTON_L1 to "LB",
            KeyEvent.KEYCODE_BUTTON_R1 to "RB",
            KeyEvent.KEYCODE_BUTTON_L2 to "LT",
            KeyEvent.KEYCODE_BUTTON_R2 to "RT",
            KeyEvent.KEYCODE_BUTTON_THUMBL to "LSB",
            KeyEvent.KEYCODE_BUTTON_THUMBR to "RSB",
            KeyEvent.KEYCODE_BUTTON_START to "START",
            KeyEvent.KEYCODE_BUTTON_SELECT to "SELECT",
            KeyEvent.KEYCODE_BUTTON_MODE to "HOME",
            KeyEvent.KEYCODE_DPAD_UP to "UP",
            KeyEvent.KEYCODE_DPAD_DOWN to "DOWN",
            KeyEvent.KEYCODE_DPAD_LEFT to "LEFT",
            KeyEvent.KEYCODE_DPAD_RIGHT to "RIGHT",
        )
    }
}
