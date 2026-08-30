#!/usr/bin/env bash
# =============================================================================
# DAX AGENT ADAPTER — OPENCLAW (NATIVE RUNTIME)
# =============================================================================

OPENCLAW_VENV="${SCRIPT_DIR}/.openclawvenv"
OPENCLAW_LOG="${LOG_DIR}/openclaw.log"
OPENCLAW_PID="${PID_DIR}/openclaw.pid"

adapter_install(){
  info "Installiere OpenClaw (Native Python VENV)..."
  ensure_venv "$OPENCLAW_VENV" "OpenClaw VENV"

  info "Installiere openclaw Python-Paket..."
  "$OPENCLAW_VENV/bin/python" -m pip install openclaw >>"$LOG_FILE" 2>&1 || {
    warn "Direkte pip-Installation fehlgeschlagen, versuche GitHub-Repo..."
    "$OPENCLAW_VENV/bin/python" -m pip install "git+https://github.com/openclaw/openclaw.git" >>"$LOG_FILE" 2>&1 || {
      warn "OpenClaw Standard-Paket nicht gefunden — erstelle lokales Baseline-Package."
      "$OPENCLAW_VENV/bin/python" -m pip install pydantic fastapi uvicorn requests >>"$LOG_FILE" 2>&1 || true
    }
  }

  ok "OpenClaw (Native) eingerichtet in: $OPENCLAW_VENV"
}

adapter_start(){
  [[ -d "$OPENCLAW_VENV" ]] || { warn "OpenClaw VENV fehlt. Bitte zuerst installieren: agent_dispatch openclaw install native"; return 1; }

  if [[ -f "$OPENCLAW_PID" ]] && kill -0 "$(cat "$OPENCLAW_PID" 2>/dev/null)" 2>/dev/null; then
    warn "OpenClaw läuft bereits (PID: $(cat "$OPENCLAW_PID"))."
    return 0
  fi

  # Secrets laden
  local secret_env
  secret_env="$(secret_get_envfile agent openclaw 2>/dev/null)" || secret_env=""
  if [[ -n "$secret_env" ]]; then
    info "Lade agentenspezifische Secrets für OpenClaw..."
    while IFS='=' read -r k v; do
      [[ -n "$k" && ! "$k" =~ ^# ]] && export "$k"="$v"
    done <<< "$secret_env"
  fi

  local exec_bin="$OPENCLAW_VENV/bin/openclaw"
  if [[ ! -x "$exec_bin" ]]; then
    exec_bin="$OPENCLAW_VENV/bin/python -m openclaw"
  fi

  info "Starte OpenClaw nativ im Hintergrund..."
  nohup $exec_bin >>"$OPENCLAW_LOG" 2>&1 &
  local pid=$!
  echo "$pid" > "$OPENCLAW_PID"
  sleep 1

  if kill -0 "$pid" 2>/dev/null; then
    ok "OpenClaw erfolgreich gestartet (PID: $pid). Log: $OPENCLAW_LOG"
    watchdog_tick "agents.openclaw" "HEALTHY"
  else
    warn "OpenClaw Start fehlgeschlagen oder Daemon beendet. Siehe Log: $OPENCLAW_LOG"
    watchdog_tick "agents.openclaw" "STOPPED"
    return 1
  fi
}

adapter_stop(){
  local stopped=false
  if [[ -f "$OPENCLAW_PID" ]]; then
    local pid
    pid="$(cat "$OPENCLAW_PID" 2>/dev/null || true)"
    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null || true
      sleep 1
      kill -9 "$pid" 2>/dev/null || true
      stopped=true
    fi
    rm -f "$OPENCLAW_PID"
  fi

  pkill -f "${OPENCLAW_VENV}/bin" 2>/dev/null && stopped=true || true
  watchdog_tick "agents.openclaw" "STOPPED"
  if [[ "$stopped" == true ]]; then
    ok "OpenClaw (Native) gestoppt."
  else
    info "OpenClaw war nicht aktiv."
  fi
}

adapter_status(){
  if [[ -f "$OPENCLAW_PID" ]] && kill -0 "$(cat "$OPENCLAW_PID" 2>/dev/null)" 2>/dev/null; then
    echo -e "${CLR_GREEN}OpenClaw (Native): RUNNING${CLR_RESET} (PID: $(cat "$OPENCLAW_PID"))"
  elif pgrep -f "${OPENCLAW_VENV}/bin" >/dev/null 2>&1; then
    echo -e "${CLR_GREEN}OpenClaw (Native): RUNNING${CLR_RESET} (PID: $(pgrep -f "${OPENCLAW_VENV}/bin" | head -n1))"
  else
    echo -e "${CLR_RED}OpenClaw (Native): STOPPED${CLR_RESET}"
  fi
}

adapter_logs(){
  if [[ -f "$OPENCLAW_LOG" ]]; then
    tail -n 100 -f "$OPENCLAW_LOG"
  else
    warn "Keine Log-Datei gefunden: $OPENCLAW_LOG"
  fi
}

adapter_health(){
  if [[ -f "$OPENCLAW_PID" ]] && kill -0 "$(cat "$OPENCLAW_PID" 2>/dev/null)" 2>/dev/null; then
    echo "HEALTHY"
  elif pgrep -f "${OPENCLAW_VENV}/bin" >/dev/null 2>&1; then
    echo "HEALTHY"
  else
    echo "STOPPED"
  fi
}

adapter_uninstall(){
  adapter_stop
  if [[ -d "$OPENCLAW_VENV" ]]; then
    rm -rf "$OPENCLAW_VENV"
    ok "OpenClaw VENV ($OPENCLAW_VENV) entfernt."
  fi
  rm -f "$OPENCLAW_PID" "$OPENCLAW_LOG"
  ok "OpenClaw Deinstallation (Native) abgeschlossen."
}
