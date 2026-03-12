#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="${ROOT_DIR}/WhisperCPP_gateway.env"
MODEL_PATH="${ROOT_DIR}/.whisper-runtime/models/ggml-small.bin"

if [[ ! -f "${MODEL_PATH}" ]]; then
  echo "Balanced model not found. Run WhisperCPP_install_runtime.command first."
  exit 1
fi

python3 <<'PY' "${ENV_FILE}" "${MODEL_PATH}"
import sys
from pathlib import Path

env_path = Path(sys.argv[1])
model_path = sys.argv[2]

lines = env_path.read_text(encoding="utf-8").splitlines()
updated = []
for line in lines:
    if line.startswith("WHISPER_CPP_MODEL="):
        updated.append(f'WHISPER_CPP_MODEL="{model_path}"')
    else:
        updated.append(line)
env_path.write_text("\n".join(updated) + "\n", encoding="utf-8")
PY

osascript -e 'display notification "Switched to the balanced small model." with title "WhisperCPP Model Switcher"' >/dev/null 2>&1 || true
echo "WhisperCPP Model Switcher: switched to balanced small model."
