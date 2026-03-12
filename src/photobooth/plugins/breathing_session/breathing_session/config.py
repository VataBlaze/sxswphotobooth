"""Configuration for the breathing_session plugin.

Uses pydantic-settings and the photobooth-app BaseConfig so the configuration
is editable in the Admin Center and persisted to a JSON file.
"""

from pydantic import Field
from pydantic_settings import SettingsConfigDict

from photobooth import CONFIG_PATH
from photobooth.services.config.baseconfig import BaseConfig


class BreathingSessionConfig(BaseConfig):
    model_config = SettingsConfigDict(
        title="Breathing Session Config",
        json_file=f"{CONFIG_PATH}plugin_breathing_session.json",
    )

    plugin_enabled: bool = Field(
        default=True,
        description="Enable or disable the Breathing Session feature.",
    )
    breathing_duration_seconds: int = Field(
        default=240,
        description="Total breathing session duration in seconds (default 240 = 4 min).",
    )
    breathing_pattern: str = Field(
        default="4-4-6-2",
        description=(
            "Breathing cycle as inhale-hold-exhale-pause in seconds. "
            "Default 4-4-6-2 = 16 s per cycle."
        ),
    )
    session_title: str = Field(
        default="BREATHE ₿",
        description="Title displayed on the breathing session landing page.",
    )
