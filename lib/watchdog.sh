#!/usr/bin/env bash
# =============================================================================
# DAX CONTROL PLANE — WATCHDOG MODULE (lib/watchdog.sh)
# Health Ticks, Recovery Engine & State Tracking
# =============================================================================
set -Eeuo pipefail

WATCHDOG_FILE="$STATE_DIR/watchdog.json"

watchdog_ensure(){
  mkdir -p "$STATE_DIR"
  if [[ ! -f "$WATCHDOG_FILE" ]]; then
    cat <<EOF > "$WATCHDOG_FILE"
{
  "ollama": { "attempts": 0, "last_status": "UNKNOWN" },
  "comfyui": { "attempts": 0, "last_status": "UNKNOWN" },
  "docker": { "attempts": 0, "last_status": "UNKNOWN" },
  "agents": {
    "hermes": { "attempts": 0, "last_status": "UNKNOWN" },
    "openclaw": { "attempts": 0, "last_status": "UNKNOWN" }
  }
}
EOF
  fi
}

watchdog_tick(){
  local service="$1"
  local status="$2"
  watchdog_ensure

  python3 -c "
import json
path = '$WATCHDOG_FILE'
with open(path, 'r') as f: d = json.load(f)
svc = '$service'
st = '$status'

if svc in d:
    node = d[svc]
else:
    node = {'attempts': 0, 'last_status': 'UNKNOWN'}

if st == 'HEALTHY':
    node['attempts'] = 0
else:
    node['attempts'] = node.get('attempts', 0) + 1

node['last_status'] = st
d[svc] = node

with open(path, 'w') as f: json.dump(d, f, indent=2)
" 2>/dev/null
}

watchdog_recover(){
  local service="$1"
  log WARN "Watchdog: Auto-Recovery ausgelöst für $service"
  echo "[$(date '+%F %T')] [RECOVERY] Auto-Recovery ausgelöst für $service" >> "$WATCHDOG_LOG"

  case "$service" in
    ollama)
      pkill -f ollama 2>/dev/null || true
      command_exists ollama && nohup ollama serve >/dev/null 2>&1 &
      ;;
    comfyui)
      pkill -f "ComfyUI/main.py" 2>/dev/null || true
      ;;
    docker)
      systemctl restart docker 2>/dev/null || true
      ;;
    agents.hermes)
      agent_dispatch hermes stop native 2>/dev/null || true
      agent_dispatch hermes start native 2>/dev/null || true
      ;;
    agents.openclaw)
      agent_dispatch openclaw stop native 2>/dev/null || true
      agent_dispatch openclaw start native 2>/dev/null || true
      ;;
  esac
}

watchdog_status(){
  watchdog_ensure
  local running="STOPPED"
  if pgrep -f "dax.sh watchdog" >/dev/null 2>&1; then
    running="RUNNING"
  fi
  echo "Watchdog: $running"
  cat "$WATCHDOG_FILE"
}

health_check(){
  info "Führe System- und Agenten-Healthcheck aus..."
  detect_runtime_capabilities

  if command_exists ollama && pgrep -f "ollama serve" >/dev/null 2>&1; then
    ok "Ollama: RUNNING"
    watchdog_tick "ollama" "HEALTHY"
  else
    warn "Ollama: STOPPED / NOT DETECTED"
    watchdog_tick "ollama" "STOPPED"
  fi

  if pgrep -f "ComfyUI/main.py" >/dev/null 2>&1; then
    ok "ComfyUI: RUNNING"
    watchdog_tick "comfyui" "HEALTHY"
  else
    warn "ComfyUI: STOPPED"
    watchdog_tick "comfyui" "STOPPED"
  fi

  local hermes_h
  hermes_h="$(agent_dispatch hermes health native 2>/dev/null || echo STOPPED)"
  ok "Hermes Agent (Native): $hermes_h"

  local openclaw_h
  openclaw_h="$(agent_dispatch openclaw health native 2>/dev/null || echo STOPPED)"
  ok "OpenClaw (Native): $openclaw_h"
}
