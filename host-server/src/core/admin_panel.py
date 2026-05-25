import asyncio
import logging


LOGGER = logging.getLogger(__name__)


class AdminPanel:
    def __init__(self, manager):
        self.manager = manager  

        self.admin_clients = set()


    def broadcast_update(self):
        pool = self.manager.get_unassigned_devices()
        slots = self.manager.get_slots_state()
        self.broadcast_event({
            'type': 'slot_update',
            'data': {
                'pool': pool,
                'slots': slots
            }
        })
        LOGGER.debug("Broadcasted admin slot update: pool=%d slots=%d", len(pool), len(slots))

    def broadcast_event(self, data):
        for client in self.admin_clients.copy():
            try:
                asyncio.create_task(client.send_json(data))
            except Exception:
                LOGGER.exception("Failed to send admin event, removing client")
                self.admin_clients.discard(client)
