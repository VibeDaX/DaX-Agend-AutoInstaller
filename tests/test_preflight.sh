#!/usr/bin/env bash
# =============================================================================
# TEST: PREFLIGHT & CAPABILITY DETECTION
# =============================================================================
TEST_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "$TEST_DIR/.." && pwd)"
cd "$ROOT_DIR"

source "$TEST_DIR/test_helper.sh"
source "$ROOT_DIR/dax.sh"
set +e
set +E

test_suite_header "Preflight & Hardware / Runtime Detection"

it "Plattform- und Betriebssystem-Erkennung"
assert_match "^(linux|wsl2|termux|proot)$" "$PLATFORM" "PLATFORM muss ein gültiger Bezeichner sein ($PLATFORM)"
assert_not_eq "" "$OS_NAME" "OS_NAME darf nicht leer sein ($OS_NAME)"

it "Hardware- & GPU-Erkennung"
detect_hardware
assert_match "^(cpu|nvidia|amd|intel|apple)$" "$GPU_TYPE" "GPU_TYPE muss ein valider Typ sein ($GPU_TYPE)"
assert_match "^(cpu|cuda|rocm|xpu|mps)$" "$COMFYUI_MODE" "COMFYUI_MODE muss mit GPU_TYPE übereinstimmen ($COMFYUI_MODE)"
assert_not_eq "" "$GPU_NAME" "GPU_NAME muss gesetzt sein ($GPU_NAME)"

it "Runtime- & Virtualisierungs-Erkennung"
detect_runtime_capabilities
assert_match "^(true|false)$" "$CAN_DOCKER" "CAN_DOCKER muss boolean sein ($CAN_DOCKER)"
assert_match "^(true|false)$" "$DOCKER_DAEMON" "DOCKER_DAEMON muss boolean sein ($DOCKER_DAEMON)"
assert_match "^(true|false)$" "$CAN_KVM" "CAN_KVM muss boolean sein ($CAN_KVM)"
assert_match "^(true|false)$" "$KVM_DEVICE" "KVM_DEVICE muss boolean sein ($KVM_DEVICE)"
assert_match "^(true|false)$" "$CAN_LIBVIRT" "CAN_LIBVIRT muss boolean sein ($CAN_LIBVIRT)"

it "RAM-Analyse & Modell-Empfehlung"
RAM_MB="$(get_ram_mb)"
assert_true "$(( RAM_MB > 0 ? 0 : 1 ))" "get_ram_mb liefert positiven Wert (${RAM_MB} MB)"
REC_OUTPUT="$(ram_recommendation)"
assert_match "RAM:" "$REC_OUTPUT" "ram_recommendation gibt formatierte RAM-Info aus"
assert_match "Empfehlung:" "$REC_OUTPUT" "ram_recommendation enthält Modell-Empfehlung"

it "State- und Capabilities-Persistierung"
persist_runtime_state
assert_file_exists "$STATE_DIR/state.json" "state.json muss existieren"
assert_file_exists "$STATE_DIR/capabilities.env" "capabilities.env muss existieren"

# JSON Validierung
python3 -c "import json; d=json.load(open('$STATE_DIR/state.json')); assert 'platform' in d and 'gpu_type' in d" 2>/dev/null
assert_true $? "state.json ist valides JSON und enthält Pflichtfelder"

test_module_summary
