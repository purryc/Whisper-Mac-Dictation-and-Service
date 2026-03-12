#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="${ROOT_DIR}/WhisperCPP_gateway.env"
MODEL_DIR="${ROOT_DIR}/.whisper-runtime/models"
MODEL_PATH="${MODEL_DIR}/ggml-small.bin"
BINARY_PATH="/opt/homebrew/bin/whisper-cli"
MODEL_URL="https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.bin"

mkdir -p "${MODEL_DIR}"

notify() {
  local title="$1"
  local message="$2"
  if command -v osascript >/dev/null 2>&1; then
    osascript -e "display notification \"${message//\"/\\\"}\" with title \"${title//\"/\\\"}\"" >/dev/null 2>&1 || true
  fi
  echo "${title}: ${message}"
}

if ! command -v brew >/dev/null 2>&1; then
  notify "WhisperCPP Runtime Installer" "Homebrew is required but was not found."
  exit 1
fi

if ! command -v whisper-cli >/dev/null 2>&1; then
  brew install whisper-cpp
fi

if [[ ! -f "${MODEL_PATH}" ]]; then
  curl -L --fail --progress-bar -o "${MODEL_PATH}" "${MODEL_URL}"
fi

if [[ ! -f "${ENV_FILE}" ]]; then
  cp "${ROOT_DIR}/WhisperCPP_gateway.env.example" "${ENV_FILE}"
fi

INSTALL_ENV_FILE="${ENV_FILE}" \
INSTALL_BINARY_PATH="${BINARY_PATH}" \
INSTALL_MODEL_PATH="${MODEL_PATH}" \
python3 <<'PY'
import os
from pathlib import Path

env_path = Path(os.environ["INSTALL_ENV_FILE"])
binary_path = os.environ["INSTALL_BINARY_PATH"]
model_path = os.environ["INSTALL_MODEL_PATH"]

updated_lines = []
for raw_line in env_path.read_text(encoding="utf-8").splitlines():
    if raw_line.startswith("WHISPER_CPP_BINARY="):
        updated_lines.append(f'WHISPER_CPP_BINARY="{binary_path}"')
    elif raw_line.startswith("WHISPER_CPP_MODEL="):
        updated_lines.append(f'WHISPER_CPP_MODEL="{model_path}"')
    else:
        updated_lines.append(raw_line)

env_path.write_text("\n".join(updated_lines) + "\n", encoding="utf-8")
PY

notify \
  "WhisperCPP Runtime Installer" \
  "Installed whisper.cpp runtime, downloaded the small multilingual model, and updated WhisperCPP_gateway.env."
