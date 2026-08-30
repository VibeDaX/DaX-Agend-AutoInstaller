#!/usr/bin/env bash
# =============================================================================
# DAX COMMAND CENTER v6.3 — CONTROL-PLANE EDITION
# Multi-OS: Debian/Ubuntu, WSL2, Termux/PRoot
# Multi-runtime control plane: Native, Docker, KVM/QEMU, Remote
# =============================================================================
set -Eeuo pipefail
IFS=$'\n\t'

VERSION="6.3-control-plane"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

CLR_BLUE=$'\033[38;2;0;210;255m'; CLR_GOLD=$'\033[38;2;212;175;55m'
CLR_GREEN=$'\033[38;2;0;255;127m'; CLR_RED=$'\033[38;2;255;69;0m'
CLR_WHITE=$'\033[1;37m'; CLR_RESET=$'\033[0m'

LOG_DIR="$SCRIPT_DIR/logs"; LOG_FILE="$LOG_DIR/installation.log"; WATCHDOG_LOG="$LOG_DIR/watchdog.log"
STATE_DIR="$SCRIPT_DIR/.dax"; PID_DIR="$STATE_DIR/pids"
VENV_COMFYUI="$SCRIPT_DIR/.comfyuivenv"; VENV_OPENWEBUI="$SCRIPT_DIR/.openwebuivenv"
VENV_WHISPER="$SCRIPT_DIR/.whispervenv"; COMFYUI_DIR="$SCRIPT_DIR/ComfyUI"
RUNTIME_DIR="$SCRIPT_DIR/runtime"; DOCKER_DIR="$SCRIPT_DIR/docker"
DOCKER_SHARED_DIR="$DOCKER_DIR/shared"; DOCKER_HERMES_DIR="$DOCKER_DIR/hermes"
DOCKER_OPENCLAW_DIR="$DOCKER_DIR/openclaw"; VM_DIR="$SCRIPT_DIR/vms"
mkdir -p "$LOG_DIR" "$PID_DIR" "$RUNTIME_DIR" "$DOCKER_DIR" "$DOCKER_SHARED_DIR" "$DOCKER_HERMES_DIR" "$DOCKER_OPENCLAW_DIR" "$VM_DIR"

SUDO=""
if [[ $(id -u) -ne 0 ]]; then
  if command -v sudo >/dev/null 2>&1; then
    SUDO="sudo"
  fi
fi

# =============================================================================
# MODULAR LIBRARIES IMPORT
# =============================================================================
source "$SCRIPT_DIR/lib/core.sh"
source "$SCRIPT_DIR/lib/policy.sh"
source "$SCRIPT_DIR/lib/secrets.sh"
source "$SCRIPT_DIR/lib/volumes.sh"
source "$SCRIPT_DIR/lib/templates.sh"
source "$SCRIPT_DIR/lib/backup.sh"
source "$SCRIPT_DIR/lib/dashboard.sh"
source "$SCRIPT_DIR/lib/watchdog.sh"
source "$SCRIPT_DIR/lib/adapters.sh"
source "$SCRIPT_DIR/lib/services.sh"
source "$SCRIPT_DIR/lib/menus.sh"

# =============================================================================
# MAIN MENU (TOP-LEVEL CATEGORIES)
# =============================================================================
main_menu(){
  termux_handoff
  while true; do
    clear 2>/dev/null || true
    detect_hardware
    detect_runtime_capabilities
    persist_runtime_state
    echo -e "${CLR_BLUE}╔════════════════════════════════════════════════════════════╗${CLR_RESET}"
    echo -e "${CLR_BLUE}║${CLR_GOLD}           DAX COMMAND CENTER v$VERSION            ${CLR_BLUE}║${CLR_RESET}"
    echo -e "${CLR_BLUE}║${CLR_GOLD}      CONTROL-PLANE EDITION (Policy/Adapter/Watchdog)       ${CLR_BLUE}║${CLR_RESET}"
    local p_col="${CLR_GOLD}${PLATFORM}${CLR_RESET}"
    local g_col="${CLR_GOLD}${GPU_TYPE}${CLR_RESET}"
    local m_col="${CLR_GOLD}${COMFYUI_MODE}${CLR_RESET}"
    local d_bin d_daemon kvm_dev libv
    [[ "$CAN_DOCKER" == true ]] && d_bin="${CLR_GREEN}true${CLR_RESET}" || d_bin="${CLR_RED}false${CLR_RESET}"
    [[ "$DOCKER_DAEMON" == true ]] && d_daemon="${CLR_GREEN}true${CLR_RESET}" || d_daemon="${CLR_RED}false${CLR_RESET}"
    [[ "$CAN_KVM" == true ]] && kvm_dev="${CLR_GREEN}true${CLR_RESET}" || kvm_dev="${CLR_RED}false${CLR_RESET}"
    [[ "$CAN_LIBVIRT" == true ]] && libv="${CLR_GREEN}true${CLR_RESET}" || libv="${CLR_RED}false${CLR_RESET}"

    echo -e "Platform: $p_col | GPU: $g_col | Mode: $m_col"
    echo -e "Docker: $d_bin/$d_daemon | KVM: $kvm_dev | libvirt: $libv"
    echo
    echo "[1] HOST (Preflight Matrix & Hardware Check)"
    echo "[2] RUNTIMES (Native, Docker, KVM, Remote)"
    echo "[3] CONTROL-PLANE MODULES (Agents, Policy, Secrets, Backups, Dashboard)"
    echo "[4] SERVICES (Ollama, ComfyUI, Open WebUI, Node-RED/Whisper)"
    echo "[5] OPERATIONS (Watchdog, Tests, State, Stop, Logs)"
    echo "[6] Hilfe & Anleitung"
    echo "[7] Beenden"
    read -rp 'Auswahl [1-7]: ' choice
    clear 2>/dev/null || true
    case "$choice" in
      1) menu_host ;;
      2) menu_runtimes ;;
      3) menu_control_plane ;;
      4) menu_services ;;
      5) menu_operations ;;
      6) menu_help ;;
      7) exit 0 ;;
      *) warn 'Ungültige Auswahl.'; sleep 1 ;;
    esac
  done
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  detect_runtime_capabilities
  persist_runtime_state
  trap 'log INFO "DAX Command Center beendet."' EXIT
  log INFO "=== DAX Command Center v$VERSION gestartet ($PLATFORM) ==="
  main_menu
fi
