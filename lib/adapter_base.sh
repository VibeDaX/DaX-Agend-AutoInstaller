#!/usr/bin/env bash
# =============================================================================
# DAX CONTROL PLANE — BASE NATIVE ADAPTER (lib/adapter_base.sh)
# Gemeinsame Logik für Native-Runtime-Agenten (Hermes, OpenClaw, ...)
# =============================================================================

ADAPTER_BASE_LOADED=true

# ---------------------------------------------------------------------------
# Konfiguration über Umgebungsvariablen (vor dem Sourcen setzen)
# ---------------------------------------------------------------------------
# AGENT_NAME        — z.B. "hermes" oder "openclaw"
# AGENT_VENV        — Pfad zum VENV, z.B. "/opt/dax/.hermesvenv"
# AGENT_LOG         — Log-Datei, z.B. "/opt/dax/logs/hermes.log"
# AGENT_PID_FILE    — PID-Datei, z.B. "/opt/dax/.dax/pids/hermes.pid"
# AGENT_EXEC        — Binärpfad im VENV, z.B. "/opt/dax/.hermesvenv/bin/hermes"
# AGENT_MODULE      — Python-Modul als Fallback, z.B. "hermes"
# AGENT_PIP_PACKAGE — Paketname für pip, z.B. "hermes-agent"
# AGENT_INSTALL_CMDS— Array mit zusätzlichen Installationsbefehlen
# ---------------------------------------------------------------------------

adapter_base_install(){
  local agent="${AGENT_NAME:-unknown}"
  local venv="${AGENT_VENV:?AGENT_VENV muss gesetzt sein}"
  local log="${AGENT_LOG:-$LOG_DIR/${agent}.log}"
  local pip_pkg="${AGENT_PIP_PACKAGE:?AGENT_PIP_PACKAGE muss gesetzt sein}"
  local install_cmds=("${AGENT_INSTALL_CMDS[@]:-}")

  info "Installiere $agent Agent (Native Python VENV)..."
  ensure_venv "$venv" "$agent Agent VENV"

  local pip_flags="--ignore-requires-python"
  if [[ "$PLATFORM" == "termux" || "$PLATFORM" == "proot" ]]; then
    info "Termux/PRoot Python 3.14+ Umgebung erkannt — wende Termux-Fixes an..."
    if command_exists pkg; then
      pkg install -y python-psutil >>"$LOG_FILE" 2>&1 || true
    fi
  fi

  info "Sicherstelle pip im VENV..."
  "$venv/bin/python" -m ensurepip --upgrade >>"$LOG_FILE" 2>&1 || \
    "$venv/bin/python" -m ensurepip >>"$LOG_FILE" 2>&1 || true

  if ! "$venv/bin/python" -c "import pip" 2>/dev/null; then
    warn "pip fehlt im VENV — versuche System-pip zu nutzen..."
    pip install --target="$venv/lib/python$( "$venv/bin/python" -c 'import sys; print(".".join(map(str, sys.version_info[:2])))' )/site-packages" $pip_flags "$pip_pkg" >>"$LOG_FILE" 2>&1 || {
      die "$agent Installation fehlgeschlagen: pip ist im VENV nicht verfügbar."
    }
  else
    info "Installiere $pip_pkg Python-Paket..."
    "$venv/bin/python" -m pip install --upgrade $pip_flags "$pip_pkg" >>"$LOG_FILE" 2>&1 || {
      warn "Direkte pip-Installation fehlgeschlagen, versuche Installer-Skript und Fallbacks..."
      for cmd in "${install_cmds[@]}"; do
        eval "$cmd" >>"$LOG_FILE" 2>&1 || true
      done
      "$venv/bin/python" -m pip install $pip_flags --no-deps "$pip_pkg" >>"$LOG_FILE" 2>&1 || \
        die "$agent Installation fehlgeschlagen."
    }
  fi

  if ! "$venv/bin/python" -c "import yaml" 2>/dev/null; then
    info "PyYAML fehlt — installiere als Dependency für $agent..."
    "$venv/bin/python" -m pip install $pip_flags pyyaml >>"$LOG_FILE" 2>&1 || true
  fi

  if [[ -x "${AGENT_EXEC:-$venv/bin/$agent}" ]]; then
    info "Führe $agent postinstall aus..."
    "${AGENT_EXEC:-$venv/bin/$agent}" postinstall >>"$LOG_FILE" 2>&1 || true
  fi

  if command_exists npx; then
    info "Installiere Playwright Chromium für Browser-Tools..."
    yes | npx playwright install chromium >>"$LOG_FILE" 2>&1 || true
  fi

  ok "$agent Agent (Native) erfolgreich installiert in: $venv"
}

adapter_base_start(){
  local agent="${AGENT_NAME:-unknown}"
  local venv="${AGENT_VENV:?AGENT_VENV muss gesetzt sein}"
  local log="${AGENT_LOG:-$LOG_DIR/${agent}.log}"
  local pid_file="${AGENT_PID_FILE:?AGENT_PID_FILE muss gesetzt sein}"
  local exec_bin="${AGENT_EXEC:-$venv/bin/$agent}"
  local agent_module="${AGENT_MODULE:-$agent}"

  [[ -d "$venv" ]] || { warn "$agent VENV fehlt. Bitte zuerst installieren."; return 1; }

  if [[ -f "$pid_file" ]] && kill -0 "$(cat "$pid_file" 2>/dev/null)" 2>/dev/null; then
    warn "$agent läuft bereits (PID: $(cat "$pid_file"))."
    return 0
  fi

  # Secrets laden
  local secret_env
  secret_env="$(secret_get_envfile agent "$agent" 2>/dev/null)" || secret_env=""
  if [[ -n "$secret_env" ]]; then
    info "Lade agentenspezifische Secrets für $agent..."
    while IFS='=' read -r k v; do
      [[ -n "$k" && ! "$k" =~ ^# ]] && export "$k"="$v"
    done <<< "$secret_env"
  fi

  if [[ ! -x "$exec_bin" ]]; then
    exec_bin="$venv/bin/python -m $agent_module"
  fi

  info "Starte $agent Agent nativ im Hintergrund..."
  nohup "$exec_bin" >>"$log" 2>&1 &
  local pid=$!
  echo "$pid" > "$pid_file"

  if wait_for_process "$pid" 10; then
    ok "$agent Agent erfolgreich gestartet (PID: $pid). Log: $log"
    watchdog_tick "agents.$agent" "HEALTHY"
  else
    warn "$agent Start fehlgeschlagen oder Prozess nicht stabil. Siehe Log: $log"
    watchdog_tick "agents.$agent" "STOPPED"
    return 1
  fi
}

adapter_base_stop(){
  local agent="${AGENT_NAME:-unknown}"
  local venv="${AGENT_VENV:?AGENT_VENV muss gesetzt sein}"
  local pid_file="${AGENT_PID_FILE:?AGENT_PID_FILE muss gesetzt sein}"
  local stopped=false

  if [[ -f "$pid_file" ]]; then
    local pid
    pid="$(cat "$pid_file" 2>/dev/null || true)"
    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null || true
      wait_for_process "$pid" 5 || true
      kill -9 "$pid" 2>/dev/null || true
      stopped=true
    fi
    rm -f "$pid_file"
  fi

  pkill -f "${venv}/bin" 2>/dev/null && stopped=true || true
  watchdog_tick "agents.$agent" "STOPPED"
  if [[ "$stopped" == true ]]; then
    ok "$agent Agent (Native) gestoppt."
  else
    info "$agent Agent war nicht aktiv."
  fi
}

adapter_base_status(){
  local agent="${AGENT_NAME:-unknown}"
  local venv="${AGENT_VENV:?AGENT_VENV muss gesetzt sein}"
  local pid_file="${AGENT_PID_FILE:?AGENT_PID_FILE muss gesetzt sein}"

  if [[ -f "$pid_file" ]] && kill -0 "$(cat "$pid_file" 2>/dev/null)" 2>/dev/null; then
    echo -e "${CLR_GREEN}$agent (Native): RUNNING${CLR_RESET} (PID: $(cat "$pid_file"))"
  elif pgrep -f "${venv}/bin" >/dev/null 2>&1; then
    echo -e "${CLR_GREEN}$agent (Native): RUNNING${CLR_RESET} (PID: $(pgrep -f "${venv}/bin" | head -n1))"
  else
    echo -e "${CLR_RED}$agent (Native): STOPPED${CLR_RESET}"
  fi
}

adapter_base_logs(){
  local agent="${AGENT_NAME:-unknown}"
  local log="${AGENT_LOG:-$LOG_DIR/${agent}.log}"

  if [[ -f "$log" ]]; then
    tail -n 100 -f "$log"
  else
    warn "Keine Log-Datei gefunden: $log"
  fi
}

adapter_base_health(){
  local agent="${AGENT_NAME:-unknown}"
  local venv="${AGENT_VENV:?AGENT_VENV muss gesetzt sein}"
  local pid_file="${AGENT_PID_FILE:?AGENT_PID_FILE muss gesetzt sein}"

  if [[ -f "$pid_file" ]] && kill -0 "$(cat "$pid_file" 2>/dev/null)" 2>/dev/null; then
    echo "HEALTHY"
  elif pgrep -f "${venv}/bin" >/dev/null 2>&1; then
    echo "HEALTHY"
  else
    echo "STOPPED"
  fi
}

adapter_base_uninstall(){
  local agent="${AGENT_NAME:-unknown}"
  local venv="${AGENT_VENV:?AGENT_VENV muss gesetzt sein}"
  local pid_file="${AGENT_PID_FILE:?AGENT_PID_FILE muss gesetzt sein}"
  local log="${AGENT_LOG:-$LOG_DIR/${agent}.log}"

  adapter_base_stop
  if [[ -d "$venv" ]]; then
    rm -rf "$venv"
    ok "$agent VENV ($venv) entfernt."
  fi
  rm -f "$pid_file" "$log"
  ok "$agent Deinstallation (Native) abgeschlossen."
}
