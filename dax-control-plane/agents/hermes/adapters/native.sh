#!/usr/bin/env bash
# =============================================================================
# DAX AGENT ADAPTER — HERMES (NATIVE RUNTIME)
# =============================================================================

HERMES_VENV="${SCRIPT_DIR}/.hermesvenv"
HERMES_LOG="${LOG_DIR}/hermes.log"
HERMES_PID="${PID_DIR}/hermes.pid"

adapter_install(){
  info "Installiere Hermes Agent 2.0 (Native Python VENV)..."
  ensure_venv "$HERMES_VENV" "Hermes Agent VENV"
  
  local pip_flags="--ignore-requires-python"
  if [[ "$PLATFORM" == "termux" || "$PLATFORM" == "proot" ]]; then
    info "Termux/PRoot Python 3.14+ Umgebung erkannt — wende Termux-Fixes an..."
    if command_exists pkg; then
      pkg install -y python-psutil >>"$LOG_FILE" 2>&1 || true
    fi
  fi

  info "Installiere hermes-agent Python-Paket..."
  "$HERMES_VENV/bin/python" -m pip install --upgrade $pip_flags hermes-agent >>"$LOG_FILE" 2>&1 || {
    warn "Direkte pip-Installation fehlgeschlagen, versuche Installer-Skript und Fallbacks..."
    curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | bash >>"$LOG_FILE" 2>&1 || true
    "$HERMES_VENV/bin/python" -m pip install $pip_flags hermes-agent >>"$LOG_FILE" 2>&1 || \
    "$HERMES_VENV/bin/python" -m pip install $pip_flags --no-deps hermes-agent >>"$LOG_FILE" 2>&1 || \
    die "Hermes Installation fehlgeschlagen."
  }

  if [[ -x "$HERMES_VENV/bin/hermes" ]]; then
    info "Führe hermes postinstall aus..."
    "$HERMES_VENV/bin/hermes" postinstall >>"$LOG_FILE" 2>&1 || true
  fi

  if command_exists npx; then
    info "Installiere Playwright Chromium für Browser-Tools..."
    npx playwright install chromium >>"$LOG_FILE" 2>&1 || true
  fi

  ok "Hermes Agent (Native) erfolgreich installiert in: $HERMES_VENV"
}

adapter_start(){
  [[ -d "$HERMES_VENV" ]] || { warn "Hermes VENV fehlt. Bitte zuerst installieren: agent_dispatch hermes install native"; return 1; }
  
  if [[ -f "$HERMES_PID" ]] && kill -0 "$(cat "$HERMES_PID" 2>/dev/null)" 2>/dev/null; then
    warn "Hermes läuft bereits (PID: $(cat "$HERMES_PID"))."
    return 0
  fi

  # Secrets laden
  local secret_env
  secret_env="$(secret_get_envfile agent hermes 2>/dev/null)" || secret_env=""
  if [[ -n "$secret_env" ]]; then
    info "Lade agentenspezifische Secrets für Hermes..."
    while IFS='=' read -r k v; do
      [[ -n "$k" && ! "$k" =~ ^# ]] && export "$k"="$v"
    done <<< "$secret_env"
  fi

  local exec_bin="$HERMES_VENV/bin/hermes"
  if [[ ! -x "$exec_bin" ]]; then
    exec_bin="$HERMES_VENV/bin/python -m hermes"
  fi

  info "Starte Hermes Agent nativ im Hintergrund..."
  nohup $exec_bin >>"$HERMES_LOG" 2>&1 &
  local pid=$!
  echo "$pid" > "$HERMES_PID"
  sleep 1

  if kill -0 "$pid" 2>/dev/null; then
    ok "Hermes Agent erfolgreich gestartet (PID: $pid). Log: $HERMES_LOG"
    watchdog_tick "agents.hermes" "HEALTHY"
  else
    warn "Hermes Start fehlgeschlagen. Siehe Log: $HERMES_LOG"
    watchdog_tick "agents.hermes" "STOPPED"
    return 1
  fi
}

adapter_stop(){
  local stopped=false
  if [[ -f "$HERMES_PID" ]]; then
    local pid
    pid="$(cat "$HERMES_PID" 2>/dev/null || true)"
    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null || true
      sleep 1
      kill -9 "$pid" 2>/dev/null || true
      stopped=true
    fi
    rm -f "$HERMES_PID"
  fi

  pkill -f "${HERMES_VENV}/bin" 2>/dev/null && stopped=true || true
  watchdog_tick "agents.hermes" "STOPPED"
  if [[ "$stopped" == true ]]; then
    ok "Hermes Agent (Native) gestoppt."
  else
    info "Hermes Agent war nicht aktiv."
  fi
}

adapter_status(){
  if [[ -f "$HERMES_PID" ]] && kill -0 "$(cat "$HERMES_PID" 2>/dev/null)" 2>/dev/null; then
    echo -e "${CLR_GREEN}Hermes (Native): RUNNING${CLR_RESET} (PID: $(cat "$HERMES_PID"))"
  elif pgrep -f "${HERMES_VENV}/bin" >/dev/null 2>&1; then
    echo -e "${CLR_GREEN}Hermes (Native): RUNNING${CLR_RESET} (PID: $(pgrep -f "${HERMES_VENV}/bin" | head -n1))"
  else
    echo -e "${CLR_RED}Hermes (Native): STOPPED${CLR_RESET}"
  fi
}

adapter_logs(){
  if [[ -f "$HERMES_LOG" ]]; then
    tail -n 100 -f "$HERMES_LOG"
  else
    warn "Keine Log-Datei gefunden: $HERMES_LOG"
  fi
}

adapter_health(){
  if [[ -f "$HERMES_PID" ]] && kill -0 "$(cat "$HERMES_PID" 2>/dev/null)" 2>/dev/null; then
    echo "HEALTHY"
  elif pgrep -f "${HERMES_VENV}/bin" >/dev/null 2>&1; then
    echo "HEALTHY"
  else
    echo "STOPPED"
  fi
}

adapter_uninstall(){
  adapter_stop
  if [[ -d "$HERMES_VENV" ]]; then
    rm -rf "$HERMES_VENV"
    ok "Hermes VENV ($HERMES_VENV) entfernt."
  fi
  rm -f "$HERMES_PID" "$HERMES_LOG"
  ok "Hermes Deinstallation (Native) abgeschlossen."
}
