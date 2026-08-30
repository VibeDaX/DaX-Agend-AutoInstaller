#!/usr/bin/env bash
# =============================================================================
# TEST: VOLUME MANAGER
# =============================================================================
TEST_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "$TEST_DIR/.." && pwd)"
cd "$ROOT_DIR"

source "$TEST_DIR/test_helper.sh"
source "$ROOT_DIR/dax.sh"
set +e
set +E

test_suite_header "Volume Manager & Docker Mounts"

it "Volumes-Konfigurationsdatei"
assert_file_exists "$VOLUMES_FILE" "volumes.yaml muss existieren"

it "Volume-Bereitstellung (volume_ensure)"
volume_ensure "hermes_data" >/dev/null 2>&1
assert_true $? "volume_ensure hermes_data ist erfolgreich"

volume_ensure "openclaw_data" >/dev/null 2>&1
assert_true $? "volume_ensure openclaw_data ist erfolgreich"

volume_ensure "ollama_data" >/dev/null 2>&1
assert_true $? "volume_ensure ollama_data ist erfolgreich"

it "Docker-Mount-Parameter-Generierung (volume_mount_docker)"
HERMES_MOUNT="$(volume_mount_docker "hermes_data" 2>/dev/null | tail -n1)"
assert_eq "-v /var/lib/dax/hermes:/opt/hermes_data:rw" "$HERMES_MOUNT" "hermes_data erzeugt korrekten Docker Bind-Mount Parameter"

OPENCLAW_MOUNT="$(volume_mount_docker "openclaw_data" 2>/dev/null | tail -n1)"
assert_eq "-v /var/lib/dax/openclaw:/opt/openclaw_data:rw" "$OPENCLAW_MOUNT" "openclaw_data erzeugt korrekten Docker Bind-Mount Parameter"

OLLAMA_MOUNT="$(volume_mount_docker "ollama_data" 2>/dev/null | tail -n1)"
assert_eq "-v /var/lib/dax/ollama:/opt/ollama_data:rw" "$OLLAMA_MOUNT" "ollama_data erzeugt korrekten Docker Bind-Mount Parameter"

it "Fehlerbehandlung bei ungültigen Volumes"
volume_ensure "invalid_volume_xyz" >/dev/null 2>&1
assert_false $? "Unbekanntes Volume wird abgelehnt"

test_module_summary
