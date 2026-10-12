from src.core.controller_manager import ControllerManager
from src.app.config import ServerConfig
from src.cli.debug_cli import DebugCLI
from src.core.admin_panel import AdminPanel
from src.core.game_library import GameLibraryStore
from src.core.session_state import SessionState


def build_dependencies(server_config: ServerConfig):
    manager = ControllerManager(server_config)

    admin_panel = AdminPanel(manager)
    manager.admin_panel = admin_panel
    session = SessionState(manager, admin_panel, GameLibraryStore())
    manager.session = session
    debug_cli = DebugCLI(manager, server_config.http_port)

    return manager, admin_panel, debug_cli
