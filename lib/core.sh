#!/usr/bin/env bash
# =============================================================================
# DAX CONTROL PLANE — CORE MODULE (lib/core.sh)
# Logging, Hardware/Platform Detection with In-Memory Caching & Preflight
# =============================================================================
set -Eeuo pipefail

log(){ printf '[%s] [%s] %s\n' "$(date '+%F %T')" "$1" "$2" | tee -a "$LOG_FILE"; }
info(){ echo -e "${CLR_BLUE}[+]${CLR_RESET} $*"; log INFO "$*"; }
ok(){ echo -e "${CLR_GREEN}[✔]${CLR_RESET} $*"; log OK "$*"; }
warn(){ echo -e "${CLR_GOLD}[!]${CLR_RESET} $*"; log WARN "$*"; }
die(){ echo -e "${CLR_RED}[✖]${CLR_RESET} $*" >&2; log ERROR "$*"; return 1 2>/dev/null || exit 1; }
command_exists(){ command -v "$1" >/dev/null 2>&1; }

ensure_venv(){
  local venv_path="$1"
  local desc="${2:-VENV}"
  if [[ ! -d "$venv_path" ]]; then
    info "Erstelle Python VENV für $desc ($venv_path)..."
    python3 -m venv "$venv_path" >>"$LOG_FILE" 2>&1 || {
      warn "VENV Erstellung mit python3 -m venv fehlgeschlagen, versuche Alternative..."
      python3 -m venv --without-pip "$venv_path" >>"$LOG_FILE" 2>&1 || return 1
    }
  fi
}

# Plattform-Erkennung
IS_TERMUX=false; IS_PROOT=false; IS_WSL=false; PLATFORM="linux"; OS_NAME="Linux"
if [[ -d "/data/data/com.termux/files/usr" ]]; then
  IS_TERMUX=true; PLATFORM="termux"; OS_NAME="Termux"
fi
if [[ -f "/proc/sys/kernel/osrelease" ]] && grep -qi "microsoft" /proc/sys/kernel/osrelease 2>/dev/null; then
  IS_WSL=true; PLATFORM="wsl2"; OS_NAME="Ubuntu (WSL2)"
fi
if [[ -f "/.dockerenv" ]]; then
  OS_NAME="$OS_NAME (Container)"
fi
if [[ -n "${PROOT_PREFIX:-}" ]] || [[ "${PATH:-}" == *proot* ]]; then
  IS_PROOT=true; PLATFORM="proot"; OS_NAME="$OS_NAME (PRoot)"
fi

# Session-Caching Variablen
_HW_DETECTED=false
_CAPS_DETECTED=false

GPU_TYPE="cpu"
GPU_NAME="Keine GPU erkannt (CPU Safe Mode)"
COMFYUI_MODE="cpu"
TORCH_INDEX="https://download.pytorch.org/whl/cpu"

CAN_DOCKER=false
DOCKER_DAEMON=false
CAN_KVM=false
KVM_DEVICE=false
CAN_LIBVIRT=false

detect_hardware(){
  local force="${1:-false}"
  if [[ "$_HW_DETECTED" == "true" && "$force" != "true" ]]; then
    return 0
  fi

  GPU_TYPE="cpu"
  GPU_NAME="Keine GPU erkannt (CPU Safe Mode)"
  COMFYUI_MODE="cpu"
  TORCH_INDEX="https://download.pytorch.org/whl/cpu"

  if command_exists nvidia-smi && nvidia-smi >/dev/null 2>&1; then
    GPU_TYPE="nvidia"
    GPU_NAME="$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -n 1 || echo 'NVIDIA GPU')"
    COMFYUI_MODE="cuda"
    TORCH_INDEX="https://download.pytorch.org/whl/cu121"
  elif command_exists rocm-smi || [[ -c "/dev/kfd" ]]; then
    GPU_TYPE="amd"
    GPU_NAME="AMD ROCm Compatible GPU"
    COMFYUI_MODE="rocm"
    TORCH_INDEX="https://download.pytorch.org/whl/rocm6.0"
  elif command_exists clinfo 2>/dev/null && clinfo 2>/dev/null | grep -qi "intel"; then
    GPU_TYPE="intel"
    GPU_NAME="Intel Arc / OneAPI Graphics"
    COMFYUI_MODE="xpu"
    TORCH_INDEX="https://download.pytorch.org/whl/cpu"
  elif [[ "$(uname -m 2>/dev/null)" == "arm64" ]] && [[ "$(uname -s 2>/dev/null)" == "Darwin" ]]; then
    GPU_TYPE="apple"
    GPU_NAME="Apple Silicon MPS"
    COMFYUI_MODE="mps"
    TORCH_INDEX=""
  fi

  _HW_DETECTED=true
}

detect_runtime_capabilities(){
  local force="${1:-false}"
  if [[ "$_CAPS_DETECTED" == "true" && "$force" != "true" ]]; then
    return 0
  fi

  CAN_DOCKER=false
  DOCKER_DAEMON=false
  CAN_KVM=false
  KVM_DEVICE=false
  CAN_LIBVIRT=false

  if command_exists docker; then
    CAN_DOCKER=true
    if docker info >/dev/null 2>&1; then
      DOCKER_DAEMON=true
    fi
  fi

  if [[ -c "/dev/kvm" ]] && [[ -w "/dev/kvm" || $(id -u) -eq 0 ]]; then
    KVM_DEVICE=true
  fi

  if command_exists kvm || command_exists qemu-system-x86_64; then
    CAN_KVM=true
  fi

  if command_exists virsh && command_exists libvirtd; then
    CAN_LIBVIRT=true
  fi

  _CAPS_DETECTED=true
}

get_ram_mb(){
  if [[ -f "/proc/meminfo" ]]; then
    awk '/MemTotal:/ {print int($2/1024)}' /proc/meminfo 2>/dev/null || echo "4096"
  else
    echo "4096"
  fi
}

ram_recommendation(){
  local ram_mb
  ram_mb="$(get_ram_mb)"
  echo "RAM: ${ram_mb} MB"
  if [[ "$ram_mb" -lt 6000 ]]; then
    echo "Empfehlung: Qwen 1.5B / Phi-3 Mini (CPU Mode / Remote Ollama)"
  elif [[ "$ram_mb" -lt 14000 ]]; then
    echo "Empfehlung: Llama 3 8B Q4 / Mistral 7B Q4"
  else
    echo "Empfehlung: Llama 3 8B Q8 / Qwen 14B / ComfyUI High-Res"
  fi
}

wait_for_port(){
  local port="$1"
  local timeout="${2:-30}"
  local start_time
  start_time=$(date +%s)
  while true; do
    if command_exists nc && nc -z localhost "$port" 2>/dev/null; then
      return 0
    fi
    if command_exists bash && (echo >"/dev/tcp/localhost/$port") 2>/dev/null; then
      return 0
    fi
    local current_time
    current_time=$(date +%s)
    if (( current_time - start_time >= timeout )); then
      warn "Timeout: Port $port war nach ${timeout}s nicht erreichbar."
      return 1
    fi
    sleep 0.5
  done
}

wait_for_process(){
  local pid="$1"
  local timeout="${2:-10}"
  local start_time
  start_time=$(date +%s)
  while true; do
    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
      return 0
    fi
    local current_time
    current_time=$(date +%s)
    if (( current_time - start_time >= timeout )); then
      warn "Timeout: Prozess $pid war nach ${timeout}s nicht stabil."
      return 1
    fi
    sleep 0.2
  done
}

show_preflight(){
  detect_hardware
  detect_runtime_capabilities
  echo "=== PREFLIGHT & HARDWARE MATRIX ==="
  echo "OS / Plattform: $OS_NAME ($PLATFORM)"
  echo "GPU Backend:    $GPU_TYPE ($GPU_NAME)"
  echo "ComfyUI Mode:   $COMFYUI_MODE"
  echo "Torch Index:    ${TORCH_INDEX:-Standard/PyPI}"
  echo "Docker Engine:  Binary=$CAN_DOCKER | Daemon=$DOCKER_DAEMON"
  echo "KVM / Hardware: Device=$KVM_DEVICE | QEMU=$CAN_KVM | libvirt=$CAN_LIBVIRT"
  ram_recommendation
}

persist_runtime_state(){
  mkdir -p "$STATE_DIR"
  cat <<EOF > "$STATE_DIR/capabilities.env"
PLATFORM="$PLATFORM"
OS_NAME="$OS_NAME"
GPU_TYPE="$GPU_TYPE"
GPU_NAME="$GPU_NAME"
COMFYUI_MODE="$COMFYUI_MODE"
CAN_DOCKER=$CAN_DOCKER
DOCKER_DAEMON=$DOCKER_DAEMON
CAN_KVM=$CAN_KVM
KVM_DEVICE=$KVM_DEVICE
CAN_LIBVIRT=$CAN_LIBVIRT
EOF

  cat <<EOF > "$STATE_DIR/state.json"
{
  "version": "$VERSION",
  "platform": "$PLATFORM",
  "os_name": "$OS_NAME",
  "gpu_type": "$GPU_TYPE",
  "gpu_name": "$GPU_NAME",
  "comfyui_mode": "$COMFYUI_MODE",
  "capabilities": {
    "docker": $CAN_DOCKER,
    "docker_daemon": $DOCKER_DAEMON,
    "kvm": $CAN_KVM,
    "kvm_device": $KVM_DEVICE,
    "libvirt": $CAN_LIBVIRT
  }
}
EOF
}
