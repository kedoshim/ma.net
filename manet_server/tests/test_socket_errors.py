import asyncio
import logging

from src.routes.websocket_routes import _log_socket_error


class _FakeSocket:
    def __init__(self, exc):
        self._exc = exc

    def exception(self):
        return self._exc


def test_missed_pong_is_info(caplog):
    with caplog.at_level(logging.INFO, logger="websocket"):
        _log_socket_error(_FakeSocket(asyncio.TimeoutError("No PONG received after 5.0 seconds")), "Device x")
    assert [r.levelno for r in caplog.records] == [logging.INFO]
    assert "stopped answering" in caplog.text


def test_other_errors_stay_errors(caplog):
    with caplog.at_level(logging.INFO, logger="websocket"):
        _log_socket_error(_FakeSocket(ConnectionResetError("boom")), "Device x")
    assert [r.levelno for r in caplog.records] == [logging.ERROR]
