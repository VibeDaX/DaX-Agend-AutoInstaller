#!/usr/bin/env bash
# =============================================================================
# DAX CONTROL PLANE — SERVICES MODULE (lib/services.sh)
# System Installer, Docker/KVM Runtimes, Service Management
# =============================================================================
set -Eeuo pipefail

apt_install(){
  info "Installiere Systempakete: $*"
  if ! $SUDO apt-get update -qq >>"$LOG_FILE" 2>&1; then
    warn "apt-get update fehlgeschlagen — versiere trotzdem Installation..."
  fi
  if ! $SUDO apt-get install -y -qq --no-install-recommends "$@" >>"$LOG_FILE" 2>&1; then
    warn "apt-get install für '$*' fehlgeschlagen — bitte prüfe deine APT-Quellen."
    return 1
  fi
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

install_system_dependencies(){
  require_native_linux || return 0
  info "Installiere Basis-Systemabhängigkeiten..."
  if ! apt_install build-essential curl wget git python3 python3-pip python3-venv openssl jq stat; then
    warn "Einige Systempakete konnten nicht installiert werden — Installation wird trotzdem fortgesetzt."
  fi
  ok "System-Basisabhängigkeiten sind bereit."
}

uninstall_system_dependencies(){
  require_native_linux || return 0
  confirm_action "Systempakete entfernen (build-essential, curl, wget, git, python3, pip, venv, openssl, jq, stat)?" || return 0
  info "Entferne Basis-Systemabhängigkeiten..."
  $SUDO apt-get remove -y --purge build-essential curl wget git python3 python3-pip python3-venv openssl jq stat >>"$LOG_FILE" 2>&1 || true
  $SUDO apt-get autoremove -y >>"$LOG_FILE" 2>&1 || true
  ok "Systempakete entfernt."
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
    wait_for_port 11434 30 || warn "Ollama Port 11434 nicht erreichbar."
  fi
  ok "Ollama läuft und ist erreichbar."
}

uninstall_ollama(){
  confirm_action "Ollama komplett entfernen (Service, Binär, Modelle)?" || return 0
  info "Stoppe Ollama Service..."
  pkill -f "ollama serve" 2>/dev/null || true
  rm -f "$PID_DIR/ollama.pid"
  info "Entferne Ollama..."
  if [[ "$PLATFORM" == "linux" || "$PLATFORM" == "wsl2" ]]; then
    $SUDO systemctl stop ollama 2>/dev/null || true
    $SUDO systemctl disable ollama 2>/dev/null || true
    $SUDO rm -f /usr/local/bin/ollama /usr/local/bin/ollama_runner /usr/local/bin/ollama_llama_server 2>/dev/null || true
    $SUDO rm -rf /usr/share/ollama /var/lib/ollama /etc/systemd/system/ollama.service 2>/dev/null || true
    $SUDO userdel -r ollama 2>/dev/null || true
  fi
  rm -rf "$HOME/.ollama"
  ok "Ollama entfernt."
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

uninstall_comfyui(){
  confirm_action "ComfyUI und VENV entfernen ($COMFYUI_DIR, $VENV_COMFYUI)?" || return 0
  info "Stoppe ComfyUI falls aktiv..."
  pkill -f "ComfyUI/main.py" 2>/dev/null || true
  rm -f "$PID_DIR/comfyui.pid"
  info "Entferne ComfyUI Dateien..."
  rm -rf "$COMFYUI_DIR" "$VENV_COMFYUI"
  ok "ComfyUI entfernt."
}

start_comfyui(){
  [[ -d "$COMFYUI_DIR" ]] || { warn "ComfyUI nicht installiert."; return 1; }
  info "Starte ComfyUI..."
  source "$VENV_COMFYUI/bin/activate"
  nohup python3 "$COMFYUI_DIR/main.py" --listen 0.0.0.0 --port 8188 >/dev/null 2>&1 &
  echo $! > "$PID_DIR/comfyui.pid"
  deactivate
  wait_for_port 8188 30 || warn "ComfyUI Port 8188 nicht erreichbar."
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

uninstall_openwebui(){
  confirm_action "Open WebUI und VENV entfernen ($VENV_OPENWEBUI)?" || return 0
  info "Stoppe Open WebUI falls aktiv..."
  pkill -f "open-webui serve" 2>/dev/null || true
  rm -f "$PID_DIR/openwebui.pid"
  info "Entferne Open WebUI VENV..."
  rm -rf "$VENV_OPENWEBUI"
  ok "Open WebUI entfernt."
}

start_openwebui(){
  [[ -d "$VENV_OPENWEBUI" ]] || { warn "Open WebUI nicht installiert."; return 1; }
  info "Starte Open WebUI..."
  source "$VENV_OPENWEBUI/bin/activate"
  nohup open-webui serve >/dev/null 2>&1 &
  echo $! > "$PID_DIR/openwebui.pid"
  deactivate
  wait_for_port 8080 30 || warn "Open WebUI Port 8080 nicht erreichbar."
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

uninstall_nodered(){
  confirm_action "Node-RED global entfernen (npm uninstall)?" || return 0
  info "Stoppe Node-RED falls aktiv..."
  pkill -f "node-red" 2>/dev/null || true
  rm -f "$PID_DIR/nodered.pid"
  info "Entferne Node-RED..."
  if command_exists npm; then
    $SUDO npm uninstall -g --unsafe-perm node-red 2>/dev/null || true
  fi
  ok "Node-RED entfernt."
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

uninstall_whisper(){
  confirm_action "Faster-Whisper und VENV entfernen ($VENV_WHISPER)?" || return 0
  info "Entferne Faster-Whisper VENV..."
  pkill -f "faster-whisper" 2>/dev/null || true
  rm -rf "$VENV_WHISPER"
  ok "Faster-Whisper entfernt."
}

start_nodered(){
  if command_exists node-red; then
    nohup node-red >/dev/null 2>&1 &
    echo $! > "$PID_DIR/nodered.pid"
    wait_for_port 1880 30 || warn "Node-RED Port 1880 nicht erreichbar."
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

uninstall_docker(){
  require_native_linux || return 0
  confirm_action "Docker und Compose komplett entfernen?" || return 0
  info "Stoppe Docker Stack falls aktiv..."
  [[ -f "$DOCKER_DIR/compose.yml" ]] && (cd "$DOCKER_DIR" && docker compose down 2>/dev/null) || true
  pkill -f "docker compose" 2>/dev/null || true
  info "Entferne Docker Pakete..."
  $SUDO systemctl stop docker 2>/dev/null || true
  $SUDO systemctl disable docker 2>/dev/null || true
  $SUDO apt-get remove -y --purge docker.io docker-compose-plugin >>"$LOG_FILE" 2>&1 || true
  $SUDO apt-get autoremove -y >>"$LOG_FILE" 2>&1 || true
  $SUDO rm -rf /var/lib/docker /etc/docker /var/run/docker.sock 2>/dev/null || true
  rm -f "$PID_DIR"/*.pid
  detect_runtime_capabilities true
  persist_runtime_state
  ok "Docker entfernt."
}

runtime_menu(){
  clear 2>/dev/null || true
  echo "=== DOCKER RUNTIME MANAGEMENT ==="
  echo "1) Docker & Compose installieren"
  echo "2) Shared Context & Dockerfiles initialisieren"
  echo "3) Stack starten (docker compose up -d)"
  echo "4) Stack stoppen"
  echo "5) Docker deinstallieren"
  echo "6) Zurück"
  read -rp "Auswahl: " c
  clear 2>/dev/null || true
  case "$c" in
    1) install_docker; pause_menu ;;
    2) docker_context_init; pause_menu ;;
    3) [[ -f "$DOCKER_DIR/compose.yml" ]] && (cd "$DOCKER_DIR" && docker compose up -d); pause_menu ;;
    4) [[ -f "$DOCKER_DIR/compose.yml" ]] && (cd "$DOCKER_DIR" && docker compose down); pause_menu ;;
    5) uninstall_docker; pause_menu ;;
    6) return 0 ;;
  esac
}

vm_menu(){
  clear 2>/dev/null || true
  echo "=== KVM / VM RUNTIME MANAGEMENT ==="
  echo "1) KVM & libvirt Pakete installieren"
  echo "2) VM Status abfragen"
  echo "3) KVM deinstallieren"
  echo "4) Zurück"
  read -rp "Auswahl: " c
  clear 2>/dev/null || true
  case "$c" in
    1) apt_install qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils; pause_menu ;;
    2) command_exists virsh && virsh list --all || echo "virsh nicht verfügbar."; pause_menu ;;
    3)
      confirm_action "KVM & libvirt Pakete entfernen?" || return 0
      info "Entferne KVM & libvirt..."
      $SUDO apt-get remove -y --purge qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils >>"$LOG_FILE" 2>&1 || true
      $SUDO apt-get autoremove -y >>"$LOG_FILE" 2>&1 || true
      ok "KVM & libvirt entfernt."
      pause_menu
      ;;
    4) return 0 ;;
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

# ════════════════════════════════════════════════════════════════════════════
# AI FRAMEWORKS — LangChain & PyTorch
# ════════════════════════════════════════════════════════════════════════════

install_langchain(){
  info "Installiere LangChain AI Framework..."
  local venv_path="${SCRIPT_DIR}/.langchainvenv"

  if [[ -d "$venv_path" ]]; then
    info "LangChain VENV existiert bereits — aktualisiere..."
  else
    python3 -m venv "$venv_path"
    info "LangChain VENV erstellt: $venv_path"
  fi

  source "$venv_path/bin/activate"
  pip install --upgrade pip setuptools wheel >>"$LOG_FILE" 2>&1
  pip install langchain langchain-community langchain-core langchain-openai >>"$LOG_FILE" 2>&1
  pip install openai tiktoken >>"$LOG_FILE" 2>&1
  deactivate

  ok "LangChain installiert in: $venv_path"
  info "Aktivieren: source $venv_path/bin/activate"
}

uninstall_langchain(){
  confirm_action "LangChain und VENV entfernen?" || return 0
  local venv_path="${SCRIPT_DIR}/.langchainvenv"
  info "Entferne LangChain VENV..."
  rm -rf "$venv_path"
  ok "LangChain entfernt."
}

install_pytorch(){
  info "Installiere PyTorch..."
  local venv_path="${SCRIPT_DIR}/.pytorchvenv"

  detect_hardware

  if [[ -d "$venv_path" ]]; then
    info "PyTorch VENV existiert bereits — aktualisiere..."
  else
    python3 -m venv "$venv_path"
    info "PyTorch VENV erstellt: $venv_path"
  fi

  source "$venv_path/bin/activate"
  pip install --upgrade pip setuptools wheel >>"$LOG_FILE" 2>&1

  case "$GPU_TYPE" in
    nvidia)
      info "Installiere PyTorch mit CUDA Support..."
      pip install torch torchvision torchaudio --index-url "$TORCH_INDEX" >>"$LOG_FILE" 2>&1
      ;;
    amd)
      info "Installiere PyTorch mit ROCm Support..."
      pip install torch torchvision torchaudio --index-url "$TORCH_INDEX" >>"$LOG_FILE" 2>&1
      ;;
    apple)
      info "Installiere PyTorch mit MPS Support..."
      pip install torch torchvision torchaudio >>"$LOG_FILE" 2>&1
      ;;
    *)
      info "Installiere PyTorch (CPU Only)..."
      pip install torch torchvision torchaudio --index-url "https://download.pytorch.org/whl/cpu" >>"$LOG_FILE" 2>&1
      ;;
  esac

  pip install transformers datasets accelerate >>"$LOG_FILE" 2>&1
  deactivate

  ok "PyTorch installiert in: $venv_path"
  info "GPU Backend: $GPU_TYPE"
  info "Aktivieren: source $venv_path/bin/activate"
}

uninstall_pytorch(){
  confirm_action "PyTorch und VENV entfernen?" || return 0
  local venv_path="${SCRIPT_DIR}/.pytorchvenv"
  info "Entferne PyTorch VENV..."
  rm -rf "$venv_path"
  ok "PyTorch entfernt."
}
