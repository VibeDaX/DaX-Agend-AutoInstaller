#!/usr/bin/env bash
# =============================================================================
# DAX CONTROL PLANE — TEMPLATE MODULE (lib/templates.sh)
# Docker Compose, VM & Remote Stacks
# =============================================================================
set -Eeuo pipefail

TEMPLATE_DIR="$SCRIPT_DIR/templates"

template_apply_compose(){
  local tmpl="$1"
  local src="$TEMPLATE_DIR/compose/$tmpl"
  [[ -f "$src" ]] || { warn "Compose-Template nicht gefunden: $tmpl"; return 1; }
  mkdir -p "$DOCKER_DIR"
  cp "$src" "$DOCKER_DIR/compose.yml"
  ok "Compose-Template $tmpl nach $DOCKER_DIR/compose.yml angewendet."
}

template_manager(){
  echo "=== TEMPLATE MANAGER ==="
  echo "Compose Templates:"
  ls -1 "$TEMPLATE_DIR/compose" 2>/dev/null || true
  echo
  echo "Agent Stacks:"
  ls -1 "$TEMPLATE_DIR/agents" 2>/dev/null || true
  echo
  echo "VM Templates:"
  ls -1 "$TEMPLATE_DIR/vm" 2>/dev/null || true
  echo
  echo "Remote Templates:"
  ls -1 "$TEMPLATE_DIR/remote" 2>/dev/null || true
  echo
  echo "1) Templates anzeigen"
  echo "2) Compose zurücksetzen (docker/compose.yml löschen)"
  read -rp "Auswahl: " c
  case "$c" in
    1) ;;
    2)
      confirm_action "docker/compose.yml wirklich löschen?" || return 0
      rm -f "$DOCKER_DIR/compose.yml"
      ok "docker/compose.yml gelöscht."
      ;;
  esac
}
