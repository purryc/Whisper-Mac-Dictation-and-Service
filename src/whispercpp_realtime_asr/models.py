from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any

from pydantic import BaseModel, Field


@dataclass
class EngineTranscript:
    text: str
    language: str
    duration_ms: int
    engine: str
    raw_stdout: str = ""
    metadata: dict[str, Any] = field(default_factory=dict)


class TranscriptResponse(BaseModel):
    text: str
    language: str
    duration_ms: int
    engine: str
    metadata: dict[str, Any] = Field(default_factory=dict)


class ErrorEvent(BaseModel):
    type: str = "error"
    code: str
    message: str


class SessionStartedEvent(BaseModel):
    type: str = "session_started"
    sample_rate: int
    channels: int


class PartialEvent(BaseModel):
    type: str = "partial"
    text: str
    is_final: bool = False


class SessionFinalEvent(BaseModel):
    type: str = "session_final"
    text: str
    is_final: bool = True
    duration_ms: int
    language: str
    engine: str
