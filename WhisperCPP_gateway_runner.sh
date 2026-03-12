#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="${ROOT_DIR}/WhisperCPP_gateway.env"
VENV_DIR="${ROOT_DIR}/.venv"

set -a
source "${ENV_FILE}"
set +a
source "${VENV_DIR}/bin/activate"

cd "${ROOT_DIR}"
exec whispercpp-asr
