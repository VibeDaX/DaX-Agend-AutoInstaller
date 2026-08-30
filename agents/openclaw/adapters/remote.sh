#!/usr/bin/env bash
# =============================================================================
# DAX AGENT ADAPTER — OPENCLAW (REMOTE SSH RUNTIME)
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
  echo "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null $key_opt ${user}@${host}"
}

adapter_install(){
  local ssh_cmd
  ssh_cmd="$(_get_ssh_cmd)"
  info "Installiere OpenClaw remote auf $REMOTE_ID..."
  $ssh_cmd "python3 -m venv ~/.openclawvenv && ~/.openclawvenv/bin/pip install openclaw" 2>/dev/null || warn "Remote SSH nicht erreichbar."
}

adapter_start(){
  local ssh_cmd
  ssh_cmd="$(_get_ssh_cmd)"
  info "Starte OpenClaw remote auf $REMOTE_ID..."
  $ssh_cmd "nohup ~/.openclawvenv/bin/openclaw start >/dev/null 2>&1 &" 2>/dev/null || warn "Remote SSH nicht erreichbar."
}

adapter_stop(){
  local ssh_cmd
  ssh_cmd="$(_get_ssh_cmd)"
  info "Stoppe OpenClaw remote auf $REMOTE_ID..."
  $ssh_cmd "pkill -f openclaw" 2>/dev/null || true
}

adapter_status(){
  local ssh_cmd
  ssh_cmd="$(_get_ssh_cmd)"
  if $ssh_cmd "pgrep -f openclaw" >/dev/null 2>&1; then
    echo "OpenClaw (Remote/$REMOTE_ID): RUNNING"
  else
    echo "OpenClaw (Remote/$REMOTE_ID): STOPPED"
  fi
}

adapter_logs(){
  local ssh_cmd
  ssh_cmd="$(_get_ssh_cmd)"
  $ssh_cmd "tail -n 50 ~/.openclaw/logs/openclaw.log 2>/dev/null || echo 'Keine Remote Logs'"
}

adapter_health(){
  local ssh_cmd
  ssh_cmd="$(_get_ssh_cmd)"
  if $ssh_cmd "pgrep -f openclaw" >/dev/null 2>&1; then
    echo "HEALTHY"
  else
    echo "STOPPED"
  fi
}

adapter_uninstall(){
  local ssh_cmd
  ssh_cmd="$(_get_ssh_cmd)"
  $ssh_cmd "rm -rf ~/.openclawvenv ~/.openclaw" 2>/dev/null || true
}
