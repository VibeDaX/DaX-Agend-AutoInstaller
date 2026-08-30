#!/usr/bin/env bash
# =============================================================================
# TEST: WATCHDOG & AUTO-RECOVERY ENGINE
# =============================================================================
TEST_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "$TEST_DIR/.." && pwd)"
cd "$ROOT_DIR"

source "$TEST_DIR/test_helper.sh"
source "$ROOT_DIR/dax.sh"
set +e
set +E

test_suite_header "Watchdog & Health Auto-Recovery Engine"

it "Watchdog State-Datei & Format"
assert_file_exists "$WATCHDOG_FILE" "watchdog.json muss existieren"

it "Watchdog Tick-Mechanismus & Attempt-Zähler"
# Setze initial HEALTHY -> attempts=0
watchdog_tick "test_unit_service" "HEALTHY"
STATE_HEALTHY="$(python3 -c "
import json
with open('$WATCHDOG_FILE') as f: d=json.load(f)
print(d['test_unit_service']['last_status'], d['test_unit_service']['attempts'])
")"
assert_eq "HEALTHY 0" "$STATE_HEALTHY" "HEALTHY Status setzt attempts auf 0"

# Setze Fehler 1
watchdog_tick "test_unit_service" "STOPPED"
ATTEMPTS_1="$(python3 -c "
import json
with open('$WATCHDOG_FILE') as f: d=json.load(f)
print(d['test_unit_service']['attempts'])
")"
assert_eq "1" "$ATTEMPTS_1" "Erster Fehler erhöht attempts auf 1"

# Setze Fehler 2 & 3
watchdog_tick "test_unit_service" "STOPPED"
watchdog_tick "test_unit_service" "STOPPED"
ATTEMPTS_3="$(python3 -c "
import json
with open('$WATCHDOG_FILE') as f: d=json.load(f)
print(d['test_unit_service']['attempts'])
")"
assert_eq "3" "$ATTEMPTS_3" "Dritter Fehler erhöht attempts auf 3"

# Erneut HEALTHY -> Reset
watchdog_tick "test_unit_service" "HEALTHY"
ATTEMPTS_RESET="$(python3 -c "
import json
with open('$WATCHDOG_FILE') as f: d=json.load(f)
print(d['test_unit_service']['attempts'])
")"
assert_eq "0" "$ATTEMPTS_RESET" "Gesunder Status setzt attempts zuverlässig auf 0 zurück"

it "Watchdog-Recovery Logging"
watchdog_recover "test_unit_service"
assert_file_exists "$WATCHDOG_LOG" "watchdog.log muss existieren"
WATCHDOG_LOG_CONTENT="$(cat "$WATCHDOG_LOG")"
assert_match "test_unit_service" "$WATCHDOG_LOG_CONTENT" "watchdog.log protokolliert Recovery-Aktionen"

it "Watchdog Statusanzeige"
STATUS_OUTPUT="$(watchdog_status)"
assert_match "(RUNNING|STOPPED)" "$STATUS_OUTPUT" "watchdog_status gibt aktuellen Laufzeitstatus aus"
assert_match "test_unit_service" "$STATUS_OUTPUT" "watchdog_status gibt den State-JSON Inhalt wieder"

# Cleanup
python3 -c "
import json
with open('$WATCHDOG_FILE', 'r') as f: d=json.load(f)
if 'test_unit_service' in d: del d['test_unit_service']
with open('$WATCHDOG_FILE', 'w') as f: json.dump(d, f, indent=2)
" 2>/dev/null

test_module_summary
