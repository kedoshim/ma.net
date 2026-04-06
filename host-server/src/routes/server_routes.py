import os

from aiohttp import web


class ServerRoutes:
    def __init__(self, web_page_static_path):
        self.web_page_static_path = web_page_static_path

    async def index(self, request):
        return web.FileResponse(
            os.path.join(self.web_page_static_path, "index.html")
        )