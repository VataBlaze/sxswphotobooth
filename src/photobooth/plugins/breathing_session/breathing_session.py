"""
breathing_session — Photobooth-app plugin for a before/after breathwork flow.

This plugin provides server-side state tracking for the Breathing Session
feature. The primary UI lives in userdata/breathing.html, which communicates
with the photobooth-app REST API to trigger captures.

Two integration approaches are supported (breathing.html handles both):

  APPROACH 1 — Direct API (simpler, recommended)
    The HTML page calls the photobooth-app's built-in capture endpoints
    directly (e.g. POST /api/action/image).  No custom REST routes needed.
    The plugin just tracks session state for optional server-side logging.

  APPROACH 2 — Custom REST endpoints via FastAPI router injection
    The plugin mounts a sub-router at /api/plugins/breathing/*.
    This requires the plugin's start() hook to receive the FastAPI app
    instance from the container.  If the photobooth-app's plugin lifecycle
    does not expose the app instance, fall back to Approach 1.

The implementation below attempts Approach 2 and falls back to Approach 1
gracefully.
"""

from __future__ import annotations

import logging
import time
from enum import Enum
from typing import Any

import pluggy

hookimpl = pluggy.HookimplMarker("photobooth")
logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Session state
# ---------------------------------------------------------------------------
class SessionState(str, Enum):
    IDLE = "idle"
    BEFORE_CAPTURE = "before_capture"
    BREATHING = "breathing"
    AFTER_CAPTURE = "after_capture"
    REVIEW = "review"


class _State:
    """Simple in-memory state store for a single active session."""

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
# Plugin class
# ---------------------------------------------------------------------------
class BreathingSession:
    """Photobooth-app plugin for the Breathing Session feature."""

    def __init__(self):
        self._session = _State()
        self._router_mounted = False

    # -- PluginManagementSpec hooks -----------------------------------------

    @hookimpl
    def start(self, app=None, **kwargs):
        """Called when the plugin is loaded.

        Parameters
        ----------
        app : optional
            If the photobooth-app plugin system passes the FastAPI ``app``
            instance (or the service container), we use it to mount custom
            routes.  If not available, the plugin still works — the
            breathing.html page can fall back to calling the built-in API.
        """
        logger.info("BreathingSession plugin starting.")
        self._session.reset()

        # Attempt to mount custom REST routes (Approach 2).
        if app is not None:
            try:
                self._mount_routes(app)
            except Exception:
                logger.warning(
                    "Could not mount custom REST routes — falling back to "
                    "client-side state management (Approach 1).  This is fine.",
                    exc_info=True,
                )
        else:
            logger.info(
                "No app instance received in start() — using Approach 1 "
                "(client-side state via built-in API)."
            )

    @hookimpl
    def stop(self, **kwargs):
        logger.info("BreathingSession plugin stopping.")
        self._session.reset()

    # -- Optional: PluginStatemachineSpec hooks ------------------------------
    # These fire on photobooth state-machine transitions.  We log them so the
    # plugin is aware when captures complete.

    @hookimpl(optionalhook=True)
    def sm_capture_completed(self, mediaitem=None, **kwargs):
        """Track mediaitem IDs when captures happen during a session."""
        if self._session.state == SessionState.BEFORE_CAPTURE and mediaitem:
            mid = getattr(mediaitem, "id", str(mediaitem))
            self._session.before_id = mid
            self._session.state = SessionState.BREATHING
            logger.info("Before-photo captured: %s", mid)

        elif self._session.state == SessionState.AFTER_CAPTURE and mediaitem:
            mid = getattr(mediaitem, "id", str(mediaitem))
            self._session.after_id = mid
            self._session.state = SessionState.REVIEW
            logger.info("After-photo captured: %s", mid)

    # -- Custom REST routes (Approach 2) ------------------------------------

    def _mount_routes(self, app):
        """Mount a FastAPI sub-router on the running application."""
        from fastapi import APIRouter
        from fastapi.responses import JSONResponse

        router = APIRouter(prefix="/api/plugins/breathing", tags=["breathing"])

        @router.post("/start")
        async def start_session():
            self._session.reset()
            self._session.state = SessionState.BEFORE_CAPTURE
            self._session.started_at = time.time()
            return JSONResponse({"status": "before_capture"})

        @router.get("/status")
        async def get_status():
            return JSONResponse(self._session.to_dict())

        @router.post("/complete")
        async def complete_session():
            self._session.state = SessionState.AFTER_CAPTURE
            return JSONResponse(self._session.to_dict())

        @router.post("/reset")
        async def reset_session():
            self._session.reset()
            return JSONResponse({"status": "idle"})

        # Try to include the router on the FastAPI app.
        # The exact attribute depends on how the container exposes it.
        fastapi_app = getattr(app, "app", None) or app
        if hasattr(fastapi_app, "include_router"):
            fastapi_app.include_router(router)
            self._router_mounted = True
            logger.info("Custom REST routes mounted at /api/plugins/breathing/*")
        else:
            raise AttributeError(
                "Could not find include_router on the provided app object."
            )
