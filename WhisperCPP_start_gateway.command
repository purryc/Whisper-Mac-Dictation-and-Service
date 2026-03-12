#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
RUNNER_PATH="${ROOT_DIR}/WhisperCPP_gateway_runner.sh"
ENV_FILE="${ROOT_DIR}/WhisperCPP_gateway.env"
VENV_DIR="${ROOT_DIR}/.venv"
APP_SUPPORT_DIR="${HOME}/Library/Application Support/WhisperCPP"
SERVICE_FILE="${APP_SUPPORT_DIR}/service.json"
LOG_FILE="${ROOT_DIR}/.gateway-runtime/gateway.log"

mkdir -p "${APP_SUPPORT_DIR}"
mkdir -p "${ROOT_DIR}/.gateway-runtime"

if lsof -tiTCP:8765 -sTCP:LISTEN >/dev/null 2>&1; then
  echo "WhisperCPP gateway is already running on http://127.0.0.1:8765."
  exit 0
fi

if [[ ! -f "${ENV_FILE}" || ! -d "${VENV_DIR}" ]]; then
  echo "Please run WhisperCPP_install_runtime.command first."
  exit 1
fi

RUN_COMMAND="cd '${ROOT_DIR}' && '${RUNNER_PATH}'"

OSA_RUN_COMMAND="${RUN_COMMAND}" osascript <<'OSA'
tell application "Terminal"
  activate
  do script (system attribute "OSA_RUN_COMMAND")
end tell
OSA

for _ in {1..20}; do
  if curl -sf http://127.0.0.1:8765/healthz >/dev/null 2>&1; then
    python3 <<'PY'
import json
import os
from pathlib import Path

service_file = Path(os.path.expanduser("~/Library/Application Support/WhisperCPP/service.json"))
payload = {
    "service_name": "WhisperCPP Local Gateway",
    "mode": "single_machine_local",
    "status": "running",
    "configured": True,
    "host": "127.0.0.1",
    "port": 8765,
    "base_url": "http://127.0.0.1:8765",
    "health_url": "http://127.0.0.1:8765/healthz",
    "capabilities_url": "http://127.0.0.1:8765/v1/asr/capabilities",
    "transcribe_url": "http://127.0.0.1:8765/v1/asr/transcribe",
    "stream_url": "ws://127.0.0.1:8765/v1/asr/stream",
    "pid": None,
    "env_file": "/Users/hmi/Documents/my skills/whispercpp-realtime-asr/WhisperCPP_gateway.env",
    "log_file": "/Users/hmi/Documents/my skills/whispercpp-realtime-asr/.gateway-runtime/gateway.log",
    "updated_at": __import__("datetime").datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"),
}
service_file.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
PY
    echo "WhisperCPP gateway started on http://127.0.0.1:8765."
    echo "A Terminal window was opened to keep the service running."
    exit 0
  fi
  sleep 1
done

echo "WhisperCPP gateway did not become healthy. Check ${LOG_FILE}."
exit 1
