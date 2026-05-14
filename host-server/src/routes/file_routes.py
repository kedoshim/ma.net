import os
from aiohttp import web

class FileRoutes:
    @staticmethod
    async def serve_apk(request):
        # Retrieve the path from the environment variable
        apk_path = os.getenv("APK_OUTPUT_PATH", "../controller_app/build/app/outputs/flutter-apk/app-release.apk")
        
        # Resolve the absolute path
        # __file__ is in src/routes/file_routes.py, so we go up 3 levels to reach host-server/
        base_dir = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))) 
        full_apk_path = os.path.normpath(os.path.join(base_dir, apk_path))

        if os.path.exists(full_apk_path):
            return web.FileResponse(
                full_apk_path,
                headers={
                    "Content-Disposition": 'attachment; filename="ma-net-controller.apk"',
                    "Content-Type": "application/vnd.android.package-archive"
                }
            )
            
        return web.Response(status=404, text=f"APK not found at path: {full_apk_path}")