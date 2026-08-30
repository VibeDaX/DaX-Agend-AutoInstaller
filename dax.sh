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
RUNTIME_DIR="$SCRIPT_DIR/runtime"
DOCKER_DIR="$SCRIPT_DIR/docker"
DOCKER_SHARED_DIR="$DOCKER_DIR/shared"
DOCKER_HERMES_DIR="$DOCKER_DIR/hermes"
DOCKER_OPENCLAW_DIR="$DOCKER_DIR/openclaw"
VM_DIR="$SCRIPT_DIR/vms"
mkdir -p "$LOG_DIR" "$PID_DIR" "$RUNTIME_DIR" "$DOCKER_DIR" "$DOCKER_SHARED_DIR" "$DOCKER_HERMES_DIR" "$DOCKER_OPENCLAW_DIR" "$VM_DIR"

log(){ printf '[%s] [%s] %s\n' "$(date '+%F %T')" "$1" "$2" | tee -a "$LOG_FILE"; }
info(){ echo -e "${CLR_BLUE}[+]${CLR_RESET} $*"; log INFO "$*"; }
ok(){ echo -e "${CLR_GREEN}[✔]${CLR_RESET} $*"; log OK "$*"; }
warn(){ echo -e "${CLR_GOLD}[!]${CLR_RESET} $*"; log WARN "$*"; }
die(){ echo -e "${CLR_RED}[✖]${CLR_RESET} $*" >&2; log ERROR "$*"; exit 1; }
command_exists(){ command -v "$1" >/dev/null 2>&1; }

# =============================================================================
# PLATFORM / CAPABILITY DETECTION
# =============================================================================
IS_TERMUX=false; IS_PROOT=false; IS_WSL=false; PLATFORM="linux"; OS_NAME="Linux"
[[ -n "${TERMUX_VERSION:-}" || -d /data/data/com.termux/files/usr ]] && IS_TERMUX=true
([[ -f /.guest ]] || grep -qa proot /proc/1/cmdline 2>/dev/null) && IS_PROOT=true || true
([[ -n "${WSL_DISTRO_NAME:-}" ]] || grep -qi microsoft /proc/version 2>/dev/null) && IS_WSL=true || true
if [[ "$IS_TERMUX" == true && "$IS_PROOT" == false ]]; then PLATFORM="termux"; OS_NAME="Termux"
elif [[ "$IS_PROOT" == true ]]; then PLATFORM="proot"; OS_NAME="PRoot/Linux"
elif [[ "$IS_WSL" == true ]]; then PLATFORM="wsl2"; OS_NAME="WSL2"
fi

SUDO=""; command_exists sudo && SUDO="sudo"

GPU_TYPE="cpu"; GPU_NAME="CPU"; TORCH_INDEX=""; COMFYUI_MODE="cpu"
CAN_LOCAL_OLLAMA=true; CAN_COMFYUI_ACCEL=true
CAN_DOCKER=false; DOCKER_DAEMON=false; DOCKER_ROOTLESS=false
CAN_KVM=false; KVM_DEVICE=false; CAN_LIBVIRT=false
HOST_VIRTUALIZATION="unknown"

if [[ "$PLATFORM" == termux || "$PLATFORM" == proot ]]; then
  CAN_LOCAL_OLLAMA=false
  CAN_COMFYUI_ACCEL=false
fi

detect_runtime_capabilities(){
  CAN_DOCKER=false; DOCKER_DAEMON=false; DOCKER_ROOTLESS=false
  CAN_KVM=false; KVM_DEVICE=false; CAN_LIBVIRT=false

  if command_exists docker; then
    CAN_DOCKER=true
    if docker info >/dev/null 2>&1; then DOCKER_DAEMON=true; fi
    if docker info 2>/dev/null | grep -qi 'rootless'; then DOCKER_ROOTLESS=true; fi
  fi

  [[ -e /dev/kvm ]] && KVM_DEVICE=true
  if command_exists kvm-ok && kvm-ok >/dev/null 2>&1; then CAN_KVM=true
  elif [[ "$KVM_DEVICE" == true && -r /dev/kvm && -w /dev/kvm ]]; then CAN_KVM=true; fi
  command_exists virsh && virsh -c qemu:///system uri >/dev/null 2>&1 && CAN_LIBVIRT=true || true

  if [[ -r /proc/cpuinfo ]]; then
    grep -Eq '(^|[[:space:]])(vmx|svm)([[:space:]]|$)' /proc/cpuinfo && HOST_VIRTUALIZATION="VT-x/AMD-V detected" || HOST_VIRTUALIZATION="not detected"
  fi

  [[ "$PLATFORM" == termux || "$PLATFORM" == proot ]] && CAN_DOCKER=false && DOCKER_DAEMON=false && CAN_KVM=false && KVM_DEVICE=false && CAN_LIBVIRT=false
}

detect_hardware(){
  GPU_TYPE="cpu"; GPU_NAME="CPU"; TORCH_INDEX=""; COMFYUI_MODE="cpu"
  if command_exists nvidia-smi && nvidia-smi -L >/dev/null 2>&1; then
    GPU_TYPE="nvidia"; GPU_NAME="$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -n1 || echo NVIDIA)"
    TORCH_INDEX="https://download.pytorch.org/whl/cu130"; COMFYUI_MODE="cuda"
  elif command_exists rocminfo || [[ -d /opt/rocm ]]; then
    GPU_TYPE="amd"; GPU_NAME="AMD ROCm"; TORCH_INDEX="https://download.pytorch.org/whl/rocm7.2"; COMFYUI_MODE="rocm"
  elif command_exists lspci && lspci 2>/dev/null | grep -qi 'Intel.*Arc'; then
    GPU_TYPE="intel"; GPU_NAME="Intel Arc"; TORCH_INDEX="https://download.pytorch.org/whl/xpu"; COMFYUI_MODE="xpu"
  elif [[ "$(uname -s)" == Darwin && "$(uname -m)" == arm64 ]]; then
    GPU_TYPE="apple"; GPU_NAME="Apple Silicon"; COMFYUI_MODE="mps"
  fi
  [[ "$CAN_COMFYUI_ACCEL" == false ]] && GPU_TYPE="cpu" && GPU_NAME="CPU (Termux/PRoot)" && COMFYUI_MODE="cpu"
}

detect_hardware; detect_runtime_capabilities

show_preflight(){
  detect_hardware; detect_runtime_capabilities
  echo -e "${CLR_BLUE}=== DAX PREFLIGHT / CAPABILITY MATRIX ===${CLR_RESET}"
  echo "Platform : $PLATFORM ($OS_NAME)"
  echo "User     : $(id -un) (uid=$(id -u))"
  echo "Root     : $([[ $(id -u) -eq 0 ]] && echo YES || echo NO)"
  echo "GPU      : $GPU_TYPE — $GPU_NAME"
  echo "ComfyUI  : $COMFYUI_MODE"
  echo "Ollama local: $CAN_LOCAL_OLLAMA"
  echo "Docker     : $CAN_DOCKER (Daemon: $DOCKER_DAEMON, Rootless: $DOCKER_ROOTLESS)"
  echo "KVM        : $CAN_KVM (/dev/kvm: $KVM_DEVICE)"
  echo "libvirt    : $CAN_LIBVIRT"
  echo "Virt CPU   : $HOST_VIRTUALIZATION"
  echo "Python   : $(python3 --version 2>/dev/null || echo missing)"
  echo "Node     : $(node --version 2>/dev/null || echo missing)"
  [[ "$PLATFORM" == termux || "$PLATFORM" == proot ]] && echo "Hinweis   : Docker/KVM auf Termux/PRoot NICHT versuchen; Remote/native Linux verwenden."
  [[ "$PLATFORM" == wsl2 ]] && echo "Hinweis   : Docker über Docker Desktop/Engine; KVM nur bei unterstützter Nested-Virtualization."
  echo
}

termux_handoff(){
  [[ "$PLATFORM" == termux ]] || return 0
  warn "Natives Termux: keine Blindinstallation von Ollama/ComfyUI GPU."
  command_exists pkg || die "Termux pkg fehlt."
  pkg update -y; pkg install -y proot-distro
  if ! proot-distro list 2>/dev/null | grep -Eq 'ubuntu.*installed'; then proot-distro install ubuntu; fi
  local base; base="$(basename "$0")"
  proot-distro login ubuntu -- bash -lc "mkdir -p ~/dax-command-center && cp '$SCRIPT_DIR/$base' ~/dax-command-center/$base && cd ~/dax-command-center && chmod +x '$base' && exec ./'$base'"
  exit $?
}

apt_install(){ [[ -n "$SUDO" || $(id -u) -eq 0 ]] || die "sudo/root für apt-Pakete erforderlich."; $SUDO apt-get update; $SUDO apt-get install -y "$@"; }
install_system_dependencies(){
  info "Installiere Systemabhängigkeiten (nur dieser Schritt nutzt sudo)."
  if command_exists apt-get; then apt_install git curl unzip zip build-essential python3 python3-venv python3-pip nodejs npm ffmpeg ca-certificates procps pciutils
  elif command_exists pkg; then pkg update -y && pkg install -y git curl unzip zip python nodejs ffmpeg procps
  else die "Kein unterstützter Paketmanager."; fi
}

ensure_venv(){ local v="$1" l="${2:-Python VENV}"; [[ ! -x "$v/bin/python" ]] && info "Erstelle $l: $v" && rm -rf -- "$v" && python3 -m venv "$v" || die "VENV fehlgeschlagen"; "$v/bin/python" -m pip install --upgrade pip setuptools wheel >>"$LOG_FILE" 2>&1 || warn "pip upgrade fehlgeschlagen"; }
pip_install(){ local v="$1"; shift; ensure_venv "$v"; "$v/bin/python" -m pip install "$@" 2>&1 | tee -a "$LOG_FILE"; }
get_ram_mb(){ awk '/MemTotal:/ {print int($2/1024); exit}' /proc/meminfo 2>/dev/null || echo 0; }
ram_recommendation(){ local mb; mb="$(get_ram_mb)"; local gb=$((mb/1024)); echo "RAM: ${gb} GB"; ((mb<8192)) && echo "Empfehlung: kleine Modelle (1B–3B)" || ((mb<16384)) && echo "Empfehlung: 7B–8B" || ((mb<32768)) && echo "Empfehlung: bis ~14B" || echo "Empfehlung: größere Modelle abhängig von GPU/RAM"; }

# =============================================================================
# OLLAMA / COMFYUI / SERVICES
# =============================================================================
install_ollama(){
  if [[ "$CAN_LOCAL_OLLAMA" != true ]]; then
    warn "Lokale Ollama-Autoinstallation auf $PLATFORM deaktiviert. Nutze Remote Ollama Host."
    configure_ollama_remote; return 0
  fi
  if command_exists ollama; then ok "Ollama bereits installiert."; else command_exists curl || die "curl fehlt."; curl -fsSL https://ollama.com/install.sh | sh; fi
  ram_recommendation
  if command_exists ollama && ! pgrep -x ollama >/dev/null 2>&1; then nohup ollama serve >>"$LOG_DIR/ollama.log" 2>&1 & echo $! > "$PID_DIR/ollama.pid"; sleep 2; fi
}
configure_ollama_remote(){ read -rp "Remote Ollama URL [http://127.0.0.1:11434]: " host; host="${host:-http://127.0.0.1:11434}"; printf 'OLLAMA_HOST="%s"\n' "$host" > "$STATE_DIR/ollama.env"; ok "Remote Ollama gespeichert: $host"; }
pull_ollama_model(){ command_exists ollama || { warn "Lokales Ollama fehlt; Remote Pull nicht implementiert."; return; }; ram_recommendation; read -rp "Modell [qwen2.5:7b]: " m; ollama pull "${m:-qwen2.5:7b}" | tee -a "$LOG_FILE"; }

install_torch_for_platform(){
  detect_hardware; ensure_venv "$VENV_COMFYUI" "ComfyUI"
  info "PyTorch Backend: $GPU_TYPE ($COMFYUI_MODE)"
  "$VENV_COMFYUI/bin/python" -m pip uninstall -y torch torchvision torchaudio >>"$LOG_FILE" 2>&1 || true
  case "$GPU_TYPE" in
    nvidia) "$VENV_COMFYUI/bin/python" -m pip install torch torchvision torchaudio --extra-index-url "$TORCH_INDEX" | tee -a "$LOG_FILE" ;;
    amd|intel) "$VENV_COMFYUI/bin/python" -m pip install torch torchvision torchaudio --index-url "$TORCH_INDEX" | tee -a "$LOG_FILE" ;;
    apple) "$VENV_COMFYUI/bin/python" -m pip install torch torchvision torchaudio | tee -a "$LOG_FILE" ;;
    *) "$VENV_COMFYUI/bin/python" -m pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu | tee -a "$LOG_FILE" ;;
  esac
}
verify_torch(){
  ensure_venv "$VENV_COMFYUI" "ComfyUI"
  "$VENV_COMFYUI/bin/python" - <<'PY'
import platform
try:
 import torch
 print('Torch:', torch.__version__)
 print('CUDA available:', torch.cuda.is_available())
 print('CUDA runtime:', torch.version.cuda)
 print('MPS available:', getattr(torch.backends, 'mps', None) and torch.backends.mps.is_available())
 print('XPU available:', hasattr(torch, 'xpu') and torch.xpu.is_available())
 print('Platform:', platform.platform())
except Exception as e:
 print('Torch verification failed:', e); raise
PY
}
install_comfyui(){
  detect_hardware
  [[ "$PLATFORM" == proot ]] && warn "PRoot: ComfyUI wird nur im CPU-Safe-Mode installiert; GPU-Passthrough wird nicht angenommen."
  [[ ! -d "$COMFYUI_DIR/.git" ]] && git clone https://github.com/Comfy-Org/ComfyUI.git "$COMFYUI_DIR" || git -C "$COMFYUI_DIR" pull --ff-only || warn "ComfyUI update fehlgeschlagen"
  install_torch_for_platform
  pip_install "$VENV_COMFYUI" -r "$COMFYUI_DIR/requirements.txt"
  verify_torch
  ok "ComfyUI eingerichtet ($COMFYUI_MODE)."
}
start_comfyui(){
  [[ -f "$COMFYUI_DIR/main.py" ]] || { warn "ComfyUI zuerst installieren."; return; }
  verify_torch || die "Torch-Backend ungültig; Start abgebrochen."
  local args=(--listen 127.0.0.1 --port 8188)
  [[ "$COMFYUI_MODE" == cpu ]] && args+=(--cpu)
  nohup "$VENV_COMFYUI/bin/python" "$COMFYUI_DIR/main.py" "${args[@]}" >>"$LOG_DIR/comfyui.log" 2>&1 & echo $! > "$PID_DIR/comfyui.pid"
  ok "ComfyUI gestartet: http://127.0.0.1:8188 ($COMFYUI_MODE)"
}
install_openwebui(){ ensure_venv "$VENV_OPENWEBUI" "Open WebUI"; pip_install "$VENV_OPENWEBUI" open-webui; }
start_openwebui(){ [[ -x "$VENV_OPENWEBUI/bin/open-webui" ]] || { warn "Open WebUI zuerst installieren."; return; }; nohup "$VENV_OPENWEBUI/bin/open-webui" serve --host 127.0.0.1 --port 8080 >>"$LOG_DIR/openwebui.log" 2>&1 & echo $! > "$PID_DIR/openwebui.pid"; }
install_nodered(){ command_exists npm || { warn "npm fehlt."; return 1; }; npm install -g node-red | tee -a "$LOG_FILE"; }
start_nodered(){ command_exists node-red || { warn "Node-RED fehlt."; return; }; nohup node-red >>"$LOG_DIR/nodered.log" 2>&1 & echo $! > "$PID_DIR/nodered.pid"; }
install_whisper(){ ensure_venv "$VENV_WHISPER" "Faster-Whisper"; pip_install "$VENV_WHISPER" faster-whisper; }

# =============================================================================
# STATE / CAPABILITIES
# =============================================================================
STATE_FILE="$STATE_DIR/state.json"
CAP_FILE="$STATE_DIR/capabilities.env"
AGENT_DIR="$SCRIPT_DIR/agents"
DATA_DIR="$SCRIPT_DIR/data"
TEMPLATE_DIR="$SCRIPT_DIR/templates"
mkdir -p "$AGENT_DIR" "$DATA_DIR" "$TEMPLATE_DIR"

write_state(){
  cat > "$STATE_FILE" <<EOF
{
  "version": "$VERSION",
  "platform": "$PLATFORM",
  "os_name": "$OS_NAME",
  "gpu_type": "$GPU_TYPE",
  "gpu_name": "$GPU_NAME",
  "comfyui_mode": "$COMFYUI_MODE",
  "docker_available": $CAN_DOCKER,
  "docker_daemon": $DOCKER_DAEMON,
  "docker_rootless": $DOCKER_ROOTLESS,
  "kvm_available": $CAN_KVM,
  "kvm_device": $KVM_DEVICE,
  "libvirt_available": $CAN_LIBVIRT,
  "virtualization": "$HOST_VIRTUALIZATION"
}
EOF
}
write_capabilities(){
  cat > "$CAP_FILE" <<EOF
PLATFORM="$PLATFORM"
OS_NAME="$OS_NAME"
GPU_TYPE="$GPU_TYPE"
GPU_NAME="$GPU_NAME"
COMFYUI_MODE="$COMFYUI_MODE"
CAN_DOCKER="$CAN_DOCKER"
DOCKER_DAEMON="$DOCKER_DAEMON"
DOCKER_ROOTLESS="$DOCKER_ROOTLESS"
CAN_KVM="$CAN_KVM"
KVM_DEVICE="$KVM_DEVICE"
CAN_LIBVIRT="$CAN_LIBVIRT"
HOST_VIRTUALIZATION="$HOST_VIRTUALIZATION"
EOF
}
persist_runtime_state(){ detect_runtime_capabilities; write_capabilities; write_state; }
require_native_linux(){
  [[ "$PLATFORM" == termux || "$PLATFORM" == proot ]] && { warn "Diese Runtime ist auf $PLATFORM absichtlich deaktiviert."; return 1; }
  return 0
}
confirm_action(){ local prompt="${1:-Fortfahren?}" answer; read -rp "$prompt [y/N]: " answer; [[ "$answer" =~ ^[YyJj]$ ]]; }

# =============================================================================
# POLICY ENGINE (v1)
# =============================================================================
POLICY_FILE="$STATE_DIR/policy.yaml"

policy_allow_runtime_for_platform(){
  local runtime="$1"
  # Erst: explizites deny erzwingen
  case "$PLATFORM" in
    linux) ;;
    wsl2) [[ " $runtime " =~ " kvm " ]] && { return 1; } ;;
    termux) [[ " $runtime " =~ " docker " || " $runtime " =~ " kvm " ]] && { return 1; } ;;
    proot) [[ " $runtime " =~ " docker " || " $runtime " =~ " kvm " ]] && { return 1; } ;;
  esac
  # Dann: allow-Check
  case "$PLATFORM" in
    linux) [[ " $runtime " =~ " native " || " $runtime " =~ " docker " || " $runtime " =~ " kvm " || " $runtime " =~ " remote " ]] && return 0 ;;
    wsl2) [[ " $runtime " =~ " native " || " $runtime " =~ " docker " ]] && return 0 ;;
    termux) [[ " $runtime " =~ " native " || " $runtime " =~ " remote " ]] && return 0 ;;
    proot) [[ " $runtime " =~ " native " || " $runtime " =~ " remote " ]] && return 0 ;;
  esac
  return 1
}

policy_is_platform_allowed(){
  local platform="$1" runtime="$2"
  [[ "$platform" == "$PLATFORM" ]] || return 1
  policy_allow_runtime_for_platform "$runtime"
}

policy_allow_runtime_for_agent(){
  local agent="$1" runtime="$2"
  local allowed=""; default_rt=""
  case "$agent" in
    hermes) allowed="native docker kvm remote"; default_rt="docker" ;;
    openclaw) allowed="docker kvm"; default_rt="docker" ;;
    *) warn "Unbekannter Agent: $agent"; return 1 ;;
  esac
  [[ " $allowed " =~ " $runtime " ]] && return 0
  [[ "$runtime" == "$default_rt" ]] && return 0
  return 1
}

# =============================================================================
# VOLUME MANAGER (v1)
# =============================================================================
VOLUMES_FILE="$STATE_DIR/volumes.yaml"

volume_ensure(){
  local vol="$1"
  [[ -f "$VOLUMES_FILE" ]] || { warn "Volumes-Datei fehlt: $VOLUMES_FILE"; return 1; }
  case "$vol" in
    hermes_data)
      local host_path="/var/lib/dax/hermes"
      info "Volume hermes_data: Host-Pfad $host_path (docker_bind)"
      $SUDO mkdir -p "$host_path" 2>/dev/null || true
      ok "Volume hermes_data bereit."
      ;;
    openclaw_data)
      local host_path="/var/lib/dax/openclaw"
      info "Volume openclaw_data: Host-Pfad $host_path (docker_bind)"
      $SUDO mkdir -p "$host_path" 2>/dev/null || true
      ok "Volume openclaw_data bereit."
      ;;
    ollama_data)
      local host_path="/var/lib/dax/ollama"
      info "Volume ollama_data: Host-Pfad $host_path (docker_bind)"
      $SUDO mkdir -p "$host_path" 2>/dev/null || true
      ok "Volume ollama_data bereit."
      ;;
    *) warn "Unbekanntes Volume: $vol"; return 1 ;;
  esac
}

volume_mount_docker(){
  local vol="$1"
  volume_ensure "$vol"
  local host_path
  case "$vol" in
    hermes_data) host_path="/var/lib/dax/hermes" ;;
    openclaw_data) host_path="/var/lib/dax/openclaw" ;;
    ollama_data) host_path="/var/lib/dax/ollama" ;;
    *) warn "Unbekanntes Volume: $vol"; return 1 ;;
  esac
  echo "-v ${host_path}:/opt/${vol}:rw"
}

# =============================================================================
# SECRETS MANAGER (v2 — mit AES-256-Verschlüsselung & Context-Injektion)
# =============================================================================
SECRETS_DIR="$STATE_DIR/secrets"
SECRETS_FILE="$SECRETS_DIR/secrets.json"
GLOBAL_SECRETS="$SECRETS_FILE"
AGENT_SECRETS_DIR="$SECRETS_DIR/agents"
REMOTE_SECRETS_DIR="$SECRETS_DIR/remote"
MASTER_KEY_FILE="$SECRETS_DIR/master.key"

ensure_master_key(){
  mkdir -p "$SECRETS_DIR"
  if [[ ! -f "$MASTER_KEY_FILE" || ! -s "$MASTER_KEY_FILE" ]]; then
    if command_exists openssl; then
      openssl rand -hex 32 > "$MASTER_KEY_FILE"
      chmod 600 "$MASTER_KEY_FILE"
      info "Neuer Master-Key generiert: $MASTER_KEY_FILE"
    else
      echo "dax-master-key-fallback-$(hostname 2>/dev/null || echo local)" > "$MASTER_KEY_FILE"
      chmod 600 "$MASTER_KEY_FILE"
    fi
  fi
}

secret_encrypt_value(){
  local plaintext="$1"
  ensure_master_key
  if [[ -f "$MASTER_KEY_FILE" ]] && command_exists openssl; then
    local enc
    enc="$(echo -n "$plaintext" | openssl enc -aes-256-cbc -pbkdf2 -salt -pass "file:$MASTER_KEY_FILE" -base64 -A 2>/dev/null)" || enc=""
    if [[ -n "$enc" ]]; then
      echo "enc:$enc"
      return 0
    fi
  fi
  echo "$plaintext"
}

secret_decrypt_value(){
  local raw="$1"
  if [[ "$raw" =~ ^enc:(.+) ]]; then
    local ciphertext="${BASH_REMATCH[1]}"
    ensure_master_key
    if [[ -f "$MASTER_KEY_FILE" ]] && command_exists openssl; then
      local dec
      dec="$(echo -n "$ciphertext" | openssl enc -d -aes-256-cbc -pbkdf2 -pass "file:$MASTER_KEY_FILE" -base64 -A 2>/dev/null)" || dec=""
      if [[ -n "$dec" ]]; then
        echo "$dec"
        return 0
      fi
    fi
  fi
  echo "$raw"
}

secret_get(){
  local key="$1" scope="${2:-global}"
  local src="$GLOBAL_SECRETS"
  case "$scope" in
    agent)
      local agent="${3:-}"
      [[ -n "$agent" ]] || { warn "Agent-Name erforderlich für scope=agent"; return 1; }
      src="$AGENT_SECRETS_DIR/${agent}.json"
      ;;
    remote)
      local host="${3:-}"
      [[ -n "$host" ]] || { warn "Host-Name erforderlich für scope=remote"; return 1; }
      src="$REMOTE_SECRETS_DIR/${host}.json"
      ;;
  esac
  [[ -f "$src" ]] || { warn "Secrets-Datei fehlt: $src"; return 1; }
  local raw_val
  raw_val="$(python3 -c "
import json
with open('$src','r') as f: data=json.load(f)
keys=data.get('secrets', data.get('keys', {}))
print(keys.get('$key',''))
" 2>/dev/null)"
  secret_decrypt_value "$raw_val"
}

secret_get_envfile(){
  local scope="${1:-global}" identifier="${2:-}"
  local src="$GLOBAL_SECRETS"
  case "$scope" in
    agent) [[ -n "$identifier" ]] && src="$AGENT_SECRETS_DIR/${identifier}.json" || return 1 ;;
    remote) [[ -n "$identifier" ]] && src="$REMOTE_SECRETS_DIR/${identifier}.json" || return 1 ;;
  esac
  [[ -f "$src" ]] || { warn "Secrets-Datei fehlt: $src"; return 1; }

  local raw_pairs
  raw_pairs="$(python3 -c "
import json
with open('$src','r') as f: data=json.load(f)
secrets=data.get('secrets', data.get('keys', {}))
for k,v in secrets.items():
    if v and not str(v).startswith('\${') and not str(v).startswith('$'):
        print(f'{k}:::{v}')
" 2>/dev/null)" || return 1

  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    local k="${line%%:::*}"
    local raw_v="${line#*:::}"
    local dec_v
    dec_v="$(secret_decrypt_value "$raw_v")"
    printf '%s=%s\n' "$k" "$dec_v"
  done <<< "$raw_pairs"
}

secret_set(){
  local key="$1" value="$2" scope="${3:-global}" identifier="${4:-}"
  local src="$GLOBAL_SECRETS"
  case "$scope" in
    agent) [[ -n "$identifier" ]] && src="$AGENT_SECRETS_DIR/${identifier}.json" || return 1 ;;
    remote) [[ -n "$identifier" ]] && src="$REMOTE_SECRETS_DIR/${identifier}.json" || return 1 ;;
  esac
  [[ -d "$(dirname "$src")" ]] || mkdir -p "$(dirname "$src")"

  local enc_value
  enc_value="$(secret_encrypt_value "$value")"

  if [[ -f "$src" ]]; then
    python3 -c "
import json
with open('$src','r') as f: data=json.load(f)
secrets=data.get('secrets', data.get('keys', {}))
secrets['$key']='$enc_value'
if 'secrets' in data: data['secrets']=secrets
else: data['keys']=secrets
with open('$src','w') as f: json.dump(data,f,indent=2)
" 2>/dev/null || warn "Secrets-Aktualisierung fehlgeschlagen"
  else
    python3 -c "
import json
data = {'version': 1, 'secrets': {'$key': '$enc_value'}}
with open('$src','w') as f: json.dump(data,f,indent=2)
" 2>/dev/null
  fi
  chmod 600 "$src" 2>/dev/null || true
  ok "Secret $key verschlüsselt gespeichert (scope=$scope, identifier=${identifier:-global})."
}

secret_inject_docker(){
  local scope="${1:-global}" identifier="${2:-}"
  local envfile="/tmp/dax-secrets-${identifier:-global}.env"
  secret_get_envfile "$scope" "$identifier" > "$envfile" 2>/dev/null || { warn "Keine Secrets für Docker-Injektion gefunden (scope=$scope, identifier=$identifier)."; return 1; }
  chmod 600 "$envfile" 2>/dev/null || true
  echo "$envfile"
}

secret_inject_remote_ssh_key(){
  local host="$1"
  local key_path
  key_path="$(secret_get SSH_KEY remote "$host")"
  [[ -n "$key_path" && -f "$key_path" ]] && echo "$key_path" || { warn "SSH-Key für $host nicht gefunden."; return 1; }
}

# =============================================================================
# AGENT ADAPTER SYSTEM (v1)
# =============================================================================
agent_dispatch(){
  local agent="$1" action="$2" runtime="${3:-}"
  [[ -f "$AGENT_DIR/$agent/manifest.yaml" ]] || { warn "Agent manifest fehlt: $agent"; return 1; }
  local default_rt
  default_rt="$(grep 'default_runtime:' "$AGENT_DIR/$agent/manifest.yaml" | awk '{print $2}')"
  runtime="${runtime:-$default_rt}"

  # Policy-Check: Plattform-Ebene vor Agent-Ebene
  policy_allow_runtime_for_platform "$runtime" || die "Policy verbietet Runtime $runtime auf Plattform $PLATFORM"
  policy_allow_runtime_for_agent "$agent" "$runtime" || die "Policy verbietet Runtime $runtime für Agent $agent"

  local adapter="$AGENT_DIR/$agent/adapters/${runtime}.sh"
  [[ -f "$adapter" ]] || { warn "Adapter fehlt: $adapter"; return 1; }
  source "$adapter"
  case "$action" in
    install) adapter_install ;;
    start) adapter_start ;;
    stop) adapter_stop ;;
    status) adapter_status ;;
    logs) adapter_logs ;;
    health) adapter_health ;;
    uninstall) adapter_uninstall ;;
    *) warn "Unbekannte Aktion: $action"; return 1 ;;
  esac
}

# =============================================================================
# REMOTE RUNTIME (v1)
# =============================================================================
REMOTE_FILE="$STATE_DIR/remote_hosts.yaml"

remote_exec(){
  local host_id="$1" cmd="$2"
  shift 2
  [[ -f "$REMOTE_FILE" ]] || { warn "Remote-Hosts-Datei fehlt: $REMOTE_FILE"; return 1; }
  local host user port
  host="$(grep -A5 "  $host_id:" "$REMOTE_FILE" | grep 'host:' | awk '{print $2}' | tr -d '"')"
  user="$(grep -A5 "  $host_id:" "$REMOTE_FILE" | grep 'user:' | awk '{print $2}' | tr -d '"')"
  port="$(grep -A5 "  $host_id:" "$REMOTE_FILE" | grep 'port:' | awk '{print $2}')"
  [[ -n "$host" ]] || { warn "Remote-Host nicht gefunden: $host_id"; return 1; }
  local ssh_key=""
  ssh_key="$(secret_inject_remote_ssh_key "$host_id")" || ssh_key=""
  info "Remote-Exec auf $host_id ($user@$host:$port): $cmd"
  if [[ -n "$ssh_key" ]]; then
    ssh -i "$ssh_key" -p "${port:-22}" -o StrictHostKeyChecking=no "${user}@${host}" "$cmd" || die "Remote-Exec fehlgeschlagen"
  else
    ssh -p "${port:-22}" "${user}@${host}" "$cmd" || die "Remote-Exec fehlgeschlagen"
  fi
}

# =============================================================================
# TEMPLATE ENGINE (v1)
# =============================================================================
template_apply_vm(){
  local tmpl="$1"
  [[ -f "$TEMPLATE_DIR/vm/$tmpl" ]] || { warn "Template fehlt: $TEMPLATE_DIR/vm/$tmpl"; return 1; }
  info "Wende VM-Template an: $tmpl"
}

template_apply_agent_stack(){
  local tmpl="$1"
  [[ -f "$TEMPLATE_DIR/agents/$tmpl" ]] || { warn "Template fehlt: $TEMPLATE_DIR/agents/$tmpl"; return 1; }
  info "Wende Agent-Stack-Template an: $tmpl"
}

template_apply_compose(){
  local tmpl="$1"
  [[ -f "$TEMPLATE_DIR/compose/$tmpl" ]] || { warn "Template fehlt: $TEMPLATE_DIR/compose/$tmpl"; return 1; }
  cp "$TEMPLATE_DIR/compose/$tmpl" "$DOCKER_DIR/compose.yml"
  ok "Compose-Template angewendet: $tmpl"
}

template_apply_remote(){
  local tmpl="$1"
  [[ -f "$TEMPLATE_DIR/remote/$tmpl" ]] || { warn "Template fehlt: $TEMPLATE_DIR/remote/$tmpl"; return 1; }
  info "Wende Remote-Template an: $tmpl"
}

# =============================================================================
# WATCHDOG (v2 — mit Auto-Recovery & Logging)
# =============================================================================
WATCHDOG_FILE="$STATE_DIR/watchdog.json"

watchdog_log(){
  printf '[%s] [%s] %s\n' "$(date '+%F %T')" "$1" "$2" | tee -a "$WATCHDOG_LOG" >> "$LOG_FILE"
}

watchdog_tick(){
  local service="$1" status="$2"
  if [[ -f "$WATCHDOG_FILE" ]]; then
    python3 -c "
import json
with open('$WATCHDOG_FILE','r') as f: data=json.load(f)
if '$service' in data:
    data['$service']['last_status']='$status'
    if '$status' == 'HEALTHY':
        data['$service']['attempts']=0
    else:
        data['$service']['attempts']=data['$service'].get('attempts', 0) + 1
else:
    data['$service']={'attempts': 0 if '$status' == 'HEALTHY' else 1, 'last_status':'$status'}
with open('$WATCHDOG_FILE','w') as f: json.dump(data,f,indent=2)
" 2>/dev/null || true
  fi
}

watchdog_recover(){
  local service="$1"
  watchdog_log "RECOVERY" "Starte automatische Wiederherstellung für Dienst: $service"
  case "$service" in
    ollama)
      if [[ "$CAN_LOCAL_OLLAMA" == true ]]; then
        pkill -x ollama 2>/dev/null || true
        sleep 1
        nohup ollama serve >>"$LOG_DIR/ollama.log" 2>&1 &
        echo $! > "$PID_DIR/ollama.pid"
        watchdog_log "RECOVERY" "Ollama wurde neu gestartet."
      fi
      ;;
    comfyui)
      if [[ -f "$COMFYUI_DIR/main.py" ]]; then
        local pid; pid="$(cat "$PID_DIR/comfyui.pid" 2>/dev/null || true)"
        [[ -n "$pid" ]] && kill -9 "$pid" 2>/dev/null || true
        start_comfyui >>"$LOG_FILE" 2>&1 || true
        watchdog_log "RECOVERY" "ComfyUI wurde neu gestartet."
      fi
      ;;
    docker)
      if [[ "$DOCKER_DAEMON" == true ]]; then
        docker restart dax-hermes dax-openclaw 2>/dev/null || true
        watchdog_log "RECOVERY" "DAX Docker-Container wurden neu gestartet."
      fi
      ;;
    agents.hermes)
      agent_dispatch hermes stop 2>/dev/null || true
      sleep 1
      agent_dispatch hermes start 2>/dev/null || true
      watchdog_log "RECOVERY" "Hermes Agent wurde neu gestartet."
      ;;
    agents.openclaw)
      agent_dispatch openclaw stop 2>/dev/null || true
      sleep 1
      agent_dispatch openclaw start 2>/dev/null || true
      watchdog_log "RECOVERY" "OpenClaw Agent wurde neu gestartet."
      ;;
    *)
      watchdog_log "WARN" "Keine Recovery-Aktion für $service definiert."
      ;;
  esac
}

start_watchdog(){
  local pid_file="$PID_DIR/watchdog.pid"
  if [[ -f "$pid_file" ]] && kill -0 "$(cat "$pid_file")" 2>/dev/null; then
    warn "Watchdog läuft bereits (PID: $(cat "$pid_file"))."
    return 0
  fi
  (
    while true; do
      sleep 60
      # Health-Checks ausführen
      if command_exists docker && docker info >/dev/null 2>&1; then
        watchdog_tick "docker" "HEALTHY"
      else
        watchdog_tick "docker" "UNHEALTHY"
      fi

      if pgrep -x ollama >/dev/null 2>&1; then
        watchdog_tick "ollama" "HEALTHY"
      fi

      if pgrep -f "ComfyUI/main.py" >/dev/null 2>&1; then
        watchdog_tick "comfyui" "HEALTHY"
      fi

      if [[ -f "$WATCHDOG_FILE" ]]; then
        local to_recover
        to_recover="$(python3 -c "
import json
with open('$WATCHDOG_FILE','r') as f: data=json.load(f)
for svc, state in data.items():
    if isinstance(state, dict):
        if state.get('attempts', 0) >= 3 and state.get('last_status') != 'HEALTHY':
            print(svc)
" 2>/dev/null)"

        for s in $to_recover; do
          watchdog_recover "$s"
          # Reset attempts nach Recovery-Versuch
          python3 -c "
import json
with open('$WATCHDOG_FILE','r') as f: data=json.load(f)
if '$s' in data and isinstance(data['$s'], dict):
    data['$s']['attempts'] = 0
with open('$WATCHDOG_FILE','w') as f: json.dump(data,f,indent=2)
" 2>/dev/null || true
        done
      fi
    done
  ) &
  local pid=$!
  echo "$pid" > "$pid_file"
  watchdog_log "INFO" "Watchdog Daemon gestartet (PID: $pid, Intervall: 60s)."
  ok "Watchdog gestartet (PID: $pid, Intervall: 60s). Log: $WATCHDOG_LOG"
}

stop_watchdog(){
  local pid_file="$PID_DIR/watchdog.pid"
  if [[ -f "$pid_file" ]]; then
    local pid="$(cat "$pid_file")"
    kill "$pid" 2>/dev/null || true
    rm -f "$pid_file"
    ok "Watchdog gestoppt (PID: $pid)."
  else
    warn "Kein laufender Watchdog gefunden."
  fi
}

watchdog_status(){
  local pid_file="$PID_DIR/watchdog.pid"
  if [[ -f "$pid_file" ]] && kill -0 "$(cat "$pid_file")" 2>/dev/null; then
    echo "Watchdog: RUNNING (PID: $(cat "$pid_file"))"
  else
    echo "Watchdog: STOPPED"
  fi
  [[ -f "$WATCHDOG_FILE" ]] && cat "$WATCHDOG_FILE" || echo "Kein Watchdog-State gefunden."
}

# =============================================================================
# DOCKER RUNTIME
# =============================================================================
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

install_docker(){
  require_native_linux || return 0
  detect_runtime_capabilities
  [[ "$DOCKER_DAEMON" == true ]] && ok "Docker ist installiert und der Daemon erreichbar." && return 0
  if ! confirm_action "Docker installieren?"; then warn "Docker-Installation abgebrochen."; return 0; fi
  if command_exists apt-get; then
    apt_install docker.io docker-compose-plugin
    $SUDO systemctl enable --now docker 2>/dev/null || true
  else die "Docker-Autoinstallation ist für diesen Paketmanager nicht implementiert."; fi
  detect_runtime_capabilities; persist_runtime_state
  [[ "$DOCKER_DAEMON" == true ]] && ok "Docker Runtime bereit." || warn "Docker installiert, aber Daemon noch nicht erreichbar."
}

docker_status(){
  detect_runtime_capabilities; persist_runtime_state
  echo "=== DOCKER RUNTIME ==="
  echo "Docker binary : $(docker --version 2>/dev/null || echo missing)"
  echo "Daemon        : $DOCKER_DAEMON"
  echo "Rootless      : $DOCKER_ROOTLESS"
  [[ "$DOCKER_DAEMON" == true ]] && docker info --format 'Server: {{.ServerVersion}} | Containers: {{.Containers}} | Images: {{.Images}}' 2>/dev/null || true
}

agent_manifest_init(){
  local name="${1:-}"
  [[ "$name" =~ ^(hermes|openclaw)$ ]] || { warn "Agent muss hermes oder openclaw sein."; return 1; }
  mkdir -p "$AGENT_DIR/$name"
  cat > "$AGENT_DIR/$name/manifest.yaml" <<EOF
name: $name
version: "baseline"
description: "DAX controlled agent profile"
supported_runtimes:
  - native
  - docker
  - kvm
  - remote
default_runtime: docker
resources:
  cpus: 2
  memory: 4G
security:
  non_root: true
  no_new_privileges: true
  cap_drop_all: true
network:
  mode: isolated
healthcheck:
  enabled: true
EOF
  ok "Agent Profile erstellt: agents/$name/manifest.yaml"
}

agent_profiles(){
  local found=false
  for d in "$AGENT_DIR"/*; do
    [[ -d "$d" ]] || continue
    [[ -f "$d/manifest.yaml" ]] || continue
    found=true; printf '• %s\n' "$(basename "$d")"
  done
  [[ "$found" == true ]] || echo "Keine Agent Profiles vorhanden."
}

docker_build_agent(){
  require_native_linux || return 0
  detect_runtime_capabilities
  [[ "$DOCKER_DAEMON" == true ]] || { warn "Docker Daemon nicht erreichbar."; return 1; }
  docker_context_init
  case "$1" in
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
  [[ "$agent" =~ ^(hermes|openclaw)$ ]] || { warn "Agent muss hermes oder openclaw sein."; return 1; }
  docker rm -f "dax-$agent" >/dev/null 2>&1 || true
  docker run -d --name "dax-$agent" --restart unless-stopped \
    --security-opt no-new-privileges:true --cap-drop ALL --pids-limit 512 --memory 4g --cpus 2 \
    -e DAX_AGENT_RUNTIME=docker -v "$DOCKER_SHARED_DIR:/opt/dax/shared:ro" "$image"
}

docker_stop_agent(){ require_native_linux || return 0; [[ "$1" =~ ^(hermes|openclaw)$ ]] && docker stop "dax-$1" 2>/dev/null || true && docker rm "dax-$1" 2>/dev/null || true; }
docker_logs_agent(){ require_native_linux || return 0; [[ "$1" =~ ^(hermes|openclaw)$ ]] && docker logs --tail 100 -f "dax-$1"; }
docker_agent_status(){ require_native_linux || return 0; docker ps -a --filter name=dax-hermes --filter name=dax-openclaw --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}'; }
docker_compose_up(){ require_native_linux || return 0; detect_runtime_capabilities; [[ "$DOCKER_DAEMON" == true ]] || { warn "Docker Daemon nicht erreichbar."; return 1; }; docker_context_init; docker compose version >/dev/null 2>&1 && (cd "$DOCKER_DIR" && docker compose up -d) || warn "Docker Compose Plugin fehlt."; }
docker_compose_down(){ require_native_linux || return 0; docker compose version >/dev/null 2>&1 && (cd "$DOCKER_DIR" && docker compose down) || warn "Docker Compose Plugin fehlt."; }

# =============================================================================
# KVM / VM RUNTIME
# =============================================================================
install_kvm(){
  require_native_linux || return 0
  [[ "$PLATFORM" == wsl2 ]] && warn "WSL2: KVM wird nicht blind installiert; Nested Virtualization/Kernel-Support zuerst prüfen." && return 0
  ! command_exists apt-get && { warn "KVM-Autoinstallation ist für diesen Paketmanager nicht implementiert."; return 0; }
  ! confirm_action "QEMU/KVM + libvirt installieren?" && { warn "KVM-Installation abgebrochen."; return 0; }
  apt_install qemu-kvm libvirt-daemon-system libvirt-clients virtinst bridge-utils ovmf cpu-checker
  $SUDO systemctl enable --now libvirtd 2>/dev/null || true
  [[ "$(id -u)" -ne 0 ]] && $SUDO usermod -aG libvirt,kvm "$(id -un)" 2>/dev/null || true && warn "Gruppenänderung wird nach neuem Login/Session wirksam."
  detect_runtime_capabilities; persist_runtime_state
  [[ "$CAN_KVM" == true ]] && ok "KVM ist nutzbar." || warn "KVM installiert, aber Nutzbarkeit nicht bestätigt."
}

kvm_status(){
  detect_runtime_capabilities; persist_runtime_state
  echo "=== KVM / VM RUNTIME ==="
  echo "Virtualization CPU : $HOST_VIRTUALIZATION"
  echo "/dev/kvm           : $KVM_DEVICE"
  echo "KVM usable         : $CAN_KVM"
  echo "libvirt            : $CAN_LIBVIRT"
  command_exists virsh && virsh -c qemu:///system list --all 2>/dev/null || true
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
  [[ "$ram" =~ ^[0-9]+$ && "$cpus" =~ ^[0-9]+$ && "$disk" =~ ^[0-9]+$ ]] || { warn "RAM/CPU/Disk müssen positive Ganzzahlen sein."; return 1; }
  confirm_action "VM '$name' jetzt anlegen?" || { warn "VM-Erstellung abgebrochen."; return 0; }
  local diskpath="$VM_DIR/${name}.qcow2"
  [[ -f "$diskpath" ]] || qemu-img create -f qcow2 "$diskpath" "${disk}G"
  virt-install --name "$name" --memory "$ram" --vcpus "$cpus" --disk "path=$diskpath,format=qcow2" --cdrom "$iso" --network "network=$network" --os-variant detect=on,require=off --graphics spice --noautoconsole
  ok "VM '$name' wurde angelegt."
}

vm_snapshot_create(){ require_native_linux || return 0; local vm="${1:-}" snap="${2:-}"; [[ -n "$vm" ]] || { warn "VM Name fehlt."; return 1; }; [[ -n "$snap" ]] || snap="dax-$(date +%Y%m%d-%H%M%S)"; virsh -c qemu:///system snapshot-create-as "$vm" "$snap" --description "DAX checkpoint $snap"; }
vm_snapshot_restore(){ require_native_linux || return 0; local vm="${1:-}" snap="${2:-}"; [[ -n "$vm" && -n "$snap" ]] || { warn "VM und Snapshot erforderlich."; return 1; }; virsh -c qemu:///system snapshot-revert "$vm" "$snap"; }

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
        read -rp "VM Name: " n; read -rp "Snapshot Name [auto]: " sn
        vm_snapshot_create "$n" "$sn" || true
        pause_menu ;;
      8)
        read -rp "VM Name: " n; read -rp "Snapshot Name: " sn
        if confirm_action "Snapshot '$sn' auf VM '$n' wiederherstellen?"; then vm_snapshot_restore "$n" "$sn" || true; fi
        pause_menu ;;
      9) read -rp "VM Name: " n; virsh -c qemu:///system snapshot-list "$n" 2>&1 || true; pause_menu ;;
      10) break ;;
      *) warn "Ungültige Auswahl."; sleep 1 ;;
    esac
  done
}

# =============================================================================
# AGENT DEPLOYMENT WIZARD
# =============================================================================
agent_deployment_wizard(){
  while true; do
    clear 2>/dev/null || true
    echo -e "${CLR_BLUE}=== DAX AGENT DEPLOYMENT WIZARD ===${CLR_RESET}"
    echo "[1] Native Host"
    echo "[2] Docker Container"
    echo "[3] Neue KVM VM"
    echo "[4] Bestehende KVM VM"
    echo "[5] Remote Server"
    echo "[6] Zurück"
    read -rp "Runtime [1-6]: " r
    case "$r" in
      1) echo "Native Runtime: Agent Profile/Native Installer verwenden."; pause_menu ;;
      2)
        echo "[1] Hermes"; echo "[2] OpenClaw"
        read -rp "Agent [1-2]: " a
        local agent=""; [[ "$a" == 1 ]] && agent=hermes; [[ "$a" == 2 ]] && agent=openclaw
        [[ -n "$agent" ]] || { warn "Ungültiger Agent."; pause_menu; continue; }
        agent_manifest_init "$agent" || true
        docker_build_agent "$agent" || true
        if confirm_action "'$agent' Container starten?"; then docker_start_agent "$agent" || true; fi
        pause_menu ;;
      3) create_kvm_vm; pause_menu ;;
      4) read -rp "Bestehende VM: " n; virsh -c qemu:///system list --all 2>/dev/null | grep -F "$n" || true; pause_menu ;;
      5) echo "Remote Runtime: SSH/remote orchestrator hook vorbereitet; kein blindes Remote-Deployment."; pause_menu ;;
      6) break ;;
      *) warn "Ungültige Auswahl."; sleep 1 ;;
    esac
  done
}

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

# =============================================================================
# TEMPLATE MANAGER
# =============================================================================
template_manager(){
  while true; do
    clear 2>/dev/null || true
    echo -e "${CLR_BLUE}=== DAX TEMPLATE MANAGER ===${CLR_RESET}"
    echo "[1] VM-Templates anzeigen"
    echo "[2] Agent-Stack-Templates anzeigen"
    echo "[3] Compose-Templates anzeigen"
    echo "[4] Remote-Templates anzeigen"
    echo "[5] Compose-Template anwenden"
    echo "[6] Zurück"
    read -rp "Auswahl [1-6]: " c
    case "$c" in
      1)
        echo "=== VM-Templates ==="
        [[ -d "$TEMPLATE_DIR/vm" ]] && ls "$TEMPLATE_DIR/vm" || echo "Keine VM-Templates vorhanden."
        pause_menu ;;
      2)
        echo "=== Agent-Stack-Templates ==="
        [[ -d "$TEMPLATE_DIR/agents" ]] && ls "$TEMPLATE_DIR/agents" || echo "Keine Agent-Templates vorhanden."
        pause_menu ;;
      3)
        echo "=== Compose-Templates ==="
        [[ -d "$TEMPLATE_DIR/compose" ]] && ls "$TEMPLATE_DIR/compose" || echo "Keine Compose-Templates vorhanden."
        pause_menu ;;
      4)
        echo "=== Remote-Templates ==="
        [[ -d "$TEMPLATE_DIR/remote" ]] && ls "$TEMPLATE_DIR/remote" || echo "Keine Remote-Templates vorhanden."
        pause_menu ;;
      5)
        echo "[1] ollama-comfyui.yaml"
        echo "[2] full-stack.yaml"
        read -rp "Compose-Template [1-2]: " t
        template_apply_compose "${t:-full-stack}.yaml" || true
        pause_menu ;;
      6) break ;;
      *) warn "Ungültige Auswahl."; sleep 1 ;;
    esac
  done
}

# =============================================================================
# POLICY MANAGER
# =============================================================================
policy_manager(){
  while true; do
    clear 2>/dev/null || true
    echo -e "${CLR_BLUE}=== DAX POLICY MANAGER ===${CLR_RESET}"
    echo "[1] Aktuelle Policy anzeigen"
    echo "[2] Plattform-Check durchführen"
    echo "[3] Agent-Runtime-Check"
    echo "[4] Zurück"
    read -rp "Auswahl [1-4]: " c
    case "$c" in
      1)
        [[ -f "$POLICY_FILE" ]] && cat "$POLICY_FILE" || warn "Policy-Datei fehlt."
        pause_menu ;;
      2)
        echo "Platform: $PLATFORM"
        policy_allow_runtime_for_platform "native" && echo "native: erlaubt" || echo "native: verboten"
        policy_allow_runtime_for_platform "docker" && echo "docker: erlaubt" || echo "docker: verboten"
        policy_allow_runtime_for_platform "kvm" && echo "kvm: erlaubt" || echo "kvm: verboten"
        policy_allow_runtime_for_platform "remote" && echo "remote: erlaubt" || echo "remote: verboten"
        pause_menu ;;
      3)
        read -rp "Agent [hermes/openclaw]: " a
        read -rp "Runtime [native/docker/kvm/remote]: " r
        policy_allow_runtime_for_agent "$a" "$r" && echo "$r für $a: erlaubt" || echo "$r für $a: verboten"
        pause_menu ;;
      4) break ;;
      *) warn "Ungültige Auswahl."; sleep 1 ;;
    esac
  done
}

# =============================================================================
# SECRETS MANAGER
# =============================================================================
secrets_manager(){
  while true; do
    clear 2>/dev/null || true
    echo -e "${CLR_BLUE}=== DAX SECRETS MANAGER (AES-256 GCM / CBC) ===${CLR_RESET}"
    echo "Current scope: ${SECRETS_SCOPE:-global} ${SECRETS_IDENTIFIER:+(ID: $SECRETS_IDENTIFIER)}"
    echo "[1] Scope wählen (global, agent, remote)"
    echo "[2] Secret sicher eingeben & verschlüsseln"
    echo "[3] Secret entschlüsseln & anzeigen"
    echo "[4] Secrets-Datei anzeigen (Rohdaten/verschlüsselt)"
    echo "[5] Secrets-Datei (Scope) anzeigen"
    echo "[6] Zurück"
    read -rp "Auswahl [1-6]: " c
    case "$c" in
      1)
        echo "[1] global"
        echo "[2] agent (identifier erforderlich)"
        echo "[3] remote (host-identifier erforderlich)"
        read -rp "Scope wählen [1-3]: " scope_choice
        case "$scope_choice" in
          1) SECRETS_SCOPE="global"; SECRETS_IDENTIFIER=""; info "Scope: global" ;;
          2) SECRETS_SCOPE="agent"; read -rp "Agent-Identifier (z.B. hermes): " SECRETS_IDENTIFIER; info "Scope: agent/$SECRETS_IDENTIFIER" ;;
          3) SECRETS_SCOPE="remote"; read -rp "Host-Identifier (z.B. lab01): " SECRETS_IDENTIFIER; info "Scope: remote/$SECRETS_IDENTIFIER" ;;
          *) warn "Ungültige Auswahl." ;;
        esac
        pause_menu ;;
      2)
        read -rp "Key: " k
        read -rsp "Secret-Wert (Eingabe wird verborgen): " v
        echo ""
        secret_set "$k" "$v" "${SECRETS_SCOPE:-global}" "${SECRETS_IDENTIFIER:-}"
        pause_menu ;;
      3)
        read -rp "Key: " k
        local val
        val="$(secret_get "$k" "${SECRETS_SCOPE:-global}" "${SECRETS_IDENTIFIER:-}")"
        if [[ -n "$val" ]]; then
          echo -e "${CLR_GREEN}[✔] Entschlüsselter Wert für $k:${CLR_RESET} $val"
        else
          warn "Secret '$k' nicht gefunden oder leer."
        fi
        pause_menu ;;
      4)
        [[ -f "$GLOBAL_SECRETS" ]] && cat "$GLOBAL_SECRETS" || warn "Globale Secrets-Datei fehlt."
        pause_menu ;;
      5)
        local src="$GLOBAL_SECRETS"
        case "${SECRETS_SCOPE:-global}" in
          agent) [[ -n "$SECRETS_IDENTIFIER" ]] && src="$AGENT_SECRETS_DIR/${SECRETS_IDENTIFIER}.json" || { warn "Agent-Identifier fehlt."; pause_menu; continue; } ;;
          remote) [[ -n "$SECRETS_IDENTIFIER" ]] && src="$REMOTE_SECRETS_DIR/${SECRETS_IDENTIFIER}.json" || { warn "Host-Identifier fehlt."; pause_menu; continue; } ;;
        esac
        [[ -f "$src" ]] && cat "$src" || warn "Secrets-Datei fehlt: $src"
        pause_menu ;;
      6) break ;;
      *) warn "Ungültige Auswahl."; sleep 1 ;;
    esac
  done
}

# =============================================================================
# VOLUME MANAGER
# =============================================================================
volume_manager(){
  while true; do
    clear 2>/dev/null || true
    echo -e "${CLR_BLUE}=== DAX VOLUME MANAGER ===${CLR_RESET}"
    echo "[1] Volumes anzeigen"
    echo "[2] Volume sicherstellen"
    echo "[3] Volume-Mount für Docker generieren"
    echo "[4] Zurück"
    read -rp "Auswahl [1-4]: " c
    case "$c" in
      1)
        [[ -f "$VOLUMES_FILE" ]] && cat "$VOLUMES_FILE" || warn "Volumes-Datei fehlt."
        pause_menu ;;
      2)
        read -rp "Volume [hermes_data/openclaw_data/ollama_data]: " v
        volume_ensure "${v:-hermes_data}" || true
        pause_menu ;;
      3)
        read -rp "Volume [hermes_data/openclaw_data/ollama_data]: " v
        volume_mount_docker "${v:-hermes_data}" || true
        pause_menu ;;
      4) break ;;
      *) warn "Ungültige Auswahl."; sleep 1 ;;
    esac
  done
}

# =============================================================================
# HEALTH / OPERATIONS
# =============================================================================
health_check(){
  echo "=== DAX HEALTH & WATCHDOG STATUS ==="
  printf "Platform : %s\n" "$PLATFORM"
  command_exists ollama && (pgrep -x ollama >/dev/null 2>&1 && echo "Ollama   : HEALTHY" || echo "Ollama   : STOPPED") || echo "Ollama   : REMOTE/MISSING"
  [[ -f "$COMFYUI_DIR/main.py" ]] && echo "ComfyUI  : INSTALLED" || echo "ComfyUI  : MISSING"
  [[ "$DOCKER_DAEMON" == true ]] && echo "Docker   : HEALTHY" && docker_agent_status || echo "Docker   : UNAVAILABLE"
  [[ "$CAN_KVM" == true ]] && echo "KVM      : HEALTHY" && (command_exists virsh && virsh -c qemu:///system list --all 2>/dev/null || true) || echo "KVM      : UNAVAILABLE"
  echo ""
  watchdog_status
}

show_state(){ persist_runtime_state; echo "=== DAX STATE ==="; cat "$STATE_FILE"; }
verify_installations(){ echo "=== VERIFIZIERUNG ==="; show_preflight; persist_runtime_state; command_exists ollama && echo '✔ Ollama vorhanden' || echo '✖ Ollama fehlt/remote'; [[ -f "$COMFYUI_DIR/main.py" ]] && echo '✔ ComfyUI vorhanden' || echo '✖ ComfyUI fehlt'; [[ -x "$VENV_OPENWEBUI/bin/open-webui" ]] && echo '✔ Open WebUI vorhanden' || echo '✖ Open WebUI fehlt'; }
stop_services(){ for f in "$PID_DIR"/*.pid; do [[ -e "$f" ]] || continue; p="$(cat "$f" 2>/dev/null || true)"; [[ "$p" =~ ^[0-9]+$ ]] && kill "$p" 2>/dev/null || true; rm -f "$f"; done; ok "Dienste gestoppt."; }
view_logs(){ touch "$LOG_FILE"; tail -n 60 -f "$LOG_FILE"; }
pause_menu(){ echo; read -rp 'ENTER zum Fortfahren...' _; }

# =============================================================================
# MAIN MENU
# =============================================================================
main_menu(){
  termux_handoff
  while true; do
    clear 2>/dev/null || true
    detect_hardware; detect_runtime_capabilities; persist_runtime_state
    echo -e "${CLR_BLUE}╔════════════════════════════════════════════════════════════╗${CLR_RESET}"
    echo -e "${CLR_BLUE}║${CLR_GOLD}          DAX COMMAND CENTER v$VERSION          ${CLR_BLUE}║${CLR_RESET}"
    echo -e "${CLR_BLUE}║${CLR_GOLD}       CONTROL-PLANE EDITION (Policy/Adapter/Watchdog)   ${CLR_BLUE}║${CLR_RESET}"
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
    echo "CONTROL-PLANE MODULES"
    echo "[5]  Agent Manager / Deployment Wizard"
    echo "[6]  Agent Profiles"
    echo "[7]  Policy Manager"
    echo "[8]  Volume Manager"
    echo "[9]  Secrets Manager"
    echo "[10] Template Manager"
    echo
    echo "SERVICES"
    echo "[11] Ollama konfigurieren (Termux/PRoot: Remote empfohlen)"
    echo "[12] Ollama Modell laden (Termux/PRoot: Remote-Host verwenden)"
    echo "[13] ComfyUI installieren/starten (Termux/PRoot: CPU Safe Mode)"
    echo "[14] Open WebUI installieren/starten (Termux/PRoot: abhängig von Python/Architektur)"
    echo "[15] Node-RED + Faster-Whisper (Termux/PRoot: eingeschränkt)"
    echo
    echo "OPERATIONS"
    echo "[16] Health / Watchdog Check"
    echo "[17] Installation verifizieren"
    echo "[18] State / Configuration anzeigen"
    echo "[19] Dienste stoppen"
    echo "[20] Logs anzeigen"
    echo "[21] Beenden"
    read -rp 'Auswahl [0-21]: ' choice
    case "$choice" in
      0) show_preflight; pause_menu;;
      1) install_system_dependencies; pause_menu;;
      2) runtime_menu;;
      3) vm_menu;;
      4) echo "Remote Runtime: SSH/Orchestrator-Schnittstelle ist vorbereitet, aber kein blindes Remote-Deployment."; pause_menu;;
      5) agent_deployment_wizard;;
      6) agent_profiles; pause_menu;;
      7) policy_manager;;
      8) volume_manager;;
      9) secrets_manager;;
      10) template_manager;;
      11) install_ollama; pause_menu;;
      12) pull_ollama_model; pause_menu;;
      13) install_comfyui; start_comfyui; pause_menu;;
      14) install_openwebui; start_openwebui; pause_menu;;
      15) install_nodered || true; install_whisper || true; start_nodered || true; pause_menu;;
      16) health_check; watchdog_tick "health_check" "HEALTHY"; pause_menu;;
      17) verify_installations; pause_menu;;
      18) show_state; pause_menu;;
      19) stop_services; pause_menu;;
      20) view_logs;;
      21) exit 0;;
      *) warn 'Ungültige Auswahl.'; sleep 1;;
    esac
  done
}

detect_runtime_capabilities
persist_runtime_state
trap 'log INFO "DAX Command Center beendet."' EXIT
log INFO "=== DAX Command Center v$VERSION gestartet ($PLATFORM) ==="
main_menu
