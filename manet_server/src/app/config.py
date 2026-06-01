from dataclasses import dataclass
import os
from pathlib import Path
from typing import Literal
import dotenv
dotenv.load_dotenv()

ControllerType = Literal["x360", "ds4", "mixed"]

@dataclass
class ServerConfig:
    web_page_static_path: Path 
    debug: bool = False
    http_port: int = 8000
    ws_endpoint: str = "/ws"
    initial_slots: int = 4
    max_slots: int = 8
    controller_type: ControllerType = "mixed"
    auto_expand_slots: bool = False
    slot_reservation_timeout: int = 300

    DEFAULT_COLORS = [
        "#EF4444",  # vermelho
        "#2563EB",  # azul
        "#F59E0B",  # amarelo
        "#10B981",  # verde
        "#7C3AED",  # roxo
        "#F97316",  # laranja
        "#EC4899",  # rosa
        "#06B6D4",  # ciano
        "#800606",  # vermelho
        "#04256D",  # azul
        "#704A08",  # amarelo
        "#045F40",  # verde
        "#280662",  # roxo
        "#933D00",  # laranja
        "#7A003D",  # rosa
        "#006D81",  # ciano

    ]