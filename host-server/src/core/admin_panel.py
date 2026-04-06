import asyncio


class AdminPanel:
    def __init__(self, manager):
        self.manager = manager  

        self.admin_clients = set()


    def broadcast_update(self):
        pool = self.manager.get_unassigned_devices()
        slots = self.manager.get_slots_state()
        data = {
            'type': 'slot_update',
            'data': {
                'pool': pool,
                'slots': slots
            }
        }
        for client in self.admin_clients.copy():
            try:
                asyncio.create_task(client.send_json(data))
            except Exception:
                self.admin_clients.discard(client)