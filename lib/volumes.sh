#!/usr/bin/env bash
# =============================================================================
# DAX CONTROL PLANE — VOLUME MODULE (lib/volumes.sh)
# Host-Pfad Provisionierung & Docker Bind-Mounts
# =============================================================================
set -Eeuo pipefail

VOLUMES_FILE="$STATE_DIR/volumes.yaml"

volume_ensure(){
  local vol="$1"
  [[ -f "$VOLUMES_FILE" ]] || { warn "Volumes-Datei fehlt: $VOLUMES_FILE"; return 1; }
  case "$vol" in
    hermes_data)
      local host_path="/var/lib/dax/hermes"
      info "Volume hermes_data: Host-Pfad $host_path (docker_bind)"
      if [[ $(id -u) -eq 0 ]]; then
        mkdir -p "$host_path" 2>/dev/null || true
      elif [[ -n "${SUDO:-}" ]] && sudo -n true 2>/dev/null; then
        $SUDO mkdir -p "$host_path" 2>/dev/null || true
      else
        mkdir -p "$host_path" 2>/dev/null || true
      fi
      ok "Volume hermes_data bereit."
      ;;
    openclaw_data)
      local host_path="/var/lib/dax/openclaw"
      info "Volume openclaw_data: Host-Pfad $host_path (docker_bind)"
      if [[ $(id -u) -eq 0 ]]; then
        mkdir -p "$host_path" 2>/dev/null || true
      elif [[ -n "${SUDO:-}" ]] && sudo -n true 2>/dev/null; then
        $SUDO mkdir -p "$host_path" 2>/dev/null || true
      else
        mkdir -p "$host_path" 2>/dev/null || true
      fi
      ok "Volume openclaw_data bereit."
      ;;
    ollama_data)
      local host_path="/var/lib/dax/ollama"
      info "Volume ollama_data: Host-Pfad $host_path (docker_bind)"
      if [[ $(id -u) -eq 0 ]]; then
        mkdir -p "$host_path" 2>/dev/null || true
      elif [[ -n "${SUDO:-}" ]] && sudo -n true 2>/dev/null; then
        $SUDO mkdir -p "$host_path" 2>/dev/null || true
      else
        mkdir -p "$host_path" 2>/dev/null || true
      fi
      ok "Volume ollama_data bereit."
      ;;
    *) warn "Unbekanntes Volume: $vol"; return 1 ;;
  esac
}

volume_mount_docker(){
  local vol="$1"
  volume_ensure "$vol" >/dev/null 2>&1 || true
  local host_path
  case "$vol" in
    hermes_data) host_path="/var/lib/dax/hermes" ;;
    openclaw_data) host_path="/var/lib/dax/openclaw" ;;
    ollama_data) host_path="/var/lib/dax/ollama" ;;
    *) warn "Unbekanntes Volume: $vol"; return 1 ;;
  esac
  echo "-v ${host_path}:/opt/${vol}:rw"
}

volume_manager(){
  echo "=== VOLUME MANAGER ==="
  [[ -f "$VOLUMES_FILE" ]] && cat "$VOLUMES_FILE" || echo "Keine volumes.yaml gefunden."
  echo
  echo "1) Volumes anzeigen"
  echo "2) Volume bereitstellen"
  echo "3) Volume entfernen"
  read -rp "Auswahl: " c
  case "$c" in
    1) cat "$VOLUMES_FILE" 2>/dev/null || echo "Keine volumes.yaml gefunden." ;;
    2)
      read -rp "Volume Name (hermes_data/openclaw_data/ollama_data): " vol
      volume_ensure "$vol"
      ;;
    3)
      read -rp "Volume Name zum Entfernen: " vol
      confirm_action "Volume $vol und Daten wirklich löschen?" || return 0
      case "$vol" in
        hermes_data) rm -rf /var/lib/dax/hermes ;;
        openclaw_data) rm -rf /var/lib/dax/openclaw ;;
        ollama_data) rm -rf /var/lib/dax/ollama ;;
        *) warn "Unbekanntes Volume: $vol"; return 1 ;;
      esac
      ok "Volume $vol entfernt."
      ;;
  esac
}
