#!/usr/bin/env bash
# =============================================================================
# DAX AGENT ADAPTER — HERMES (KVM / QEMU RUNTIME)
# =============================================================================

HERMES_VM_NAME="dax-hermes-vm"

adapter_install(){
  require_native_linux || return 1
  detect_runtime_capabilities
  [[ "$CAN_KVM" == true ]] || { warn "KVM ist auf diesem System nicht verfügbar."; return 1; }
  
  info "KVM-Setup für Hermes VM ($HERMES_VM_NAME)..."
  local diskpath="$VM_DIR/${HERMES_VM_NAME}.qcow2"
  if [[ ! -f "$diskpath" ]]; then
    info "Erstelle QCOW2-Image für Hermes VM (40GB)..."
    qemu-img create -f qcow2 "$diskpath" 40G >>"$LOG_FILE" 2>&1 || die "Image-Erstellung fehlgeschlagen."
  fi
  ok "Hermes KVM-Storage vorbereitet: $diskpath"
}

adapter_start(){
  require_native_linux || return 1
  command_exists virsh || { warn "virsh fehlt. Bitte KVM installieren."; return 1; }

  info "Starte Hermes VM ($HERMES_VM_NAME)..."
  if virsh -c qemu:///system list --all --name 2>/dev/null | grep -qx "$HERMES_VM_NAME"; then
    virsh -c qemu:///system start "$HERMES_VM_NAME" 2>&1 | tee -a "$LOG_FILE"
    watchdog_tick "agents.hermes" "HEALTHY"
    ok "Hermes VM ($HERMES_VM_NAME) gestartet."
  else
    warn "VM $HERMES_VM_NAME nicht definiert. Bitte zuerst über KVM Manager / virt-install erstellen."
    return 1
  fi
}

adapter_stop(){
  require_native_linux || return 1
  command_exists virsh || return 0

  info "Stoppe Hermes VM ($HERMES_VM_NAME)..."
  virsh -c qemu:///system shutdown "$HERMES_VM_NAME" 2>/dev/null || virsh -c qemu:///system destroy "$HERMES_VM_NAME" 2>/dev/null || true
  watchdog_tick "agents.hermes" "STOPPED"
  ok "Hermes VM ($HERMES_VM_NAME) gestoppt."
}

adapter_status(){
  if command_exists virsh && virsh -c qemu:///system list --all --name 2>/dev/null | grep -qx "$HERMES_VM_NAME"; then
    local state
    state="$(virsh -c qemu:///system domstate "$HERMES_VM_NAME" 2>/dev/null || echo unknown)"
    echo "Hermes KVM VM ($HERMES_VM_NAME): $state"
  else
    echo "Hermes KVM VM ($HERMES_VM_NAME): NOT CONFIGURED"
  fi
}

adapter_logs(){
  local logfile="/var/log/libvirt/qemu/${HERMES_VM_NAME}.log"
  if [[ -f "$logfile" ]]; then
    tail -n 100 -f "$logfile"
  else
    info "Kein libvirt-Log unter $logfile gefunden. Nutze ggf. 'virsh console $HERMES_VM_NAME'."
  fi
}

adapter_health(){
  if command_exists virsh; then
    local state
    state="$(virsh -c qemu:///system domstate "$HERMES_VM_NAME" 2>/dev/null || echo stopped)"
    [[ "$state" == "running" ]] && echo "HEALTHY" || echo "STOPPED"
  else
    echo "STOPPED"
  fi
}

adapter_uninstall(){
  adapter_stop
  if command_exists virsh && virsh -c qemu:///system list --all --name 2>/dev/null | grep -qx "$HERMES_VM_NAME"; then
    virsh -c qemu:///system undefine "$HERMES_VM_NAME" --remove-all-storage 2>/dev/null || true
  fi
  rm -f "$VM_DIR/${HERMES_VM_NAME}.qcow2"
  ok "Hermes KVM VM entfernt."
}
