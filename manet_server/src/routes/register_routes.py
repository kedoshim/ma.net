
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
    
    # Ensure wasm and js have the correct MIME types, which is essential for offline CanvasKit/Skwasm on Windows
    import mimetypes
    mimetypes.add_type('application/wasm', '.wasm')
    mimetypes.add_type('application/javascript', '.js')

    if getattr(sys, 'frozen', False) and hasattr(sys, '_MEIPASS'):
        web_static_path = os.path.join(sys._MEIPASS, 'web')
    else:
        # Ensure absolute path in Dev Mode to avoid aiohttp ValueError
        base_dir = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
        web_static_path = os.path.normpath(os.path.join(base_dir, '..', 'manet_mobile', 'build', 'web'))
        
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
    app.router.add_post('/api/server/shutdown', services.server_shutdown_handler)
    # Older phone builds probe `/status` when diagnosing a disconnect.
    app.router.add_get('/status', services.server_status_handler)
    app.router.add_get('/api/server/connection', services.connection_info_handler)
    app.router.add_get('/api/server/connections', services.connections_handler)
    app.router.add_get('/api/server/diagnostics', services.diagnostics_handler)
    app.router.add_post('/api/server/diagnostics/actions', services.diagnostics_action_handler)
    app.router.add_post('/api/server/connections/select', services.select_connection_handler)
    app.router.add_get('/api/server/qrcode', services.qr_code_handler)
    app.router.add_get('/api/presets', services.presets_handler)
    app.router.add_get('/api/presets/current', services.current_preset_handler)
    app.router.add_post('/api/presets/apply', services.apply_preset_handler)
    app.router.add_post('/api/presets/select', services.select_preset_handler)
    app.router.add_post('/api/presets/custom', services.create_preset_handler)
    app.router.add_put('/api/presets/custom/{preset_id}', services.update_preset_handler)
    app.router.add_delete('/api/presets/custom/{preset_id}', services.delete_preset_handler)
    app.router.add_get('/api/slots', services.slots_handler)
    app.router.add_post('/api/slots/assign', services.assign_handler)
    app.router.add_post('/api/slots/move', services.move_handler)
    app.router.add_post('/api/slots/swap', services.swap_handler)
    app.router.add_post('/api/slots/unassign', services.unassign_handler)
    app.router.add_post('/api/server/reset-controllers', services.reset_controllers_handler)
    app.router.add_post('/api/input-mode', services.input_mode_handler)
    app.router.add_get('/api/controllers/inventory', services.controllers_inventory_handler)
    app.router.add_post('/api/controllers/recreate', services.controllers_recreate_handler)
    app.router.add_post('/api/controllers/close-stale-servers', services.close_stale_servers_handler)
    app.router.add_get('/api/session', services.session_handler)
    app.router.add_post('/api/session/focus', services.session_focus_handler)
    app.router.add_post('/api/session/phase', services.session_phase_handler)
    app.router.add_post('/api/session/vote', services.session_vote_handler)
    app.router.add_post('/api/session/play', services.session_play_handler)
    app.router.add_post('/api/session/cancel-countdown', services.session_cancel_countdown_handler)
    app.router.add_post('/api/session/stop-game', services.session_stop_game_handler)
    app.router.add_post('/api/session/return', services.session_return_handler)
    app.router.add_post('/api/session/overlay', services.session_overlay_handler)
    app.router.add_get('/api/session/overlay-shot', services.session_overlay_shot_handler)
    app.router.add_post('/api/session/switch-game', services.session_switch_game_handler)
    app.router.add_post('/api/session/focus-game', services.session_focus_game_handler)
    app.router.add_post('/api/session/place-overlay', services.session_place_overlay_handler)
    app.router.add_post('/api/session/cancel-tournament', services.session_cancel_tournament_handler)
    app.router.add_post('/api/session/settings', services.session_settings_handler)
    app.router.add_get('/api/session/game-window', services.session_game_window_handler)
    app.router.add_post('/api/session/tournament-vote', services.session_tournament_vote_handler)
    app.router.add_post('/api/session/free-mode', services.session_free_mode_handler)
    app.router.add_post('/api/session/details', services.session_details_handler)
    app.router.add_post('/api/session/lobby-request', services.session_lobby_request_handler)
    app.router.add_get('/api/games/{game_id}/cover', services.game_cover_handler)
    app.router.add_get('/api/displays', services.displays_handler)
    app.router.add_get('/api/games', services.games_handler)
    app.router.add_post('/api/games', services.create_game_handler)
    app.router.add_put('/api/games/{game_id}', services.update_game_handler)
    app.router.add_delete('/api/games/{game_id}', services.delete_game_handler)
