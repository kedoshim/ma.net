
import os
import sys

from aiohttp import web

def register_all_routes(app, server_routes, http_routes, websocket_routes, file_routes):

    register_server_routes(app, server_routes)
    register_http_routes(app, http_routes)
    register_websocket_routes(app, websocket_routes)
    register_file_routes(app, file_routes)


def register_server_routes(app, server_routes):
    app.router.add_get("/", server_routes.index)
    
    if getattr(sys, 'frozen', False) and hasattr(sys, '_MEIPASS'):
        web_static_path = os.path.join(sys._MEIPASS, 'web')
    else:
        # Ensure absolute path in Dev Mode to avoid aiohttp ValueError
        base_dir = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
        web_static_path = os.path.normpath(os.path.join(base_dir, '..', 'controller_app', 'build', 'web'))
        
    app.router.add_static("/", path=web_static_path)

def register_file_routes(app, file_routes):
    app.router.add_get('/apk', file_routes.serve_apk)

def register_websocket_routes(app,services):
    app.router.add_get(services.ws_endpoint, services.websocket_handler)
    app.router.add_get('/ws/admin', services.admin_websocket_handler)

def register_http_routes(app, services):
    app.router.add_get('/api/server/status', services.server_status_handler)
    app.router.add_post('/api/server/start', services.server_start_handler)
    app.router.add_post('/api/server/stop', services.server_stop_handler)
    app.router.add_get('/api/server/connection', services.connection_info_handler)
    app.router.add_get('/api/server/qrcode', services.qr_code_handler)
    app.router.add_get('/api/slots', services.slots_handler)
    app.router.add_post('/api/slots/assign', services.assign_handler)
    app.router.add_post('/api/slots/move', services.move_handler)
    app.router.add_post('/api/slots/swap', services.swap_handler)
    app.router.add_post('/api/slots/unassign', services.unassign_handler)