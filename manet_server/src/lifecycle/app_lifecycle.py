import asyncio
from src.tasks.watchdog import stick_watchdog

class AppLifecycle:
    def __init__(self, manager):
        self.manager = manager

    def register_lifecycle(self, app):
        app.on_startup.append(self.start_background_tasks)
        app.on_cleanup.append(self.cleanup_background_tasks)

    async def start_background_tasks(self, app):
        loop = asyncio.get_running_loop()

        self.manager.set_main_loop(loop)
        self.manager.initialize_slots()

        app["stick_watchdog"] = asyncio.create_task(
            stick_watchdog(self.manager)
        )

    async def cleanup_background_tasks(self, app):
        task = app.get("stick_watchdog")
        if task:
            task.cancel()
            try:
                await task
            except asyncio.CancelledError:
                pass