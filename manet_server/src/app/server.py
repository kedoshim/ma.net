from aiohttp import web
import aiohttp_cors
import threading

from src.routes.server_routes import ServerRoutes
from src.routes.http_routes import HTTPRoutes
from src.routes.websocket_routes import WebSocketRoutes
from src.routes.file_routes import FileRoutes
from src.lifecycle.app_lifecycle import AppLifecycle
from src.routes.register_routes import register_all_routes
from src.bootstrap.dependencies import build_dependencies
from src.cli.debug_cli import DebugCLI
from src.services.connection_service import ConnectionService
from src.services.network_diagnostics_service import NetworkDiagnosticsService

import logging

LOG = logging.getLogger("piko-proto") 


def create_app(config):
    LOG.info("Initializing MaNet Server dependencies...")
    manager, admin_panel, _ = build_dependencies(config)
    connection_service = ConnectionService(
        port=config.http_port,
        ws_endpoint=config.ws_endpoint,
    )
    diagnostics_service = NetworkDiagnosticsService(
        manager,
        connection_service,
    )

    LOG.info("Creating aiohttp web application...")
    app = web.Application()

    cors = aiohttp_cors.setup(app, defaults={
        "*": aiohttp_cors.ResourceOptions(
            allow_credentials=True,
            expose_headers="*",
            allow_headers="*",
        )
    })

    server_routes = ServerRoutes(config.web_page_static_path)
    http_routes = HTTPRoutes(
        manager,
        admin_panel,
        config.http_port,
        config.ws_endpoint,
        connection_service,
        diagnostics_service,
    )

    websocket_routes = WebSocketRoutes(
        config.ws_endpoint,
        manager,
        admin_panel,
        connection_service,
    )

    file_routes = FileRoutes()

    LOG.info("Registering application routes...")
    register_all_routes(
        app,
        server_routes,
        http_routes,
        websocket_routes,
        file_routes
    )

    for route in list(app.router.routes()):
        cors.add(route)

    lifecycle = AppLifecycle(manager)
    lifecycle.register_lifecycle(app)

    LOG.info("Application setup complete.")
    return app, manager


def run_server(config):
    LOG.info(f"Starting server on port {config.http_port} (Debug mode: {config.debug})")
    app, manager = create_app(config)

    if config.debug:
        LOG.info("Starting Debug CLI thread...")
        debug_cli = DebugCLI(manager, config.http_port)

        threading.Thread(
            target=debug_cli.start,
            daemon=True
        ).start()

    try:
        LOG.info("Running aiohttp server...")
        web.run_app(
            app,
            host="0.0.0.0",
            port=config.http_port,
            print=None  # Suppresses the default aiohttp stdout print to keep logs clean
        )
    except Exception as e:
        LOG.exception("Server encountered a fatal exception during runtime.")
        raise
    finally:
        LOG.info("Server shutting down, cleaning up gamepads...")
        manager.cleanup_gamepads()
        LOG.info("Gamepad cleanup complete. Goodbye.")
