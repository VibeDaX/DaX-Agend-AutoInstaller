adapter_install(){
  echo "Remote-Installation: Agent-Kontext via SSH auf Remote-Host bereitstellen."
}

adapter_start(){
  local host="lab01"
  local ssh_key
  ssh_key="$(secret_inject_remote_ssh_key "$host")" || ssh_key=""
  info "Remote-Start: Agent auf $host starten (remote_exec mit SSH-Key: ${ssh_key:-none})."
  remote_exec "$host" "sudo systemctl start dax-hermes" || warn "Remote-Start fehlgeschlagen."
}

adapter_stop(){
  local host="lab01"
  remote_exec "$host" "sudo systemctl stop dax-hermes" || warn "Remote-Stop fehlgeschlagen."
}

adapter_status(){
  local host="lab01"
  remote_exec "$host" "systemctl is-active dax-hermes" || echo "unknown"
}

adapter_logs(){
  local host="lab01"
  remote_exec "$host" "journalctl -u dax-hermes --no-pager -n 100" || warn "Remote-Logs fehlgeschlagen."
}

adapter_health(){
  local host="lab01"
  local status
  status="$(remote_exec "$host" "systemctl is-active dax-hermes" 2>/dev/null)" || status="unknown"
  [[ "$status" == "active" ]] && echo "HEALTHY" || echo "STOPPED"
}

adapter_uninstall(){
  local host="lab01"
  remote_exec "$host" "sudo systemctl stop dax-hermes; sudo rm -f /etc/systemd/system/dax-hermes.service" || warn "Remote-Uninstall fehlgeschlagen."
}
