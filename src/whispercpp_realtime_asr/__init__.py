"""Reusable local ASR gateway built around whisper.cpp."""

from .app import create_app

__all__ = ["create_app"]
