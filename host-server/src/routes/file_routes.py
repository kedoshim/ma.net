import os
import sys
from aiohttp import web

class FileRoutes:
    @staticmethod
    def get_resource_path(relative_path):
        """ Get absolute path to resource, works for dev and for PyInstaller """
        if getattr(sys, 'frozen', False) and hasattr(sys, '_MEIPASS'):
            return os.path.join(sys._MEIPASS, relative_path)
        
        # In dev mode, go up 3 levels to reach host-server/
        base_dir = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
        return os.path.normpath(os.path.join(base_dir, relative_path))

    @staticmethod
    async def serve_apk(request):
        if getattr(sys, 'frozen', False) and hasattr(sys, '_MEIPASS'):
            full_apk_path = FileRoutes.get_resource_path(os.path.join('apk', 'app-release.apk'))
        else:
            apk_path = os.getenv("APK_OUTPUT_PATH", "../controller_app/build/app/outputs/flutter-apk/app-release.apk")
            full_apk_path = FileRoutes.get_resource_path(apk_path)

        if os.path.exists(full_apk_path):
            return web.FileResponse(
                full_apk_path,
                headers={
                    "Content-Disposition": 'attachment; filename="ma-net-controller.apk"',
                    "Content-Type": "application/vnd.android.package-archive"
                }
            )
            
        return web.Response(status=404, text=f"APK not found at path: {full_apk_path}")