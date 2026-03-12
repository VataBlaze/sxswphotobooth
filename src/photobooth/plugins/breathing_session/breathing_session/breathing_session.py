"""
breathing_session — Photobooth-app plugin for a before/after breathwork flow.

Logs all activity to ./log/breathing_session.log (relative to the photobooth
working directory, ~/photobooth-data/).  Also exposes a POST endpoint at
/api/plugins/breathing/log so the breathing.html frontend can write to the
same log file.

Architecture notes:
  - Uses BasePlugin[BreathingSessionConfig] per the official plugin skeleton.
  - The config class uses pydantic-settings and writes to
    ./config/plugin_breathing_session.json so it appears in Admin Center.
  - The plugin attempts to mount FastAPI routes for session orchestration.
    If that fails (import paths change across versions), breathing.html
    falls back to calling the app's built-in /api/ endpoints directly.
"""

from __future__ import annotations

import logging
import logging.handlers
import time
from enum import Enum
from pathlib import Path
from typing import Any

from photobooth.plugins import hookimpl
from photobooth.plugins.base_plugin import BasePlugin

from .config import BreathingSessionConfig

# ---------------------------------------------------------------------------
# File logger — writes to ./log/breathing_session.log
# CWD is ~/photobooth-data, so ./log/ already exists from the app.
# ---------------------------------------------------------------------------
LOG_DIR = Path("log")
LOG_FILE = LOG_DIR / "breathing_session.log"

logger = logging.getLogger("breathing_session")
logger.setLevel(logging.DEBUG)
logger.propagate = False  # avoid duplicate output to root logger

LOG_DIR.mkdir(parents=True, exist_ok=True)

_file_handler = logging.handlers.RotatingFileHandler(
    LOG_FILE,
    maxBytes=2 * 1024 * 1024,  # 2 MB
    backupCount=3,
    encoding="utf-8",
)
_file_handler.setLevel(logging.DEBUG)
_file_handler.setFormatter(
    logging.Formatter(
        fmt="%(asctime)s [%(levelname)-7s] %(name)s: %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
    )
)
logger.addHandler(_file_handler)

_console_handler = logging.StreamHandler()
_console_handler.setLevel(logging.INFO)
_console_handler.setFormatter(
    logging.Formatter(fmt="[breathing_session] %(levelname)s: %(message)s")
)
logger.addHandler(_console_handler)


# ---------------------------------------------------------------------------
# Session state machine
# ---------------------------------------------------------------------------
class SessionState(str, Enum):
    IDLE = "idle"
    BEFORE_CAPTURE = "before_capture"
    BREATHING = "breathing"
    AFTER_CAPTURE = "after_capture"
    REVIEW = "review"


class _SessionStore:
    def __init__(self):
        self.reset()

    def reset(self):
        self.state: SessionState = SessionState.IDLE
        self.before_id: str | None = None
        self.after_id: str | None = None
        self.started_at: float | None = None

    def to_dict(self) -> dict[str, Any]:
        return {
            "state": self.state.value,
            "before_id": self.before_id,
            "after_id": self.after_id,
            "started_at": self.started_at,
        }


# ---------------------------------------------------------------------------
# Plugin class  (folder = breathing_session → class = BreathingSession)
# ---------------------------------------------------------------------------
class BreathingSession(BasePlugin[BreathingSessionConfig]):
    def __init__(self):
        super().__init__()
        self._config: BreathingSessionConfig = BreathingSessionConfig()
        self._session = _SessionStore()
        self._router_mounted = False

    # ── PluginManagementSpec ──────────────────────────────────────────────

    @hookimpl
    def start(self):
        logger.info("═══ BreathingSession plugin starting ═══")
        logger.info(
            "Config: enabled=%s  duration=%ds  pattern=%s",
            self._config.plugin_enabled,
            self._config.breathing_duration_seconds,
            self._config.breathing_pattern,
        )
        self._session.reset()

        # Best-effort: try to mount custom REST routes
        try:
            self._mount_routes()
        except Exception as exc:
            logger.info(
                "Custom routes not mounted (%s). breathing.html will use the "
                "app's built-in capture API directly — this is normal.",
                exc,
            )

        logger.info("Plugin ready.  Log file → %s", LOG_FILE.resolve())

    @hookimpl
    def stop(self):
        logger.info("═══ BreathingSession plugin stopping ═══")
        self._session.reset()

    # ── PluginStatemachineSpec (optional hooks) ───────────────────────────

    @hookimpl(optionalhook=True)
    def sm_capture_completed(self, mediaitem=None, **kwargs):
        if self._session.state == SessionState.BEFORE_CAPTURE and mediaitem:
            mid = getattr(mediaitem, "id", str(mediaitem))
            self._session.before_id = mid
            self._session.state = SessionState.BREATHING
            logger.info("BEFORE photo captured → mediaitem_id=%s", mid)

        elif self._session.state == SessionState.AFTER_CAPTURE and mediaitem:
            mid = getattr(mediaitem, "id", str(mediaitem))
            self._session.after_id = mid
            self._session.state = SessionState.REVIEW
            logger.info("AFTER photo captured → mediaitem_id=%s", mid)

    # ── FastAPI route mounting (best-effort) ──────────────────────────────

    def _mount_routes(self):
        from fastapi import APIRouter, Request
        from fastapi.responses import JSONResponse

        router = APIRouter(prefix="/api/plugins/breathing", tags=["breathing"])

        @router.post("/start")
        async def _start():
            self._session.reset()
            self._session.state = SessionState.BEFORE_CAPTURE
            self._session.started_at = time.time()
            logger.info("Session started → awaiting before-capture")
            return JSONResponse({"status": "before_capture"})

        @router.get("/status")
        async def _status():
            return JSONResponse(self._session.to_dict())

        @router.post("/complete")
        async def _complete():
            self._session.state = SessionState.AFTER_CAPTURE
            logger.info("Breathing phase complete → awaiting after-capture")
            return JSONResponse(self._session.to_dict())

        @router.post("/reset")
        async def _reset():
            self._session.reset()
            logger.info("Session reset → idle")
            return JSONResponse({"status": "idle"})

        @router.post("/log")
        async def _frontend_log(request: Request):
            """Accept log entries from breathing.html and write them to the
            same rotating log file."""
            try:
                body = await request.json()
                level_name = body.get("level", "INFO").upper()
                message = body.get("message", "")
                level = getattr(logging, level_name, logging.INFO)
                logger.log(level, "[FRONTEND] %s", message)
                return JSONResponse({"ok": True})
            except Exception as exc:
                logger.error("Bad frontend log payload: %s", exc)
                return JSONResponse({"ok": False}, status_code=400)

        # Try known import paths for the FastAPI application instance.
        app_found = False
        import_attempts = [
            ("photobooth.application", "app"),
            ("photobooth.web", "app"),
            ("photobooth.container", "app"),
        ]
        for module_path, attr_name in import_attempts:
            try:
                import importlib
                mod = importlib.import_module(module_path)
                fastapi_app = getattr(mod, attr_name)
                if hasattr(fastapi_app, "include_router"):
                    fastapi_app.include_router(router)
                    self._router_mounted = True
                    app_found = True
                    logger.info("Routes mounted via %s.%s", module_path, attr_name)
                    break
            except (ImportError, AttributeError):
                continue

        if not app_found:
            raise RuntimeError("No FastAPI app instance found in known import paths")
