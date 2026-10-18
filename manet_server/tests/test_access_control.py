import asyncio

from src.core.access_control import (
    ADMITTED,
    BANNED,
    LAN_DISABLED,
    MAX_PASSWORD_ATTEMPTS,
    MODE_APPROVAL,
    MODE_OPEN,
    MODE_PASSWORD,
    AccessGate,
)


def test_defaults_open_lan_and_approval_online():
    gate = AccessGate()
    assert gate.check("a", "lan", "192.168.0.10") == ADMITTED
    assert gate.check("b", "online", "203.0.113.1") == MODE_APPROVAL


def test_password_mode_without_password_falls_back_to_approval():
    gate = AccessGate()
    gate.configure(online=MODE_PASSWORD)
    assert gate.check("a", "online", None) == MODE_APPROVAL
    gate.configure(password="  1234 ")
    assert gate.check("a", "online", None) == MODE_PASSWORD


def test_right_password_admits_and_reconnect_skips_the_gate():
    gate = AccessGate()
    gate.configure(online=MODE_PASSWORD, password="1234")
    assert gate.try_password("a", "203.0.113.1", "nope") == ("wrong", MAX_PASSWORD_ATTEMPTS - 1)
    assert gate.try_password("a", "203.0.113.1", "1234")[0] == "ok"
    assert gate.check("a", "online", "203.0.113.1") == ADMITTED


def test_too_many_wrong_passwords_lock_out_the_device_and_address():
    gate = AccessGate()
    gate.configure(online=MODE_PASSWORD, password="1234")
    results = [gate.try_password("a", "203.0.113.1", "x")[0] for _ in range(MAX_PASSWORD_ATTEMPTS)]
    assert results[-1] == "locked"
    assert gate.try_password("a", "203.0.113.1", "1234")[0] == "locked"
    # Another phone behind the same address is locked too.
    assert gate.try_password("b", "203.0.113.1", "1234")[0] == "locked"


def test_changing_the_rule_keeps_admitted_phones():
    gate = AccessGate()
    assert gate.check("a", "lan", None) == ADMITTED
    gate.configure(lan=MODE_APPROVAL)
    assert gate.check("a", "lan", None) == ADMITTED
    assert gate.check("b", "lan", None) == MODE_APPROVAL


async def test_approval_accept_and_reject():
    changes = []
    gate = AccessGate(on_change=changes.append)
    accepted = gate.request_approval("a", "Ana", "online", {"color": "#fff"})
    rejected = gate.request_approval("b", "Bia", "online", {})
    assert [p["name"] for p in gate.to_payload()["pending"]] == ["Ana", "Bia"]

    gate.answer("a", True)
    gate.answer("b", False)
    assert await accepted is True
    assert await rejected is False
    assert gate.check("a", "online", None) == ADMITTED
    assert gate.check("b", "online", None) == MODE_APPROVAL
    assert changes[-1]["pending"] == []


async def test_withdraw_cancels_the_request():
    gate = AccessGate()
    decision = gate.request_approval("a", "Ana", "online", {})
    gate.withdraw("a")
    assert decision.cancelled()
    assert gate.to_payload()["pending"] == []


async def test_ban_from_the_queue_blocks_device_and_public_address():
    gate = AccessGate()
    gate.check("a", "online", "203.0.113.9")
    decision = gate.request_approval("a", "Ana", "online", {})
    gate.answer("a", True, ban=True)
    assert await decision is False
    assert gate.check("a", "online", "203.0.113.9") == BANNED
    assert gate.check("other", "online", "203.0.113.9") == BANNED


def test_kick_removes_admission_and_ban_keeps_out_until_unban():
    gate = AccessGate()
    gate.configure(lan=MODE_OPEN)
    gate.check("a", "lan", "192.168.0.10")
    gate.kick("a", ban=True)
    assert gate.check("a", "lan", "192.168.0.10") == BANNED
    gate.unban_all()
    assert gate.check("a", "lan", "192.168.0.10") == ADMITTED


def test_tunnel_loopback_address_is_never_banned():
    gate = AccessGate()
    gate.check("a", "online", "127.0.0.1")
    gate.kick("a", ban=True)
    assert gate.check("b", "online", "127.0.0.1") != BANNED


def test_online_only_refuses_new_lan_phones_but_keeps_admitted_ones():
    gate = AccessGate()
    assert gate.check("old", "lan", "192.168.0.10") == ADMITTED
    gate.configure(lan_enabled=False)
    assert gate.check("new", "lan", "192.168.0.11") == LAN_DISABLED
    assert gate.check("old", "lan", "192.168.0.10") == ADMITTED
    assert gate.check("far", "online", "203.0.113.1") == MODE_APPROVAL
    assert gate.to_payload()["lanEnabled"] is False
    gate.configure(lan_enabled=True)
    assert gate.check("new", "lan", "192.168.0.11") == ADMITTED


def test_each_origin_has_its_own_password():
    gate = AccessGate()
    gate.configure(lan=MODE_PASSWORD, online=MODE_PASSWORD, password="casa", online_password="live")
    assert gate.try_password("a", "192.168.0.10", "live", "lan")[0] == "wrong"
    assert gate.try_password("a", "192.168.0.10", "casa", "lan")[0] == "ok"
    assert gate.try_password("b", "203.0.113.1", "casa", "online")[0] == "wrong"
    assert gate.try_password("b", "203.0.113.1", "live", "online")[0] == "ok"
    payload = gate.to_payload()
    assert payload["passwordSet"] and payload["onlinePasswordSet"]


def test_online_password_without_its_own_follows_the_lan_one():
    # Older desktop builds send a single `password`.
    gate = AccessGate()
    gate.configure(online=MODE_PASSWORD, password="casa")
    assert gate.mode_for("online") == MODE_PASSWORD
    assert gate.try_password("b", "203.0.113.1", "casa", "online")[0] == "ok"


def test_empty_online_password_falls_back_to_approval_online_only():
    gate = AccessGate()
    gate.configure(lan=MODE_PASSWORD, online=MODE_PASSWORD, password="casa", online_password="")
    assert gate.mode_for("lan") == MODE_PASSWORD
    assert gate.mode_for("online") == MODE_APPROVAL
