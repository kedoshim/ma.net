import logging

LOG = logging.getLogger(__name__)

async def notify_device_slot(manager, device_id):
    slot = manager.get_slot_by_device(device_id)
    ws = manager.get_ws_by_device(device_id)

    if not slot or not ws:
        return

    try:
        await ws.send_json({
            "type": "slot_changed",
            "slot": slot.slot_id,
            **manager.get_slot_identity(slot),
        })
    except Exception as e:
        LOG.error("Failed to notify device: %s", e)

async def notify_device_unassigned(manager, device_id):
    ws = manager.get_ws_by_device(device_id)

    if not ws:
        return

    try:
        await ws.send_json({
            "type": "unassigned"
        })
        name = manager.connected_devices.get(device_id, {}).get("name", "unknown")
        LOG.info(
            "Unassigned device %s (%s)",
            device_id,
            name
        )
    except Exception as e:
        LOG.error("Failed to notify device unassigned: %s", e)

def reset_slot_gamepad(slot):
    LOG.info("Resetting gamepad states for slot %s", getattr(slot, 'slot_id', 'unknown'))
    try:
        slot.gamepad.reset()
        slot.gamepad.update()
    except Exception as e:
        LOG.exception("Failed to reset gamepad: %s", e)
