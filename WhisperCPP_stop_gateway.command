#!/bin/bash
set -euo pipefail

APP_SUPPORT_DIR="${HOME}/Library/Application Support/WhisperCPP"
SERVICE_FILE="${APP_SUPPORT_DIR}/service.json"

pid="$(lsof -tiTCP:8765 -sTCP:LISTEN 2>/dev/null | head -n 1 || true)"
if [[ -n "${pid}" ]]; then
  kill "${pid}" >/dev/null 2>&1 || true
  sleep 1
  if kill -0 "${pid}" >/dev/null 2>&1; then
    kill -9 "${pid}" >/dev/null 2>&1 || true
  fi
fi

mkdir -p "${APP_SUPPORT_DIR}"
python3 <<'PY'
import json
import os
from pathlib import Path

service_file = Path(os.path.expanduser("~/Library/Application Support/WhisperCPP/service.json"))
payload = {
    "service_name": "WhisperCPP Local Gateway",
    "mode": "single_machine_local",
    "status": "stopped",
    "configured": True,
    "host": "127.0.0.1",
    "port": 8765,
    "base_url": "http://127.0.0.1:8765",
    "health_url": "http://127.0.0.1:8765/healthz",
    "capabilities_url": "http://127.0.0.1:8765/v1/asr/capabilities",
    "transcribe_url": "http://127.0.0.1:8765/v1/asr/transcribe",
    "stream_url": "ws://127.0.0.1:8765/v1/asr/stream",
    "pid": None,
    "updated_at": __import__("datetime").datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"),
}
service_file.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
PY

echo "WhisperCPP gateway stopped."
