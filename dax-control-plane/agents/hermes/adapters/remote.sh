#!/usr/bin/env bash
# =============================================================================
# DAX AGENT ADAPTER — HERMES (REMOTE SSH RUNTIME)
# =============================================================================
set -Eeuo pipefail

REMOTE_ID="${REMOTE_ID:-lab01}"

_get_ssh_cmd(){
  local host
  host="$(secret_get "SSH_HOST" "remote" "$REMOTE_ID" 2>/dev/null || echo "")"
  local user
  user="$(secret_get "SSH_USER" "remote" "$REMOTE_ID" 2>/dev/null || echo "root")"
  local key
  key="$(secret_get "SSH_KEY" "remote" "$REMOTE_ID" 2>/dev/null || echo "")"

  if [[ -z "$host" ]]; then
    echo "echo 'Remote Host (SSH_HOST) für scope=remote/$REMOTE_ID nicht konfiguriert.'; exit 1;"
    return 0
  fi

  local key_opt=""
  if [[ -n "$key" && -f "$key" ]]; then
    key_opt="-i $key"
  fi
  echo "ssh -o StrictHostKeyChecking=accept-new $key_opt ${user}@${host}"
}

adapter_install(){
  local ssh_cmd
  ssh_cmd="$(_get_ssh_cmd)"
  info "Installiere Hermes Agent remote auf $REMOTE_ID..."
  $ssh_cmd "python3 -m venv ~/.hermesvenv && ~/.hermesvenv/bin/pip install hermes-agent" 2>/dev/null || warn "Remote SSH nicht erreichbar."
}

adapter_start(){
  local ssh_cmd
  ssh_cmd="$(_get_ssh_cmd)"
  info "Starte Hermes Agent remote auf $REMOTE_ID..."
  $ssh_cmd "nohup ~/.hermesvenv/bin/hermes start >/dev/null 2>&1 &" 2>/dev/null || warn "Remote SSH nicht erreichbar."
}

adapter_stop(){
  local ssh_cmd
  ssh_cmd="$(_get_ssh_cmd)"
  info "Stoppe Hermes Agent remote auf $REMOTE_ID..."
  $ssh_cmd "pkill -f hermes" 2>/dev/null || true
}

adapter_status(){
  local ssh_cmd
  ssh_cmd="$(_get_ssh_cmd)"
  if $ssh_cmd "pgrep -f hermes" >/dev/null 2>&1; then
    echo "Hermes (Remote/$REMOTE_ID): RUNNING"
  else
    echo "Hermes (Remote/$REMOTE_ID): STOPPED"
  fi
}

adapter_logs(){
  local ssh_cmd
  ssh_cmd="$(_get_ssh_cmd)"
  $ssh_cmd "tail -n 50 ~/.hermes/logs/hermes.log 2>/dev/null || echo 'Keine Remote Logs'"
}

adapter_health(){
  local ssh_cmd
  ssh_cmd="$(_get_ssh_cmd)"
  if $ssh_cmd "pgrep -f hermes" >/dev/null 2>&1; then
    echo "HEALTHY"
  else
    echo "STOPPED"
  fi
}

adapter_uninstall(){
  local ssh_cmd
  ssh_cmd="$(_get_ssh_cmd)"
  $ssh_cmd "rm -rf ~/.hermesvenv ~/.hermes" 2>/dev/null || true
}
