import asyncio
import logging
import socket
import psutil
from src.services.connection_service import ConnectionService
from src.core.admin_panel import AdminPanel

LOG = logging.getLogger("network_monitor")


def get_fast_network_signature() -> set[tuple[str, str]]:
    signature = set()
    try:
        addrs = psutil.net_if_addrs()
        stats = psutil.net_if_stats()
        for iface_name, iface_addrs in addrs.items():
            stat = stats.get(iface_name)
            if stat and stat.isup:
                for snic in iface_addrs:
                    if snic.family == socket.AF_INET:
                        ip = snic.address
                        if ip != "127.0.0.1" and not ip.startswith("169.254"):
                            signature.add((iface_name, ip))
    except Exception as exc:
        LOG.debug("Failed to get fast network signature: %s", exc)
    return signature


async def network_monitor_task(connection_service: ConnectionService, admin_panel: AdminPanel):
    LOG.info("Starting network monitor background task...")
    last_signature = get_fast_network_signature()

    while True:
        await asyncio.sleep(2.0)
        try:
            current_signature = get_fast_network_signature()
            if current_signature != last_signature:
                LOG.info(
                    "Network change detected! Old: %s, New: %s",
                    last_signature,
                    current_signature,
                )
                last_signature = current_signature

                # Refresh connection snapshot
                snapshot = connection_service.refresh_snapshot()
                selected = snapshot.selected
                LOG.info("Selected network option updated: %s (%s)", selected.ip, selected.kind)

                # Broadcast to admin clients
                admin_panel.broadcast_event({
                    "type": "network_update",
                    "data": {
                        "selectedConnection": selected.to_payload(
                            connection_service.port,
                            connection_service.ws_endpoint,
                        ),
                        "connections": [
                            option.to_payload(
                                connection_service.port,
                                connection_service.ws_endpoint,
                            )
                            for option in snapshot.connections
                        ],
                    }
                })
        except asyncio.CancelledError:
            break
        except Exception as exc:
            LOG.exception("Error in network monitor background task: %s", exc)
