import asyncio
import logging
import os
from pathlib import Path
import threading
from aiohttp import web
import vgamepad as vg
import aiohttp_cors
 
from src.routes.server_routes import ServerRoutes
from src.routes.http_routes import HTTPRoutes
from src.routes.websocket_routes import WebSocketRoutes
from src.lifecycle.app_lifecycle import AppLifecycle
from src.routes.register_routes import register_all_routes
from src.bootstrap.dependencies import build_dependencies
from src.cli.debug_cli import DebugCLI

from src.app.config import ServerConfig

import dotenv
dotenv.load_dotenv()


logging.basicConfig(level=logging.INFO)
LOG = logging.getLogger("piko-proto")

logging.getLogger("aiohttp.access").setLevel(logging.WARNING)
logging.getLogger("aiohttp.server").setLevel(logging.WARNING)

MAIN_LOOP = None

SERVER_CONFIG = ServerConfig(web_page_static_path=Path(os.getenv("WEB_PAGE_STATIC_PATH", "../controller_app/build/web")))

manager, admin_panel, debug_cli = build_dependencies(SERVER_CONFIG)

def create_app():
    app = web.Application()

    cors = aiohttp_cors.setup(app, defaults={
        "*": aiohttp_cors.ResourceOptions(
            allow_credentials=True,
            expose_headers="*",
            allow_headers="*",
        )
    })

    server_routes = ServerRoutes(SERVER_CONFIG.web_page_static_path)
    http_routes = HTTPRoutes(manager, admin_panel, SERVER_CONFIG.http_port, SERVER_CONFIG.ws_endpoint)
    websocket_routes = WebSocketRoutes(SERVER_CONFIG.ws_endpoint, manager, admin_panel)

    register_all_routes(app, server_routes, http_routes, websocket_routes)

    for route in list(app.router.routes()):
        cors.add(route)

    return app

def main():
    try:
        app = create_app()

        debug_cli = DebugCLI(manager, SERVER_CONFIG.http_port)
        threading.Thread(
            target=debug_cli.start,
            daemon=True
        ).start()

        app_lifecycle = AppLifecycle(manager)
        app_lifecycle.register_lifecycle(app)

        web.run_app(
            app,
            host="0.0.0.0",
            port=SERVER_CONFIG.http_port
        )

    finally:
        manager.cleanup_gamepads()

if __name__ == "__main__":
    main()