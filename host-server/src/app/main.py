import asyncio
import logging
import os
import threading
from aiohttp import web
import vgamepad as vg
import aiohttp_cors
 
from routes.websocket_routes import WebSocketRoutes
from routes.http_routes import HTTPRoutes
from src.lifecycle.app_lifecycle import register_lifecycle
from src.routes.register_routes import register_all_routes
from bootstrap.dependencies import build_dependencies

from src.app.config import ServerConfig


logging.basicConfig(level=logging.INFO)
LOG = logging.getLogger("piko-proto")

logging.getLogger("aiohttp.access").setLevel(logging.WARNING)
logging.getLogger("aiohttp.server").setLevel(logging.WARNING)

MAIN_LOOP = None

SERVER_CONFIG = ServerConfig()

manager, admin_panel, debug_cli = build_dependencies(SERVER_CONFIG)
manager.initialize_slots()


async def index(request):
    return web.FileResponse(
        os.path.join(ServerConfig.web_page_static_path, "index.html")
    )


def create_app():
    app = web.Application()

    cors = aiohttp_cors.setup(app, defaults={
        "*": aiohttp_cors.ResourceOptions(
            allow_credentials=True,
            expose_headers="*",
            allow_headers="*",
        )
    })

    http_routes = HTTPRoutes(manager, admin_panel, SERVER_CONFIG.http_port, SERVER_CONFIG.ws_endpoint)
    websocket_services = WebSocketRoutes(manager, admin_panel)

    register_all_routes(app, http_routes, websocket_services)

    for route in list(app.router.routes()):
        cors.add(route)

    return app

def main():
    try:
        app = create_app()

        threading.Thread(
            target=debug_cli.start,
            daemon=True
        ).start()

        register_lifecycle(app)

        loop = asyncio.get_event_loop()

        manager.set_main_loop(loop) 

        web.run_app(
            app,
            host="0.0.0.0",
            port=SERVER_CONFIG.http_port
        )

    finally:
        manager.cleanup_gamepads()

if __name__ == "__main__":
    main()