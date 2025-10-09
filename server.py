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

logging.basicConfig(level=logging.INFO)
LOG = logging.getLogger("piko-proto")

# CONFIG
HTTP_PORT = 8000
WS_ENDPOINT = "/ws"
MAX_PLAYERS = 8

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
    "LB": vg.XUSB_BUTTON.XUSB_GAMEPAD_LEFT_SHOULDER,
    "RB": vg.XUSB_BUTTON.XUSB_GAMEPAD_RIGHT_SHOULDER,
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

    # create gamepad
    try:
        gamepad = vg.VX360Gamepad()
        LOG.debug("Created virtual gamepad for slot %d", slot)
    except Exception as e:
        LOG.exception("Failed to create gamepad (ViGEmBus driver installed?)")
        await ws.send_json({"type":"error","msg":"vigem_error","detail":str(e)})
        await ws.close()
        return ws

    slots[slot] = {"ws": ws, "gamepad": gamepad, "addr": peer}
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
                    # vgamepad expects left_joystick_float(x_value_float, y_value_float)
                    # note: vgamepad left_joystick_float uses x:-1..1, y:-1..1
                    gamepad.left_joystick_float(x_value_float=x, y_value_float=y)
                    gamepad.update()
                elif data.get("type") == "button":
                    btn = data.get("id")
                    state = data.get("state")
                    # print(btn)
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
    return web.FileResponse(os.path.join('static', 'controller.html'))

app = web.Application()
app.router.add_get('/', index)
app.router.add_static('/', path='static', name='static')
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
        elif cmd in ["exit", "quit"]:
            print("Exiting...")
            os._exit(0)
        else:
            print("Commands: reset | show [a|b|x|y] | qrcode | exit")

if __name__ == '__main__':
    # Suppress aiohttp access logs
    logging.getLogger('aiohttp.access').setLevel(logging.WARNING)
    logging.getLogger('aiohttp.server').setLevel(logging.WARNING)
    LOG.debug("Starting server on 0.0.0.0:%d", HTTP_PORT)
    print_access_debug(HTTP_PORT)
    threading.Thread(target=command_line_interface, daemon=True).start()
    web.run_app(app, host='0.0.0.0', port=HTTP_PORT)
