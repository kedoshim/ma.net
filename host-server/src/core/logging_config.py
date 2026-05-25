import logging


def setup_logging(level: int = logging.INFO) -> None:
    """Configure root logging for the server.

    Call this early in application startup (e.g. in src.app.main) so all
    modules use a consistent format and level.
    """
    fmt = "%(asctime)s %(levelname)s [%(name)s] %(message)s"
    logging.basicConfig(level=level, format=fmt)

    # Reduce verbosity of known noisy third-party loggers
    for noisy in ("vgamepad", "asyncio", "websockets"):
        try:
            logging.getLogger(noisy).setLevel(logging.WARNING)
        except Exception:
            pass


def get_logger(name: str):
    return logging.getLogger(name)
