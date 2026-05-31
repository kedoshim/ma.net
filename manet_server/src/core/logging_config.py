import logging
import sys
import os
from pathlib import Path

class FlushFileHandler(logging.FileHandler):
    """
    Custom FileHandler that flushes the stream and calls os.fsync on emit
    to ensure logs are reliably written to disk even during native/hard crashes.
    """
    def emit(self, record):
        super().emit(record)
        try:
            if self.stream:
                self.stream.flush()
                # Force synchronization with disk
                os.fsync(self.stream.fileno())
        except Exception:
            pass

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

    # 3. Console Handler
    console_handler = logging.StreamHandler(sys.stdout)
    console_handler.setFormatter(formatter)
    root_logger.addHandler(console_handler)

    # 4. File Handler (mode='w' to overwrite on startup, custom FlushFileHandler for reliable flushing)
    file_handler = FlushFileHandler(
        log_file, mode='w', encoding='utf-8'
    )
    file_handler.setFormatter(formatter)
    root_logger.addHandler(file_handler)

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