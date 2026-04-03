# server.py
import asyncio
import json
import logging
from aiohttp import web, WSMsgType
import vgamepad as vg
import os
import psutil
import socket
import threading
import sys
try:
    import qrcode
except ImportError:
    qrcode = None

import ctypes
from ctypes import wintypes
from enum import IntEnum

logging.basicConfig(level=logging.INFO)
LOG = logging.getLogger("piko-proto")

# CONFIG
HTTP_PORT = 8000
WS_ENDPOINT = "/ws"
MAX_PLAYERS = 8

WEB_PAGE_STATIC_PATH = os.path.join(os.path.dirname(__file__), "../controller_app/build/web")

# controller selection mode: 'auto' (default), 'force_ds4', 'force_x360'
controller_mode = 'auto'

# player slot state
slots = [None] * MAX_PLAYERS  # each slot -> {'ws': websocket, 'gamepad': vg.VX360Gamepad(), 'addr': addr}

# helper to find free slot
def allocate_slot():
    for i in range(MAX_PLAYERS):
        if slots[i] is None:
            return i
    return None

# map simple button ids to vgamepad constants
BUTTON_MAP = {
    "A": vg.XUSB_BUTTON.XUSB_GAMEPAD_A,
    "B": vg.XUSB_BUTTON.XUSB_GAMEPAD_B,
    "X": vg.XUSB_BUTTON.XUSB_GAMEPAD_X,
    "Y": vg.XUSB_BUTTON.XUSB_GAMEPAD_Y,
    "UP": vg.XUSB_BUTTON.XUSB_GAMEPAD_DPAD_UP,
    "DOWN": vg.XUSB_BUTTON.XUSB_GAMEPAD_DPAD_DOWN,
    "LEFT": vg.XUSB_BUTTON.XUSB_GAMEPAD_DPAD_LEFT,
    "RIGHT": vg.XUSB_BUTTON.XUSB_GAMEPAD_DPAD_RIGHT,
    "START": vg.XUSB_BUTTON.XUSB_GAMEPAD_START,
    "SELECT": vg.XUSB_BUTTON.XUSB_GAMEPAD_BACK,
    "LB": vg.XUSB_BUTTON.XUSB_GAMEPAD_LEFT_SHOULDER,
    "RB": vg.XUSB_BUTTON.XUSB_GAMEPAD_RIGHT_SHOULDER,
}

# Map the same logical button ids to DS4 constants when using VDS4Gamepad
DS4_BUTTON_MAP = {
    "A": vg.DS4_BUTTONS.DS4_BUTTON_CROSS,
    "B": vg.DS4_BUTTONS.DS4_BUTTON_CIRCLE,
    "X": vg.DS4_BUTTONS.DS4_BUTTON_SQUARE,
    "Y": vg.DS4_BUTTONS.DS4_BUTTON_TRIANGLE,
    "START": vg.DS4_BUTTONS.DS4_BUTTON_OPTIONS,
    "SELECT": vg.DS4_BUTTONS.DS4_BUTTON_SHARE,
    "LB": vg.DS4_BUTTONS.DS4_BUTTON_SHOULDER_LEFT,
    "RB": vg.DS4_BUTTONS.DS4_BUTTON_SHOULDER_RIGHT,
    "DOWN": vg.DS4_DPAD_DIRECTIONS.DS4_BUTTON_DPAD_SOUTH,
    "UP": vg.DS4_DPAD_DIRECTIONS.DS4_BUTTON_DPAD_NORTH,
    "LEFT": vg.DS4_DPAD_DIRECTIONS.DS4_BUTTON_DPAD_WEST,
    "RIGHT": vg.DS4_DPAD_DIRECTIONS.DS4_BUTTON_DPAD_EAST,
}

async def websocket_handler(request):
    ws = web.WebSocketResponse()
    await ws.prepare(request)
    peer = request.remote
    LOG.debug("WebSocket connected from %s", peer)

    # allocate a slot
    slot = allocate_slot()
    if slot is None:
        await ws.send_json({"type":"error","msg":"server_full"})
        await ws.close()
        return ws

    # create gamepad: prefer X360 (XInput). If creation fails (e.g. XInput limit reached),
    # fall back to a DS4 virtual device and print a warning.
    gamepad = None
    gamepad_type = None
    # Decide which gamepad type to create (avoid creating >4 XInput devices)
    gp_choice = decide_gamepad_type(slot_index=slot)
    if gp_choice == 'ds4':
        try:
            gamepad = vg.VDS4Gamepad()
            gamepad_type = 'ds4'
            warning_msg = (f"Using DS4 virtual controller for slot {slot} (decided by policy).")
            print(warning_msg)
            LOG.warning(warning_msg)
        except Exception as e:
            LOG.exception("Failed to create VDS4Gamepad fallback")
            await ws.send_json({"type":"error","msg":"vigem_error","detail":str(e)})
            await ws.close()
            return ws
    else:
        try:
            gamepad = vg.VX360Gamepad()
            gamepad_type = 'x360'
            LOG.debug("Created virtual VX360Gamepad for slot %d", slot)
        except Exception as e:
            # If VX360 creation failed for any reason, fallback to DS4 and warn
            LOG.warning("VX360Gamepad creation failed: %s. Falling back to VDS4Gamepad.", e)
            try:
                gamepad = vg.VDS4Gamepad()
                gamepad_type = 'ds4'
                warning_msg = (
                    f"Warning: XInput (VX360) unavailable. Using DS4 virtual controller for slot {slot} instead."
                )
                print(warning_msg)
                LOG.warning(warning_msg)
            except Exception as e2:
                LOG.exception("Failed to create gamepad (ViGEmBus driver installed?)")
                await ws.send_json({"type":"error","msg":"vigem_error","detail":str(e2)})
                await ws.close()
                return ws

    slots[slot] = {"ws": ws, "gamepad": gamepad, "addr": peer, "type": gamepad_type}
    # send assigned slot back
    await ws.send_json({"type":"assigned","slot":slot})
    print(f"Player {slot+1} connected")
    LOG.debug("Assigned slot %d to %s", slot, peer)

    try:
        async for msg in ws:
            if msg.type == WSMsgType.TEXT:
                try:
                    data = json.loads(msg.data)
                except Exception:
                    continue
                # handle messages
                if data.get("type") == "stick":
                    # expects x,y floats -1..1
                    x = float(data.get("x",0.0))
                    y = float(data.get("y",0.0))
                    # invert Y axis for DS4 devices
                    gp_type = slots[slot].get("type") if slots[slot] else None
                    if gp_type == 'ds4':
                        y = -y
                    # vgamepad expects left_joystick_float(x_value_float, y_value_float)
                    # note: vgamepad left_joystick_float uses x:-1..1, y:-1..1
                    gamepad.left_joystick_float(x_value_float=x, y_value_float=y)
                    gamepad.update()
                elif data.get("type") == "button":
                    btn = data.get("id")
                    state = data.get("state")
                    # choose map based on underlying virtual device type
                    gp_type = slots[slot].get("type") if slots[slot] else None
                    if gp_type == 'ds4':
                        if btn in DS4_BUTTON_MAP:
                            const = DS4_BUTTON_MAP[btn]
                            if state == "down":
                                if const in [vg.DS4_DPAD_DIRECTIONS.DS4_BUTTON_DPAD_NORTH,
                                             vg.DS4_DPAD_DIRECTIONS.DS4_BUTTON_DPAD_SOUTH,
                                             vg.DS4_DPAD_DIRECTIONS.DS4_BUTTON_DPAD_WEST,
                                             vg.DS4_DPAD_DIRECTIONS.DS4_BUTTON_DPAD_EAST]:
                                    # D-Pad direction
                                    gamepad.directional_pad(const)
                                else:
                                    gamepad.press_button(button=const)
                            else:
                                gamepad.release_button(button=const)
                                gamepad.reset()
                            gamepad.update()
                        else:
                            LOG.info("No DS4 mapping for button %s", btn)
                    else:
                        # default X360 behavior
                        if btn in BUTTON_MAP:
                            if state == "down":
                                gamepad.press_button(button=BUTTON_MAP[btn])
                            else:
                                gamepad.release_button(button=BUTTON_MAP[btn])
                            gamepad.update()
                elif data.get("type") == "keepalive":
                    # just ignore or update last-seen timestamp if you do timeouts
                    pass
                elif data.get("type") == "raw":
                    # if you want to send raw mask or raw mapping
                    pass
            elif msg.type == WSMsgType.ERROR:
                LOG.error("WS error %s", ws.exception())
    except asyncio.CancelledError:
        LOG.debug("WS cancelled for slot %d", slot)
    finally:
        # cleanup slot
        LOG.debug("Client disconnected: freeing slot %s", slot)
        print(f"Player {slot+1} disconnected")
        try:
            # reset & remove gamepad
            if slots[slot] and slots[slot]["gamepad"]:
                slots[slot]["gamepad"].reset()
                slots[slot]["gamepad"].update()
        except Exception as e:
            LOG.exception("Error resetting gamepad: %s", e)
        slots[slot] = None
        await ws.close()

    return ws

# simple static file serving
async def index(request):
    return web.FileResponse(os.path.join(WEB_PAGE_STATIC_PATH, 'index.html'))

app = web.Application()
app.router.add_get('/', index)
app.router.add_static('/', path=WEB_PAGE_STATIC_PATH, name='static')
app.router.add_get(WS_ENDPOINT, websocket_handler)

def get_local_ipv4_addresses():
    addrs = []
    for iface, snics in psutil.net_if_addrs().items():
        for snic in snics:
            if snic.family == socket.AF_INET:
                # Filter out localhost
                if not snic.address.startswith("127."):
                    addrs.append((iface, snic.address))
    return addrs


def count_xinput_connected():
    """Return number of XInput devices that report connected (0..4).

    Uses XInputGetState from available XInput DLLs. If not running on Windows or
    the call fails, returns 0 which will cause the server to prefer VX360.
    """
    if sys.platform != 'win32':
        return 0

    dll_names = ["xinput1_4.dll", "xinput1_3.dll", "xinput9_1_0.dll", "xinput1_2.dll"]
    xinput = None
    for name in dll_names:
        try:
            xinput = ctypes.WinDLL(name)
            break
        except Exception:
            xinput = None
    if xinput is None:
        return 0

    # Prototype: DWORD XInputGetState(DWORD dwUserIndex, XINPUT_STATE* pState)
    try:
        XInputGetState = xinput.XInputGetState
        XInputGetState.argtypes = [wintypes.DWORD, ctypes.c_void_p]
        XInputGetState.restype = wintypes.DWORD
    except Exception:
        return 0

    connected = 0
    # Query indices 0..3
    for i in range(4):
        # pass a buffer large enough for XINPUT_STATE
        buf = ctypes.create_string_buffer(128)
        try:
            res = XInputGetState(i, ctypes.byref(buf))
            # ERROR_SUCCESS == 0
            if res == 0:
                connected += 1
        except Exception:
            # ignore errors per-index
            pass
    return connected


def decide_gamepad_type(slot_index=None):
    """Decide whether to create an 'x360' or 'ds4' gamepad.

    Logic:
    - If controller_mode is forced, obey it.
    - Otherwise, count system XInput devices (0..4) and also count how many
      VX360 devices we already created in `slots`. If total >= 4, choose DS4.
    """
    global controller_mode
    if controller_mode == 'force_ds4':
        return 'ds4'
    if controller_mode == 'force_x360':
        return 'x360'

    # auto mode: combine system XInput count with our current x360 slots
    try:
        sys_count = count_xinput_connected()
    except Exception:
        sys_count = 0

    existing_x360 = 0
    for s in slots:
        if s and s.get('type') == 'x360':
            existing_x360 += 1

    total_xinput_like = sys_count + existing_x360
    if total_xinput_like >= 4:
        return 'ds4'
    return 'x360'

def print_access_debug(port):
    addrs = get_local_ipv4_addresses()
    print("\nAccess the site from another device using one of these URLs:")
    for iface, ip in addrs:
        url = f"http://{ip}:{port}"
        iface_lower = iface.lower()
        if qrcode and ("conexão local* 10" in iface_lower or "wi-fi" in iface_lower or "wifi" in iface_lower):
            print(f"  {iface}: {url}")  
            qr = qrcode.QRCode()
            qr.add_data(url)
            qr.make(fit=True)
            print(f"  QR for {iface}:")
            qr.print_ascii(invert=True)
    if not addrs:
        print("No non-local IPv4 addresses found.")
    if not qrcode:
        print("(Install 'qrcode' package for QR code support)")

def command_line_interface():
    while True:
        try:
            cmd = input("\n> ").strip().lower()
        except EOFError:
            break
        if cmd == "reset":
            print("Resetting all controllers...")
            for slot in slots:
                if slot and slot["gamepad"]:
                    slot["gamepad"].reset()
                    slot["gamepad"].update()
            print("All controllers reset.")
        elif cmd.startswith("show "):
            btn = cmd.split(" ", 1)[1].strip().upper()
            if btn in ["A", "B", "X", "Y"]:
                print(f"Toggling visibility for button {btn}...")
                for slot in slots:
                    if slot and slot["ws"]:
                        try:
                            slot["ws"].send_json({"type": "toggle_btn", "btn": btn})
                        except Exception:
                            pass
            else:
                print("Usage: show [a|b|x|y]")
        elif cmd == "qrcode":
            print_access_debug(HTTP_PORT)
        elif cmd.startswith("force "):
            arg = cmd.split(" ", 1)[1].strip().lower()
            if arg in ["ds4", "x360", "auto"]:
                if arg == "ds4":
                    controller_mode = 'force_ds4'
                elif arg == "x360":
                    controller_mode = 'force_x360'
                else:
                    controller_mode = 'auto'
                print(f"Controller selection mode set to: {controller_mode}")
            else:
                print("Usage: force [ds4|x360|auto]")
        elif cmd in ["exit", "quit"]:
            print("Exiting...")
            os._exit(0)
        else:
            print("Commands: reset | show [a|b|x|y] | qrcode | force [ds4|x360|auto] | exit")

if __name__ == '__main__':
    # Suppress aiohttp access logs
    logging.getLogger('aiohttp.access').setLevel(logging.WARNING)
    logging.getLogger('aiohttp.server').setLevel(logging.WARNING)
    LOG.debug("Starting server on 0.0.0.0:%d", HTTP_PORT)
    print_access_debug(HTTP_PORT)
    threading.Thread(target=command_line_interface, daemon=True).start()
    web.run_app(app, host='0.0.0.0', port=HTTP_PORT)
