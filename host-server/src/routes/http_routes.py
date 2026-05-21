
from io import BytesIO

from aiohttp import web

from src.services.qr_service import generate_qr_code_image
from src.services.connection_service import ConnectionService
from src.services.network_diagnostics_service import NetworkDiagnosticsService
from src.core.slot_handler import notify_device_slot, notify_device_unassigned

import logging
logging.basicConfig(level=logging.INFO)
LOG = logging.getLogger("http_routes")


class HTTPRoutes:
    def __init__(
        self,
        manager,
        admin_panel,
        port,
        ws_endpoint,
        connection_service: ConnectionService,
        diagnostics_service: NetworkDiagnosticsService,
    ):
        self.manager = manager
        self.admin_panel = admin_panel
        self.port = port
        self.ws_endpoint = ws_endpoint
        self.connection_service = connection_service
        self.diagnostics_service = diagnostics_service


    async def server_status_handler(self, request):
        info = self.connection_service.get_connection_info_payload()
        return web.json_response({
            'running': True,
            'ip': info['ip'],
            'port': self.port
        })


    async def server_start_handler(self, request):
        # Server is always running
        return web.json_response({'success': True})


    async def server_stop_handler(self, request):
        # For now, just return success
        return web.json_response({'success': True})


    async def connection_info_handler(self, request):
        payload = self.connection_service.get_connection_info_payload()
        return web.json_response({
            "success": True,
            "url": payload["url"],
            "wsUrl": payload["wsUrl"],
            "ip": payload["ip"],
            "kind": payload["kind"],
        })


    async def connections_handler(self, request):
        return web.json_response(self.connection_service.get_connections_payload())


    async def diagnostics_handler(self, request):
        return web.json_response(self.diagnostics_service.build_payload())


    async def diagnostics_action_handler(self, request):
        data = await request.json()
        action_id = data.get("actionId")
        if not action_id:
            return web.json_response(
                {"success": False, "code": "missing_action_id"},
                status=400,
            )

        result = self.diagnostics_service.run_action(action_id)
        status = 200 if result.success else 400
        return web.json_response(result.to_payload(), status=status)


    async def select_connection_handler(self, request):
        data = await request.json()
        connection_id = data.get("connectionId")
        if not connection_id:
            return web.json_response(
                {"success": False, "code": "missing_connection_id"},
                status=400,
            )

        try:
            option = self.connection_service.set_preferred_connection(connection_id)
        except Exception as exc:
            LOG.error("Failed to select connection: %s", exc)
            return web.json_response(
                {"success": False, "code": "select_connection_failed"},
                status=400,
            )

        return web.json_response({
            "success": True,
            "selectedConnection": option.to_payload(self.port, self.ws_endpoint),
        })


    async def qr_code_handler(self, request):
        connection_id = request.query.get("id")
        url = self.connection_service.get_qr_url_for_id(connection_id)

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
                {"success": False, "code": "qr_generation_failed"},
                status=500
            )


    async def slots_handler(self, request):
        pool = self.manager.get_unassigned_devices()
        slots = self.manager.get_slots_state()
        print("Slots state:")
        for slot in slots:
            print(slot)
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
        device_id = self.manager.slots[slot_index].assigned_device_id
        self.manager.unassign_slot(slot_index)
        await notify_device_unassigned(self.manager, device_id)
        self.admin_panel.broadcast_update()
        return web.json_response({'success': True})
