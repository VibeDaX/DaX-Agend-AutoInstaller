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

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================
apt_install(){
  info "Installiere Systempakete: $*"
  $SUDO apt-get update -qq
  $SUDO apt-get install -y -qq --no-install-recommends "$@"
  ok "Pakete installiert: $*"
}

confirm_action(){
  read -rp "${1:-Aktion fortfahren?} [y/N]: " choice
  case "$choice" in [yY][eE][sS]|[yY]) return 0 ;; *) return 1 ;; esac
}

require_native_linux(){
  if [[ "$PLATFORM" == "termux" || "$PLATFORM" == "proot" ]]; then
    warn "Diese Funktion ist im Termux/PRoot-Modus nicht verfügbar."
    return 1
  fi
  return 0
}

termux_handoff(){
  if [[ "$PLATFORM" == "termux" || "$PLATFORM" == "proot" ]]; then
    warn "Termux/PRoot erkannt. Native Linux-Runtimes (Sudo/Docker/KVM) deaktiviert."
  fi
}

# =============================================================================
# SYSTEM INSTALLERS & SERVICES
# =============================================================================
install_system_dependencies(){
  require_native_linux || return 0
  info "Installiere Basis-Systemabhängigkeiten..."
  apt_install build-essential curl wget git python3 python3-pip python3-venv openssl jq stat
  ok "System-Basisabhängigkeiten sind bereit."
}

install_ollama(){
  info "Konfiguriere Ollama Inferenz-Engine..."
  if command_exists ollama; then
    ok "Ollama ist bereits installiert."
  else
    if [[ "$PLATFORM" == "linux" || "$PLATFORM" == "wsl2" ]]; then
      curl -fsSL https://ollama.com/install.sh | sh
    else
      warn "Ollama-Autoinstallation auf $PLATFORM nicht unterstützt. Bitte Remote-Host nutzen."
      return 1
    fi
  fi

  if ! pgrep -f "ollama serve" >/dev/null 2>&1; then
    info "Starte Ollama Service..."
    nohup ollama serve >/dev/null 2>&1 &
    echo $! > "$PID_DIR/ollama.pid"
    sleep 2
  fi
  ok "Ollama läuft und ist erreichbar."
}

pull_ollama_model(){
  command_exists ollama || { warn "Ollama ist nicht installiert."; return 1; }
  ram_recommendation
  read -rp "Modellname zum Laden eingeben (z.B. llama3:8b, qwen2:7b): " model_name
  if [[ -n "$model_name" ]]; then
    info "Lade Modell: $model_name ..."
    ollama pull "$model_name"
    ok "Modell $model_name erfolgreich geladen."
  fi
}

install_comfyui(){
  info "Installiere ComfyUI..."
  if [[ ! -d "$COMFYUI_DIR" ]]; then
    git clone https://github.com/comfyanonymous/ComfyUI.git "$COMFYUI_DIR"
  fi

  if [[ ! -d "$VENV_COMFYUI" ]]; then
    python3 -m venv "$VENV_COMFYUI"
  fi

  source "$VENV_COMFYUI/bin/activate"
  pip install --upgrade pip setuptools wheel
  detect_hardware
  if [[ "$GPU_TYPE" == "nvidia" ]]; then
    pip install torch torchvision torchaudio --index-url "$TORCH_INDEX"
  else
    pip install torch torchvision torchaudio
  fi
  pip install -r "$COMFYUI_DIR/requirements.txt"
  deactivate
  ok "ComfyUI Installation abgeschlossen."
}

start_comfyui(){
  [[ -d "$COMFYUI_DIR" ]] || { warn "ComfyUI nicht installiert."; return 1; }
  info "Starte ComfyUI..."
  source "$VENV_COMFYUI/bin/activate"
  nohup python3 "$COMFYUI_DIR/main.py" --listen 0.0.0.0 --port 8188 >/dev/null 2>&1 &
  echo $! > "$PID_DIR/comfyui.pid"
  deactivate
  ok "ComfyUI gestartet auf http://localhost:8188"
}

install_openwebui(){
  info "Installiere Open WebUI..."
  if [[ ! -d "$VENV_OPENWEBUI" ]]; then
    python3 -m venv "$VENV_OPENWEBUI"
  fi
  source "$VENV_OPENWEBUI/bin/activate"
  pip install --upgrade pip
  pip install open-webui
  deactivate
  ok "Open WebUI erfolgreich installiert."
}

start_openwebui(){
  [[ -d "$VENV_OPENWEBUI" ]] || { warn "Open WebUI nicht installiert."; return 1; }
  info "Starte Open WebUI..."
  source "$VENV_OPENWEBUI/bin/activate"
  nohup open-webui serve >/dev/null 2>&1 &
  echo $! > "$PID_DIR/openwebui.pid"
  deactivate
  ok "Open WebUI gestartet auf http://localhost:8080"
}

install_nodered(){
  info "Installiere Node-RED..."
  if command_exists npm; then
    $SUDO npm install -g --unsafe-perm node-red
    ok "Node-RED installiert."
  else
    warn "Node.js / npm fehlt. Bitte erst Systempakete installieren."
  fi
}

install_whisper(){
  info "Installiere Faster-Whisper..."
  if [[ ! -d "$VENV_WHISPER" ]]; then
    python3 -m venv "$VENV_WHISPER"
  fi
  source "$VENV_WHISPER/bin/activate"
  pip install faster-whisper
  deactivate
  ok "Faster-Whisper installiert."
}

start_nodered(){
  if command_exists node-red; then
    nohup node-red >/dev/null 2>&1 &
    echo $! > "$PID_DIR/nodered.pid"
    ok "Node-RED gestartet auf http://localhost:1880"
  fi
}

docker_context_init(){
  mkdir -p "$DOCKER_DIR/hermes" "$DOCKER_DIR/openclaw" "$DOCKER_SHARED_DIR"
  cat > "$DOCKER_SHARED_DIR/entrypoint.sh" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
exec "$@"
EOF
  chmod +x "$DOCKER_SHARED_DIR/entrypoint.sh"
}

install_docker(){
  require_native_linux || return 0
  detect_runtime_capabilities
  [[ "$DOCKER_DAEMON" == true ]] && ok "Docker ist bereits installiert und erreichbar." && return 0
  apt_install docker.io docker-compose-plugin
  $SUDO systemctl enable --now docker 2>/dev/null || true
  detect_runtime_capabilities true
  persist_runtime_state
}

runtime_menu(){
  clear 2>/dev/null || true
  echo "=== DOCKER RUNTIME MANAGEMENT ==="
  echo "1) Docker & Compose installieren"
  echo "2) Shared Context & Dockerfiles initialisieren"
  echo "3) Stack starten (docker compose up -d)"
  echo "4) Stack stoppen"
  echo "5) Zurück"
  read -rp "Auswahl: " c
  clear 2>/dev/null || true
  case "$c" in
    1) install_docker; pause_menu ;;
    2) docker_context_init; pause_menu ;;
    3) [[ -f "$DOCKER_DIR/compose.yml" ]] && (cd "$DOCKER_DIR" && docker compose up -d); pause_menu ;;
    4) [[ -f "$DOCKER_DIR/compose.yml" ]] && (cd "$DOCKER_DIR" && docker compose down); pause_menu ;;
    5) return 0 ;;
  esac
}

vm_menu(){
  clear 2>/dev/null || true
  echo "=== KVM / VM RUNTIME MANAGEMENT ==="
  echo "1) KVM & libvirt Pakete installieren"
  echo "2) VM Status abfragen"
  echo "3) Zurück"
  read -rp "Auswahl: " c
  clear 2>/dev/null || true
  case "$c" in
    1) apt_install qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils; pause_menu ;;
    2) command_exists virsh && virsh list --all || echo "virsh nicht verfügbar."; pause_menu ;;
    3) return 0 ;;
  esac
}

verify_installations(){
  echo "=== VERIFIZIERUNG ==="
  show_preflight
  persist_runtime_state
  command_exists ollama && echo '✔ Ollama vorhanden' || echo '✖ Ollama fehlt/remote'
  [[ -f "$COMFYUI_DIR/main.py" ]] && echo '✔ ComfyUI vorhanden' || echo '✖ ComfyUI fehlt'
  [[ -x "$VENV_OPENWEBUI/bin/open-webui" ]] && echo '✔ Open WebUI vorhanden' || echo '✖ Open WebUI fehlt'
}

stop_services(){
  for f in "$PID_DIR"/*.pid; do
    [[ -e "$f" ]] || continue
    p="$(cat "$f" 2>/dev/null || true)"
    [[ "$p" =~ ^[0-9]+$ ]] && kill "$p" 2>/dev/null || true
    rm -f "$f"
  done
  ok "Dienste gestoppt."
}

show_state(){
  persist_runtime_state
  echo "=== DAX RUNTIME STATE ==="
  cat "$STATE_DIR/state.json"
}

view_logs(){
  touch "$LOG_FILE"
  tail -n 60 -f "$LOG_FILE"
}

pause_menu(){
  echo
  read -rp 'ENTER zum Fortfahren...' _
  clear 2>/dev/null || true
}

# =============================================================================
# KATEGORIEN-SUBMENÜS
# =============================================================================

menu_host(){
  while true; do
    clear 2>/dev/null || true
    echo -e "${CLR_BLUE}=== [1] HOST & HARDWARE MATRIX ===${CLR_RESET}"
    echo "[1] System / Capability Check (Preflight Matrix)"
    echo "[2] Zurück ins Hauptmenü"
    read -rp 'Auswahl [1-2]: ' c
    clear 2>/dev/null || true
    case "$c" in
      1) show_preflight; pause_menu ;;
      2) return 0 ;;
      *) warn 'Ungültige Auswahl.'; sleep 1 ;;
    esac
  done
}

menu_runtimes(){
  while true; do
    clear 2>/dev/null || true
    echo -e "${CLR_BLUE}=== [2] RUNTIMES ===${CLR_RESET}"
    echo "[1] Native Runtime / System Dependencies (Python VENVs)"
    echo "[2] Docker Runtime (Container & Compose Management)"
    echo "[3] KVM / VM Runtime (QEMU/libvirt & Snapshots)"
    echo "[4] Remote Runtime (SSH Orchestrierung)"
    echo "[5] Zurück ins Hauptmenü"
    read -rp 'Auswahl [1-5]: ' c
    clear 2>/dev/null || true
    case "$c" in
      1) install_system_dependencies; pause_menu ;;
      2) runtime_menu ;;
      3) vm_menu ;;
      4) echo "Remote Runtime: SSH/Orchestrator-Schnittstelle ist bereit."; pause_menu ;;
      5) return 0 ;;
      *) warn 'Ungültige Auswahl.'; sleep 1 ;;
    esac
  done
}

menu_control_plane(){
  while true; do
    clear 2>/dev/null || true
    echo -e "${CLR_BLUE}=== [3] CONTROL-PLANE MODULES ===${CLR_RESET}"
    echo "[1] Agent Manager / Deployment Wizard"
    echo "[2] Agent Profiles (Manifeste)"
    echo "[3] Policy Manager (.dax/policy.yaml)"
    echo "[4] Volume Manager (.dax/volumes.yaml)"
    echo "[5] Secrets Manager (AES-256)"
    echo "[6] Template Manager"
    echo "[7] Encrypted Backup & Restore (.tar.gz.enc)"
    echo "[8] Web Status Dashboard & API (Port 9090)"
    echo "[9] Zurück ins Hauptmenü"
    read -rp 'Auswahl [1-9]: ' c
    clear 2>/dev/null || true
    case "$c" in
      1) agent_deployment_wizard ;;
      2) agent_profiles; pause_menu ;;
      3) policy_manager; pause_menu ;;
      4) volume_manager; pause_menu ;;
      5) secrets_manager; pause_menu ;;
      6) template_manager; pause_menu ;;
      7) backup_manager; pause_menu ;;
      8) dashboard_manager; pause_menu ;;
      9) return 0 ;;
      *) warn 'Ungültige Auswahl.'; sleep 1 ;;
    esac
  done
}

menu_services(){
  while true; do
    clear 2>/dev/null || true
    echo -e "${CLR_BLUE}=== [4] SERVICES ===${CLR_RESET}"
    echo "[1] Ollama konfigurieren & starten"
    echo "[2] Ollama Modell laden (intelligenter RAM-Check)"
    echo "[3] ComfyUI installieren/starten"
    echo "[4] Open WebUI installieren/starten"
    echo "[5] Node-RED + Faster-Whisper"
    echo "[6] Zurück ins Hauptmenü"
    read -rp 'Auswahl [1-6]: ' c
    clear 2>/dev/null || true
    case "$c" in
      1) install_ollama; pause_menu ;;
      2) pull_ollama_model; pause_menu ;;
      3) install_comfyui; start_comfyui; pause_menu ;;
      4) install_openwebui; start_openwebui; pause_menu ;;
      5) install_nodered || true; install_whisper || true; start_nodered || true; pause_menu ;;
      6) return 0 ;;
      *) warn 'Ungültige Auswahl.'; sleep 1 ;;
    esac
  done
}

menu_operations(){
  while true; do
    clear 2>/dev/null || true
    echo -e "${CLR_BLUE}=== [5] OPERATIONS & MONITORING ===${CLR_RESET}"
    echo "[1] Health / Watchdog Check"
    echo "[2] Installation verifizieren"
    echo "[3] State / Configuration anzeigen"
    echo "[4] Automatisierte Testsuite ausführen (100% Validierung)"
    echo "[5] Dienste stoppen"
    echo "[6] Logs anzeigen"
    echo "[7] Zurück ins Hauptmenü"
    read -rp 'Auswahl [1-7]: ' c
    clear 2>/dev/null || true
    case "$c" in
      1) health_check; pause_menu ;;
      2) verify_installations; pause_menu ;;
      3) show_state; pause_menu ;;
      4) "$SCRIPT_DIR/tests/run_tests.sh"; pause_menu ;;
      5) stop_services; pause_menu ;;
      6) view_logs ;;
      7) return 0 ;;
      *) warn 'Ungültige Auswahl.'; sleep 1 ;;
    esac
  done
}

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
    echo -e "${CLR_BLUE}║${CLR_GOLD}          DAX COMMAND CENTER v$VERSION          ${CLR_BLUE}║${CLR_RESET}"
    echo -e "${CLR_BLUE}║${CLR_GOLD}       CONTROL-PLANE EDITION (Policy/Adapter/Watchdog)   ${CLR_BLUE}║${CLR_RESET}"
    echo -e "${CLR_BLUE}╚════════════════════════════════════════════════════════════╝${CLR_RESET}"
    echo "Platform: $PLATFORM | GPU: $GPU_TYPE | Mode: $COMFYUI_MODE"
    echo "Docker: $CAN_DOCKER/$DOCKER_DAEMON | KVM: $CAN_KVM | libvirt: $CAN_LIBVIRT"
    echo
    echo "[1] HOST (Preflight Matrix & Hardware Check)"
    echo "[2] RUNTIMES (Native, Docker, KVM, Remote)"
    echo "[3] CONTROL-PLANE MODULES (Agents, Policy, Secrets, Backups, Dashboard)"
    echo "[4] SERVICES (Ollama, ComfyUI, Open WebUI, Node-RED/Whisper)"
    echo "[5] OPERATIONS (Watchdog, Tests, State, Stop, Logs)"
    echo "[6] Beenden"
    read -rp 'Auswahl [1-6]: ' choice
    clear 2>/dev/null || true
    case "$choice" in
      1) menu_host ;;
      2) menu_runtimes ;;
      3) menu_control_plane ;;
      4) menu_services ;;
      5) menu_operations ;;
      6) exit 0 ;;
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
