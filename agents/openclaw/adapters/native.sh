adapter_install(){
  echo "Native-Installation: OpenClaw Pakete prüfen (pip/venv)."
}

adapter_start(){
  echo "Native-Start: openclaw daemon starten."
}

adapter_stop(){
  echo "Native-Stop: openclaw Prozess beenden."
}

adapter_status(){
  echo "openclaw not running (native runtime nicht für openclaw empfohlen)"
}

adapter_logs(){
  echo "Native-Logs: ~/dax-logs/openclaw/*.log"
}

adapter_health(){
  echo "STOPPED"
}

adapter_uninstall(){
  echo "Native-Uninstall: openclaw aus VENV entfernen."
}
