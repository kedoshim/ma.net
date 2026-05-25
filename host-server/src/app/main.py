import argparse
from pathlib import Path

from src.app.config import ServerConfig
from src.app.server import run_server
from src.core.logging_config import setup_logging
import logging


def parse_args():
    parser = argparse.ArgumentParser(
        description="Piko Host Server"
    )

    parser.add_argument(
        "--port",
        type=int,
        default=8000,
        help="HTTP server port"
    )

    parser.add_argument(
        "--slots",
        type=int,
        default=4,
        help="Initial number of slots"
    )

    parser.add_argument(
        "--max-slots",
        type=int,
        default=8,
        help="Maximum slots"
    )

    parser.add_argument(
        "--controller-type",
        choices=["x360", "ds4", "mixed"],
        default="mixed"
    )

    parser.add_argument(
        "--auto-expand",
        action="store_true"
    )

    parser.add_argument(
        "--static-path",
        type=Path,
        default=Path("../controller_app/build/web")
    )

    parser.add_argument(
        "--debug",
        action="store_true"
    )

    return parser.parse_args()


def main():
    args = parse_args()

    # Initialize logging early so core modules emit structured logs
    setup_logging(logging.DEBUG if args.debug else logging.INFO)

    config = ServerConfig(
        web_page_static_path=args.static_path,
        http_port=args.port,
        initial_slots=args.slots,
        max_slots=args.max_slots,
        controller_type=args.controller_type,
        auto_expand_slots=args.auto_expand,
        debug=args.debug
    )

    run_server(config)


if __name__ == "__main__":
    main()