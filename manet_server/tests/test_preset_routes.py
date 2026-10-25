"""Saving a layout reaches the phones that are already using it."""
from src.core.controller_presets import ControllerPresetStore
from src.routes.http_routes import HTTPRoutes


class _Manager:
    def __init__(self, store):
        self.preset_store = store
        self.session = None
        self.layout_broadcasts = 0

    def broadcast_active_layout(self):
        self.layout_broadcasts += 1


class _Admin:
    def __init__(self):
        self.events = []

    def broadcast_event(self, data, droppable=False):
        self.events.append(data)


class _Request:
    def __init__(self, preset_id, body):
        self.match_info = {"preset_id": preset_id}
        self._body = body

    async def json(self):
        return self._body


def _routes(tmp_path):
    store = ControllerPresetStore(storage_path=tmp_path / "presets.json")
    manager = _Manager(store)
    admin = _Admin()
    routes = HTTPRoutes(manager, admin, 0, "/ws", connection_service=None, diagnostics_service=None)
    for name in ("Mine", "Other"):
        store.create_custom_preset({"id": f"user-{name}", "name": name, "layout": {}})
    return routes, manager, admin


async def test_saving_the_active_layout_sends_it_to_phones(tmp_path):
    routes, manager, admin = _routes(tmp_path)
    manager.preset_store.set_active_preset("user-Mine")
    await routes.update_preset_handler(_Request("user-Mine", {"name": "Mine", "layout": {"movementMode": "dpad"}}))
    assert manager.layout_broadcasts == 1


async def test_saving_another_layout_only_refreshes_the_desktop(tmp_path):
    routes, manager, admin = _routes(tmp_path)
    manager.preset_store.set_active_preset("user-Mine")
    await routes.update_preset_handler(_Request("user-Other", {"name": "Other", "layout": {}}))
    assert manager.layout_broadcasts == 0
    assert [e["type"] for e in admin.events] == ["preset_update"]
