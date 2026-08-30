#!/usr/bin/env bash
# =============================================================================
# DAX CONTROL PLANE v6.3 — CONTROL-PLANE EDITION
# Reconstituierte Paketversion: Policy Engine, Agent-Adapter-System,
# Watchdog, Remote Runtime, Secrets Manager, Volume Manager, Template Engine.
#
# Basis: ~/.dax AutoInstaller Workspace (start.sh, lib/*.sh, agents/*, tests/*)
# Ergänzt: Policy Engine, Agent-Adapter-System, Watchdog, Remote Runtime,
#          Secrets Manager, Volume Manager, Template Engine
# =============================================================================
set -Eeuo pipefail
IFS=$'\n\t'

# =============================================================================
# VERZEICHNIS- & SONSTIGE KONSTANTEN
# =============================================================================
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

VERSION="6.3-control-plane"

CLR_BLUE=$'\033[38;2;0;210;255m'; CLR_GOLD=$'\033[38;2;212;175;55m'
CLR_GREEN=$'\033[38;2;0;255;127m'; CLR_RED=$'\033[38;2;255;69;0m'
CLR_WHITE=$'\033[1;37m'; CLR_RESET=$'\033[0m'; CLR_DIM=$'\033[2;37m'

LOG_DIR="$SCRIPT_DIR/logs"; LOG_FILE="$LOG_DIR/installation.log"
STATE_DIR="$SCRIPT_DIR/.dax"; PID_DIR="$STATE_DIR/pids"
VENV_COMFYUI="$SCRIPT_DIR/.comfyuivenv"; VENV_OPENWEBUI="$SCRIPT_DIR/.openwebuivenv"
VENV_WHISPER="$SCRIPT_DIR/.whispervenv"; COMFYUI_DIR="$SCRIPT_DIR/ComfyUI"
ENV_FILE="$SCRIPT_DIR/.env"; RUNTIME_DIR="$SCRIPT_DIR/runtime"
DOCKER_DIR="$SCRIPT_DIR/docker"; DOCKER_SHARED_DIR="$DOCKER_DIR/shared"
DOCKER_HERMES_DIR="$DOCKER_DIR/hermes"; DOCKER_OPENCLAW_DIR="$DOCKER_DIR/openclaw"
VM_DIR="$SCRIPT_DIR/vms"; DATA_DIR="$SCRIPT_DIR/data"
TEMPLATE_DIR="$SCRIPT_DIR/templates"; NETWORK_DIR="$SCRIPT_DIR/networks"
AGENT_DIR="$SCRIPT_DIR/agents"
BACKUP_DIR="$DATA_DIR/backups"; WATCHDOG_LOG="$LOG_DIR/watchdog.log"

mkdir -p "$LOG_DIR" "$PID_DIR" "$RUNTIME_DIR" "$DOCKER_DIR" "$DOCKER_SHARED_DIR" \
  "$DOCKER_HERMES_DIR" "$DOCKER_OPENCLAW_DIR" "$VM_DIR" "$DATA_DIR" "$TEMPLATE_DIR" \
  "$NETWORK_DIR" "$AGENT_DIR" "$BACKUP_DIR"

WATCHDOG_FILE="$STATE_DIR/watchdog.json"
POLICY_FILE="$STATE_DIR/policy.yaml"
VOLUMES_FILE="$STATE_DIR/volumes.yaml"
REMOTE_FILE="$STATE_DIR/remote_hosts.yaml"

log(){ printf '[%s] [%s] %s\n' "$(date '+%F %T')" "$1" "$2" | tee -a "$LOG_FILE"; }
info(){ echo -e "${CLR_BLUE}[+]${CLR_RESET} $*"; log INFO "$*"; }
ok(){ echo -e "${CLR_GREEN}[✔]${CLR_RESET} $*"; log OK "$*"; }
warn(){ echo -e "${CLR_GOLD}[!]${CLR_RESET} $*"; log WARN "$*"; }
die(){ echo -e "${CLR_RED}[✖]${CLR_RESET} $*" >&2; log ERROR "$*"; exit 1; }
command_exists(){ command -v "$1" >/dev/null 2>&1; }

pause_menu(){ echo; read -rp 'ENTER zum Fortfahren...' _ || true; }

# =============================================================================
# PLATFORM- & HARDWARERKENNUNG (aus core.sh)
# =============================================================================
detect_hardware(){. "$SCRIPT_DIR/lib/core.sh" && detect_hardware "$@"; }
detect_runtime_capabilities(){
  . "$SCRIPT_DIR/lib/core.sh"
  detect_runtime_capabilities "$@"
}
get_ram_mb(){ . "$SCRIPT_DIR/lib/core.sh" && get_ram_mb; }
ram_recommendation(){
  local ram_mb
  ram_mb="$(get_ram_mb)"
  echo "RAM: ${ram_mb} MB"
  if (( ram_mb < 6000 )); then
    echo "Empfehlung: Qwen 1.5B / Phi-3 Mini (CPU Mode / Remote Ollama)"
  elif (( ram_mb < 14000 )); then
    echo "Empfehlung: Llama 3 8B Q4 / Mistral 7B Q4"
  else
    echo "Empfehlung: Llama 3 8B Q8 / Qwen 14B / ComfyUI High-Res"
  fi
}
show_preflight(){
  detect_hardware
  detect_runtime_capabilities
  echo "=== PREFLIGHT & HARDWARE MATRIX ==="
  echo "OS / Plattform: $(. "$SCRIPT_DIR/lib/core.sh" && echo "$OS_NAME") ($PLATFORM)"
  echo "GPU Backend:    $GPU_TYPE ($GPU_NAME)"
  echo "ComfyUI Mode:   $COMFYUI_MODE"
  echo "Torch Index:    ${TORCH_INDEX:-Standard/PyPI}"
  echo "Docker Engine:  Binary=$CAN_DOCKER | Daemon=$DOCKER_DAEMON"
  echo "KVM / Hardware: Device=$KVM_DEVICE | QEMU=$CAN_KVM | libvirt=$CAN_LIBVIRT"
  ram_recommendation
}
persist_runtime_state(){
  . "$SCRIPT_DIR/lib/core.sh"
  persist_runtime_state
}

# =============================================================================
# POLICY ENGINE (lib/policy.sh)
# =============================================================================
policy_ensure()   { . "$SCRIPT_DIR/lib/policy.sh" && policy_ensure; }
policy_allow_runtime_for_platform(){
  local rt="$1"
  . "$SCRIPT_DIR/lib/policy.sh"
  policy_allow_runtime_for_platform "$rt"
}
policy_allow_runtime_for_agent(){
  local agent="$1" rt="$2"
  . "$SCRIPT_DIR/lib/policy.sh"
  policy_allow_runtime_for_agent "$agent" "$rt"
}
policy_manager(){
  . "$SCRIPT_DIR/lib/policy.sh"
  policy_manager
}

# =============================================================================
# SECRETS MANAGER (lib/secrets.sh)
# =============================================================================
secret_encrypt_value(){ . "$SCRIPT_DIR/lib/secrets.sh" && secret_encrypt_value "$@"; }
secret_decrypt_value(){ . "$SCRIPT_DIR/lib/secrets.sh" && secret_decrypt_value "$@"; }
secret_set(){ . "$SCRIPT_DIR/lib/secrets.sh" && secret_set "$@"; }
secret_get(){ . "$SCRIPT_DIR/lib/secrets.sh" && secret_get "$@"; }
secret_get_envfile(){ . "$SCRIPT_DIR/lib/secrets.sh" && secret_get_envfile "$@"; }
secret_inject_docker(){ . "$SCRIPT_DIR/lib/secrets.sh" && secret_inject_docker "$@"; }
ensure_master_key(){ . "$SCRIPT_DIR/lib/secrets.sh" && ensure_master_key; }
secrets_manager(){
  . "$SCRIPT_DIR/lib/secrets.sh"
  secrets_manager
}

# =============================================================================
# VOLUME MANAGER (lib/volumes.sh)
# =============================================================================
volume_ensure(){ . "$SCRIPT_DIR/lib/volumes.sh" && volume_ensure "$@"; }
volume_mount_docker(){ . "$SCRIPT_DIR/lib/volumes.sh" && volume_mount_docker "$@"; }
volume_manager(){
  . "$SCRIPT_DIR/lib/volumes.sh"
  volume_manager
}

# =============================================================================
# TEMPLATE ENGINE (lib/templates.sh)
# =============================================================================
template_apply_compose(){ . "$SCRIPT_DIR/lib/templates.sh" && template_apply_compose "$@"; }
template_manager(){
  . "$SCRIPT_DIR/lib/templates.sh"
  template_manager
}

# =============================================================================
# AGENT-ADAPTER-SYSTEM (lib/adapters.sh + lib/adapter_base.sh)
# =============================================================================
agent_dispatch(){
  local agent="$1" action="$2" rt="${3:-docker}"
  . "$SCRIPT_DIR/lib/adapters.sh"
  agent_dispatch "$agent" "$action" "$rt"
}
agent_profiles(){
  . "$SCRIPT_DIR/lib/adapters.sh"
  agent_profiles
}
agent_deployment_wizard(){
  . "$SCRIPT_DIR/lib/adapters.sh"
  agent_deployment_wizard
}

# =============================================================================
# WATCHDOG (lib/watchdog.sh)
# =============================================================================
watchdog_ensure()    { . "$SCRIPT_DIR/lib/watchdog.sh" && watchdog_ensure; }
watchdog_tick()      { . "$SCRIPT_DIR/lib/watchdog.sh" && watchdog_tick "$@"; }
watchdog_recover()   { . "$SCRIPT_DIR/lib/watchdog.sh" && watchdog_recover "$@"; }
watchdog_status()    { . "$SCRIPT_DIR/lib/watchdog.sh" && watchdog_status; }
health_check(){
  . "$SCRIPT_DIR/lib/watchdog.sh"
  health_check
}

# =============================================================================
# BACKUP (lib/backup.sh)
# =============================================================================
backup_create(){ . "$SCRIPT_DIR/lib/backup.sh" && backup_create; }
backup_list(){ . "$SCRIPT_DIR/lib/backup.sh" && backup_list; }
backup_restore(){ . "$SCRIPT_DIR/lib/backup.sh" && backup_restore "$@"; }
backup_manager(){
  . "$SCRIPT_DIR/lib/backup.sh"
  backup_manager
}

# =============================================================================
# DASHBOARD (lib/dashboard.sh)
# =============================================================================
dashboard_start(){ . "$SCRIPT_DIR/lib/dashboard.sh" && dashboard_start; }
dashboard_stop(){ . "$SCRIPT_DIR/lib/dashboard.sh" && dashboard_stop; }
dashboard_status(){ . "$SCRIPT_DIR/lib/dashboard.sh" && dashboard_status; }
dashboard_manager(){
  . "$SCRIPT_DIR/lib/dashboard.sh"
  dashboard_manager
}

# =============================================================================
# MENUS (lib/menus.sh)
# =============================================================================
menu_host()          { . "$SCRIPT_DIR/lib/menus.sh" && menu_host; }
menu_runtimes()      { . "$SCRIPT_DIR/lib/menus.sh" && menu_runtimes; }
menu_control_plane() { . "$SCRIPT_DIR/lib/menus.sh" && menu_control_plane; }
menu_services()      { . "$SCRIPT_DIR/lib/menus.sh" && menu_services; }
menu_operations()    { . "$SCRIPT_DIR/lib/menus.sh" && menu_operations; }
menu_help()          { . "$SCRIPT_DIR/lib/menus.sh" && menu_help; }

# =============================================================================
# NATIVE RUNTIMES & SERVICES
# =============================================================================
install_system_dependencies(){
  . "$SCRIPT_DIR/lib/core.sh"
  if command_exists apt-get; then
    . "$SCRIPT_DIR/lib/core.sh"
    sudo apt-get update -qq 2>/dev/null || true
    sudo apt-get install -y -qq git curl unzip zip build-essential python3 python3-venv python3-pip nodejs npm ffmpeg ca-certificates procps pciutils 2>/dev/null || true
  elif command_exists pkg; then
    pkg update -y >>"$LOG_FILE" 2>&1 || true
    pkg install -y git curl unzip zip python nodejs ffmpeg procps >>"$LOG_FILE" 2>&1 || true
  fi
  ok "Systemabhängigkeiten installiert."
}

install_ollama(){
  if [[ "$PLATFORM" == "termux" || "$PLATFORM" == "proot" ]]; then
    warn "Lokale Ollama Install nicht unterstützt auf $PLATFORM — verwende Remote Ollama."
    return 0
  fi
  if command_exists ollama; then
    ok "Ollama bereits installiert."
  else
    curl -fsSL https://ollama.com/install.sh | sh >>"$LOG_FILE" 2>&1 || die "Ollama-Installation fehlgeschlagen."
  fi
  ram_recommendation
  if command_exists ollama && ! pgrep -x ollama >/dev/null 2>&1; then
    nohup ollama serve >>"$LOG_DIR/ollama.log" 2>&1 &
    echo $! > "$PID_DIR/ollama.pid"
    sleep 2
  fi
  ok "Ollama bereit."
}

pull_ollama_model(){
  command_exists ollama || { warn "Ollama fehlt."; return; }
  ram_recommendation
  read -rp "Modell [qwen2.5:7b]: " m
  m="${m:-qwen2.5:7b}"
  ollama pull "$m" 2>&1 | tee -a "$LOG_FILE"
  ok "Modell $m geladen."
}

install_comfyui(){
  detect_hardware
  git clone https://github.com/Comfy-Org/ComfyUI.git "$COMFYUI_DIR" 2>/dev/null || (cd "$COMFYUI_DIR" && git pull --ff-only 2>/dev/null)
  ensure_venv "$VENV_COMFYUI" "ComfyUI"
  "$VENV_COMFYUI/bin/python" -m pip install -r "$COMFYUI_DIR/requirements.txt" >>"$LOG_FILE" 2>&1 || warn "ComfyUI Requirements nicht vollständig installiert."
  ok "ComfyUI eingerichtet."
}

start_comfyui(){
  [[ -f "$COMFYUI_DIR/main.py" ]] || { warn "ComfyUI nicht installiert."; return; }
  nohup "$VENV_COMFYUI/bin/python" "$COMFYUI_DIR/main.py" --listen 127.0.0.1 --port 8188 >>"$LOG_DIR/comfyui.log" 2>&1 &
  echo $! > "$PID_DIR/comfyui.pid"
  ok "ComfyUI gestartet: http://127.0.0.1:8188"
}

install_openwebui(){
  ensure_venv "$VENV_OPENWEBUI" "Open WebUI"
  "$VENV_OPENWEBUI/bin/python" -m pip install open-webui >>"$LOG_FILE" 2>&1 || warn "Open WebUI nicht installiert."
  ok "Open WebUI eingerichtet."
}

start_openwebui(){
  [[ -x "$VENV_OPENWEBUI/bin/open-webui" ]] || { warn "Open WebUI nicht installiert."; return; }
  nohup "$VENV_OPENWEBUI/bin/open-webui" serve --host 127.0.0.1 --port 8080 >>"$LOG_DIR/openwebui.log" 2>&1 &
  echo $! > "$PID_DIR/openwebui.pid"
  ok "Open WebUI gestartet: http://127.0.0.1:8080"
}

install_nodered(){
  command_exists npm || { warn "npm fehlt."; return 1; }
  npm install -g node-red >>"$LOG_FILE" 2>&1 || warn "Node-RED nicht installiert."
}

start_nodered(){
  command_exists node-red || { warn "Node-RED fehlt."; return; }
  nohup node-red >>"$LOG_DIR/nodered.log" 2>&1 &
  echo $! > "$PID_DIR/nodered.pid"
  ok "Node-RED gestartet: http://127.0.0.1:1880"
}

install_whisper(){
  ensure_venv "$VENV_WHISPER" "Faster-Whisper"
  "$VENV_WHISPER/bin/python" -m pip install faster-whisper >>"$LOG_FILE" 2>&1 || warn "Faster-Whisper nicht installiert."
  ok "Faster-Whisper eingerichtet."
}
start_whisper(){
  [[ -x "$VENV_WHISPER/bin/faster-whisper" ]] || { warn "Faster-Whisper nicht installiert."; return; }
  nohup "$VENV_WHISPER/bin/faster-whisper" --help >>"$LOG_DIR/whisper.log" 2>&1 &
  echo $! > "$PID_DIR/whisper.pid"
}

# =============================================================================
# SERVICE-STOPP & LOGS
# =============================================================================
stop_services(){
  for f in "$PID_DIR"/*.pid; do
    [[ -e "$f" ]] || continue
    p="$(cat "$f" 2>/dev/null || true)"
    [[ "$p" =~ ^[0-9]+$ ]] && kill "$p" 2>/dev/null || true
    rm -f "$f"
  done
  ok "Dienste gestoppt."
  rm -f /tmp/dax-secrets-*.env 2>/dev/null || true
}

view_logs(){
  touch "$LOG_FILE"
  tail -n 60 -f "$LOG_FILE"
}

verify_installations(){
  echo "=== VERIFIZIERUNG ==="
  show_preflight
  persist_runtime_state
  command_exists ollama && echo '✔ Ollama vorhanden' || echo '✖ Ollama fehlt/remote'
  [[ -f "$COMFYUI_DIR/main.py" ]] && echo '✔ ComfyUI vorhanden' || echo '✖ ComfyUI fehlt'
  [[ -x "$VENV_OPENWEBUI/bin/open-webui" ]] && echo '✔ Open WebUI vorhanden' || echo '✖ Open WebUI fehlt'
  docker info >/dev/null 2>&1 && echo '✔ Docker Daemon erreichbar' || echo '✖ Docker nicht erreichbar'
  command_exists virsh && virsh -c qemu:///system uri >/dev/null 2>&1 && echo '✔ libvirt erreichbar' || echo '✖ libvirt nicht erreichbar'
}

show_state(){
  persist_runtime_state
  echo "=== DAX STATE ==="
  cat "$STATE_DIR/state.json" 2>/dev/null || echo "Kein State vorhanden."
}

# =============================================================================
# HAUPTMENÜ (INTERAKTIV)
# =============================================================================
main_menu(){
  detect_hardware
  detect_runtime_capabilities
  persist_runtime_state

  while true; do
    clear 2>/dev/null || true
    echo -e "${CLR_BLUE}╔════════════════════════════════════════════════════════════╗${CLR_RESET}"
    echo -e "${CLR_BLUE}║${CLR_GOLD}          DAX COMMAND CENTER v$VERSION          ${CLR_BLUE}║${CLR_RESET}"
    echo -e "${CLR_BLUE}╚════════════════════════════════════════════════════════════╝${CLR_RESET}"
    echo "Platform: $PLATFORM | GPU: $GPU_TYPE | Mode: $COMFYUI_MODE"
    echo "Docker: $CAN_DOCKER/$DOCKER_DAEMON | KVM: $CAN_KVM | libvirt: $CAN_LIBVIRT"
    echo
    echo "HOST"
    echo "[0]  System / Capability Check"
    echo
    echo "RUNTIMES"
    echo "[1]  Native Runtime / System Dependencies (sudo nur hier; Termux/PRoot eingeschränkt)"
    echo "[2]  Docker Runtime (Termux/PRoot: NICHT versuchen)"
    echo "[3]  KVM / VM Runtime (Termux/PRoot: NICHT versuchen)"
    echo "[4]  Remote Runtime (Vorbereitung)"
    echo
    echo "AGENTS"
    echo "[5]  Agent Manager / Deployment Wizard"
    echo "[6]  Agent Profiles"
    echo
    echo "SERVICES"
    echo "[7]  Ollama konfigurieren (Termux/PRoot: Remote empfohlen)"
    echo "[8]  Ollama Modell laden (Termux/PRoot: Remote-Host verwenden)"
    echo "[9]  ComfyUI installieren/starten (Termux/PRoot: CPU Safe Mode)"
    echo "[10] Open WebUI installieren/starten (Termux/PRoot: abhängig von Python/Architektur)"
    echo "[11] Node-RED + Faster-Whisper (Termux/PRoot: eingeschränkt)"
    echo
    echo "OPERATIONS"
    echo "[12] Health / Watchdog Check"
    echo "[13] Installation verifizieren"
    echo "[14] State / Configuration anzeigen"
    echo "[15] Dienste stoppen"
    echo "[16] Logs anzeigen"
    echo "[17] Beenden"
    read -rp 'Auswahl [0-17]: ' choice
    case "$choice" in
      0) show_preflight; pause_menu;;
      1) install_system_dependencies; pause_menu;;
      2) runtime_menu;;
      3) vm_menu;;
      4) echo "Remote Runtime: SSH/Orchestrator-Schnittstelle ist vorbereitet, aber kein blindes Remote-Deployment."; pause_menu;;
      5) agent_deployment_wizard;;
      6) agent_profiles; pause_menu;;
      7) install_ollama; pause_menu;;
      8) pull_ollama_model; pause_menu;;
      9) install_comfyui; start_comfyui; pause_menu;;
      10) install_openwebui; start_openwebui; pause_menu;;
      11) install_nodered || true; install_whisper || true; start_nodered || true; pause_menu;;
      12) health_check; pause_menu;;
      13) verify_installations; pause_menu;;
      14) show_state; pause_menu;;
      15) stop_services; pause_menu;;
      16) view_logs;;
      17) exit 0;;
      *) warn 'Ungültige Auswahl.'; sleep 1;;
    esac
  done
}

# =============================================================================
# RUNTIME-SUBMENTÜS
# =============================================================================
runtime_menu(){
  while true; do
    clear 2>/dev/null || true
    echo -e "${CLR_BLUE}=== DAX MULTI-RUNTIME MANAGER ===${CLR_RESET}"
    echo "[1] Docker prüfen"
    echo "[2] Docker installieren"
    echo "[3] Agent-Docker-Struktur erzeugen"
    echo "[4] Agent Container bauen"
    echo "[5] Agent Container starten"
    echo "[6] Agent Container stoppen"
    echo "[7] Container-Logs"
    echo "[8] Container-Status"
    echo "[9] Docker Compose UP"
    echo "[10] Docker Compose DOWN"
    echo "[11] KVM / VM Manager"
    echo "[12] Agent Profiles"
    echo "[13] Agent Deployment Wizard"
    echo "[14] Zurück"
    read -rp "Auswahl [1-14]: " c
    case "$c" in
      1) docker_status; pause_menu ;;
      2) install_docker; pause_menu ;;
      3) docker_context_init; pause_menu ;;
      4) read -rp "Agent [hermes/openclaw]: " a; docker_build_agent "$a" || true; pause_menu ;;
      5) read -rp "Agent [hermes/openclaw]: " a; docker_start_agent "$a" || true; pause_menu ;;
      6) read -rp "Agent [hermes/openclaw]: " a; docker_stop_agent "$a" || true; pause_menu ;;
      7) read -rp "Agent [hermes/openclaw]: " a; docker_logs_agent "$a" || true ;;
      8) docker_agent_status; pause_menu ;;
      9) docker_compose_up || true; pause_menu ;;
      10) docker_compose_down || true; pause_menu ;;
      11) vm_menu ;;
      12) agent_profiles; pause_menu ;;
      13) agent_deployment_wizard ;;
      14) break ;;
      *) warn "Ungültige Auswahl."; sleep 1 ;;
    esac
  done
}

docker_status(){
  detect_runtime_capabilities
  persist_runtime_state
  echo "=== DOCKER RUNTIME ==="
  echo "Docker binary : $(docker --version 2>/dev/null || echo missing)"
  echo "Daemon        : $DOCKER_DAEMON"
  echo "Rootless      : (nicht zugeordnet)"
  if [[ "$DOCKER_DAEMON" == true ]]; then
    docker info --format 'Server: {{.ServerVersion}} | Containers: {{.Containers}} | Images: {{.Images}}' 2>/dev/null || true
  fi
}
install_docker(){
  require_native_linux || return 0
  detect_runtime_capabilities
  if [[ "$DOCKER_DAEMON" == true ]]; then ok "Docker ist installiert und der Daemon erreichbar."; return 0; fi
  if ! confirm_action "Docker installieren?"; then warn "Abgebrochen."; return 0; fi
  if command_exists apt-get; then
    . "$SCRIPT_DIR/lib/core.sh"
    sudo apt-get update -qq 2>/dev/null || true
    sudo apt-get install -y -qq docker.io docker-compose-plugin 2>/dev/null || true
    sudo systemctl enable --now docker 2>/dev/null || true
  else
    die "Docker-Autoinstallation ist für diesen Paketmanager nicht implementiert."
  fi
  detect_runtime_capabilities
  persist_runtime_state
  [[ "$DOCKER_DAEMON" == true ]] && ok "Docker Runtime bereit." || warn "Docker installiert, aber Daemon noch nicht erreichbar."
}
docker_context_init(){
  mkdir -p "$DOCKER_DIR/hermes" "$DOCKER_DIR/openclaw" "$DOCKER_SHARED_DIR"
  cat > "$DOCKER_SHARED_DIR/entrypoint.sh" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
exec "$@"
EOF
  chmod +x "$DOCKER_SHARED_DIR/entrypoint.sh"

  cat > "$DOCKER_DIR/hermes/Dockerfile" <<'EOF'
FROM ubuntu:24.04
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash ca-certificates curl git python3 python3-venv && \
    rm -rf /var/lib/apt/lists/*
WORKDIR /opt/agent
COPY shared/entrypoint.sh /usr/local/bin/dax-entrypoint
RUN useradd --create-home --shell /bin/bash daxagent && chown -R daxagent:daxagent /opt/agent
USER daxagent
ENTRYPOINT ["/usr/local/bin/dax-entrypoint"]
CMD ["bash"]
EOF

  cat > "$DOCKER_DIR/openclaw/Dockerfile" <<'EOF'
FROM ubuntu:24.04
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash ca-certificates curl git python3 python3-venv nodejs npm && \
    rm -rf /var/lib/apt/lists/*
WORKDIR /opt/agent
COPY shared/entrypoint.sh /usr/local/bin/dax-entrypoint
RUN useradd --create-home --shell /bin/bash daxagent && chown -R daxagent:daxagent /opt/agent
USER daxagent
ENTRYPOINT ["/usr/local/bin/dax-entrypoint"]
CMD ["bash"]
EOF

  cat > "$DOCKER_DIR/compose.yml" <<'EOF'
services:
  hermes:
    build:
      context: .
      dockerfile: hermes/Dockerfile
    container_name: dax-hermes
    restart: unless-stopped
    security_opt:
      - no-new-privileges:true
    cap_drop:
      - ALL
    environment:
      DAX_AGENT_RUNTIME: docker
    volumes:
      - ./shared:/opt/dax/shared:ro

  openclaw:
    build:
      context: .
      dockerfile: openclaw/Dockerfile
    container_name: dax-openclaw
    restart: unless-stopped
    security_opt:
      - no-new-privileges:true
    cap_drop:
      - ALL
    environment:
      DAX_AGENT_RUNTIME: docker
    volumes:
      - ./shared:/opt/dax/shared:ro
EOF
}
docker_build_agent(){
  require_native_linux || return 0
  detect_runtime_capabilities
  [[ "$DOCKER_DAEMON" == true ]] || { warn "Docker Daemon nicht erreichbar."; return 1; }
  docker_context_init
  local agent="${1:-}"
  case "$agent" in
    hermes) docker build -t dax/hermes:baseline -f "$DOCKER_DIR/hermes/Dockerfile" "$DOCKER_DIR" ;;
    openclaw) docker build -t dax/openclaw:baseline -f "$DOCKER_DIR/openclaw/Dockerfile" "$DOCKER_DIR" ;;
    *) warn "Agent muss hermes oder openclaw sein."; return 1 ;;
  esac
}
docker_start_agent(){
  require_native_linux || return 0
  detect_runtime_capabilities
  [[ "$DOCKER_DAEMON" == true ]] || { warn "Docker Daemon nicht erreichbar."; return 1; }
  local agent="${1:-}" image="dax/${agent}:baseline"
  case "$agent" in
    hermes|openclaw) ;;
    *) warn "Agent muss hermes oder openclaw sein."; return 1 ;;
  esac
  docker rm -f "dax-$agent" >/dev/null 2>&1 || true
  docker run -d \
    --name "dax-$agent" \
    --restart unless-stopped \
    --security-opt no-new-privileges:true \
    --cap-drop ALL \
    --pids-limit 512 \
    --memory 4g \
    --cpus 2 \
    -e DAX_AGENT_RUNTIME=docker \
    -v "$DOCKER_SHARED_DIR:/opt/dax/shared:ro" \
    "$image"
  ok "Container dax-$agent gestartet."
}
docker_stop_agent(){
  require_native_linux || return 0
  local agent="${1:-}"
  case "$agent" in
    hermes|openclaw) docker stop "dax-$agent" 2>/dev/null || true; docker rm "dax-$agent" 2>/dev/null || true ;;
    *) warn "Agent muss hermes oder openclaw sein."; return 1 ;;
  esac
}
docker_logs_agent(){
  require_native_linux || return 0
  local agent="${1:-}"
  case "$agent" in
    hermes|openclaw) docker logs --tail 100 -f "dax-$agent" ;;
    *) warn "Agent muss hermes oder openclaw sein."; return 1 ;;
  esac
}
docker_agent_status(){
  require_native_linux || return 0
  docker ps -a --filter name=dax-hermes --filter name=dax-openclaw \
    --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}'
}
docker_compose_up(){
  require_native_linux || return 0
  detect_runtime_capabilities
  [[ "$DOCKER_DAEMON" == true ]] || { warn "Docker Daemon nicht erreichbar."; return 1; }
  docker_context_init
  if docker compose version >/dev/null 2>&1; then
    (cd "$DOCKER_DIR" && docker compose up -d)
  else
    warn "Docker Compose Plugin fehlt."
    return 1
  fi
}
docker_compose_down(){
  require_native_linux || return 0
  if docker compose version >/dev/null 2>&1; then
    (cd "$DOCKER_DIR" && docker compose down)
  else
    warn "Docker Compose Plugin fehlt."
  fi
}

vm_menu(){
  while true; do
    clear 2>/dev/null || true
    echo -e "${CLR_BLUE}=== DAX KVM / VM MANAGER ===${CLR_RESET}"
    echo "[1] KVM installieren (native Linux; Termux/PRoot: NICHT versuchen)"
    echo "[2] KVM/VM Status"
    echo "[3] Neue VM erstellen (KVM/QEMU)"
    echo "[4] VM starten"
    echo "[5] VM stoppen"
    echo "[6] VM löschen"
    echo "[7] Snapshot erstellen"
    echo "[8] Snapshot wiederherstellen"
    echo "[9] Snapshot-Liste"
    echo "[10] Zurück"
    read -rp "Auswahl [1-10]: " c
    case "$c" in
      1) install_kvm; pause_menu ;;
      2) kvm_status; pause_menu ;;
      3) create_kvm_vm; pause_menu ;;
      4) read -rp "VM Name: " n; virsh -c qemu:///system start "$n" 2>&1 || true; pause_menu ;;
      5) read -rp "VM Name: " n; virsh -c qemu:///system shutdown "$n" 2>&1 || true; pause_menu ;;
      6)
        read -rp "VM Name: " n
        if confirm_action "VM '$n' undefinieren und Storage entfernen?"; then
          virsh -c qemu:///system destroy "$n" 2>/dev/null || true
          virsh -c qemu:///system undefine "$n" --remove-all-storage 2>&1 || true
        fi
        pause_menu ;;
      7)
        read -rp "VM Name: " n
        read -rp "Snapshot Name [auto]: " sn
        vm_snapshot_create "$n" "$sn" || true
        pause_menu ;;
      8)
        read -rp "VM Name: " n
        read -rp "Snapshot Name: " sn
        if confirm_action "Snapshot '$sn' auf VM '$n' wiederherstellen?"; then vm_snapshot_restore "$n" "$sn" || true; fi
        pause_menu ;;
      9)
        read -rp "VM Name: " n
        virsh -c qemu:///system snapshot-list "$n" 2>&1 || true
        pause_menu ;;
      10) break ;;
      *) warn "Ungültige Auswahl."; sleep 1 ;;
    esac
  done
}

install_kvm(){
  require_native_linux || return 0
  if [[ "$PLATFORM" == "wsl2" ]]; then
    warn "WSL2: KVM wird nicht blind installiert; Nested Virtualization/Kernel-Support zuerst prüfen."
    return 0
  fi
  if ! command_exists apt-get; then
    warn "KVM-Autoinstallation ist für diesen Paketmanager nicht implementiert."
    return 0
  fi
  if ! confirm_action "QEMU/KVM + libvirt installieren?"; then
    warn "KVM-Installation abgebrochen."
    return 0
  fi
  . "$SCRIPT_DIR/lib/core.sh"
  sudo apt-get update -qq 2>/dev/null || true
  sudo apt-get install -y -qq qemu-kvm libvirt-daemon-system libvirt-clients virtinst bridge-utils ovmf cpu-checker 2>/dev/null || true
  sudo systemctl enable --now libvirtd 2>/dev/null || true
  if [[ "$(id -u)" -ne 0 ]]; then
    sudo usermod -aG libvirt,kvm "$(id -un)" 2>/dev/null || true
    warn "Gruppenänderung wird nach neuem Login/Session wirksam."
  fi
  detect_runtime_capabilities
  persist_runtime_state
  [[ "$CAN_KVM" == true ]] && ok "KVM ist nutzbar." || warn "KVM installiert, aber Nutzbarkeit nicht bestätigt."
}
kvm_status(){
  detect_runtime_capabilities
  persist_runtime_state
  echo "=== KVM / VM RUNTIME ==="
  echo "Virtualization CPU : $HOST_VIRTUALIZATION"
  echo "/dev/kvm           : $KVM_DEVICE"
  echo "KVM usable         : $CAN_KVM"
  echo "libvirt            : $CAN_LIBVIRT"
  if command_exists virsh; then
    virsh -c qemu:///system list --all 2>/dev/null || true
  fi
}
create_kvm_vm(){
  require_native_linux || return 0
  detect_runtime_capabilities
  [[ "$CAN_KVM" == true ]] || { warn "KVM nicht verfügbar. BIOS/Nested-Virtualization/Kernel prüfen."; return 1; }
  command_exists virt-install || { warn "virt-install fehlt. Erst KVM installieren."; return 1; }

  local name os ram cpus disk network iso
  read -rp "VM Name [dax-agent-vm]: " name; name="${name:-dax-agent-vm}"
  read -rp "OS [ubuntu/debian]: " os; os="${os:-ubuntu}"
  read -rp "RAM MB [8192]: " ram; ram="${ram:-8192}"
  read -rp "CPU Cores [4]: " cpus; cpus="${cpus:-4}"
  read -rp "Disk GB [80]: " disk; disk="${disk:-80}"
  read -rp "ISO-Pfad: " iso
  read -rp "Network [default]: " network; network="${network:-default}"

  [[ -f "$iso" ]] || { warn "ISO-Datei nicht gefunden. Kein ungefragter ISO-Download."; return 1; }
  if ! [[ "$ram" =~ ^[0-9]+$ && "$cpus" =~ ^[0-9]+$ && "$disk" =~ ^[0-9]+$ ]]; then
    warn "RAM/CPU/Disk müssen positive Ganzzahlen sein."
    return 1
  fi
  confirm_action "VM '$name' jetzt anlegen?" || { warn "VM-Erstellung abgebrochen."; return 0; }

  local diskpath="$VM_DIR/${name}.qcow2"
  [[ -f "$diskpath" ]] || qemu-img create -f qcow2 "$diskpath" "${disk}G"

  virt-install \
    --name "$name" \
    --memory "$ram" \
    --vcpus "$cpus" \
    --disk "path=$diskpath,format=qcow2" \
    --cdrom "$iso" \
    --network "network=$network" \
    --os-variant detect=on,require=off \
    --graphics spice \
    --noautoconsole

  ok "VM '$name' wurde angelegt."
}
vm_snapshot_create(){
  require_native_linux || return 0
  local vm="${1:-}" snap="${2:-}"
  [[ -n "$vm" ]] || { warn "VM Name fehlt."; return 1; }
  [[ -n "$snap" ]] || snap="dax-$(date +%Y%m%d-%H%M%S)"
  virsh -c qemu:///system snapshot-create-as "$vm" "$snap" --description "DAX checkpoint $snap"
}
vm_snapshot_restore(){
  require_native_linux || return 0
  local vm="${1:-}" snap="${2:-}"
  [[ -n "$vm" && -n "$snap" ]] || { warn "VM und Snapshot erforderlich."; return 1; }
  virsh -c qemu:///system snapshot-revert "$vm" "$snap"
}

confirm_action(){
  local prompt="${1:-Fortfahren?}" answer
  read -rp "$prompt [y/N]: " answer
  [[ "$answer" =~ ^[YyJj]$ ]]
}
require_native_linux(){
  if [[ "$PLATFORM" == "termux" || "$PLATFORM" == "proot" ]]; then
    warn "Diese Runtime ist auf $PLATFORM absichtlich deaktiviert."
    warn "Termux/PRoot: Docker/KVM nicht erzwingen; native Linux-oder Remote-Runtime verwenden."
    return 1
  fi
  return 0
}

# =============================================================================
# MAIN
# =============================================================================
detect_hardware
detect_runtime_capabilities
persist_runtime_state
log INFO "=== DAX Control Plane v$VERSION gestartet ($PLATFORM) ==="
main_menu
