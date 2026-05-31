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


def log_startup_diagnostics(config):
    import sys
    import os
    import subprocess
    from pathlib import Path
    
    app_version = "0.2.0"
    server_version = "0.2.0"
    frozen = getattr(sys, 'frozen', False)
    exe_path = sys.executable
    working_dir = os.getcwd()
    meipass = getattr(sys, '_MEIPASS', None)
    
    vigem_installed = False
    if sys.platform == "win32":
        try:
            # Check ViGEmBus service via sc query
            res = subprocess.run(["sc", "query", "ViGEmBus"], capture_output=True, text=True, timeout=2.0)
            if "1060" not in res.stdout and res.returncode == 0:
                vigem_installed = True
            else:
                vigem_installed = Path(r"C:\Windows\System32\drivers\ViGEmBus.sys").exists()
        except Exception:
            vigem_installed = Path(r"C:\Windows\System32\drivers\ViGEmBus.sys").exists()
            
    LOG.info("=== STARTUP DIAGNOSTICS ===")
    LOG.info(f"Application Version: {app_version}")
    LOG.info(f"Server Version: {server_version}")
    LOG.info(f"Is Bundled (frozen): {frozen}")
    LOG.info(f"Executable Path: {exe_path}")
    LOG.info(f"Working Directory: {working_dir}")
    if meipass:
        LOG.info(f"PyInstaller MEIPASS: {meipass}")
    LOG.info(f"Python version: {sys.version}")
    LOG.info(f"ViGEm Driver Detected: {vigem_installed}")
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
