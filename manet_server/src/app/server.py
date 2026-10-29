import asyncio

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
from src.services.tunnel_service import TunnelService
from src.services.hotspot_service import HotspotService
from src.core.access_control import AccessGate
from src.app.security import admin_auth_middleware, load_admin_token, requires_admin

import logging

LOG = logging.getLogger("piko-proto") 


def _is_reset_on_close(context) -> bool:
    """A phone that dropped off abruptly (screen locked, left the Wi-Fi):
    on Windows, asyncio then fails to shut down the already-reset socket and
    logs a scary traceback for a connection that is simply gone."""
    return (
        isinstance(context.get("exception"), ConnectionResetError)
        and "_call_connection_lost" in repr(context.get("handle"))
    )


def _quiet_loop_errors(loop):
    def handler(loop, context):
        if _is_reset_on_close(context):
            return
        loop.default_exception_handler(context)

    loop.set_exception_handler(handler)


async def _install_quiet_loop_errors(app):
    _quiet_loop_errors(asyncio.get_running_loop())


def create_app(config):
    LOG.info("Initializing MaNet Server dependencies...")
    manager, admin_panel, _ = build_dependencies(config)
    connection_service = ConnectionService(
        port=config.http_port,
        ws_endpoint=config.ws_endpoint,
    )
    # The network monitor and the routes reach it through the connections.
    connection_service.hotspot_service = HotspotService(connection_service)
    diagnostics_service = NetworkDiagnosticsService(
        manager,
        connection_service,
    )

    def on_tunnel_change(snapshot):
        connection_service.internet_url = snapshot["url"] if snapshot["state"] == "online" else None
        admin_panel.broadcast_event({"type": "online_status", **snapshot})

    tunnel_service = TunnelService(config.http_port, on_change=on_tunnel_change)
    access_gate = AccessGate(
        on_change=lambda payload: admin_panel.broadcast_event({"type": "access_update", **payload})
    )

    LOG.info("Creating aiohttp web application...")
    app = web.Application(middlewares=[admin_auth_middleware(load_admin_token())])
    app.on_startup.append(_install_quiet_loop_errors)

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
        tunnel_service,
        access_gate,
    )

    websocket_routes = WebSocketRoutes(
        config.ws_endpoint,
        manager,
        admin_panel,
        connection_service,
        manager.session,
        tunnel_service,
        access_gate,
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

    # Only what phones use is open to other origins; the desktop app is a
    # native client and needs no CORS.
    for route in list(app.router.routes()):
        if not requires_admin(route.method, route.resource.canonical):
            cors.add(route)

    lifecycle = AppLifecycle(manager, connection_service, admin_panel, tunnel_service)
    lifecycle.register_lifecycle(app)

    LOG.info("Application setup complete.")
    return app, manager


def log_startup_diagnostics(config):
    import sys
    import os
    import subprocess
    from pathlib import Path
    
    from src.app.version import APP_VERSION

    app_version = APP_VERSION
    server_version = APP_VERSION
    frozen = getattr(sys, 'frozen', False)
    exe_path = sys.executable
    working_dir = os.getcwd()
    meipass = getattr(sys, '_MEIPASS', None)
    
    def log_driver_status():
        # `sc query` takes a noticeable moment and is informational only,
        # so it runs off the startup path.
        vigem_installed = False
        try:
            res = subprocess.run(["sc", "query", "ViGEmBus"], capture_output=True, text=True, timeout=2.0)
            if "1060" not in res.stdout and res.returncode == 0:
                vigem_installed = True
            else:
                vigem_installed = Path(r"C:\Windows\System32\drivers\ViGEmBus.sys").exists()
        except Exception:
            vigem_installed = Path(r"C:\Windows\System32\drivers\ViGEmBus.sys").exists()
        LOG.info(f"ViGEm Driver Detected: {vigem_installed}")

    if sys.platform == "win32":
        threading.Thread(target=log_driver_status, daemon=True).start()

    LOG.info("=== STARTUP DIAGNOSTICS ===")
    LOG.info(f"Application Version: {app_version}")
    LOG.info(f"Server Version: {server_version}")
    LOG.info(f"Is Bundled (frozen): {frozen}")
    LOG.info(f"Executable Path: {exe_path}")
    LOG.info(f"Working Directory: {working_dir}")
    if meipass:
        LOG.info(f"PyInstaller MEIPASS: {meipass}")
    LOG.info(f"Python version: {sys.version}")
    LOG.info(f"Config - Controller Mode: {config.controller_type}")
    LOG.info(f"Config - Slots: {config.initial_slots} (Max: {config.max_slots})")
    LOG.info(f"Config - Auto Expand: {config.auto_expand_slots}")
    LOG.info(f"Config - HTTP Port: {config.http_port}")
    LOG.info("===========================")


def run_server(config):
    log_startup_diagnostics(config)
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
