import os
import sys

from aiohttp import web


class ServerRoutes:
    def __init__(self, web_page_static_path):
        self.web_page_static_path = web_page_static_path

    async def index(self, request):
        if getattr(sys, 'frozen', False) and hasattr(sys, '_MEIPASS'):
            index_path = os.path.join(sys._MEIPASS, "web", "index.html")
        else:
            base_dir = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
            index_path = os.path.normpath(os.path.join(base_dir, '..', 'manet_mobile', 'build', 'web', 'index.html'))
            
        if not os.path.exists(index_path):
            return web.Response(status=404, text=f"Index not found at: {index_path}")
            
        return web.FileResponse(index_path)