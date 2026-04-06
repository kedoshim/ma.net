import os

import qrcode

from src.core.slot_handler import reset_slot_gamepad
from src.utils.network import get_local_ipv4_addresses


class DebugCLI:
    def __init__(self, manager, port):
        self.manager = manager
        self.port = port

    def start(self):
        self.print_access_debug()
        self.command_line_interface()

    def print_access_debug(self):
        addrs = get_local_ipv4_addresses()

        print("\nAccess the site from another device using:")

        for iface, ip in addrs:
            url = f"http://{ip}:{self.port}"
            print(f"  {iface}: {url}")

            iface_lower = iface.lower()

            if qrcode and (
                "wifi" in iface_lower
                or "wi-fi" in iface_lower
                or "conexão local" in iface_lower
            ):
                qr = qrcode.QRCode()
                qr.add_data(url)
                qr.make(fit=True)

                print(f"\nQR for {iface}:")
                qr.print_ascii(invert=True)

        if not addrs:
            print("No non-local IPv4 addresses found.")

        if not qrcode:
            print("(Install qrcode package for QR support)")

    def command_line_interface(self):
        while True:
            try:
                cmd = input("\n> ").strip().lower()
            except EOFError:
                break

            if cmd == "reset":
                print("Resetting all controllers...")
                for slot in self.manager.slots:
                    reset_slot_gamepad(slot)

            elif cmd.startswith("swap "):
                try:
                    _, a, b = cmd.split()
                    self.manager.swap_slots(int(a), int(b))
                    print(f"Swapped {a} <-> {b}")
                except Exception:
                    print("Usage: swap <slot_a> <slot_b>")

            elif cmd == "slots":
                for slot in self.manager.slots:
                    print(
                        f"[{slot.slot_id}] "
                        f"name={slot.player_name} "
                        f"device={slot.assigned_device_id} "
                        f"connected={slot.connected}"
                    )

            elif cmd == "qrcode":
                self.print_access_debug(self.port)

            elif cmd in ["exit", "quit"]:
                os._exit(0)

            else:
                print("Commands: reset | swap a b | slots | qrcode | exit")