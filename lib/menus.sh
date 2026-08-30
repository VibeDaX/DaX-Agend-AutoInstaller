#!/usr/bin/env bash
# =============================================================================
# DAX CONTROL PLANE — MENUS MODULE (lib/menus.sh)
# Interactive Menu System & Help System
# =============================================================================

menu_host(){
  while true; do
    clear 2>/dev/null || true
    echo -e "${CLR_BLUE}=== [1] HOST & HARDWARE MATRIX ===${CLR_RESET}"
    echo "[1] System / Capability Check (Preflight Matrix)"
    echo "[2] Zurück ins Hauptmenü"
    read -rp 'Auswahl [1-2]: ' c
    clear 2>/dev/null || true
    case "$c" in
      1) show_preflight; pause_menu ;;
      2) return 0 ;;
      *) warn 'Ungültige Auswahl.'; sleep 1 ;;
    esac
  done
}

menu_runtimes(){
  while true; do
    clear 2>/dev/null || true
    echo -e "${CLR_BLUE}=== [2] RUNTIMES ===${CLR_RESET}"
    echo "[1] Native Runtime / System Dependencies (Python VENVs)"
    echo "    └─ [1a] Installieren"
    echo "    └─ [1b] Deinstallieren"
    echo "[2] Docker Runtime (Container & Compose Management)"
    echo "    └─ [2a] Docker & Compose installieren"
    echo "    └─ [2b] Docker deinstallieren"
    echo "[3] KVM / VM Runtime (QEMU/libvirt & Snapshots)"
    echo "    └─ [3a] KVM & libvirt installieren"
    echo "    └─ [3b] KVM deinstallieren"
    echo "[4] Remote Runtime (SSH Orchestrierung)"
    echo "[5] Zurück ins Hauptmenü"
    read -rp 'Auswahl [1-5]: ' c
    clear 2>/dev/null || true
    case "$c" in
      1|1a) install_system_dependencies; pause_menu ;;
      1b) uninstall_system_dependencies; pause_menu ;;
      2|2a) runtime_menu ;;
      2b) uninstall_docker; pause_menu ;;
      3|3a) vm_menu ;;
      3b)
        confirm_action "KVM & libvirt Pakete entfernen?" || return 0
        info "Entferne KVM & libvirt..."
        $SUDO apt-get remove -y --purge qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils >>"$LOG_FILE" 2>&1 || true
        $SUDO apt-get autoremove -y >>"$LOG_FILE" 2>&1 || true
        ok "KVM & libvirt entfernt."
        pause_menu
        ;;
      4) echo "Remote Runtime: SSH/Orchestrator-Schnittstelle ist bereit."; pause_menu ;;
      5) return 0 ;;
      *) warn 'Ungültige Auswahl.'; sleep 1 ;;
    esac
  done
}

menu_control_plane(){
  while true; do
    clear 2>/dev/null || true
    echo -e "${CLR_BLUE}=== [3] CONTROL-PLANE MODULES ===${CLR_RESET}"
    echo "[1] Agent Manager / Deployment Wizard"
    echo "    └─ [1u] Agent deinstallieren"
    echo "[2] Agent Profiles (Manifeste)"
    echo "[3] Policy Manager (.dax/policy.yaml)"
    echo "[4] Volume Manager (.dax/volumes.yaml)"
    echo "[5] Secrets Manager (AES-256)"
    echo "    └─ [5d] Secrets löschen"
    echo "[6] Template Manager"
    echo "[7] Encrypted Backup & Restore (.tar.gz.enc)"
    echo "    └─ [7d] Backups löschen"
    echo "[8] Web Status Dashboard & API (Port 9090)"
    echo "[9] Zurück ins Hauptmenü"
    read -rp 'Auswahl [1-9]: ' c
    clear 2>/dev/null || true
    case "$c" in
      1) agent_deployment_wizard ;;
      1u)
        read -rp "Agent zum Deinstallieren (hermes/openclaw): " ag
        ag="$(echo "$ag" | tr -d '[:space:]')"
        [[ -z "$ag" ]] && { warn "Kein Agent eingegeben."; pause_menu; return 0; }
        read -rp "Runtime (native/docker/kvm/remote): " rt
        rt="$(echo "$rt" | tr -d '[:space:]')"
        [[ -z "$rt" ]] && { warn "Keine Runtime eingegeben."; pause_menu; return 0; }
        confirm_action "Agent $ag ($rt) wirklich deinstallieren?" || return 0
        agent_dispatch "$ag" "uninstall" "$rt"
        pause_menu
        ;;
      2) agent_profiles; pause_menu ;;
      3) policy_manager; pause_menu ;;
      4) volume_manager; pause_menu ;;
      5) secrets_manager; pause_menu ;;
      5d)
        read -rp "Scope (global/agent/remote): " sc
        read -rp "Identifier (oder 'all' für alle): " id
        if [[ "$id" == "all" ]]; then
          confirm_action "ALLE Secrets löschen?" || return 0
          rm -f "$GLOBAL_SECRETS" "$AGENT_SECRETS_DIR"/*.json "$REMOTE_SECRETS_DIR"/*.json 2>/dev/null || true
          ok "Alle Secrets gelöscht."
        else
          read -rp "Key Name (oder 'all' für alle Keys): " k
          if [[ "$k" == "all" ]]; then
            rm -f "$AGENT_SECRETS_DIR/${id}.json" "$REMOTE_SECRETS_DIR/${id}.json" 2>/dev/null || true
            ok "Alle Secrets für $sc/$id gelöscht."
          else
            local target_file=""
            case "$sc" in
              global) target_file="$GLOBAL_SECRETS" ;;
              agent) target_file="$AGENT_SECRETS_DIR/${id}.json" ;;
              remote) target_file="$REMOTE_SECRETS_DIR/${id}.json" ;;
            esac
            if [[ -f "$target_file" ]]; then
              python3 "$SCRIPT_DIR/lib/state_helper.py" json_del_secret "$target_file" "$k" 2>/dev/null || true
              ok "Secret $k aus $sc/$id gelöscht."
            else
              warn "Secret-Datei nicht gefunden: $target_file"
            fi
          fi
        fi
        pause_menu
        ;;
      6) template_manager; pause_menu ;;
      7) backup_manager; pause_menu ;;
      7d)
        confirm_action "ALLE verschlüsselten Backups löschen?" || return 0
        rm -f data/backups/*.tar.gz.enc 2>/dev/null || true
        ok "Alle Backups gelöscht."
        pause_menu
        ;;
      8) dashboard_manager; pause_menu ;;
      9) return 0 ;;
      *) warn 'Ungültige Auswahl.'; sleep 1 ;;
    esac
  done
}

menu_services(){
  while true; do
    clear 2>/dev/null || true
    echo -e "${CLR_BLUE}=== [4] SERVICES ===${CLR_RESET}"
    echo "[1] Ollama konfigurieren & starten"
    echo "    └─ [1a] Installieren/Starten"
    echo "    └─ [1b] Deinstallieren"
    echo "[2] Ollama Modell laden (intelligenter RAM-Check)"
    echo "[3] ComfyUI installieren/starten"
    echo "    └─ [3a] Installieren/Starten"
    echo "    └─ [3b] Deinstallieren"
    echo "[4] Open WebUI installieren/starten"
    echo "    └─ [4a] Installieren/Starten"
    echo "    └─ [4b] Deinstallieren"
    echo "[5] Node-RED + Faster-Whisper"
    echo "    └─ [5a] Node-RED installieren/starten"
    echo "    └─ [5b] Node-RED deinstallieren"
    echo "    └─ [5c] Faster-Whisper installieren"
    echo "    └─ [5d] Faster-Whisper deinstallieren"
    echo "[6] Zurück ins Hauptmenü"
    read -rp 'Auswahl [1-6]: ' c
    clear 2>/dev/null || true
    case "$c" in
      1|1a) install_ollama; pause_menu ;;
      1b) uninstall_ollama; pause_menu ;;
      2) pull_ollama_model; pause_menu ;;
      3|3a) install_comfyui; start_comfyui; pause_menu ;;
      3b) uninstall_comfyui; pause_menu ;;
      4|4a) install_openwebui; start_openwebui; pause_menu ;;
      4b) uninstall_openwebui; pause_menu ;;
      5a) install_nodered; start_nodered; pause_menu ;;
      5b) uninstall_nodered; pause_menu ;;
      5c) install_whisper; pause_menu ;;
      5d) uninstall_whisper; pause_menu ;;
      6) return 0 ;;
      *) warn 'Ungültige Auswahl.'; sleep 1 ;;
    esac
  done
}

menu_operations(){
  while true; do
    clear 2>/dev/null || true
    echo -e "${CLR_BLUE}=== [5] OPERATIONS & MONITORING ===${CLR_RESET}"
    echo "[1] Health / Watchdog Check"
    echo "[2] Installation verifizieren"
    echo "[3] State / Configuration anzeigen"
    echo "[4] Automatisierte Testsuite ausführen (100% Validierung)"
    echo "[5] Dienste stoppen"
    echo "[6] Logs anzeigen"
    echo "[7] Zurück ins Hauptmenü"
    read -rp 'Auswahl [1-7]: ' c
    clear 2>/dev/null || true
    case "$c" in
      1) health_check; pause_menu ;;
      2) verify_installations; pause_menu ;;
      3) show_state; pause_menu ;;
      4) "$SCRIPT_DIR/tests/run_tests.sh"; pause_menu ;;
      5) stop_services; pause_menu ;;
      6) view_logs ;;
      7) return 0 ;;
      *) warn 'Ungültige Auswahl.'; sleep 1 ;;
    esac
  done
}

menu_help(){
  while true; do
    clear 2>/dev/null || true
    echo -e "${CLR_BLUE}=== [6] HILFE & ANLEITUNG ===${CLR_RESET}"
    echo "1) Hauptmenü erklärt"
    echo "2) Kategorie [1] HOST & Hardware"
    echo "3) Kategorie [2] RUNTIMES"
    echo "4) Kategorie [3] CONTROL-PLANE MODULES"
    echo "5) Kategorie [4] SERVICES"
    echo "6) Kategorie [5] OPERATIONS"
    echo "7) Schritt-für-Schritt Anleitungen (Workflows)"
    echo "8) Zurück ins Hauptmenü"
    read -rp 'Auswahl [1-8]: ' c
    clear 2>/dev/null || true
    case "$c" in
      1) help_main ;;
      2) help_host ;;
      3) help_runtimes ;;
      4) help_control_plane ;;
      5) help_services ;;
      6) help_operations ;;
      7) help_workflows ;;
      8) return 0 ;;
      *) warn 'Ungültige Auswahl.'; sleep 1 ;;
    esac
  done
}

help_main(){
  clear 2>/dev/null || true
  echo -e "${CLR_GOLD}╔══════════════════════════════════════════════════════════════════╗${CLR_RESET}"
  echo -e "${CLR_GOLD}║${CLR_WHITE}  DAX COMMAND CENTER — HAUPTMENÜ ERKLÄRT                     ${CLR_GOLD}║${CLR_RESET}"
  echo -e "${CLR_GOLD}╚══════════════════════════════════════════════════════════════════╝${CLR_RESET}"
  echo
  echo "Das Hauptmenü ist in 5 Kategorien plus Beenden unterteilt:"
  echo
  echo -e "${CLR_GREEN}[1] HOST (Preflight Matrix & Hardware Check)${CLR_RESET}"
  echo "    Zeigt Informationen über dein System, Betriebssystem, GPU und"
  echo "    Virtualisierungsfähigkeiten. Nutze dies zuerst, um die Umgebung"
  echo "    zu verstehen."
  echo
  echo -e "${CLR_GREEN}[2] RUNTIMES (Native, Docker, KVM, Remote)${CLR_RESET}"
  echo "    Verwaltet die Laufzeitumgebungen, in denen KI-Agenten und Services"
  echo "    ausgeführt werden können."
  echo
  echo -e "${CLR_GREEN}[3] CONTROL-PLANE MODULES${CLR_RESET}"
  echo "    Zentrale Verwaltung von Agenten, Richtlinien, Secrets, Volumes,"
  echo "    Templates, Backups und dem Web-Dashboard."
  echo
  echo -e "${CLR_GREEN}[4] SERVICES${CLR_RESET}"
  echo "    Installation und Verwaltung von Ollama (LLM), ComfyUI (Bilder),"
  echo "    Open WebUI (Chat), Node-RED und Faster-Whisper (Spracherkennung)."
  echo
  echo -e "${CLR_GREEN}[5] OPERATIONS & MONITORING${CLR_RESET}"
  echo "    Health-Checks, Watchdog, Tests, Logs und Service-Stopp."
  echo
  echo -e "${CLR_RED}[6] Hilfe & Anleitung${CLR_RESET}"
  echo "    Erklärungen und Schritt-für-Schritt Anleitungen für alle Funktionen."
  echo
  echo -e "${CLR_RED}[7] Beenden${CLR_RESET}"
  echo "    Schließt das Command Center sauber."
  echo
  pause_menu
}

help_host(){
  clear 2>/dev/null || true
  echo -e "${CLR_GOLD}╔══════════════════════════════════════════════════════════════════╗${CLR_RESET}"
  echo -e "${CLR_GOLD}║${CLR_WHITE}  KATEGORIE [1] — HOST & HARDWARE MATRIX                       ${CLR_GOLD}║${CLR_RESET}"
  echo -e "${CLR_GOLD}╚══════════════════════════════════════════════════════════════════╝${CLR_RESET}"
  echo
  echo "Zweck:"
  echo "  Erkennt automatisch dein Betriebssystem, verfügbare Hardware und"
  echo "  Virtualisierungsoptionen."
  echo
  echo "Menüpunkte:"
  echo "  [1] System / Capability Check (Preflight Matrix)"
  echo "      Führt einen vollständigen Hardware- und Fähigkeits-Check durch."
  echo "      Zeigt an:"
  echo "        • Plattform (Linux, WSL2, Termux, PRoot)"
  echo "        • GPU-Typ (NVIDIA CUDA, AMD ROCm, Intel Arc, Apple MPS, CPU)"
  echo "        • Docker-Verfügbarkeit"
  echo "        • KVM/libvirt-Unterstützung"
  echo "        • Gesamter RAM und Empfehlungen für LLM-Modelle"
  echo
  echo "  [2] Zurück"
  echo
  echo "Schritt-für-Schritt:"
  echo "  1. Wähle [1] im Hauptmenü."
  echo "  2. Das System analysiert automatisch deine Hardware."
  echo "  3. Die Ergebnisse werden gespeichert in .dax/state.json."
  echo "  4. Nutze diese Informationen, um zu entscheiden, welche Runtimes"
  echo "     und Services du nutzen kannst."
  echo
  pause_menu
}

help_runtimes(){
  clear 2>/dev/null || true
  echo -e "${CLR_GOLD}╔══════════════════════════════════════════════════════════════════╗${CLR_RESET}"
  echo -e "${CLR_GOLD}║${CLR_WHITE}  KATEGORIE [2] — RUNTIMES                                    ${CLR_GOLD}║${CLR_RESET}"
  echo -e "${CLR_GOLD}╚══════════════════════════════════════════════════════════════════╝${CLR_RESET}"
  echo
  echo "Zweck:"
  echo "  Runtimes sind die Umgebungen, in denen KI-Agenten und Services"
  echo "  ausgeführt werden. DAX unterstützt vier Runtime-Typen."
  echo
  echo "Menüpunkte:"
  echo "  [1] Native Runtime / System Dependencies"
  echo "      Installiert Python, pip, VENVs und System-Tools direkt auf"
  echo "      dem Host. Am besten für einzelne Agenten ohne Container."
  echo "      Deinstallation: [1b] entfernt die Pakete wieder."
  echo
  echo "  [2] Docker Runtime"
  echo "      Installiert Docker und Docker Compose. Bietet Isolation und"
  echo "      reproduzierbare Umgebungen."
  echo "      Deinstallation: [2b] entfernt docker.io, Compose und /var/lib/docker."
  echo
  echo "  [3] KVM / VM Runtime"
  echo "      Verwaltet virtuelle Maschinen mit QEMU/KVM. Nur auf nativen"
  echo "      Linux-Systemen verfügbar."
  echo "      Deinstallation: [3b] entfernt qemu-kvm, libvirt und bridge-utils."
  echo
  echo "  [4] Remote Runtime"
  echo "      Orchestriert Agenten auf entfernten Servern per SSH."
  echo
  echo "  [5] Zurück"
  echo
  echo "Schritt-für-Schritt (Docker Beispiel):"
  echo "  1. Wähle [2] RUNTIMES im Hauptmenü."
  echo "  2. Wähle [2] Docker Runtime."
  echo "  3. Wähle [1] Docker & Compose installieren."
  echo "  4. Wähle [2] Shared Context initialisieren (erstellt Ordner)."
  echo "  5. Wähle [3] Stack starten, sobald compose.yml bereit ist."
  echo "  6. Zum Entfernen: [2b] Docker deinstallieren."
  echo
  pause_menu
}

help_control_plane(){
  clear 2>/dev/null || true
  echo -e "${CLR_GOLD}╔══════════════════════════════════════════════════════════════════╗${CLR_RESET}"
  echo -e "${CLR_GOLD}║${CLR_WHITE}  KATEGORIE [3] — CONTROL-PLANE MODULES                        ${CLR_GOLD}║${CLR_RESET}"
  echo -e "${CLR_GOLD}╚══════════════════════════════════════════════════════════════════╝${CLR_RESET}"
  echo
  echo "Zweck:"
  echo "  Diese Module steuern die gesamte Control-Plane-Architektur."
  echo
  echo "Menüpunkte:"
  echo "  [1] Agent Manager / Deployment Wizard"
  echo "      Installiert, startet, stoppt und überwacht KI-Agenten."
  echo "      Agenten: Hermes 2.0 und OpenClaw."
  echo "      Deinstallation: [1u] entfernt Agent + VENV/Container."
  echo
  echo "  [2] Agent Profiles (Manifeste)"
  echo "      Zeigt die Konfiguration der Agenten (Runtimes, Abhängigkeiten)."
  echo
  echo "  [3] Policy Manager (.dax/policy.yaml)"
  echo "      Verwaltet Regeln, welche Runtimes auf welchen Plattformen"
  echo "      erlaubt sind. Verhindert inkompatible Ausführungen."
  echo
  echo "  [4] Volume Manager (.dax/volumes.yaml)"
  echo "      Definiert persistente Speicherbereiche für Agenten und Services."
  echo "      Deinstallation: Im Volume Manager einzelne Volumes löschen."
  echo
  echo "  [5] Secrets Manager (AES-256)"
  echo "      Verschlüsselt API-Keys und Passwörter mit OpenSSL."
  echo "      Secrets werden on-the-fly entschlüsselt und nie im Klartext"
  echo "      gespeichert."
  echo "      Deinstallation: [5d] löscht einzelne Secrets oder alle."
  echo
  echo "  [6] Template Manager"
  echo "      Verwaltet Vorlagen für Docker Compose, VMs und Remote-Hosts."
  echo "      Deinstallation: Im Template Manager compose.yml zurücksetzen."
  echo
  echo "  [7] Encrypted Backup & Restore"
  echo "      Erstellt AES-256 verschlüsselte Backups von .dax/ und"
  echo "      kann diese wiederherstellen."
  echo "      Deinstallation: [7d] löscht alle Backup-Archive."
  echo
  echo "  [8] Web Status Dashboard & API (Port 9090)"
  echo "      Startet einen Webserver mit Live-Monitoring und JSON-API."
  echo
  echo "  [9] Zurück"
  echo
  echo "Schritt-für-Schritt (Agent starten):"
  echo "  1. Wähle [3] CONTROL-PLANE MODULES."
  echo "  2. Wähle [1] Agent Manager."
  echo "  3. Folge dem Wizard: Agent auswählen → Runtime wählen → Installieren."
  echo "  4. Nach der Installation: Starten und Status prüfen."
  echo "  5. Nutze [8] Dashboard, um den Live-Status zu sehen."
  echo "  6. Zum Entfernen: [1u] Agent deinstallieren."
  echo
  pause_menu
}

help_services(){
  clear 2>/dev/null || true
  echo -e "${CLR_GOLD}╔══════════════════════════════════════════════════════════════════╗${CLR_RESET}"
  echo -e "${CLR_GOLD}║${CLR_WHITE}  KATEGORIE [4] — SERVICES                                     ${CLR_GOLD}║${CLR_RESET}"
  echo -e "${CLR_GOLD}╚══════════════════════════════════════════════════════════════════╝${CLR_RESET}"
  echo
  echo "Zweck:"
  echo "  Installation und Verwaltung von KI-Diensten und Tools."
  echo
  echo "Menüpunkte:"
  echo "  [1] Ollama konfigurieren & starten"
  echo "      Lokale LLM-Inferenz-Engine. Lädt Modelle von ollama.com."
  echo "      Deinstallation: [1b] entfernt Binär, Service und Modelle."
  echo
  echo "  [2] Ollama Modell laden"
  echo "      Lädt ein LLM-Modell herunter. Prüft automatisch den RAM."
  echo "      Empfohlen: llama3:8b für 8GB+ RAM, qwen2:7b für 4GB+ RAM."
  echo
  echo "  [3] ComfyUI installieren/starten"
  echo "      Grafische Benutzeroberfläche für Stable Diffusion."
  echo "      Port: 8188. Benötigt NVIDIA GPU für optimale Leistung."
  echo "      Deinstallation: [3b] löscht Repo und VENV."
  echo
  echo "  [4] Open WebUI installieren/starten"
  echo "      Chat-Interface für lokale LLMs (Ollama)."
  echo "      Port: 8080."
  echo "      Deinstallation: [4b] löscht VENV und PID-File."
  echo
  echo "  [5] Node-RED + Faster-Whisper"
  echo "      Node-RED: Visuelle Automatisierung (Port 1880)."
  echo "      Deinstallation: [5b] per npm uninstall."
  echo "      Faster-Whisper: Spracherkennung (STT) über Docker API (Port 8000)."
  echo "      Deinstallation: [5d] löscht VENV."
  echo
  echo "  [6] Zurück"
  echo
  echo "Schritt-für-Schritt (Ollama + Modell):"
  echo "  1. Wähle [4] SERVICES."
  echo "  2. Wähle [1] Ollama konfigurieren → automatische Installation."
  echo "  3. Wähle [2] Ollama Modell laden."
  echo "  4. Modellnamen eingeben, z.B. 'llama3:8b'."
  echo "  5. Warte bis Download abgeschlossen ist."
  echo "  6. Modell ist einsatzbereit unter http://localhost:11434"
  echo "  7. Zum Entfernen: [1b] Ollama deinstallieren."
  echo
  pause_menu
}

help_operations(){
  clear 2>/dev/null || true
  echo -e "${CLR_GOLD}╔══════════════════════════════════════════════════════════════════╗${CLR_RESET}"
  echo -e "${CLR_GOLD}║${CLR_WHITE}  KATEGORIE [5] — OPERATIONS & MONITORING                      ${CLR_GOLD}║${CLR_RESET}"
  echo -e "${CLR_GOLD}╚══════════════════════════════════════════════════════════════════╝${CLR_RESET}"
  echo
  echo "Zweck:"
  echo "  Überwachung, Tests und Wartung der gesamten Installation."
  echo
  echo "Menüpunkte:"
  echo "  [1] Health / Watchdog Check"
  echo "      Prüft den Status aller laufenden Dienste."
  echo "      Bei Fehlern (≥3 Versuche) löst der Watchdog automatisch"
  echo "      einen Neustart aus."
  echo
  echo "  [2] Installation verifizieren"
  echo "      Führt den Preflight-Check erneut aus und prüft, ob alle"
  echo "      Tools installiert sind."
  echo
  echo "  [3] State / Configuration anzeigen"
  echo "      Zeigt die aktuelle Konfiguration und den Systemzustand"
  echo "      aus .dax/state.json."
  echo
  echo "  [4] Automatisierte Testsuite"
  echo "      Führt alle 8 Testmodule aus (100% Validierung)."
  echo "      Dauer: ca. 9 Sekunden."
  echo
  echo "  [5] Dienste stoppen"
  echo "      Beendet alle gestarteten Dienste sauber."
  echo
  echo "  [6] Logs anzeigen"
  echo "      Zeigt die letzten 60 Zeilen von installation.log und"
  echo "      watchdog.log in Echtzeit an."
  echo
  echo "  [7] Zurück"
  echo
  echo "Schritt-für-Schritt (Tests ausführen):"
  echo "  1. Wähle [5] OPERATIONS."
  echo "  2. Wähle [4] Automatisierte Testsuite."
  echo "  3. Die Tests laufen automatisch durch."
  echo "  4. Am Ende siehst du eine Zusammenfassung (Module gesamt /"
  echo "     bestanden / fehlgeschlagen)."
  echo
  pause_menu
}

help_workflows(){
  clear 2>/dev/null || true
  echo -e "${CLR_GOLD}╔══════════════════════════════════════════════════════════════════╗${CLR_RESET}"
  echo -e "${CLR_GOLD}║${CLR_WHITE}  SCHRITT-FÜR-SCHRITT ANLEITUNGEN (WORKFLOWS)                  ${CLR_GOLD}║${CLR_RESET}"
  echo -e "${CLR_GOLD}╚══════════════════════════════════════════════════════════════════╝${CLR_RESET}"
  echo
  echo -e "${CLR_BLUE}Workflow 1: Erstinstallation & System-Check${CLR_RESET}"
  echo "  1. ./start.sh ausführen (oder ./dax.sh direkt)."
  echo "  2. Hauptmenü → [1] HOST → [1] System Check."
  echo "  3. Notiere dir GPU-Typ und RAM aus der Ausgabe."
  echo "  4. Hauptmenü → [2] RUNTIMES → [1] Native Dependencies."
  echo "  5. Fertig — Basis-System ist einsatzbereit."
  echo
  echo -e "${CLR_BLUE}Workflow 2: Ollama LLM einrichten${CLR_RESET}"
  echo "  1. Hauptmenü → [4] SERVICES → [1] Ollama installieren."
  echo "  2. Warten bis Installation abgeschlossen ist."
  echo "  3. [2] Ollama Modell laden, z.B. 'llama3:8b'."
  echo "  4. Testen: curl http://localhost:11434/api/generate"
  echo
  echo -e "${CLR_BLUE}Workflow 3: ComfyUI mit GPU starten${CLR_RESET}"
  echo "  1. Hauptmenü → [4] SERVICES → [3] ComfyUI installieren."
  echo "  2. ComfyUI wird automatisch gestartet (Port 8188)."
  echo "  3. Öffne http://localhost:8188 im Browser."
  echo "  4. Für Docker-Stack: [2] RUNTIMES → [2] Docker → Stack starten."
  echo
  echo -e "${CLR_BLUE}Workflow 4: Agenten deployen (Native)${CLR_RESET}"
  echo "  1. Hauptmenü → [3] CONTROL-PLANE MODULES → [1] Agent Manager."
  echo "  2. Agent auswählen (Hermes oder OpenClaw)."
  echo "  3. Runtime 'native' wählen."
  echo "  4. Installation bestätigen."
  echo "  5. Status prüfen: muss 'RUNNING' anzeigen."
  echo
  echo -e "${CLR_BLUE}Workflow 5: Backup erstellen & wiederherstellen${CLR_RESET}"
  echo "  1. Hauptmenü → [3] CONTROL-PLANE MODULES → [7] Backup & Restore."
  echo "  2. Option [1] Neues AES-256 Backup erstellen."
  echo "  3. Backup-Datei liegt in data/backups/*.tar.gz.enc."
  echo "  4. Zum Wiederherstellen: Option [3] und Dateinamen eingeben."
  echo
  echo -e "${CLR_BLUE}Workflow 6: Web-Dashboard nutzen${CLR_RESET}"
  echo "  1. Hauptmenü → [3] CONTROL-PLANE MODULES → [8] Dashboard."
  echo "  2. Option [1] Web Dashboard starten."
  echo "  3. Öffne http://localhost:9090 im Browser."
  echo "  4. JSON-API verfügbar unter http://localhost:9090/api/status."
  echo
  echo -e "${CLR_BLUE}Workflow 7: Secrets sicher speichern${CLR_RESET}"
  echo "  1. Hauptmenü → [3] CONTROL-PLANE MODULES → [5] Secrets Manager."
  echo "  2. Neues Secret eingeben (Key + Wert + Scope)."
  echo "  3. Der Wert wird mit AES-256 verschlüsselt in .dax/secrets/ gespeichert."
  echo "  4. Zur Laufzeit wird er automatisch entschlüsselt."
  echo
  echo -e "${CLR_BLUE}Workflow 8: Services deinstallieren${CLR_RESET}"
  echo "  • Ollama entfernen:"
  echo "    → [4] SERVICES → [1b] Deinstallieren"
  echo "    → Entfernt Binär, Service, Modelle und ~/.ollama"
  echo "  • ComfyUI entfernen:"
  echo "    → [4] SERVICES → [3b] Deinstallieren"
  echo "    → Löscht ComfyUI-Repo und VENV"
  echo "  • Open WebUI entfernen:"
  echo "    → [4] SERVICES → [4b] Deinstallieren"
  echo "    → Löscht VENV und PID-File"
  echo "  • Node-RED entfernen:"
  echo "    → [4] SERVICES → [5b] Deinstallieren"
  echo "    → npm uninstall -g + PID-File"
  echo "  • Faster-Whisper entfernen:"
  echo "    → [4] SERVICES → [5d] Deinstallieren"
  echo "    → Löscht VENV"
  echo "  • Docker entfernen:"
  echo "    → [2] RUNTIMES → [2b] Docker deinstallieren"
  echo "    → Entfernt docker.io, docker-compose-plugin, /var/lib/docker"
  echo "  • KVM entfernen:"
  echo "    → [2] RUNTIMES → [3b] KVM deinstallieren"
  echo "    → Entfernt qemu-kvm, libvirt, bridge-utils"
  echo
  echo -e "${CLR_BLUE}Workflow 9: Fehlerbehandlung${CLR_RESET}"
  echo "  • Dienst startet nicht:"
  echo "    → [5] OPERATIONS → [6] Logs anzeigen, Fehler suchen."
  echo "    → [5] OPERATIONS → [1] Health Check, um Neustart zu erzwingen."
  echo "  • Tests schlagen fehl:"
  echo "    → Prüfe .dax/watchdog.json auf fehlgeschlagene Dienste."
  echo "    → Prüfe logs/watchdog.log auf Recovery-Meldungen."
  echo "  • Docker-Stack startet nicht:"
  echo "    → [2] RUNTIMES → [2] Docker → Status prüfen."
  echo "    → Prüfe ob compose.yml im docker/-Ordner existiert."
  echo
  pause_menu
}
