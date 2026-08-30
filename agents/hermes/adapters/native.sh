#!/usr/bin/env bash
# =============================================================================
# DAX AGENT ADAPTER — HERMES (NATIVE RUNTIME)
# =============================================================================

source "$SCRIPT_DIR/lib/adapter_base.sh"

AGENT_NAME="hermes"
AGENT_VENV="${SCRIPT_DIR}/.hermesvenv"
AGENT_LOG="${LOG_DIR}/hermes.log"
AGENT_PID_FILE="${PID_DIR}/hermes.pid"
AGENT_EXEC="$AGENT_VENV/bin/hermes"
AGENT_MODULE="hermes"
AGENT_PIP_PACKAGE="hermes-agent"
AGENT_INSTALL_CMDS=(
  "curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | bash"
)

adapter_install(){ adapter_base_install; }
adapter_start(){ adapter_base_start; }
adapter_stop(){ adapter_base_stop; }
adapter_status(){ adapter_base_status; }
adapter_logs(){ adapter_base_logs; }
adapter_health(){ adapter_base_health; }
adapter_uninstall(){ adapter_base_uninstall; }
