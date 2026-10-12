import atexit
import logging
import logging.handlers
import queue
import sys
import os
from pathlib import Path

class FlushFileHandler(logging.FileHandler):
    """
    FileHandler that fsyncs only WARNING+ records, so crash diagnostics still
    reach disk without paying a disk sync for every routine log line.
    """
    def emit(self, record):
        super().emit(record)
        if record.levelno < logging.WARNING:
            return
        try:
            if self.stream:
                self.stream.flush()
                os.fsync(self.stream.fileno())
        except Exception:
            pass


_listener = None

def setup_logging(level=logging.INFO):
    # 1. Target the %LOCALAPPDATA%/MaNet/logs directory for unified logs
    localappdata = os.environ.get('LOCALAPPDATA')
    if localappdata:
        log_dir = Path(localappdata) / "MaNet" / "logs"
    else:
        # Fallback to roaming APPDATA or home
        appdata = os.environ.get('APPDATA')
        if appdata:
            log_dir = Path(appdata) / "MaNet" / "logs"
        else:
            log_dir = Path.home() / ".manet" / "logs"
        
    log_dir.mkdir(parents=True, exist_ok=True)
    log_file = log_dir / "latest.log"

    # 2. Setup format and root logger
    formatter = logging.Formatter('%(asctime)s | %(levelname)-8s | PYTHON  | %(name)s | %(message)s')
    root_logger = logging.getLogger()
    root_logger.setLevel(level)
    root_logger.handlers.clear()

    # 3. Console + file handlers run on a background thread (QueueListener)
    # so logging never blocks the asyncio event loop with I/O.
    console_handler = logging.StreamHandler(sys.stdout)
    console_handler.setFormatter(formatter)

    file_handler = FlushFileHandler(
        log_file, mode='w', encoding='utf-8'
    )
    file_handler.setFormatter(formatter)

    global _listener
    if _listener is not None:
        _listener.stop()
    log_queue = queue.SimpleQueue()
    root_logger.addHandler(logging.handlers.QueueHandler(log_queue))
    _listener = logging.handlers.QueueListener(
        log_queue, console_handler, file_handler, respect_handler_level=True
    )
    _listener.start()
    atexit.register(_stop_listener)

    # 5. Suppress spammy web framework logs
    logging.getLogger("aiohttp.access").setLevel(logging.WARNING) 
    logging.getLogger("aiohttp.server").setLevel(logging.WARNING)

    # 6. Global Exception Capture
    def handle_exception(exc_type, exc_value, exc_traceback):
        if issubclass(exc_type, KeyboardInterrupt):
            sys.__excepthook__(exc_type, exc_value, exc_traceback)
            return
        root_logger.critical("Uncaught Python Exception", exc_info=(exc_type, exc_value, exc_traceback))

    sys.excepthook = handle_exception
    root_logger.info(f"Python server logging initialized. Writing to {log_file}")


def stop_logging():
    """Flush and stop the background log writer (before a hard exit)."""
    _stop_listener()


def _stop_listener():
    global _listener
    if _listener is not None:
        _listener.stop()
        _listener = None
