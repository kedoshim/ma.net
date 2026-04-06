
import socket

import psutil


def get_local_ipv4_addresses():
    addrs = []

    for iface, snics in psutil.net_if_addrs().items():
        for snic in snics:
            if snic.family == socket.AF_INET:
                if not snic.address.startswith("127."):
                    addrs.append((iface, snic.address))

    return addrs
def get_best_access_url(HTTP_PORT = 8000):
    addrs = get_local_ipv4_addresses()

    if not addrs:
        return f"http://127.0.0.1:{HTTP_PORT}"

    preferred_keywords = [
        "wifi",
        "wi-fi",
        "wlan",
        "wireless",
    ]

    for iface, ip in addrs:
        iface_lower = iface.lower()
        if any(k in iface_lower for k in preferred_keywords):
            return f"http://{ip}:{HTTP_PORT}"

    return f"http://{addrs[0][1]}:{HTTP_PORT}"