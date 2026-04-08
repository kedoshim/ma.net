import logging

logging.basicConfig(level=logging.INFO)
LOG = logging.getLogger("slot_manager")

async def notify_device_slot(manager, device_id):
    slot = manager.get_slot_by_device(device_id)
    color = manager.get_device_color(device_id)
    ws = manager.get_ws_by_device(device_id)

    if not slot or not ws:
        return

    try:
        await ws.send_json({
            "type": "slot_changed",
            "slot": slot.slot_id,
            "color": color
        })
    except Exception as e:
        LOG.error("Failed to notify device: %s", e)

def reset_slot_gamepad(slot):
    try:
        slot.gamepad.reset()
        slot.gamepad.update()
    except Exception as e:
        LOG.exception("Failed to reset gamepad: %s", e)