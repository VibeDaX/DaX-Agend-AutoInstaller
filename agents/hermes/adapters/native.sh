adapter_install(){
  echo "Native-Installation: Hermes Pakete prüfen (pip/venv)."
}

adapter_start(){
  echo "Native-Start: hermes daemon starten (Workspace-Konfiguration erforderlich)."
}

adapter_stop(){
  echo "Native-Stop: hermes Prozess beenden."
}

adapter_status(){
  pgrep -x hermes >/dev/null 2>&1 && echo "hermes running" || echo "hermes not running"
}

adapter_logs(){
  echo "Native-Logs: ~/dax-logs/hermes/*.log"
}

adapter_health(){
  pgrep -x hermes >/dev/null 2>&1 && echo "HEALTHY" || echo "STOPPED"
}

adapter_uninstall(){
  echo "Native-Uninstall: hermes aus VENV entfernen."
}
