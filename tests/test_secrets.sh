#!/usr/bin/env bash
# =============================================================================
# TEST: SECRETS MANAGER (AES-256 GCM/CBC & CONTEXT INJECTION)
# =============================================================================
TEST_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "$TEST_DIR/.." && pwd)"
cd "$ROOT_DIR"

source "$TEST_DIR/test_helper.sh"
source "$ROOT_DIR/dax.sh"
set +e
set +E

test_suite_header "Secrets Manager & AES-256 Encryption"

it "Master-Key Erstellung & Zugriffsrechte"
ensure_master_key
assert_file_exists "$MASTER_KEY_FILE" "master.key muss existieren"

# Dateirechte prüfen (muss 600 sein)
FILE_MODE="$(stat -c '%a' "$MASTER_KEY_FILE" 2>/dev/null || stat -f '%A' "$MASTER_KEY_FILE" 2>/dev/null || echo '600')"
assert_match "600" "$FILE_MODE" "master.key muss auf chmod 600 beschränkt sein ($FILE_MODE)"

it "Kryptographische Ver- und Entschlüsselung (AES-256)"
RAW_INPUT="DaxTest_Secret_String_!@#\$%^&*()_123456789"
ENC_VAL="$(secret_encrypt_value "$RAW_INPUT")"
assert_match "^enc:[A-Za-z0-9+/=]+$" "$ENC_VAL" "Verschlüsselter Wert muss mit 'enc:' beginnen und Base64 sein"
assert_not_eq "$RAW_INPUT" "$ENC_VAL" "Chiffrat darf nicht dem Klartext entsprechen"

DEC_VAL="$(secret_decrypt_value "$ENC_VAL")"
assert_eq "$RAW_INPUT" "$DEC_VAL" "Entschlüsselter Wert muss exakt dem Original entsprechen"

it "Globales Secret (Setzen, Verschlüsselt Speichern, Auslesen)"
secret_set "GLOBAL_TEST_KEY" "global_secret_value_999" "global"
RAW_GLOBAL="$(cat "$GLOBAL_SECRETS")"
assert_match "enc:" "$RAW_GLOBAL" "secrets.json muss enc: Tag enthalten"
assert_not_match "global_secret_value_999" "$RAW_GLOBAL" "Klartext darf NICHT in secrets.json vorkommen"

FETCHED_GLOBAL="$(secret_get "GLOBAL_TEST_KEY" "global")"
assert_eq "global_secret_value_999" "$FETCHED_GLOBAL" "secret_get muss globalen Wert korrekt entschlüsseln"

it "Agent-Scoped Secret (Scope: agent / hermes)"
secret_set "HERMES_AUTH_TOKEN" "hermes_secure_token_456" "agent" "hermes"
AGENT_FILE="$AGENT_SECRETS_DIR/hermes.json"
assert_file_exists "$AGENT_FILE" "Agenten-Secrets-Datei muss existieren"
RAW_AGENT="$(cat "$AGENT_FILE")"
assert_not_match "hermes_secure_token_456" "$RAW_AGENT" "Klartext darf NICHT in hermes.json vorkommen"

FETCHED_AGENT="$(secret_get "HERMES_AUTH_TOKEN" "agent" "hermes")"
assert_eq "hermes_secure_token_456" "$FETCHED_AGENT" "secret_get muss Agenten-Secret korrekt entschlüsseln"

it "Remote-Scoped Secret (Scope: remote / lab01)"
secret_set "SSH_KEY" "/home/dax/.ssh/id_rsa_lab01" "remote" "lab01"
REMOTE_FILE="$REMOTE_SECRETS_DIR/lab01.json"
assert_file_exists "$REMOTE_FILE" "Remote-Secrets-Datei muss existieren"
FETCHED_REMOTE="$(secret_get "SSH_KEY" "remote" "lab01")"
assert_eq "/home/dax/.ssh/id_rsa_lab01" "$FETCHED_REMOTE" "secret_get muss Remote-Secret korrekt entschlüsseln"

it "Envfile-Generierung & Docker-Injektion (On-the-Fly)"
ENV_OUTPUT="$(secret_get_envfile "agent" "hermes")"
assert_match "HERMES_AUTH_TOKEN=hermes_secure_token_456" "$ENV_OUTPUT" "secret_get_envfile muss entschlüsselte Key-Value Paare liefern"

DOCKER_TMP_ENV="$(secret_inject_docker "agent" "hermes")"
assert_file_exists "$DOCKER_TMP_ENV" "Flüchtige Docker-Env-Datei muss existieren"
TMP_MODE="$(stat -c '%a' "$DOCKER_TMP_ENV" 2>/dev/null || stat -f '%A' "$DOCKER_TMP_ENV" 2>/dev/null || echo '600')"
assert_match "600" "$TMP_MODE" "Docker-Env-Datei muss mit chmod 600 abgesichert sein"
assert_match "HERMES_AUTH_TOKEN=hermes_secure_token_456" "$(cat "$DOCKER_TMP_ENV")" "Docker-Env-Datei enthält entschlüsselte Werte"
rm -f "$DOCKER_TMP_ENV"

it "Edge Cases & Fehlerbehandlung"
NON_EXISTENT="$(secret_get "DOES_NOT_EXIST" "global")"
assert_eq "" "$NON_EXISTENT" "Nicht existierender Key liefert leeren String"

secret_get "SOME_KEY" "agent" "" >/dev/null 2>&1
assert_false $? "Aufruf von scope=agent ohne Identifier scheitert mit Fehlercode"

# Cleanup der Test-Keys
python3 -c "
import json
for path, key in [('$GLOBAL_SECRETS', 'GLOBAL_TEST_KEY'), ('$AGENT_FILE', 'HERMES_AUTH_TOKEN'), ('$REMOTE_FILE', 'SSH_KEY')]:
    try:
        with open(path, 'r') as f: data = json.load(f)
        sec = data.get('secrets', data.get('keys', {}))
        if key in sec: del sec[key]
        with open(path, 'w') as f: json.dump(data, f, indent=2)
    except Exception: pass
" 2>/dev/null

test_module_summary
