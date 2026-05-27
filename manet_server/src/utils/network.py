
from src.services.connection_service import ConnectionService


def get_local_ipv4_addresses():
    service = ConnectionService(port=8000, ws_endpoint="/ws")
    snapshot = service.get_snapshot()
    return [
        (option.interface_name, option.ip)
        for option in snapshot.connections
        if option.ip != "127.0.0.1"
    ]


def get_best_access_url(HTTP_PORT=8000):
    service = ConnectionService(port=HTTP_PORT, ws_endpoint="/ws")
    return service.get_connection_info_payload()["url"]
