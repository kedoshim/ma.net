import asyncio
import logging


LOGGER = logging.getLogger(__name__)

# Per-admin outbound queue size. Admin sockets are local (desktop app), so a
# full queue means the client is stuck; we drop rather than block input.
ADMIN_QUEUE_SIZE = 512
# Stick events are coalesced to this interval per (device, stick) so the
# desktop UI is not flooded at the phone's frame rate.
STICK_EVENT_INTERVAL = 1 / 30


class AdminPanel:
    def __init__(self, manager):
        self.manager = manager
        # ws -> (queue, pump task)
        self._clients: dict = {}
        self._last_stick_sent: dict[tuple[str, str], float] = {}
        self._pending_sticks: dict[tuple[str, str], dict] = {}

    @property
    def admin_clients(self):
        return set(self._clients)

    def add_client(self, ws):
        queue: asyncio.Queue = asyncio.Queue(maxsize=ADMIN_QUEUE_SIZE)
        task = asyncio.create_task(self._pump(ws, queue))
        self._clients[ws] = (queue, task)

    def remove_client(self, ws):
        entry = self._clients.pop(ws, None)
        if entry is not None:
            entry[1].cancel()

    async def _pump(self, ws, queue: asyncio.Queue):
        try:
            while True:
                data = await queue.get()
                await ws.send_json(data)
        except asyncio.CancelledError:
            raise
        except Exception:
            LOGGER.debug("Admin client send failed; dropping client", exc_info=True)
            self._clients.pop(ws, None)

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
        session = getattr(self.manager, "session", None)
        if session is not None:
            session.sync_players()
        try:
            self.manager.broadcast_slot_status()
        except Exception:
            LOGGER.exception("Failed to broadcast slot status to devices")

    def broadcast_event(self, data, droppable: bool = False):
        """Queue `data` for every admin client without blocking the caller.

        Droppable events (stick motion) are skipped when a client's queue is
        full; state events evict the oldest queued item instead.
        """
        for ws, (queue, _) in list(self._clients.items()):
            try:
                queue.put_nowait(data)
            except asyncio.QueueFull:
                if droppable:
                    continue
                try:
                    queue.get_nowait()
                except asyncio.QueueEmpty:
                    pass
                queue.put_nowait(data)

    def broadcast_input(self, msg: dict):
        """Forward a phone input event to admin clients, coalescing sticks."""
        if not self._clients:
            return

        event = msg.get("event")
        if event not in ("stick", "rstick"):
            self.broadcast_event(msg)
            return

        loop = asyncio.get_running_loop()
        key = (msg.get("deviceId"), event)
        now = loop.time()
        elapsed = now - self._last_stick_sent.get(key, 0.0)
        if elapsed >= STICK_EVENT_INTERVAL and key not in self._pending_sticks:
            self._last_stick_sent[key] = now
            self.broadcast_event(msg, droppable=True)
            return

        first_pending = key not in self._pending_sticks
        self._pending_sticks[key] = msg
        if first_pending:
            loop.call_later(
                max(0.0, STICK_EVENT_INTERVAL - elapsed),
                self._flush_stick,
                key,
            )

    def _flush_stick(self, key):
        msg = self._pending_sticks.pop(key, None)
        if msg is None:
            return
        self._last_stick_sent[key] = asyncio.get_running_loop().time()
        self.broadcast_event(msg, droppable=True)

    def forget_device(self, device_id):
        for event in ("stick", "rstick"):
            self._last_stick_sent.pop((device_id, event), None)
