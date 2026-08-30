#!/usr/bin/env bash
# =============================================================================
# DAX AGENT ADAPTER — OPENCLAW (NATIVE RUNTIME)
# =============================================================================

source "$SCRIPT_DIR/lib/adapter_base.sh"

AGENT_NAME="openclaw"
AGENT_VENV="${SCRIPT_DIR}/.openclawvenv"
AGENT_LOG="${LOG_DIR}/openclaw.log"
AGENT_PID_FILE="${PID_DIR}/openclaw.pid"
AGENT_EXEC="$AGENT_VENV/bin/openclaw"
AGENT_MODULE="openclaw"
AGENT_PIP_PACKAGE="openclaw"
AGENT_INSTALL_CMDS=(
  "$AGENT_VENV/bin/python -m pip install --ignore-requires-python git+https://github.com/openclaw/openclaw.git"
)

adapter_install(){ adapter_base_install; }
adapter_start(){ adapter_base_start; }
adapter_stop(){ adapter_base_stop; }
adapter_status(){ adapter_base_status; }
adapter_logs(){ adapter_base_logs; }
adapter_health(){ adapter_base_health; }
adapter_uninstall(){ adapter_base_uninstall; }
