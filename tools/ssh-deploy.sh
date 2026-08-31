#!/usr/bin/env bash
# =============================================================================
# DAX SSH DEPLOY — Universal SSH Key Discovery & Deploy Tool
# Features: Network Scan, Auto-Detection, Collect-First-Deploy-Later
# =============================================================================
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SCRIPT_DIR"

# Colors
CLR_BLUE=$'\033[38;2;0;210,255m'; CLR_GOLD=$'\033[38;2;212;175;55m'
CLR_GREEN=$'\033[38;2;0;255;127m'; CLR_RED=$'\033[38;2;255;69;0m'
CLR_WHITE=$'\033[1;37m'; CLR_DIM=$'\033[2;37m'; CLR_RESET=$'\033[0m'

log_ok()   { echo -e "${CLR_GREEN}[✓]${CLR_RESET} $*"; }
log_info() { echo -e "${CLR_BLUE}[→]${CLR_RESET} $*"; }
log_warn() { echo -e "${CLR_GOLD}[!]${CLR_RESET} $*"; }
log_err()  { echo -e "${CLR_RED}[✗]${CLR_RESET} $*" >&2; }
log_hdr()  { echo -e "\n${CLR_WHITE}$*${CLR_RESET}"; }

# ─── SSH Config ───
SSH_DIR="${HOME}/.ssh"
CONFIG_FILE="${SSH_DIR}/config"
IDENTITY_FILE="${SSH_DIR}/id_ed25519"
HOSTS_FILE="${SCRIPT_DIR}/.dax/ssh_hosts.yaml"
COLLECTED_FILE="/tmp/dax_ssh_collected_$$.json"

# ─── Common Users to try ───
COMMON_USERS=("root" "dax" "admin" "user" "ubuntu" "pi" "ubuntu" "operator")

# ─── State ───
declare -a DISCOVERED_HOSTS=()

# ════════════════════════════════════════════════════════════════════════════
# PHASE 1: DISCOVERY
# ════════════════════════════════════════════════════════════════════════════

detect_networks() {
    log_hdr "╔════════════════════════════════════════════════════════════╗"
    log_hdr "║           PHASE 1: NETZWERK & GERÄTE ERKENNUNG             ║"
    log_hdr "╚════════════════════════════════════════════════════════════╝"
    echo ""

    local interfaces
    interfaces=$(ip -4 addr show 2>/dev/null | grep -E 'inet ' | grep -v '127.0.0.1' || true)

    if [[ -z "$interfaces" ]]; then
        log_warn "Keine Netzwerkschnittstellen gefunden."
        return 1
    fi

    log_info "Erkannte Netzwerkschnittstellen:"
    echo "$interfaces" | while read -r line; do
        local ip cidr netmask
        ip=$(echo "$line" | awk '{print $2}' | cut -d/ -f1)
        cidr=$(echo "$line" | awk '{print $2}' | cut -d/ -f2)
        log_info "  ${CLR_WHITE}${ip}/${cidr}${CLR_RESET}"
    done
}

scan_network() {
    local network="$1"
    local port="${2:-22}"
    local timeout="${3:-2}"

    log_info "Scanne ${network}:${port} (Timeout: ${timeout}s)..."

    # Use nmap if available, fallback to ping sweep + nc
    if command -v nmap >/dev/null 2>&1; then
        nmap -p "$port" --open -T4 --max-retries 1 --host-timeout "${timeout}s" \
            "$network" 2>/dev/null | grep -E 'scan report|open' | paste - - | \
        while read -r line; do
            local host
            host=$(echo "$line" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | head -1)
            [[ -n "$host" ]] && echo "$host"
        done
    else
        # Fallback: ping sweep + port check
        local base_net
        base_net=$(echo "$network" | cut -d/ -f1 | cut -d. -f1-3)
        for i in $(seq 1 254); do
            local host="${base_net}.${i}"
            (
                if nc -z -w "$timeout" "$host" "$port" 2>/dev/null; then
                    echo "$host"
                fi
            ) &
        done
        wait
    fi
}

detect_ssh_user() {
    local host="$1"
    local port="${2:-22}"

    # Try key-based auth first with common users
    for user in "${COMMON_USERS[@]}"; do
        if ssh -o ConnectTimeout=3 -o BatchMode=yes -o StrictHostKeyChecking=no \
            -i "$IDENTITY_FILE" -p "$port" "${user}@${host}" "echo ok" 2>/dev/null | grep -q "ok"; then
            echo "$user"
            return 0
        fi
    done
    return 1
}

probe_host() {
    local host="$1"
    local port="$2"

    local os_info="unknown"
    local hostname="unknown"

    # Try to get hostname
    hostname=$(ssh -o ConnectTimeout=3 -o BatchMode=yes -o StrictHostKeyChecking=no \
        -i "$IDENTITY_FILE" -p "$port" "${3}@${host}" "hostname" 2>/dev/null || echo "unknown")

    # Try to detect OS
    os_info=$(ssh -o ConnectTimeout=3 -o BatchMode=yes -o StrictHostKeyChecking=no \
        -i "$IDENTITY_FILE" -p "$port" "${3}@${host}" \
        "cat /etc/os-release 2>/dev/null | grep ^ID= | cut -d= -f2 || echo unknown" 2>/dev/null || echo "unknown")

    echo "{\"host\":\"$host\",\"port\":\"$port\",\"user\":\"$3\",\"hostname\":\"$hostname\",\"os\":\"$os_info\"}"
}

interactive_add_host() {
    log_hdr "Manuelles Gerät hinzufügen"
    echo ""
    local name hn user port netz
    read -rp "  Alias (z.B. 'server01'): " name
    [[ -z "$name" ]] && { log_warn "Abgebrochen."; return 1; }
    read -rp "  Hostname/IP: " hn
    [[ -z "$hn" ]] && { log_warn "Abgebrochen."; return 1; }
    read -rp "  User [root]: " user
    user="${user:-root}"
    read -rp "  Port [22]: " port
    port="${port:-22}"
    read -rp "  Netzwerk [LAN]: " netz
    netz="${netz:-LAN}"

    echo "${name}|${hn}|${user}|${port}|${netz}"
}

collect_phase() {
    log_hdr "╔════════════════════════════════════════════════════════════╗"
    log_hdr "║              SAMMELPHASE — Geräte erfassen                 ║"
    log_hdr "╚════════════════════════════════════════════════════════════╝"
    echo ""

    DISCOVERED_HOSTS=()

    # Option 1: Auto-discovery
    echo "[1] Netzwerk-Scan (automatische Erkennung)"
    echo "[2] Manuell Geräte eingeben"
    echo "[3] Beides (Scan + manuell)"
    echo "[4] Abbrechen"
    echo ""
    read -rp "Auswahl [1-4]: " mode

    case "$mode" in
        1|3)
            echo ""
            read -rp "Netzwerk-Range (z.B. 192.168.1.0/24): " net_range
            [[ -n "$net_range" ]] && {
                local found_hosts
                found_hosts=$(scan_network "$net_range" 22 2 | sort -t. -k4 -n | uniq)

                if [[ -z "$found_hosts" ]]; then
                    log_warn "Keine Hosts mit offenem SSH-Port gefunden."
                else
                    log_ok "Gefundene Hosts:"
                    echo "$found_hosts" | while read -r host; do
                        log_info "  ${CLR_WHITE}${host}${CLR_RESET}"
                    done
                fi

                # For each found host, detect user
                echo "$found_hosts" | while read -r host; do
                    [[ -z "$host" ]] && continue
                    log_info "Teste ${host}..."
                    local detected_user
                    detected_user=$(detect_ssh_user "$host" 22)
                    if [[ -n "$detected_user" ]]; then
                        log_ok "  ${host}: User '${detected_user}' (Key-Auth möglich)"
                        local probe
                        probe=$(probe_host "$host" 22 "$detected_user")
                        DISCOVERED_HOSTS+=("$probe")
                        echo "$probe" >> "$COLLECTED_FILE"
                    else
                        log_warn "  ${host}: Kein Key-Auth möglich (manuelle Eingabe nötig)"
                    fi
                done
            }
            ;;
    esac

    if [[ "$mode" == "2" || "$mode" == "3" ]]; then
        echo ""
        while true; do
            local entry
            entry=$(interactive_add_host) || break
            [[ -z "$entry" ]] && break

            IFS='|' read -r name hn user port netz <<< "$entry"
            local probe="{\"host\":\"$hn\",\"port\":\"$port\",\"user\":\"$user\",\"hostname\":\"$name\",\"os\":\"unknown\"}"
            echo "$probe" >> "$COLLECTED_FILE"
            log_ok "Gesammelt: ${CLR_WHITE}${name}${CLR_RESET} (${user}@${hn}:${port})"

            read -rp "Weiteres Gerät? [y/N]: " more
            [[ "$more" != "y" && "$more" != "Y" ]] && break
        done
    fi

    # Show summary
    if [[ -f "$COLLECTED_FILE" ]]; then
        echo ""
        log_hdr "╔════════════════════════════════════════════════════════════╗"
        log_hdr "║              GESAMMELTE GERÄTE — Übersicht                 ║"
        log_hdr "╚════════════════════════════════════════════════════════════╝"
        echo ""

        local count=0
        while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            count=$((count + 1))
            local hn port user hostname
            hn=$(echo "$line" | grep -oE '"host":"[^"]+"' | cut -d'"' -f4)
            port=$(echo "$line" | grep -oE '"port":"[^"]+"' | cut -d'"' -f4)
            user=$(echo -e "${CLR_DIM}$(echo "$line" | grep -oE '"user":"[^"]+"' | cut -d'"' -f4)${CLR_RESET}")
            hostname=$(echo "$line" | grep -oE '"hostname":"[^"]+"' | cut -d'"' -f4)
            printf "  ${CLR_WHITE}%2d.${CLR_RESET} %-15s → %s@%s:%s\n" \
                "$count" "$hostname" "$user" "$hn" "$port"
        done < "$COLLECTED_FILE"
        echo ""
        log_ok "${count} Geräte gesammelt."
        return 0
    else
        log_warn "Keine Geräte gesammelt."
        return 1
    fi
}

# ════════════════════════════════════════════════════════════════════════════
# PHASE 2: DEPLOY
# ════════════════════════════════════════════════════════════════════════════

ensure_key() {
    if [[ -f "$IDENTITY_FILE" ]]; then
        log_ok "SSH-Schlüssel vorhanden: ${IDENTITY_FILE}"
        return 0
    fi

    log_warn "Kein SSH-Schlüssel gefunden."
    read -rp "Schlüssel generieren? [Y/n]: " ans
    [[ "$ans" == "n" || "$ans" == "N" ]] && { log_err "Abgebrochen."; return 1; }

    mkdir -p "$SSH_DIR" && chmod 700 "$SSH_DIR"
    ssh-keygen -t ed25519 -f "$IDENTITY_FILE" -N "" -C "dax-deploy-$(date +%Y%m%d)" 2>/dev/null
    chmod 600 "$IDENTITY_FILE"
    log_ok "Schlüssel generiert: ${IDENTITY_FILE}"
}

deploy_keys_to_host() {
    local host="$1"
    local port="$2"
    local user="$3"
    local name="$4"

    if [[ ! -f "${IDENTITY_FILE}.pub" ]]; then
        log_err "Kein Public-Key gefunden."
        return 1
    fi

    log_info "→ ${name} (${user}@${host}:${port})"

    local output
    output=$(ssh-copy-id -o ConnectTimeout=10 \
        -i "${IDENTITY_FILE}.pub" -p "${port}" "${user}@${host}" 2>&1)

    if [[ $? -eq 0 ]]; then
        log_ok "Key deployed: ${name}"
        return 0
    else
        log_err "Key deploy fehlgeschlagen: ${name}"
        log_err "  ${output}"
        return 1
    fi
}

generate_ssh_config() {
    local config_content=""

    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        local hn port user hostname
        hn=$(echo "$line" | grep -oE '"host":"[^"]+"' | cut -d'"' -f4)
        port=$(echo "$line" | grep -oE '"port":"[^"]+"' | cut -d'"' -f4)
        user=$(echo "$line" | grep -oE '"user":"[^"]+"' | cut -d'"' -f4)
        hostname=$(echo "$line" | grep -oE '"hostname":"[^"]+"' | cut -d'"' -f4)

        config_content+="Host ${hostname}
    HostName ${hn}
    User ${user}
    Port ${port}
    IdentityFile ${IDENTITY_FILE}
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null

"
    done < "$COLLECTED_FILE"

    echo "$config_content"
}

deploy_phase() {
    log_hdr "╔════════════════════════════════════════════════════════════╗"
    log_hdr "║              DEPLOYPHASE — Keys verteilen                  ║"
    log_hdr "╚════════════════════════════════════════════════════════════╝"
    echo ""

    if [[ ! -f "$COLLECTED_FILE" ]]; then
        log_err "Keine gesammelten Geräte. Bitte zuerst Phase 1 ausführen."
        return 1
    fi

    ensure_key || return 1

    echo ""
    echo "Deploy-Optionen:"
    echo "[1] Nur SSH-Config generieren (keine Keys deployen)"
    echo "[2] Nur Keys deployen (Config existiert bereits)"
    echo "[3] Beides (Config + Keys)"
    echo "[4] Abbrechen"
    echo ""
    read -rp "Auswahl [1-4]: " deploy_mode

    case "$deploy_mode" in
        1|3)
            echo ""
            local config_content
            config_content=$(generate_ssh_config)

            echo "━━━ Vorschau SSH-Config ━━━"
            echo "$config_content"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo ""
            read -rp "Config speichern nach ${CONFIG_FILE}? [Y/n]: " confirm
            if [[ "$confirm" != "n" && "$confirm" != "N" ]]; then
                mkdir -p "$SSH_DIR"
                [[ -f "$CONFIG_FILE" ]] && cp "$CONFIG_FILE" "${CONFIG_FILE}.bak.$(date +%Y%m%d%H%M%S)"
                echo "$config_content" > "$CONFIG_FILE"
                chmod 600 "$CONFIG_FILE"
                log_ok "SSH-Config gespeichert: ${CONFIG_FILE}"
            fi
            ;;
    esac

    case "$deploy_mode" in
        2|3)
            echo ""
            log_info "Starte Key-Deployment..."
            echo ""

            local success=0 failed=0
            while IFS= read -r line; do
                [[ -z "$line" ]] && continue
                local hn port user hostname
                hn=$(echo "$line" | grep -oE '"host":"[^"]+"' | cut -d'"' -f4)
                port=$(echo "$line" | grep -oE '"port":"[^"]+"' | cut -d'"' -f4)
                user=$(echo "$line" | grep -oE '"user":"[^"]+"' | cut -d'"' -f4)
                hostname=$(echo "$line" | grep -oE '"hostname":"[^"]+"' | cut -d'"' -f4)

                if deploy_keys_to_host "$hn" "$port" "$user" "$hostname"; then
                    success=$((success + 1))
                else
                    failed=$((failed + 1))
                fi
            done < "$COLLECTED_FILE"

            echo ""
            log_ok "Deploy abgeschlossen: ${success} OK, ${failed} fehlgeschlagen"
            ;;
    esac

    # Save to hosts file for DAX
    cp "$COLLECTED_FILE" "$HOSTS_FILE" 2>/dev/null || true
}

# ════════════════════════════════════════════════════════════════════════════
# MAIN MENU
# ════════════════════════════════════════════════════════════════════════════

pause_menu() {
    echo ""
    read -rp "Drücke Enter um fortzufahren..."
}

menu_ssh_deploy() {
    while true; do
        clear 2>/dev/null || true
        echo -e "${CLR_BLUE}╔════════════════════════════════════════════════════════════╗${CLR_RESET}"
        echo -e "${CLR_BLUE}║${CLR_GOLD}           [7] SSH DEPLOY — Universal Tool             ${CLR_BLUE}║${CLR_RESET}"
        echo -e "${CLR_BLUE}╚════════════════════════════════════════════════════════════╝${CLR_RESET}"
        echo ""
        echo "[1] Phase 1: Geräte erfassen (Scan + Manuell)"
        echo "[2] Phase 2: Keys deployen + SSH-Config"
        echo "[3] Beides (Phase 1 → Phase 2)"
        echo "[4] Netzwerk-Scan only"
        echo "[5] Bestehende Hosts anzeigen"
        echo "[6] SSH-Config anzeigen"
        echo "[7] Zurück ins Hauptmenü"
        echo ""
        read -rp "Auswahl [1-7]: " c
        clear 2>/dev/null || true

        case "$c" in
            1) collect_phase; pause_menu ;;
            2) deploy_phase; pause_menu ;;
            3) collect_phase && deploy_phase; pause_menu ;;
            4)
                read -rp "Netzwerk-Range (z.B. 192.168.1.0/24): " net_range
                [[ -n "$net_range" ]] && {
                    log_info "Scanne ${net_range}..."
                    scan_network "$net_range" 22 2 | sort -t. -k4 -n | uniq | while read -r host; do
                        log_ok "  ${host}:22 offen"
                    done
                }
                pause_menu
                ;;
            5)
                if [[ -f "$HOSTS_FILE" ]]; then
                    log_hdr "Gespeicherte SSH-Hosts:"
                    cat "$HOSTS_FILE"
                else
                    log_warn "Keine gespeicherten Hosts gefunden."
                fi
                pause_menu
                ;;
            6)
                if [[ -f "$CONFIG_FILE" ]]; then
                    echo "━━━ ${CONFIG_FILE} ━━━"
                    cat "$CONFIG_FILE"
                    echo "━━━━━━━━━━━━━━━━━━━━━━━"
                else
                    log_warn "Keine SSH-Config gefunden."
                fi
                pause_menu
                ;;
            7) return 0 ;;
            *) log_warn "Ungültige Auswahl."; sleep 1 ;;
        esac
    done
}

# Entry point
menu_ssh_deploy "$@"
