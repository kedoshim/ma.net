import pytest
from aiohttp import web

from src.app.security import (
    ADMIN_HEADER,
    admin_auth_middleware,
    client_ip,
    request_origin,
    requires_admin,
)

TOKEN = "secret-token"


@pytest.mark.parametrize(
    "method,path,expected",
    [
        ("GET", "/", False),
        ("GET", "/main.dart.js", False),
        ("GET", "/ws", False),
        ("GET", "/apk", False),
        ("GET", "/status", False),
        ("GET", "/api/server/status", False),
        ("GET", "/api/games/abc/cover", False),
        ("GET", "/ws/admin", True),
        ("GET", "/api/games", True),
        ("DELETE", "/api/games/abc", True),
        ("PUT", "/api/games/abc/cover", True),
        ("POST", "/api/server/shutdown", True),
        ("GET", "/api/server/qrcode", True),
    ],
)
def test_requires_admin(method, path, expected):
    assert requires_admin(method, path) is expected


async def _ok(request):
    return web.json_response({"origin": request_origin(request), "ip": client_ip(request)})


@pytest.fixture
async def client(aiohttp_client):
    app = web.Application(middlewares=[admin_auth_middleware(TOKEN)])
    app.router.add_get("/api/games", _ok)
    app.router.add_get("/api/server/status", _ok)
    app.router.add_get("/ws/admin", _ok)
    return await aiohttp_client(app)


async def test_admin_route_rejects_missing_token(client):
    resp = await client.get("/api/games")
    assert resp.status == 401


async def test_admin_route_rejects_wrong_token(client):
    resp = await client.get("/api/games", headers={ADMIN_HEADER: "nope"})
    assert resp.status == 401


async def test_admin_route_accepts_header_token(client):
    resp = await client.get("/api/games", headers={ADMIN_HEADER: TOKEN})
    assert resp.status == 200


async def test_admin_socket_accepts_query_token(client):
    assert (await client.get("/ws/admin")).status == 401
    assert (await client.get(f"/ws/admin?admin={TOKEN}")).status == 200


async def test_public_route_is_open(client):
    resp = await client.get("/api/server/status")
    assert resp.status == 200


async def test_origin_lan_without_cloudflare_header(client):
    data = await (await client.get("/api/server/status")).json()
    assert data["origin"] == "lan"
    assert data["ip"] == "127.0.0.1"


async def test_origin_online_through_tunnel(client):
    resp = await client.get("/api/server/status", headers={"CF-Connecting-IP": "203.0.113.7"})
    data = await resp.json()
    assert data["origin"] == "online"
    assert data["ip"] == "203.0.113.7"
