#!/usr/bin/env bash
# =============================================================================
# TEST: POLICY ENGINE
# =============================================================================
TEST_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "$TEST_DIR/.." && pwd)"
cd "$ROOT_DIR"

source "$TEST_DIR/test_helper.sh"
source "$ROOT_DIR/dax.sh"
set +e
set +E

test_suite_header "Policy Engine (Platforms & Agents)"

it "Policy-Datei Existenz & Format"
assert_file_exists "$POLICY_FILE" "policy.yaml muss existieren"

it "Plattform-Richtlinien (Standard Linux)"
ORIG_PLATFORM="$PLATFORM"

PLATFORM="linux"
policy_allow_runtime_for_platform "native"; assert_true $? "Linux erlaubt 'native'"
policy_allow_runtime_for_platform "docker"; assert_true $? "Linux erlaubt 'docker'"
policy_allow_runtime_for_platform "kvm";    assert_true $? "Linux erlaubt 'kvm'"
policy_allow_runtime_for_platform "remote"; assert_true $? "Linux erlaubt 'remote'"

it "Plattform-Richtlinien (WSL2)"
PLATFORM="wsl2"
policy_allow_runtime_for_platform "native"; assert_true $? "WSL2 erlaubt 'native'"
policy_allow_runtime_for_platform "docker"; assert_true $? "WSL2 erlaubt 'docker'"
policy_allow_runtime_for_platform "kvm";    assert_false $? "WSL2 verbietet 'kvm'"

it "Plattform-Richtlinien (Termux & PRoot Restriktionen)"
PLATFORM="termux"
policy_allow_runtime_for_platform "native"; assert_true $? "Termux erlaubt 'native'"
policy_allow_runtime_for_platform "remote"; assert_true $? "Termux erlaubt 'remote'"
policy_allow_runtime_for_platform "docker"; assert_false $? "Termux verbietet 'docker'"
policy_allow_runtime_for_platform "kvm";    assert_false $? "Termux verbietet 'kvm'"

PLATFORM="proot"
policy_allow_runtime_for_platform "native"; assert_true $? "PRoot erlaubt 'native'"
policy_allow_runtime_for_platform "docker"; assert_false $? "PRoot verbietet 'docker'"
policy_allow_runtime_for_platform "kvm";    assert_false $? "PRoot verbietet 'kvm'"

# Restore
PLATFORM="$ORIG_PLATFORM"

it "Agent-Richtlinien (Hermes 2.0)"
policy_allow_runtime_for_agent "hermes" "native"; assert_true $? "Hermes erlaubt 'native'"
policy_allow_runtime_for_agent "hermes" "docker"; assert_true $? "Hermes erlaubt 'docker'"
policy_allow_runtime_for_agent "hermes" "kvm";    assert_true $? "Hermes erlaubt 'kvm'"
policy_allow_runtime_for_agent "hermes" "remote"; assert_true $? "Hermes erlaubt 'remote'"
policy_allow_runtime_for_agent "hermes" "invalid_rt"; assert_false $? "Hermes verbietet ungültige Runtimes"

it "Agent-Richtlinien (OpenClaw)"
policy_allow_runtime_for_agent "openclaw" "native"; assert_true $? "OpenClaw erlaubt 'native'"
policy_allow_runtime_for_agent "openclaw" "docker"; assert_true $? "OpenClaw erlaubt 'docker'"
policy_allow_runtime_for_agent "openclaw" "kvm";    assert_true $? "OpenClaw erlaubt 'kvm'"
policy_allow_runtime_for_agent "openclaw" "remote"; assert_true $? "OpenClaw erlaubt 'remote'"

it "Unbekannte Agenten Abweisung"
policy_allow_runtime_for_agent "unknown_agent" "docker"; assert_false $? "Unbekannte Agenten werden abgewiesen"

test_module_summary
