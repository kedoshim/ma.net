"""Admin authentication and request origin helpers.

Everything that controls the host (the desktop app's REST calls and the
`/ws/admin` feed) needs the admin token the desktop app hands the server at
spawn. Phones only reach the controller socket, the web page and a few
read-only endpoints.

Behind a Cloudflare tunnel every request arrives from cloudflared on
loopback, so the peer address says nothing about who is calling: the real
client is in `CF-Connecting-IP`.
"""

import hmac
import logging
import os
import re
import secrets

from aiohttp import web

LOG = logging.getLogger("security")

ADMIN_TOKEN_ENV = "MANET_ADMIN_TOKEN"
ADMIN_HEADER = "X-Manet-Admin"
ADMIN_QUERY = "admin"

# Paths phones (or anyone on the network) may use without the token.
_PUBLIC_PATHS = {
    "/api/server/status",
    "/status",
}
_PUBLIC_GET_PATTERNS = (
    re.compile(r"^/api/games/[^/]+/cover$"),
)


def load_admin_token() -> str:
    token = os.environ.get(ADMIN_TOKEN_ENV, "").strip()
    if token:
        return token
    # Started by hand (dev, run_server.bat): make one up so the admin
    # surface is never open, and print it for local tooling.
    token = secrets.token_urlsafe(32)
    LOG.warning("%s not set; generated admin token: %s", ADMIN_TOKEN_ENV, token)
    return token


def requires_admin(method: str, path: str) -> bool:
    if path == "/ws/admin":
        return True
    if not path.startswith("/api/"):
        return False
    if path in _PUBLIC_PATHS:
        return False
    if method in ("GET", "HEAD") and any(p.match(path) for p in _PUBLIC_GET_PATTERNS):
        return False
    return True


def has_admin_token(request: web.Request, token: str) -> bool:
    supplied = request.headers.get(ADMIN_HEADER) or request.query.get(ADMIN_QUERY) or ""
    return hmac.compare_digest(supplied.encode(), token.encode())


def admin_auth_middleware(token: str):
    @web.middleware
    async def middleware(request: web.Request, handler):
        # CORS preflights carry no credentials; aiohttp_cors answers them.
        if request.method != "OPTIONS" and requires_admin(request.method, request.path):
            if not has_admin_token(request, token):
                LOG.warning("Rejected unauthenticated %s %s from %s",
                            request.method, request.path, client_ip(request))
                return web.json_response(
                    {"success": False, "code": "unauthorized"}, status=401
                )
        return await handler(request)

    return middleware


def request_origin(request: web.Request) -> str:
    """"online" for requests relayed by the Cloudflare tunnel, else "lan"."""
    return "online" if request.headers.get("CF-Connecting-IP") else "lan"


def client_ip(request: web.Request) -> str | None:
    return request.headers.get("CF-Connecting-IP") or request.remote
