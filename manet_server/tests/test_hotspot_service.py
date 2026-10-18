from types import SimpleNamespace

from src.services.hotspot_service import (
    HotspotInfo,
    HotspotService,
    hotspot_from_options,
    parse_tethering_output,
    wifi_qr_payload,
)


def test_parses_hotspot_on_with_name_and_password():
    info = parse_tethering_output('{"state":"On","ssid":"MANET-PC","passphrase":"segredo123"}')
    assert info == HotspotInfo(active=True, ssid="MANET-PC", passphrase="segredo123")
    assert info.to_payload() == {"active": True, "ssid": "MANET-PC", "hasPassword": True}


def test_parses_hotspot_off_and_garbage():
    assert parse_tethering_output('{"state":"Off","ssid":"MANET-PC","passphrase":"x"}') == HotspotInfo()
    assert parse_tethering_output('{"state":"NoProfile"}') is None
    assert parse_tethering_output("") is None
    assert parse_tethering_output("not json") is None


def test_payload_never_carries_the_password():
    info = HotspotInfo(active=True, ssid="A", passphrase="secret")
    assert "secret" not in str(info.to_payload())


def test_adapter_fallback_by_kind_or_subnet():
    wifi = SimpleNamespace(kind="wifi", ip="192.168.0.20")
    assert hotspot_from_options([wifi]) == HotspotInfo()
    by_subnet = SimpleNamespace(kind="other", ip="192.168.137.1")
    assert hotspot_from_options([wifi, by_subnet]) == HotspotInfo(active=True)
    by_kind = SimpleNamespace(kind="hotspot", ip="10.0.0.1")
    assert hotspot_from_options([by_kind]).active


def test_service_falls_back_to_adapters_when_windows_says_nothing(monkeypatch):
    options = [SimpleNamespace(kind="other", ip="192.168.137.1")]
    connections = SimpleNamespace(get_snapshot=lambda: SimpleNamespace(connections=options))
    service = HotspotService(connections)
    monkeypatch.setattr(service, "_query_windows", lambda: None)
    assert service.refresh() == HotspotInfo(active=True)


def test_wifi_qr_escapes_special_characters():
    assert wifi_qr_payload("MANET-PC", "abc12345") == "WIFI:T:WPA;S:MANET-PC;P:abc12345;;"
    assert wifi_qr_payload(r'a;b,c:d"e\f', "p;w") == r'WIFI:T:WPA;S:a\;b\,c\:d\"e\\f;P:p\;w;;'
    assert wifi_qr_payload("Open", None) == "WIFI:T:nopass;S:Open;;"
