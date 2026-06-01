import asyncio
from src.tasks.watchdog import stick_watchdog
from src.tasks.network_monitor import network_monitor_task

class AppLifecycle:
    def __init__(self, manager, connection_service, admin_panel):
        self.manager = manager
        self.connection_service = connection_service
        self.admin_panel = admin_panel

    def register_lifecycle(self, app):
        app.on_startup.append(self.start_background_tasks)
        app.on_cleanup.append(self.cleanup_background_tasks)

    async def start_background_tasks(self, app):
        loop = asyncio.get_running_loop()

        self.manager.set_main_loop(loop)
        
        async def init_slots_task():
            import logging
            logger = logging.getLogger("app_lifecycle")
            logger.info("Initializing %d gamepad slots in background...", self.manager.config.initial_slots)
            for i in range(self.manager.config.initial_slots):
                await asyncio.sleep(0.02)
                try:
                    self.manager._create_empty_slot(i)
                    # Check for waiting connected devices and auto-assign
                    for device_id, device_info in list(self.manager.connected_devices.items()):
                        if device_id not in self.manager.device_map:
                            slot = self.manager.assign_slot(device_id, device_info.get("name"))
                            if slot:
                                ws = self.manager.get_ws_by_device(device_id)
                                if ws:
                                    asyncio.create_task(ws.send_json({
                                        "type": "assigned",
                                        "slot": slot.slot_id,
                                        **self.manager.get_slot_identity(slot),
                                        "total_slots": len(self.manager.slots)
                                    }))
                                break
                except Exception:
                    logger.exception("Failed to initialize slot %d", i)
            self.admin_panel.broadcast_update()

        app["init_slots"] = asyncio.create_task(init_slots_task())

        app["stick_watchdog"] = asyncio.create_task(
            stick_watchdog(self.manager, self.admin_panel)
        )
        app["network_monitor"] = asyncio.create_task(
            network_monitor_task(self.connection_service, self.admin_panel)
        )

    async def cleanup_background_tasks(self, app):
        for task_key in ("stick_watchdog", "network_monitor"):
            task = app.get(task_key)
            if task:
                task.cancel()
                try:
                    await task
                except asyncio.CancelledError:
                    pass