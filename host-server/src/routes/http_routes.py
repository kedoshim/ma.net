
from io import BytesIO

from aiohttp import web

from src.services.qr_service import generate_qr_code_image
from src.core.slot_handler import notify_device_slot
from src.utils.network import get_best_access_url, get_local_ipv4_addresses

import logging
logging.basicConfig(level=logging.INFO)
LOG = logging.getLogger("http_routes")


class HTTPRoutes:
    def __init__(self, manager, admin_panel, port, ws_endpoint):
        self.manager = manager
        self.admin_panel = admin_panel
        self.port = port
        self.ws_endpoint = ws_endpoint


    async def server_status_handler(self, request):
        addrs = get_local_ipv4_addresses()
        ip = addrs[0][1] if addrs else '127.0.0.1'
        return web.json_response({
            'running': True,
            'ip': ip,
            'port': self.port
        })


    async def server_start_handler(self, request):
        # Server is always running
        return web.json_response({'success': True})


    async def server_stop_handler(self, request):
        # For now, just return success
        return web.json_response({'success': True})


    async def connection_info_handler(self, request):
        url = get_best_access_url(self.port)

        return web.json_response({
            "success": True,
            "url": url,
            "wsUrl": url.replace("http", "ws") + self.ws_endpoint
        })


    async def qr_code_handler(self, request):

        url = get_best_access_url(self.port)

        try:
            img = generate_qr_code_image(url)

            buffer = BytesIO()
            img.save(buffer, format="PNG")
            buffer.seek(0)

            return web.Response(
                body=buffer.getvalue(),
                content_type="image/png"
            )
        except Exception as e:
            LOG.error("Failed to generate QR code: %s", e)
            return web.json_response(
                {"success": False, "error": "Failed to generate QR code"},
                status=500
            )


    async def slots_handler(self, request):
        pool = self.manager.get_unassigned_devices()
        slots = self.manager.get_slots_state()
        return web.json_response({
            'pool': pool,
            'slots': slots
        })


    async def assign_handler(self, request):
        data = await request.json()
        device_id = data['deviceId']
        slot_index = data['slotIndex']
        slot = self.manager.assign_to_slot(device_id, slot_index)
        if slot:
            self.admin_panel.broadcast_update()
            return web.json_response({'success': True})
        else:
            return web.json_response({'success': False}, status=400)


    async def move_handler(self, request):
        data = await request.json()
        from_slot = data['fromSlot']
        to_slot = data['toSlot']
        old_device = self.manager.slots[from_slot].assigned_device_id
        self.manager.move_slot(from_slot, to_slot)
        if old_device:
            await notify_device_slot(self.manager, old_device)
        self.admin_panel.broadcast_update()
        return web.json_response({'success': True})


    async def swap_handler(self, request):
        data = await request.json()
        slot_a = data['slotA']
        slot_b = data['slotB']
        device_a = self.manager.slots[slot_a].assigned_device_id
        device_b = self.manager.slots[slot_b].assigned_device_id
        self.manager.swap_slots(slot_a, slot_b)
        if device_a:
            await notify_device_slot(self.manager, device_a)
        if device_b:
            await notify_device_slot(self.manager, device_b)
        self.admin_panel.broadcast_update()
        return web.json_response({'success': True})


    async def unassign_handler(self, request):
        data = await request.json()
        slot_index = data['slotIndex']
        self.manager.unassign_slot(slot_index)
        self.admin_panel.broadcast_update()
        return web.json_response({'success': True})
