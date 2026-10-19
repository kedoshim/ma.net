import asyncio
from src.tasks.watchdog import stick_watchdog
from src.tasks.network_monitor import network_monitor_task
from src.core.gamepad_factory import probe_gamepad_type_cached
from src.lifecycle.process_exit import watch_parent

class AppLifecycle:
    def __init__(self, manager, connection_service, admin_panel, tunnel_service=None):
        self.manager = manager
        self.connection_service = connection_service
        self.admin_panel = admin_panel
        self.tunnel_service = tunnel_service

    def register_lifecycle(self, app):
        app.on_startup.append(self.start_background_tasks)
        app.on_cleanup.append(self.cleanup_background_tasks)

    async def start_background_tasks(self, app):
        loop = asyncio.get_running_loop()

        self.manager.set_main_loop(loop)

        parent_pid = getattr(self.manager.config, "parent_pid", None)
        if parent_pid:
            watch_parent(parent_pid, self.manager, loop)
        
        async def init_slots_task():
            import logging
            logger = logging.getLogger("app_lifecycle")
            if self.manager.console_mode:
                # Console mode: no pads up front; phones get seats as they join.
                logger.info("Console mode: virtual pads are created when a game starts")
                for device_id, device_info in list(self.manager.connected_devices.items()):
                    if device_id not in self.manager.device_map:
                        slot = self.manager.assign_slot(device_id, device_info.get("name"))
                        if slot:
                            self.manager.notify_device(device_id, {
                                "type": "assigned",
                                "slot": slot.slot_id,
                                **self.manager.get_slot_identity(slot),
                                "total_slots": len(self.manager.slots)
                            })
                self.admin_panel.broadcast_update()
                return
            logger.info("Initializing %d gamepad slots in background...", self.manager.config.initial_slots)
            async with self.manager._slot_lock:
                for i in range(self.manager.config.initial_slots):
                    try:
                        await self.manager._create_empty_slot_async(i)
                        # Check for waiting connected devices and auto-assign
                        for device_id, device_info in list(self.manager.connected_devices.items()):
                            if device_id not in self.manager.device_map:
                                slot = self.manager.assign_slot(device_id, device_info.get("name"))
                                if slot:
                                    self.manager.notify_device(device_id, {
                                        "type": "assigned",
                                        "slot": slot.slot_id,
                                        **self.manager.get_slot_identity(slot),
                                        "total_slots": len(self.manager.slots)
                                    })
                                break
                    except Exception:
                        logger.exception("Failed to initialize slot %d", i)
                await self.manager.order_pads_for_games()
            self.admin_panel.broadcast_update()

        async def warm_gamepad_probe():
            # Run the (slow, subprocess-based) DS4 safety probe once in the
            # background so choosing DInput later does not pay for it.
            await asyncio.to_thread(probe_gamepad_type_cached, "ds4")

        app["init_slots"] = asyncio.create_task(init_slots_task())
        app["warm_probe"] = asyncio.create_task(warm_gamepad_probe())

        app["stick_watchdog"] = asyncio.create_task(
            stick_watchdog(self.manager, self.admin_panel)
        )
        app["network_monitor"] = asyncio.create_task(
            network_monitor_task(self.connection_service, self.admin_panel)
        )

    async def cleanup_background_tasks(self, app):
        if self.tunnel_service is not None:
            await self.tunnel_service.stop()
        for task_key in ("init_slots", "warm_probe", "stick_watchdog", "network_monitor"):
            task = app.get(task_key)
            if task:
                task.cancel()
                try:
                    await task
                except asyncio.CancelledError:
                    pass