#!/usr/bin/env bash
# =============================================================================
# DAX CONTROL PLANE — SECRETS MODULE (lib/secrets.sh)
# OpenSSL AES-256 GCM/CBC Crypto-Engine, Scoped Storage & Trap Cleanup
# =============================================================================
set -Eeuo pipefail

SECRETS_DIR="$STATE_DIR/secrets"
SECRETS_FILE="$SECRETS_DIR/secrets.json"
GLOBAL_SECRETS="$SECRETS_FILE"
AGENT_SECRETS_DIR="$SECRETS_DIR/agents"
REMOTE_SECRETS_DIR="$SECRETS_DIR/remote"
MASTER_KEY_FILE="$SECRETS_DIR/master.key"

ensure_master_key(){
  mkdir -p "$SECRETS_DIR"
  if [[ ! -f "$MASTER_KEY_FILE" || ! -s "$MASTER_KEY_FILE" ]]; then
    if command_exists openssl; then
      openssl rand -hex 32 > "$MASTER_KEY_FILE"
      chmod 600 "$MASTER_KEY_FILE" 2>/dev/null || true
      info "Neuer Master-Key generiert: $MASTER_KEY_FILE"
    else
      die "OpenSSL ist erforderlich für den Secrets Manager. Bitte installieren: apt install openssl"
    fi
  else
    chmod 600 "$MASTER_KEY_FILE" 2>/dev/null || true
  fi
}

secret_encrypt_value(){
  local raw_val="$1"
  ensure_master_key
  if command_exists openssl; then
    local enc
    enc=$(echo -n "$raw_val" | openssl enc -aes-256-cbc -pbkdf2 -salt -pass "file:$MASTER_KEY_FILE" -a -A 2>/dev/null)
    echo "enc:$enc"
  else
    echo "$raw_val"
  fi
}

secret_decrypt_value(){
  local val="$1"
  if [[ "$val" =~ ^enc: ]]; then
    local ciphertext="${val#enc:}"
    ensure_master_key
    if command_exists openssl; then
      echo -n "$ciphertext" | openssl enc -d -aes-256-cbc -pbkdf2 -salt -pass "file:$MASTER_KEY_FILE" -a -A 2>/dev/null || echo ""
    else
      echo "$ciphertext"
    fi
  else
    echo "$val"
  fi
}

secret_set(){
  local key="$1" val="$2" scope="${3:-global}" id="${4:-global}"
  ensure_master_key
  local target_file=""
  case "$scope" in
    global) target_file="$GLOBAL_SECRETS" ;;
    agent)  mkdir -p "$AGENT_SECRETS_DIR"; target_file="$AGENT_SECRETS_DIR/${id}.json" ;;
    remote) mkdir -p "$REMOTE_SECRETS_DIR"; target_file="$REMOTE_SECRETS_DIR/${id}.json" ;;
    *) warn "Ungültiger Secrets-Scope: $scope"; return 1 ;;
  esac

  if [[ ! -f "$target_file" ]]; then
    cat <<EOF > "$target_file"
{
  "version": 1,
  "scope": "$scope",
  "identifier": "$id",
  "secrets": {}
}
EOF
  fi

  local enc_val
  enc_val="$(secret_encrypt_value "$val")"

  python3 "$SCRIPT_DIR/lib/state_helper.py" json_set_secret \
    "$target_file" "$key" "$enc_val" 2>/dev/null
  ok "Secret $key verschlüsselt gespeichert (scope=$scope, identifier=$id)."
}

secret_get(){
  local key="$1" scope="${2:-global}" id="${3:-}"
  local target_file=""
  case "$scope" in
    global) target_file="$GLOBAL_SECRETS" ;;
    agent)
      [[ -n "$id" ]] || return 1
      target_file="$AGENT_SECRETS_DIR/${id}.json"
      ;;
    remote)
      [[ -n "$id" ]] || return 1
      target_file="$REMOTE_SECRETS_DIR/${id}.json"
      ;;
    *) return 1 ;;
  esac
  [[ -f "$target_file" ]] || return 0

  local enc_val
  enc_val="$(python3 "$SCRIPT_DIR/lib/state_helper.py" json_get_secret \
    "$target_file" "$key" 2>/dev/null)"

  if [[ -n "$enc_val" ]]; then
    secret_decrypt_value "$enc_val"
  fi
}

secret_get_envfile(){
  local scope="$1" id="$2"
  local target_file=""
  case "$scope" in
    agent)  target_file="$AGENT_SECRETS_DIR/${id}.json" ;;
    remote) target_file="$REMOTE_SECRETS_DIR/${id}.json" ;;
    global) target_file="$GLOBAL_SECRETS" ;;
  esac
  [[ -f "$target_file" ]] || return 0

  python3 "$SCRIPT_DIR/lib/state_helper.py" print_envfile \
    "$target_file" "$MASTER_KEY_FILE" 2>/dev/null
}

secret_inject_docker(){
  local scope="$1" id="$2"
  local tmp_env
  tmp_env="$(mktemp /tmp/dax-secrets-XXXXXX.env)"
  secret_get_envfile "$scope" "$id" > "$tmp_env"
  chmod 600 "$tmp_env"
  echo "$tmp_env"
}

cleanup_temp_secrets(){
  rm -f /tmp/dax-secrets-*.env 2>/dev/null || true
}

# Signal Trap Cleanup für flüchtige Env-Dateien
trap cleanup_temp_secrets EXIT INT TERM

secrets_manager(){
  ensure_master_key
  echo "=== SECRETS MANAGER (AES-256) ==="
  echo "Master-Key: $MASTER_KEY_FILE"
  echo "1) Secret setzen"
  echo "2) Secrets anzeigen (Entschlüsselt)"
  read -rp "Auswahl: " c
  case "$c" in
    1)
      read -rp "Key Name: " k
      read -rp "Wert: " v
      read -rp "Scope (global/agent/remote): " sc
      read -rp "Identifier (z.B. hermes/lab01): " id
      secret_set "$k" "$v" "${sc:-global}" "${id:-global}"
      ;;
    2)
      read -rp "Scope (global/agent/remote): " sc
      read -rp "Identifier: " id
      secret_get_envfile "${sc:-global}" "${id:-global}"
      ;;
  esac
}
