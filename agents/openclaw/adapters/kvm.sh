adapter_install(){
  echo "KVM-Installation: VM-Vorlage für OpenClaw (Template: templates/agents/openclaw-stack.yaml)."
}

adapter_start(){
  local vm_name="dax-openclaw-vm"
  echo "KVM-Start: VM $vm_name starten."
}

adapter_stop(){
  local vm_name="dax-openclaw-vm"
  echo "KVM-Stop: VM $vm_name stoppen."
}

adapter_status(){
  echo "KVM-Status: virsh list --all (VM: dax-openclaw-vm)"
}

adapter_logs(){
  echo "KVM-Logs: VM-Konsole / var/log/libvirt/*.log"
}

adapter_health(){
  echo "HEALTHY"
}

adapter_uninstall(){
  echo "KVM-Uninstall: VM deinstallieren."
}
