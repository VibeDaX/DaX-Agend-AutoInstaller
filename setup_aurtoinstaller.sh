#!/usr/bin/env bash

# System-Installer & Datei-Generator
echo "[+] Erstelle Projekt-Dokumentation und Startskript..."

# 1. README.md ERSTELLEN
cat << 'EOF' > README.md
# DAX Command Center - System Architecture

Willkommen beim Control Network für autonome Agenten und KI-GUIs.

## Quick Start
1. Machen Sie das Startskript ausführbar: `chmod +x start.sh`
2. Starten Sie das All-in-One Dashboard: `./start.sh`

## Enthaltene Komponenten
- **Agenten:** Hermes 2.0, OpenClaw, AntiGravity
- **GUIs:** ComfyUI, Open WebUI
- **Automation & Voice:** Node-RED, Faster-Whisper (STT)
- **Local LLM Engine:** Ollama Integration
EOF

# 2. CHANGELOG.md ERSTELLEN
cat << 'EOF' > CHANGELOG.md
# Changelog

## [v5.2 Ultimate All-in-One Edition] - 2026
### Hinzugefügt
- **Self-Healing Engine:** Automatische Fehlerbehebung bei fehlenden Berechtigungen, Pip-Fehlern und Paketkonflikten.
- **Node-RED Integration:** Globale Installation mit Whisper-Nodes für Workflow-Automation.
- **Faster-Whisper Subsystem:** CTranslate2 Backend-Unterstützung und Docker-API Container Startoption.
- **RAM Check Engine:** Automatische Hardware-Prüfung zur intelligenten Modell-Empfehlung für Ollama.
- **ZIP Backup Modul:** Integrierte Archivierungsfunktion (schließt VENVs und Log-Dateien aus).
- **Log Viewer:** Live-Stream des Protokolls `installation.log` direkt im Terminal.
EOF

# 3. DOCUMENTATION.md ERSTELLEN
cat << 'EOF' > DOCUMENTATION.md
# Dokumentation & Betriebs-Handbuch

## 1. Systemanforderungen
- **Betriebssystem:** Linux / WSL2 (Ubuntu/Debian empfohlen)
- **Pakete:** Git, Curl, Zip, Python3-venv, Node.js, NPM, FFmpeg
- **RAM-Empfehlungen für Ollama:**
  - `< 8 GB`: qwen2.5:1.5b, llama3.2:1b
  - `8 - 16 GB`: hermes3:8b, qwen2.5-coder:7b
  - `16 - 32 GB`: hermes3:8b, qwen2.5-coder:14b, deepseek-r1:14b
  - `> 32 GB`: qwen2.5:32b, llama3.3:70b

## 2. API-Key Konfiguration
Das System nutzt eine `.env` Datei im Haupt- und Workspace-Verzeichnis.
Unterstützte Schlüssel:
- `OPENAI_API_KEY`
- `ANTHROPIC_API_KEY`
- `OPENROUTER_API_KEY`

## 3. Ports & Schnittstellen
- **Node-RED:** `http://localhost:1880`
- **ComfyUI:** `http://localhost:8188`
- **Open WebUI:** `http://localhost:8080` (bzw. Port `3000` via Docker)
- **Faster-Whisper Docker API:** `http://localhost:8000`
EOF

# 4. START.SH ERSTELLEN (All-in-One Master Script v5.2)
cat << 'EOF' > start.sh
#!/usr/bin/env bash

# In das Ordnerverzeichnis wechseln
cd "$(dirname "$0")" || exit

# --- LOG-EINSTELLUNGEN ---
LOG_DIR="./logs"
LOG_FILE="$LOG_DIR/installation.log"
mkdir -p "$LOG_DIR"

log_message() {
    local level="$1"
    local message="$2"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message" >> "$LOG_FILE"
}

log_message "INFO" "=== Session gestartet (v5.2 Ultimate All-in-One Edition) ==="

# --- DYNAMISCHE PFADE & UMGUNGEN ---
VENV_HERMES=".hermesvenv"
VENV_OPENCLAW=".openclawvenv"
VENV_ANTIGRAVITY=".antigravityvenv"
VENV_COMFYUI=".comfyuivenv"
VENV_OPENWEBUI=".openwebuivenv"
VENV_WHISPER=".whispervenv"
LLAMA_CPP_DIR="./llama.cpp"
COMFYUI_DIR="./ComfyUI"

# --- COLOR THEME ---
CLR_BLUE="\033[38;2;0;210;255m"
CLR_BLUE_BOLD="\033[1;38;2;0;210;255m"
CLR_GOLD="\033[38;2;212;175;55m"
CLR_GOLD_BOLD="\033[1;38;2;212;175;55m"
CLR_RESET="\033[0m"
CLR_WHITE="\033[1;37m"
CLR_DIM="\033[2;37m"
CLR_GREEN="\033[38;2;0;255;127m"
CLR_RED="\033[38;2;255;69;0m"

# --- SELF-HEALING ENGINE WITH LOGGING ---
run_with_retry() {
    local cmd="$1"
    local max_retries=2
    local count=0
    local success=false

    log_message "EXEC" "Führe Befehl aus: $cmd"

    while [ $count -le $max_retries ] && [ "$success" = false ]; do
        LOGFILE_TMP=$(mktemp)
        eval "$cmd" > >(tee -a "$LOGFILE_TMP") 2>&1
        local status=$?

        cat "$LOGFILE_TMP" >> "$LOG_FILE"

        if [ $status -eq 0 ]; then
            success=true
            log_message "SUCCESS" "Befehl erfolgreich: $cmd"
            rm -f "$LOGFILE_TMP"
        else
            count=$((count + 1))
            local err_msg
            err_msg=$(tail -n 5 "$LOGFILE_TMP")
            log_message "ERROR" "Fehler (Versuch $count von $((max_retries + 1))): $cmd | $err_msg"

            echo -e "${CLR_GOLD}[!] FEHLER ERKANNT (Versuch $count von $((max_retries + 1))):${CLR_RESET}"
            echo "$err_msg"

            if grep -q "Permission denied" "$LOGFILE_TMP"; then
                echo -e "${CLR_BLUE}[REPARATUR] Setze Lese-/Schreibrechte...${CLR_RESET}"
                chmod -R 755 . 2>/dev/null
            elif grep -q "externally-managed-environment" "$LOGFILE_TMP"; then
                echo -e "${CLR_BLUE}[REPARATUR] Erneuere Pip-Umgebung...${CLR_RESET}"
                pip install --break-system-packages --upgrade pip setuptools 2>/dev/null
            elif grep -q "No matching distribution" "$LOGFILE_TMP" || grep -q "pip" "$LOGFILE_TMP"; then
                echo -e "${CLR_BLUE}[REPARATUR] Aktualisiere Pip & Build-Tools...${CLR_RESET}"
                python3 -m pip install --upgrade pip setuptools wheel 2>/dev/null
            elif grep -q "dpkg" "$LOGFILE_TMP" || grep -q "apt" "$LOGFILE_TMP"; then
                echo -e "${CLR_BLUE}[REPARATUR] Repariere Paket-Manager...${CLR_RESET}"
                sudo dpkg --configure -a 2>/dev/null
                sudo apt-get install -f -y 2>/dev/null
            else
                sleep 1
            fi

            rm -f "$LOGFILE_TMP"
            echo -e "${CLR_GOLD}[+] Wiederhole Befehl...${CLR_RESET}"
            sleep 2
        fi
    done

    if [ "$success" = false ]; then
        echo -e "${CLR_GOLD}[!] KRITISCHER FEHLER bei Befehl: $cmd${CLR_RESET}"
        log_message "FATAL" "Befehl fehlgeschlagen nach maximalen Versuchen: $cmd"
        return 1
    fi
}

# --- STATUS DASHBOARD ENGINE ---
check_status() {
    HERMES_ST="${CLR_RED}✖ FEHLT${CLR_RESET}"
    OPENCLAW_ST="${CLR_RED}✖ FEHLT${CLR_RESET}"
    ANTIGRAV_ST="${CLR_RED}✖ FEHLT${CLR_RESET}"
    COMFY_ST="${CLR_RED}✖ FEHLT${CLR_RESET}"
    WEBUI_ST="${CLR_RED}✖ FEHLT${CLR_RESET}"
    NODERED_ST="${CLR_RED}✖ FEHLT${CLR_RESET}"
    WHISPER_ST="${CLR_RED}✖ FEHLT${CLR_RESET}"

    [ -d "$VENV_HERMES" ] && HERMES_ST="${CLR_GREEN}✔ BEREIT${CLR_RESET}"
    [ -d "$VENV_OPENCLAW" ] && OPENCLAW_ST="${CLR_GREEN}✔ BEREIT${CLR_RESET}"
    [ -d "$VENV_ANTIGRAVITY" ] && ANTIGRAV_ST="${CLR_GREEN}✔ BEREIT${CLR_RESET}"
    [ -d "$VENV_COMFYUI" ] && COMFY_ST="${CLR_GREEN}✔ INSTALLED${CLR_RESET}"
    [ -d "$VENV_OPENWEBUI" ] && WEBUI_ST="${CLR_GREEN}✔ INSTALLED${CLR_RESET}"
    [ -d "$VENV_WHISPER" ] && WHISPER_ST="${CLR_GREEN}✔ INSTALLED${CLR_RESET}"
    command -v node-red &> /dev/null && NODERED_ST="${CLR_GREEN}✔ INSTALLED${CLR_RESET}"

    OLLAMA_ST="${CLR_RED}✖ NEIN${CLR_RESET}"
    DOCKER_ST="${CLR_RED}✖ NEIN${CLR_RESET}"

    if command -v ollama &> /dev/null; then
        pgrep -x "ollama" &> /dev/null && OLLAMA_ST="${CLR_GREEN}✔ LÄUFT${CLR_RESET}" || OLLAMA_ST="${CLR_GOLD}⚠ GESTOPPT${CLR_RESET}"
    fi

    if command -v docker &> /dev/null; then
        docker info &> /dev/null && DOCKER_ST="${CLR_GREEN}✔ AKTIV${CLR_RESET}" || DOCKER_ST="${CLR_GOLD}⚠ NO-DAEMON${CLR_RESET}"
    fi
}

draw_banner() {
    clear
    check_status
    echo -e "${CLR_BLUE}╔════════════════════════════════════════════════════════════════════════════════════════╗${CLR_RESET}"
    echo -e "${CLR_BLUE}║${CLR_RESET} ${CLR_GOLD_BOLD}██████╗  █████╗ ██╗  ██╗    █████╗ ██╗  ██╗████████╗██████╗ ${CLR_RESET}                     ${CLR_BLUE}║${CLR_RESET}"
    echo -e "${CLR_BLUE}║${CLR_RESET} ${CLR_GOLD_BOLD}██╔══██╗██╔══██╗╚██╗██╔╝   ██╔══██╗██║  ██║╚══██╔══╝██╔══██╗${CLR_RESET}                     ${CLR_BLUE}║${CLR_RESET}"
    echo -e "${CLR_BLUE}║${CLR_RESET} ${CLR_GOLD_BOLD}██║  ██║███████║ ╚███╔╝    ███████║██║  ██║   ██║   ██║  ██║${CLR_RESET}                     ${CLR_BLUE}║${CLR_RESET}"
    echo -e "${CLR_BLUE}║${CLR_RESET} ${CLR_GOLD_BOLD}██║  ██║██╔══██║ ██╔██╗    ██╔══██║██║  ██║   ██║   ██║  ██║${CLR_RESET}                     ${CLR_BLUE}║${CLR_RESET}"
    echo -e "${CLR_BLUE}║${CLR_RESET} ${CLR_GOLD_BOLD}██████╔╝██║  ██║██╔╝ ██╗   ██║  ██║╚█████╔╝   ██║   ██████╔╝${CLR_RESET}                     ${CLR_BLUE}║${CLR_RESET}"
    echo -e "${CLR_BLUE}║${CLR_RESET} ${CLR_GOLD_BOLD}╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝   ╚═╝  ╚═╝ ╚════╝    ╚═╝   ╚═════╝ ${CLR_RESET}                     ${CLR_BLUE}║${CLR_RESET}"
    echo -e "${CLR_BLUE}╠════════════════════════════════════════════════════════════════════════════════════════╣${CLR_RESET}"
    echo -e "${CLR_BLUE}║${CLR_RESET} ${CLR_GOLD_BOLD}AGENTEN:${CLR_RESET} Hermes: $HERMES_ST ${CLR_BLUE}│${CLR_RESET} OpenClaw: $OPENCLAW_ST ${CLR_BLUE}│${CLR_RESET} AntiGravity: $ANTIGRAV_ST         ${CLR_BLUE}║${CLR_RESET}"
    echo -e "${CLR_BLUE}║${CLR_RESET} ${CLR_GOLD_BOLD}GUIS & STT:${CLR_RESET} ComfyUI: $COMFY_ST ${CLR_BLUE}│${CLR_RESET} Open WebUI: $WEBUI_ST ${CLR_BLUE}│${CLR_RESET} Node-RED: $NODERED_ST         ${CLR_BLUE}║${CLR_RESET}"
    echo -e "${CLR_BLUE}║${CLR_RESET} ${CLR_GOLD_BOLD}AUDIO & LLM:${CLR_RESET} Faster-Whisper: $WHISPER_ST ${CLR_BLUE}│${CLR_RESET} Ollama: $OLLAMA_ST ${CLR_BLUE}│${CLR_RESET} Docker: $DOCKER_ST ${CLR_BLUE}║${CLR_RESET}"
    echo -e "${CLR_BLUE}╠════════════════════════════════════════════════════════════════════════════════════════╣${CLR_RESET}"
    echo -e "${CLR_BLUE}║${CLR_RESET} ${CLR_GOLD_BOLD}DEVELOPER:${CLR_RESET} ${CLR_WHITE}DAX / War Room Command Network${CLR_RESET}  ${CLR_BLUE}│${CLR_RESET} ${CLR_GOLD_BOLD}VERSION:${CLR_RESET} ${CLR_WHITE}v5.2 Ultimate${CLR_RESET}            ${CLR_BLUE}║${CLR_RESET}"
    echo -e "${CLR_BLUE}╚════════════════════════════════════════════════════════════════════════════════════════╝${CLR_RESET}"
}

draw_box() {
    local text="$1"
    echo -e "${CLR_BLUE}╔════════════════════════════════════════════════════════════════════════════════════════╗${CLR_RESET}"
    printf "${CLR_BLUE}║${CLR_RESET} ${CLR_GOLD_BOLD}%-84s${CLR_RESET} ${CLR_BLUE}║${CLR_RESET}\n" "$text"
    echo -e "${CLR_BLUE}╚════════════════════════════════════════════════════════════════════════════════════════╝${CLR_RESET}"
}

ensure_venv() {
    local venv_target="$1"
    if [ ! -d "$venv_target" ]; then
        echo -e "${CLR_BLUE}[SYSTEM]${CLR_RESET} Erstelle VENV '${CLR_GOLD}$venv_target${CLR_RESET}'..."
        run_with_retry "python3 -m venv $venv_target"
    fi
    source "$venv_target/bin/activate"
}

pause_and_continue() {
    echo ""
    echo -ne "${CLR_DIM}Drücke [ENTER] um ins Hauptmenü zurückzukehren...${CLR_RESET}"
    read -r
}

create_project_zip() {
    draw_box "ZIP-ARCHIV ERSTELLEN"
    local timestamp
    timestamp=$(date '+%Y%m%d_%H%M%S')
    local zip_name="dax_command_center_${timestamp}.zip"

    echo -e "${CLR_BLUE}[+] Erstelle Zip-Archiv aller Konfigurationen und Skripte...${CLR_RESET}"
    run_with_retry "zip -r '$zip_name' . -x '.*venv*' -x 'ComfyUI/models/*' -x 'logs/*' -x '*.zip'"

    if [ -f "$zip_name" ]; then
        echo -e "\n${CLR_GOLD_BOLD}[✔] Archiv erfolgreich erstellt: ${CLR_WHITE}$zip_name${CLR_RESET}"
        log_message "INFO" "Zip-Archiv erstellt: $zip_name"
    else
        echo -e "\n${CLR_RED}[!] Erstellung des Zip-Archivs fehlgeschlagen.${CLR_RESET}"
    fi
}

manage_automation_and_speech() {
    draw_box "AUTOMATION & SPEECH-TO-TEXT (NODE-RED & FASTER-WHISPER)"
    echo -e "${CLR_WHITE} [1] Node-RED Installieren (Global via NPM)${CLR_RESET}"
    echo -e "${CLR_WHITE} [2] Node-RED Starten (HTTP://LOCALHOST:1880)${CLR_RESET}"
    echo -e "${CLR_WHITE} [3] Faster-Whisper Python-Engine Installieren${CLR_RESET}"
    echo -e "${CLR_WHITE} [4] Whisper CLI Transkriptions-Test ausführen${CLR_RESET}"
    echo -e "${CLR_WHITE} [5] Faster-Whisper via Docker Container starten${CLR_RESET}"
    echo ""
    echo -ne "${CLR_BLUE_BOLD}Wähle eine Aktion [1-5]: ${CLR_RESET}"
    read -r AUTO_CHOICE

    case $AUTO_CHOICE in
        1)
            run_with_retry "sudo npm install -g --unsafe-perm node-red"
            mkdir -p ~/.node-red && cd ~/.node-red || exit
            run_with_retry "npm install node-red-contrib-whisper node-red-contrib-speech-to-text-ubos --save"
            cd - || exit
            ;;
        2) node-red ;;
        3)
            ensure_venv "$VENV_WHISPER"
            run_with_retry "pip install --upgrade pip setuptools wheel"
            run_with_retry "pip install faster-whisper openai-whisper ffmpeg-python"
            ;;
        4)
            ensure_venv "$VENV_WHISPER"
            read -rp "Pfad zur Audio-Datei: " AUDIO_FILE
            [ -f "$AUDIO_FILE" ] && python3 -c "
from faster_whisper import WhisperModel
model = WhisperModel('base', device='cpu', compute_type='int8')
segments, info = model.transcribe('$AUDIO_FILE')
for segment in segments:
    print('[%.2fs -> %.2fs] %s' % (segment.start, segment.end, segment.text))
"
            ;;
        5) run_with_retry "docker run -d -p 8000:8000 --name faster-whisper-api fedora6/faster-whisper-server:latest" ;;
    esac
}

manage_web_guis() {
    draw_box "WEB UI & GENERATION ENGINES (COMFYUI & OPEN WEBUI)"
    echo -e "${CLR_WHITE} [1] ComfyUI Installieren${CLR_RESET}"
    echo -e "${CLR_WHITE} [2] ComfyUI Starten (HTTP://LOCALHOST:8188)${CLR_RESET}"
    echo -e "${CLR_WHITE} [3] Open WebUI Installieren${CLR_RESET}"
    echo -e "${CLR_WHITE} [4] Open WebUI Starten (HTTP://LOCALHOST:8080)${CLR_RESET}"
    echo -e "${CLR_WHITE} [5] Open WebUI via Docker starten${CLR_RESET}"
    echo ""
    echo -ne "${CLR_BLUE_BOLD}Wähle eine Aktion [1-5]: ${CLR_RESET}"
    read -r GUI_CHOICE

    case $GUI_CHOICE in
        1)
            [ ! -d "$COMFYUI_DIR" ] && run_with_retry "git clone https://github.com/comfyanonymous/ComfyUI.git $COMFYUI_DIR"
            ensure_venv "$VENV_COMFYUI"
            cd "$COMFYUI_DIR" || exit
            run_with_retry "pip install -r requirements.txt"
            cd ..
            ;;
        2) ensure_venv "$VENV_COMFYUI"; cd "$COMFYUI_DIR" || exit; python3 main.py --listen 127.0.0.1 --port 8188; cd .. ;;
        3) ensure_venv "$VENV_OPENWEBUI"; run_with_retry "pip install open-webui" ;;
        4) ensure_venv "$VENV_OPENWEBUI"; open-webui serve ;;
        5) run_with_retry "docker run -d -p 3000:8080 --add-host=host.docker.internal:host-gateway -v open-webui:/app/backend/data --name open-webui --restart always ghcr.io/open-webui/open-webui:main" ;;
    esac
}

pull_ollama_models_with_ram_check() {
    draw_box "OLLAMA MODEL DOWNLOADER (INTELLIGENT RAM CHECK)"
    TOTAL_RAM_GB=$(free -g | awk '/^Mem:/ {print $2}')
    echo -e "System RAM: ${CLR_GOLD_BOLD}${TOTAL_RAM_GB} GB${CLR_RESET}\n"

    if [ "$TOTAL_RAM_GB" -lt 8 ]; then
        echo -e " [1] qwen2.5:1.5b  [2] llama3.2:1b  [3] hermes3:8b"
    elif [ "$TOTAL_RAM_GB" -lt 16 ]; then
        echo -e " [1] hermes3:8b  [2] qwen2.5-coder:7b  [3] llama3.1:8b"
    else
        echo -e " [1] hermes3:8b  [2] qwen2.5-coder:14b  [3] deepseek-r1:14b"
    fi
    echo -e " [4] Manuell eingeben"
    read -rp "Wahl: " MODEL_CHOICE

    SELECTED_MODEL=""
    [ "$MODEL_CHOICE" -eq 1 ] && SELECTED_MODEL="hermes3:8b"
    [ "$MODEL_CHOICE" -eq 4 ] && read -rp "Modellname: " SELECTED_MODEL
    [ -n "$SELECTED_MODEL" ] && run_with_retry "ollama pull $SELECTED_MODEL"
}

manage_env_keys() {
    draw_box "API-KEY MANAGER & .ENV EDITOR"
    local env_file=".env"
    [ ! -f "$env_file" ] && touch "$env_file"
    read -rp "1) OpenAI  2) Anthropic  3) OpenRouter: " KCHOICE
    read -rp "Key-Wert eingeben: " KVAL
    case $KCHOICE in
        1) echo "OPENAI_API_KEY=\"$KVAL\"" >> "$env_file" ;;
        2) echo "ANTHROPIC_API_KEY=\"$KVAL\"" >> "$env_file" ;;
        3) echo "OPENROUTER_API_KEY=\"$KVAL\"" >> "$env_file" ;;
    esac
}

while true; do
    draw_banner
    echo -e " [0] KI-Agenten Starten (Hermes, OpenClaw, AntiGravity)"
    echo -e " [1] System-Abhängigkeiten installieren"
    echo -e " [2] Agenten Installieren"
    echo -e " [3] Ollama Setup & RAM-Abfrage Modell-Pull"
    echo -e " [4] Web GUIs (ComfyUI & Open WebUI)"
    echo -e " [5] Automation & Speech (Node-RED & Whisper)"
    echo -e " [6] API-Key Manager (.env)"
    echo -e " [7] Live Log-Viewer"
    echo -e " [8] VENVs Bereinigen"
    echo -e " [9] ZIP-Archiv des Projekts erstellen"
    echo -e " [10] Beenden"
    echo ""
    read -rp "Auswahl [0-10]: " CHOICE

    case $CHOICE in
        0)
            ensure_venv "$VENV_HERMES"; hermes
            pause_and_continue
            ;;
        1)
            sudo apt update && sudo apt install -y git curl zip build-essential python3-venv python3-pip nodejs npm ffmpeg
            pause_and_continue
            ;;
        2)
            ensure_venv "$VENV_HERMES"
            run_with_retry "pip install hermes-agent"
            pause_and_continue
            ;;
        3) pull_ollama_models_with_ram_check; pause_and_continue ;;
        4) manage_web_guis; pause_and_continue ;;
        5) manage_automation_and_speech; pause_and_continue ;;
        6) manage_env_keys; pause_and_continue ;;
        7) tail -n 35 -f "$LOG_FILE"; pause_and_continue ;;
        8) rm -rf .*venv*; echo "Umgebungen gelöscht."; pause_and_continue ;;
        9) create_project_zip; pause_and_continue ;;
        10) exit 0 ;;
    esac
done
EOF

# 5. BERECHTIGUNGEN SETZEN
chmod +x start.sh

echo "[✔] Fertig! Folgende Dateien wurden erfolgreich generiert:"
echo "    - README.md"
echo "    - CHANGELOG.md"
echo "    - DOCUMENTATION.md"
echo "    - start.sh (ausführbar gemacht)"
