"""Configuration for the breathing_session plugin."""

from pydantic import BaseModel, Field


class BreathingSessionConfig(BaseModel):
    """Pydantic config — editable via Admin Center if the plugin registers it."""

    plugin_enabled: bool = Field(
        default=True,
        description="Enable or disable the Breathing Session feature.",
    )
    breathing_duration_seconds: int = Field(
        default=240,
        description="Total breathing session duration in seconds (default 4 min).",
    )
    breathing_pattern: str = Field(
        default="4-4-6-2",
        description=(
            "Breathing pattern as inhale-hold-exhale-pause in seconds. "
            "Default 4-4-6-2 = 16 s cycle."
        ),
    )
    session_title: str = Field(
        default="BREATHE ₿",
        description="Title displayed on the breathing session page.",
    )
