from src.services import tunnel_service
from src.services.tunnel_service import _URL_PATTERN, TunnelService


def test_url_pattern_picks_quick_tunnel_address():
    line = "2026-10-14T01:05:37Z INF |  https://amongst-mono-ana-latter.trycloudflare.com  |"
    assert _URL_PATTERN.search(line).group(0) == "https://amongst-mono-ana-latter.trycloudflare.com"
    assert _URL_PATTERN.search("INF Requesting new quick Tunnel on trycloudflare.com...") is None


async def test_missing_binary_reports_error(monkeypatch):
    monkeypatch.setattr(tunnel_service, "resolve_cloudflared_path", lambda: None)
    changes = []
    service = TunnelService(8799, on_change=changes.append)

    service.start()
    await service._runner

    assert service.snapshot() == {"state": "error", "url": None, "error": "cloudflared_missing"}
    assert [c["state"] for c in changes] == ["starting", "error"]

    await service.stop()
    assert service.snapshot()["state"] == "off"
