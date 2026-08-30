#!/usr/bin/env bash
# =============================================================================
# DAX CONTROL PLANE — AGENT ADAPTER MODULE (lib/adapters.sh)
# Agent Dispatch Engine & Manifest Profiles
# =============================================================================
set -Eeuo pipefail

AGENT_DIR="$SCRIPT_DIR/agents"

agent_dispatch(){
  local agent="$1"
  local action="$2"
  local rt="${3:-docker}"

  local manifest="$AGENT_DIR/$agent/manifest.yaml"
  local adapter="$AGENT_DIR/$agent/adapters/${rt}.sh"

  [[ -f "$manifest" ]] || { warn "Agent $agent nicht gefunden ($manifest)."; return 1; }
  [[ -f "$adapter" ]] || { warn "Adapter für $agent ($rt) nicht gefunden ($adapter)."; return 1; }

  policy_allow_runtime_for_platform "$rt" || { warn "Runtime $rt ist auf Plattform $PLATFORM durch Policy gesperrt."; return 1; }
  policy_allow_runtime_for_agent "$agent" "$rt" || { warn "Runtime $rt ist für Agent $agent gesperrt."; return 1; }

  source "$adapter"

  case "$action" in
    install)   adapter_install ;;
    start)     adapter_start ;;
    stop)      adapter_stop ;;
    status)    adapter_status ;;
    logs)      adapter_logs ;;
    health)    adapter_health ;;
    uninstall) adapter_uninstall ;;
    *) warn "Unbekannte Adapter-Aktion: $action"; return 1 ;;
  esac
}

agent_profiles(){
  echo "=== AGENT PROFILES & MANIFESTS ==="
  for m in "$AGENT_DIR"/*/manifest.yaml; do
    [[ -f "$m" ]] || continue
    echo "--- $(basename "$(dirname "$m")") ---"
    cat "$m"
    echo
  done
}

agent_deployment_wizard(){
  clear 2>/dev/null || true
  echo "=== AGENT DEPLOYMENT WIZARD ==="
  echo "Verfügbare Agenten:"
  echo "1) Hermes 2.0"
  echo "2) OpenClaw"
  read -rp "Auswahl: " ag_c
  local ag=""
  case "$ag_c" in
    1) ag="hermes" ;;
    2) ag="openclaw" ;;
    *) warn "Ungültige Auswahl"; return 1 ;;
  esac

  echo "Verfügbare Runtimes für $ag:"
  echo "1) Native (Python VENV)"
  echo "2) Docker Container"
  echo "3) KVM Virtuelle Maschine"
  echo "4) Remote SSH Host"
  read -rp "Runtime [1-4]: " rt_c
  local rt="native"
  case "$rt_c" in
    1) rt="native" ;;
    2) rt="docker" ;;
    3) rt="kvm" ;;
    4) rt="remote" ;;
  esac

  echo "Aktion wählen:"
  echo "1) Installieren"
  echo "2) Starten"
  echo "3) Stoppen"
  echo "4) Status prüfen"
  echo "5) Health Check"
  echo "6) Logs anzeigen"
  read -rp "Aktion [1-6]: " act_c
  local act="status"
  case "$act_c" in
    1) act="install" ;;
    2) act="start" ;;
    3) act="stop" ;;
    4) act="status" ;;
    5) act="health" ;;
    6) act="logs" ;;
  esac

  agent_dispatch "$ag" "$act" "$rt"
}
