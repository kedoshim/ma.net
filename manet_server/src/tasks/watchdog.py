import asyncio
import time
import logging

from src.input.input_handler import apply_stick, apply_right_stick

LOGGER = logging.getLogger("watchdog")


async def stick_watchdog(manager, admin_panel=None):
    last_res_check = 0.0
    while True:
        now = time.time()

        # Check expired reservations once per second
        if now - last_res_check >= 1.0:
            last_res_check = now
            res_expired = False
            for slot in manager.slots:
                if slot.assigned_device_id is not None and not slot.connected:
                    if slot.reserved_until > 0 and now >= slot.reserved_until:
                        LOGGER.info(
                            "Reservation expired for slot %d (device %s - %s)",
                            slot.slot_id,
                            slot.assigned_device_id,
                            slot.player_name,
                        )
                        manager.unassign_slot(slot.slot_id)
                        res_expired = True
            if res_expired and admin_panel:
                admin_panel.broadcast_update()

        for slot in manager.slots:
            if not slot.connected:
                continue

            # Left stick watchdog
            if not (
                abs(slot.last_stick_x) <= 0.05
                and abs(slot.last_stick_y) <= 0.05
            ):
                if now - slot.last_input_at > 0.15:
                    slot.last_stick_x = 0
                    slot.last_stick_y = 0
                    apply_stick(slot, 0, 0)

            # Right stick watchdog
            if hasattr(slot, "last_rstick_x") and not (
                abs(slot.last_rstick_x) <= 0.05
                and abs(slot.last_rstick_y) <= 0.05
            ):
                if now - slot.last_input_at > 0.15:
                    slot.last_rstick_x = 0
                    slot.last_rstick_y = 0
                    apply_right_stick(slot, 0, 0)

        await asyncio.sleep(0.03)