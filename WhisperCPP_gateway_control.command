#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="${ROOT_DIR}/WhisperCPP_gateway.env"
ENV_EXAMPLE="${ROOT_DIR}/WhisperCPP_gateway.env.example"
VENV_DIR="${ROOT_DIR}/.venv"
RUNTIME_DIR="${ROOT_DIR}/.gateway-runtime"
PID_FILE="${RUNTIME_DIR}/gateway.pid"
LOG_FILE="${RUNTIME_DIR}/gateway.log"
APP_SUPPORT_DIR="${HOME}/Library/Application Support/WhisperCPP"
SERVICE_FILE="${APP_SUPPORT_DIR}/service.json"
RUNNER_FILE="${ROOT_DIR}/WhisperCPP_gateway_runner.sh"
LAUNCH_AGENT_DIR="${HOME}/Library/LaunchAgents"
PLIST_FILE="${LAUNCH_AGENT_DIR}/com.hmi.whispercpp.gateway.plist"
LABEL="com.hmi.whispercpp.gateway"

DEFAULT_HOST="127.0.0.1"
DEFAULT_PORT="8765"
HOST_VALUE="${DEFAULT_HOST}"
PORT_VALUE="${DEFAULT_PORT}"

mkdir -p "${RUNTIME_DIR}"
mkdir -p "${APP_SUPPORT_DIR}"
mkdir -p "${LAUNCH_AGENT_DIR}"

notify() {
  local title="$1"
  local message="$2"
  if command -v osascript >/dev/null 2>&1; then
    osascript -e "display notification \"${message//\"/\\\"}\" with title \"${title//\"/\\\"}\"" >/dev/null 2>&1 || true
  fi
  echo "${title}: ${message}"
}

refresh_defaults() {
  HOST_VALUE="${WHISPER_CPP_HOST:-${DEFAULT_HOST}}"
  PORT_VALUE="${WHISPER_CPP_PORT:-${DEFAULT_PORT}}"
}

current_listener_pid() {
  lsof -tiTCP:"${PORT_VALUE}" -sTCP:LISTEN 2>/dev/null | head -n 1 || true
}

write_service_discovery() {
  local status="$1"
  local configured="$2"
  local pid_value="${3:-}"
  local last_error="${4:-}"

  refresh_defaults

  SERVICE_STATUS="${status}" \
  SERVICE_CONFIGURED="${configured}" \
  SERVICE_PID="${pid_value}" \
  SERVICE_HOST="${HOST_VALUE}" \
  SERVICE_PORT="${PORT_VALUE}" \
  SERVICE_LOG_FILE="${LOG_FILE}" \
  SERVICE_ENV_FILE="${ENV_FILE}" \
  SERVICE_LAST_ERROR="${last_error}" \
  SERVICE_UPDATED_AT="$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  SERVICE_FILE_PATH="${SERVICE_FILE}" \
  python3 <<'PY'
import json
import os
from pathlib import Path

service_file = Path(os.environ["SERVICE_FILE_PATH"]).expanduser()
host = os.environ["SERVICE_HOST"]
port = os.environ["SERVICE_PORT"]
base_url = f"http://{host}:{port}"
payload = {
    "service_name": "WhisperCPP Local Gateway",
    "mode": "single_machine_local",
    "status": os.environ["SERVICE_STATUS"],
    "configured": os.environ["SERVICE_CONFIGURED"].lower() == "true",
    "host": host,
    "port": int(port),
    "base_url": base_url,
    "health_url": f"{base_url}/healthz",
    "capabilities_url": f"{base_url}/v1/asr/capabilities",
    "transcribe_url": f"{base_url}/v1/asr/transcribe",
    "stream_url": f"ws://{host}:{port}/v1/asr/stream",
    "pid": int(os.environ["SERVICE_PID"]) if os.environ["SERVICE_PID"] else None,
    "env_file": os.environ["SERVICE_ENV_FILE"],
    "log_file": os.environ["SERVICE_LOG_FILE"],
    "updated_at": os.environ["SERVICE_UPDATED_AT"],
    "client_guidance": {
        "mac": "Other apps on this Mac should reuse this local gateway.",
        "iphone_ipad": "Use on-device transcription instead of this local gateway.",
    },
}
last_error = os.environ.get("SERVICE_LAST_ERROR")
if last_error:
    payload["last_error"] = last_error

service_file.parent.mkdir(parents=True, exist_ok=True)
service_file.write_text(json.dumps(payload, indent=2, ensure_ascii=True) + "\n", encoding="utf-8")
PY
}

ensure_env_file() {
  if [[ ! -f "${ENV_FILE}" ]]; then
    cp "${ENV_EXAMPLE}" "${ENV_FILE}"
    write_service_discovery "needs_configuration" "false" "" "Missing local gateway configuration."
    notify \
      "WhisperCPP Local ASR Gateway" \
      "Created WhisperCPP_gateway.env. Edit WHISPER_CPP_BINARY and WHISPER_CPP_MODEL, then run this command again."
    open -R "${ENV_FILE}" >/dev/null 2>&1 || true
    exit 0
  fi
}

load_env() {
  set -a
  source "${ENV_FILE}"
  set +a
  export WHISPER_CPP_HOST="${WHISPER_CPP_HOST:-${DEFAULT_HOST}}"
  export WHISPER_CPP_PORT="${WHISPER_CPP_PORT:-${DEFAULT_PORT}}"
  refresh_defaults
}

ensure_configured() {
  if [[ -z "${WHISPER_CPP_BINARY:-}" || -z "${WHISPER_CPP_MODEL:-}" ]]; then
    write_service_discovery "needs_configuration" "false" "" "WHISPER_CPP_BINARY or WHISPER_CPP_MODEL is missing."
    notify \
      "WhisperCPP Local ASR Gateway" \
      "WhisperCPP_gateway.env is missing WHISPER_CPP_BINARY or WHISPER_CPP_MODEL."
    open -R "${ENV_FILE}" >/dev/null 2>&1 || true
    exit 1
  fi

  if [[ "${WHISPER_CPP_BINARY}" == /absolute/path/* || ! -x "${WHISPER_CPP_BINARY}" ]]; then
    write_service_discovery "needs_configuration" "false" "" "WHISPER_CPP_BINARY is still a placeholder or is not executable."
    notify \
      "WhisperCPP Local ASR Gateway" \
      "WhisperCPP_gateway.env needs a real executable WHISPER_CPP_BINARY path."
    open -R "${ENV_FILE}" >/dev/null 2>&1 || true
    exit 1
  fi

  if [[ "${WHISPER_CPP_MODEL}" == /absolute/path/* || ! -f "${WHISPER_CPP_MODEL}" ]]; then
    write_service_discovery "needs_configuration" "false" "" "WHISPER_CPP_MODEL is still a placeholder or does not exist."
    notify \
      "WhisperCPP Local ASR Gateway" \
      "WhisperCPP_gateway.env needs a real WHISPER_CPP_MODEL file path."
    open -R "${ENV_FILE}" >/dev/null 2>&1 || true
    exit 1
  fi
}

ensure_python_env() {
  if [[ ! -d "${VENV_DIR}" ]]; then
    python3 -m venv "${VENV_DIR}"
  fi

  source "${VENV_DIR}/bin/activate"
  "${VENV_DIR}/bin/python" -m ensurepip --upgrade >/dev/null 2>&1 || true

  if [[ ! -x "${VENV_DIR}/bin/whispercpp-asr" ]]; then
    (
      cd "${ROOT_DIR}"
      pip install . >/dev/null
    )
  fi
}

is_running() {
  refresh_defaults
  local listener_pid
  listener_pid="$(current_listener_pid)"
  if [[ -n "${listener_pid}" ]]; then
    echo "${listener_pid}" > "${PID_FILE}"
    write_service_discovery "running" "true" "${listener_pid}" ""
    return 0
  fi

  if [[ -f "${PID_FILE}" ]]; then
    local pid
    pid="$(cat "${PID_FILE}")"
    if [[ -n "${pid}" ]] && kill -0 "${pid}" >/dev/null 2>&1; then
      write_service_discovery "running" "true" "${pid}" ""
      return 0
    fi
    rm -f "${PID_FILE}"
    write_service_discovery "stopped" "true" "" ""
  fi
  return 1
}

write_launch_agent() {
  cat > "${PLIST_FILE}" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>${LABEL}</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>-lc</string>
    <string>cd "${ROOT_DIR}" &amp;&amp; exec "${RUNNER_FILE}"</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>WorkingDirectory</key>
  <string>${ROOT_DIR}</string>
  <key>StandardOutPath</key>
  <string>${LOG_FILE}</string>
  <key>StandardErrorPath</key>
  <string>${LOG_FILE}</string>
</dict>
</plist>
EOF
}

bootstrap_launch_agent() {
  launchctl bootout "gui/$(id -u)/${LABEL}" >/dev/null 2>&1 || true
  launchctl bootstrap "gui/$(id -u)" "${PLIST_FILE}"
  launchctl kickstart -k "gui/$(id -u)/${LABEL}" >/dev/null 2>&1 || true
}

stop_launch_agent() {
  launchctl bootout "gui/$(id -u)/${LABEL}" >/dev/null 2>&1 || true
}

start_gateway() {
  ensure_env_file
  load_env
  ensure_configured
  ensure_python_env
  chmod +x "${RUNNER_FILE}"
  write_launch_agent

  write_service_discovery "starting" "true" "" ""
  bootstrap_launch_agent
  sleep 2

  local pid
  pid="$(current_listener_pid)"
  if kill -0 "${pid}" >/dev/null 2>&1; then
    echo "${pid}" > "${PID_FILE}"
    write_service_discovery "running" "true" "${pid}" ""
    notify \
      "WhisperCPP Local ASR Gateway" \
      "Started on http://127.0.0.1:${WHISPER_CPP_PORT}. Other Mac apps can now call the local ASR service."
    exit 0
  fi

  stop_launch_agent
  rm -f "${PID_FILE}"
  write_service_discovery "error" "true" "" "Gateway process exited before becoming healthy. Check the log file."
  notify "WhisperCPP Local ASR Gateway" "Failed to start. Check ${LOG_FILE}."
  open -R "${LOG_FILE}" >/dev/null 2>&1 || true
  exit 1
}

stop_gateway() {
  local pid=""
  if [[ -f "${PID_FILE}" ]]; then
    pid="$(cat "${PID_FILE}")"
  fi

  stop_launch_agent

  if [[ -n "${pid}" ]]; then
    kill "${pid}" >/dev/null 2>&1 || true

    for _ in 1 2 3 4 5; do
      if kill -0 "${pid}" >/dev/null 2>&1; then
        sleep 1
      else
        break
      fi
    done

    if kill -0 "${pid}" >/dev/null 2>&1; then
      kill -9 "${pid}" >/dev/null 2>&1 || true
    fi
  fi

  rm -f "${PID_FILE}"
  write_service_discovery "stopped" "true" "" ""
  notify "WhisperCPP Local ASR Gateway" "Stopped."
}

action="${1:-toggle}"

case "${action}" in
  start)
    if is_running; then
      notify "WhisperCPP Local ASR Gateway" "Already running on http://127.0.0.1:${PORT_VALUE}."
      exit 0
    fi
    start_gateway
    ;;
  stop)
    if is_running; then
      stop_gateway
    else
      write_service_discovery "stopped" "true" "" ""
      notify "WhisperCPP Local ASR Gateway" "Already stopped."
    fi
    ;;
  toggle)
    if is_running; then
      stop_gateway
    else
      start_gateway
    fi
    ;;
  *)
    echo "Usage: $0 [start|stop|toggle]"
    exit 1
    ;;
esac
