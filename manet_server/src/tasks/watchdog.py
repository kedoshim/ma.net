import asyncio
import time

from src.input.input_handler import apply_stick


async def stick_watchdog(manager):
    while True:
        now = time.time()

        for slot in manager.slots:
            if not slot.connected:
                continue

            if (
                abs(slot.last_stick_x) <= 0.05
                and abs(slot.last_stick_y) <= 0.05
            ):
                continue

            if now - slot.last_input_at > 0.15:
                slot.last_stick_x = 0
                slot.last_stick_y = 0
                apply_stick(slot, 0, 0)

        await asyncio.sleep(0.03)