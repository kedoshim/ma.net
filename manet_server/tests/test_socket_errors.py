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


def test_reset_while_closing_a_dropped_phone_is_silent(caplog):
    from src.app.server import _quiet_loop_errors

    class _ProactorBasePipeTransport:
        def _call_connection_lost(self):
            pass

    loop = asyncio.new_event_loop()
    try:
        _quiet_loop_errors(loop)
        handle = loop.call_soon(_ProactorBasePipeTransport()._call_connection_lost)
        with caplog.at_level(logging.ERROR, logger="asyncio"):
            loop.call_exception_handler({
                "message": "Exception in callback",
                "exception": ConnectionResetError(10054, "reset"),
                "handle": handle,
            })
            assert caplog.records == []
            # Any other loop error still shows up.
            loop.call_exception_handler({
                "message": "Exception in callback",
                "exception": RuntimeError("real bug"),
                "handle": handle,
            })
        assert [r.levelno for r in caplog.records] == [logging.ERROR]
    finally:
        loop.close()
