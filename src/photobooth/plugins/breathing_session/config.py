"""Configuration for the breathing_session plugin."""

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
        description="Enable the Breathing Session feature.",
    )
    breathing_duration_seconds: int = Field(
        default=240,
        description="Session duration in seconds (default 240 = 4 min).",
    )
    breathing_pattern: str = Field(
        default="4-4-6-2",
        description="Cycle as inhale-hold-exhale-pause seconds. Default 4-4-6-2 = 16s.",
    )
    session_title: str = Field(
        default="BREATHE ₿",
        description="Title shown on the breathing session page.",
    )
