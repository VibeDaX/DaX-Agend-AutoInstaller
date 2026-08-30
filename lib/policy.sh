#!/usr/bin/env bash
# =============================================================================
# DAX CONTROL PLANE — POLICY MODULE (lib/policy.sh)
# Plattform- & Agenten-Sicherheitsregeln
# =============================================================================
set -Eeuo pipefail

POLICY_FILE="$STATE_DIR/policy.yaml"

policy_ensure(){
  mkdir -p "$STATE_DIR"
  if [[ ! -f "$POLICY_FILE" ]]; then
    cat <<EOF > "$POLICY_FILE"
version: 1
platforms:
  linux:
    allowed_runtimes: [native, docker, kvm, remote]
  wsl2:
    allowed_runtimes: [native, docker, remote]
  termux:
    allowed_runtimes: [native, remote]
  proot:
    allowed_runtimes: [native, remote]

agents:
  hermes:
    allowed_runtimes: [native, docker, kvm, remote]
    default_runtime: docker
    auto_recover: true
  openclaw:
    allowed_runtimes: [native, docker, kvm, remote]
    default_runtime: docker
    auto_recover: false
EOF
  fi
}

policy_allow_runtime_for_platform(){
  local rt="$1"
  policy_ensure
  case "$PLATFORM" in
    linux)  [[ "$rt" =~ ^(native|docker|kvm|remote)$ ]] && return 0 ;;
    wsl2)   [[ "$rt" =~ ^(native|docker|remote)$ ]] && return 0 ;;
    termux|proot) [[ "$rt" =~ ^(native|remote)$ ]] && return 0 ;;
  esac
  return 1
}

policy_allow_runtime_for_agent(){
  local agent="$1"
  local rt="$2"
  policy_ensure
  case "$agent" in
    hermes|openclaw) [[ "$rt" =~ ^(native|docker|kvm|remote)$ ]] && return 0 ;;
  esac
  return 1
}

policy_manager(){
  policy_ensure
  echo "=== POLICY MANAGER ==="
  cat "$POLICY_FILE"
}
