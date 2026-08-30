#!/usr/bin/env bash
# =============================================================================
# TEST: ENCRYPTED BACKUP & RESTORE MODULE
# =============================================================================
TEST_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "$TEST_DIR/.." && pwd)"
cd "$ROOT_DIR"

source "$TEST_DIR/test_helper.sh"
source "$ROOT_DIR/dax.sh"
set +e
set +E

test_suite_header "Encrypted Backup & Restore Engine (AES-256)"

it "Erstellung eines AES-256 verschlüsselten Backups"
BACKUP_FILE="$(backup_create 2>/dev/null | tail -n1)"
assert_file_exists "$BACKUP_FILE" "Verschlüsseltes Backup-Archiv muss existieren"
assert_match "\.tar\.gz\.enc$" "$BACKUP_FILE" "Backup-Dateiendung muss .tar.gz.enc lauten"

it "Backup-Auflistung (backup_list)"
LIST_OUTPUT="$(backup_list)"
assert_match "dax-backup-" "$LIST_OUTPUT" "backup_list zeigt erstelle Backup-Dateien an"

it "Entschlüsselung & Wiederherstellung (backup_restore)"
backup_restore "$BACKUP_FILE" >/dev/null 2>&1
assert_true $? "backup_restore beendet sich ohne Fehler"
assert_file_exists "$STATE_DIR/state.json" "state.json muss nach Restore existieren"

# Cleanup der Test-Backups
rm -f "$BACKUP_FILE"

test_module_summary
