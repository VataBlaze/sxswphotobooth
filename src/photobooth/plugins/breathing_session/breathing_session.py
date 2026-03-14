"""
breathing_session — Before/after breathwork photo session.

Logs to ./log/breathing_session.log (relative to CWD = ~/photobooth-data/).
"""

import logging
import logging.handlers
from pathlib import Path

from photobooth.plugins import hookimpl
from photobooth.plugins.base_plugin import BasePlugin

from .config import BreathingSessionConfig

# ---------------------------------------------------------------------------
# File logger
# ---------------------------------------------------------------------------
LOG_DIR = Path("log")
LOG_FILE = LOG_DIR / "breathing_session.log"

logger = logging.getLogger("breathing_session")
logger.setLevel(logging.DEBUG)
logger.propagate = False

LOG_DIR.mkdir(parents=True, exist_ok=True)

_fh = logging.handlers.RotatingFileHandler(
    LOG_FILE, maxBytes=2 * 1024 * 1024, backupCount=3, encoding="utf-8",
)
_fh.setLevel(logging.DEBUG)
_fh.setFormatter(logging.Formatter(
    fmt="%(asctime)s [%(levelname)-7s] %(name)s: %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
))
logger.addHandler(_fh)

_ch = logging.StreamHandler()
_ch.setLevel(logging.INFO)
_ch.setFormatter(logging.Formatter(fmt="[breathing_session] %(levelname)s: %(message)s"))
logger.addHandler(_ch)


# ---------------------------------------------------------------------------
# Plugin class (folder = breathing_session → class = BreathingSession)
# ---------------------------------------------------------------------------
class BreathingSession(BasePlugin[BreathingSessionConfig]):
    def __init__(self):
        super().__init__()
        self._config: BreathingSessionConfig = BreathingSessionConfig()

    @hookimpl
    def start(self):
        logger.info("═══ BreathingSession plugin starting ═══")
        logger.info(
            "Config: enabled=%s duration=%ds pattern=%s",
            self._config.plugin_enabled,
            self._config.breathing_duration_seconds,
            self._config.breathing_pattern,
        )
        logger.info("Log file: %s", LOG_FILE.resolve())

    @hookimpl
    def stop(self):
        logger.info("═══ BreathingSession plugin stopping ═══")

    @hookimpl(optionalhook=True)
    def sm_capture_completed(self, mediaitem=None, **kwargs):
        """Log every capture — useful for debugging the breathing flow."""
        if mediaitem:
            mid = getattr(mediaitem, "id", str(mediaitem))
            logger.info("Capture completed: mediaitem_id=%s", mid)
