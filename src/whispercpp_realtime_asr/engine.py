from __future__ import annotations

import asyncio
import re
import shlex
from pathlib import Path
from typing import Protocol

from .config import Settings
from .models import EngineTranscript


class TranscriptionEngine(Protocol):
    async def transcribe(
        self,
        audio_path: Path,
        *,
        language: str | None = None,
        prompt: str | None = None,
        duration_ms: int = 0,
    ) -> EngineTranscript:
        ...


class WhisperCliEngine:
    """Invoke a local whisper.cpp CLI binary.

    The default command template expects a binary compatible with:
    `{bin} -m {model} -f {input} -l {language}`
    """

    def __init__(self, settings: Settings) -> None:
        self.settings = settings

    async def transcribe(
        self,
        audio_path: Path,
        *,
        language: str | None = None,
        prompt: str | None = None,
        duration_ms: int = 0,
    ) -> EngineTranscript:
        if not self.settings.configured:
            raise RuntimeError(
                "Missing whisper.cpp configuration. Set WHISPER_CPP_BINARY and "
                "WHISPER_CPP_MODEL before starting the service."
            )

        language_value = language or self.settings.default_language
        language_flag = "" if language_value in {"", "auto"} else f"-l {language_value}"
        prompt_flag = "" if not prompt else f'--prompt {shlex.quote(prompt)}'

        command_string = self.settings.command_template.format(
            bin=shlex.quote(self.settings.whisper_binary),
            model=shlex.quote(self.settings.whisper_model),
            input=shlex.quote(str(audio_path)),
            language_flag=language_flag,
            prompt_flag=prompt_flag,
            language=language_value,
            prompt=prompt or "",
        ).strip()

        process = await asyncio.create_subprocess_exec(
            *shlex.split(command_string),
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
        stdout_bytes, stderr_bytes = await process.communicate()
        stdout = stdout_bytes.decode("utf-8", errors="ignore")
        stderr = stderr_bytes.decode("utf-8", errors="ignore")

        if process.returncode != 0:
            raise RuntimeError(
                f"whisper.cpp command failed with code {process.returncode}: {stderr.strip() or stdout.strip()}"
            )

        text = self._extract_text(stdout)
        return EngineTranscript(
            text=text,
            language=language_value,
            duration_ms=duration_ms,
            engine="whisper-cli",
            raw_stdout=stdout,
            metadata={"stderr": stderr.strip()},
        )

    def _extract_text(self, stdout: str) -> str:
        lines = []
        for raw_line in stdout.splitlines():
            line = raw_line.strip()
            if not line:
                continue
            line = re.sub(r"^\[[^\]]+\]\s*", "", line)
            if not line:
                continue
            if ":" in line and not line[0].isalnum():
                continue
            if line:
                lines.append(line)
        return " ".join(lines).strip()
