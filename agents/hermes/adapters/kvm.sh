adapter_install(){
  echo "KVM-Installation: Vorlage für Agent-Instanz in VM (Template: templates/agents/hermes-stack.yaml)."
}

adapter_start(){
  local vm_name="dax-hermes-vm"
  echo "KVM-Start: VM $vm_name starten (virt-install/virsh)."
}

adapter_stop(){
  local vm_name="dax-hermes-vm"
  echo "KVM-Stop: VM $vm_name stoppen."
}

adapter_status(){
  echo "KVM-Status: virsh list --all (VM: dax-hermes-vm)"
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
