#!/usr/bin/env bash
# =============================================================================
# TEST: AGENT ADAPTERS & DISPATCH ENGINE
# =============================================================================
TEST_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "$TEST_DIR/.." && pwd)"
cd "$ROOT_DIR"

source "$TEST_DIR/test_helper.sh"
source "$ROOT_DIR/dax.sh"
set +e
set +E

test_suite_header "Agent Adapters & Dispatch System"

it "Agenten-Manifeste & Adapter-Dateien"
for agent in hermes openclaw; do
  assert_file_exists "$AGENT_DIR/$agent/manifest.yaml" "$agent: manifest.yaml muss existieren"
  for rt in native docker kvm remote; do
    assert_file_exists "$AGENT_DIR/$agent/adapters/${rt}.sh" "$agent: Adapter ${rt}.sh muss existieren"
  done
done

it "Manifest-Validierung"
HERMES_DEFAULT_RT="$(grep 'default_runtime:' "$AGENT_DIR/hermes/manifest.yaml" | awk '{print $2}')"
assert_match "^(docker|native|kvm|remote)$" "$HERMES_DEFAULT_RT" "Hermes default_runtime ist valide ($HERMES_DEFAULT_RT)"

OPENCLAW_DEFAULT_RT="$(grep 'default_runtime:' "$AGENT_DIR/openclaw/manifest.yaml" | awk '{print $2}')"
assert_match "^(docker|native|kvm|remote)$" "$OPENCLAW_DEFAULT_RT" "OpenClaw default_runtime ist valide ($OPENCLAW_DEFAULT_RT)"

it "Hermes Native Adapter (Status, Health, Stop)"
HERMES_STATUS="$(agent_dispatch hermes status native 2>/dev/null)"
assert_match "(RUNNING|STOPPED)" "$HERMES_STATUS" "Hermes Status muss RUNNING oder STOPPED sein ($HERMES_STATUS)"

HERMES_HEALTH="$(agent_dispatch hermes health native 2>/dev/null)"
assert_match "^(HEALTHY|STOPPED)$" "$HERMES_HEALTH" "Hermes Health muss HEALTHY oder STOPPED sein ($HERMES_HEALTH)"

agent_dispatch hermes stop native >/dev/null 2>&1
assert_true $? "agent_dispatch hermes stop native muss fehlerfrei zurückkehren"

it "OpenClaw Native Adapter (Status, Health, Stop)"
OPENCLAW_STATUS="$(agent_dispatch openclaw status native 2>/dev/null)"
assert_match "(RUNNING|STOPPED)" "$OPENCLAW_STATUS" "OpenClaw Status muss RUNNING oder STOPPED sein ($OPENCLAW_STATUS)"

OPENCLAW_HEALTH="$(agent_dispatch openclaw health native 2>/dev/null)"
assert_match "^(HEALTHY|STOPPED)$" "$OPENCLAW_HEALTH" "OpenClaw Health muss HEALTHY oder STOPPED sein ($OPENCLAW_HEALTH)"

agent_dispatch openclaw stop native >/dev/null 2>&1
assert_true $? "agent_dispatch openclaw stop native muss fehlerfrei zurückkehren"

it "KVM Adapter Schnittstellen"
agent_dispatch hermes status kvm >/dev/null 2>&1
assert_true $? "agent_dispatch hermes status kvm liefert Status"

agent_dispatch openclaw status kvm >/dev/null 2>&1
assert_true $? "agent_dispatch openclaw status kvm liefert Status"

it "Dispatch-Fehlerbehandlung (Ungültige Aufrufe)"
agent_dispatch "unknown_agent_xyz" status native >/dev/null 2>&1
assert_false $? "Dispatch auf unbekannten Agenten schlägt fehl"

agent_dispatch hermes "invalid_action_xyz" native >/dev/null 2>&1
assert_false $? "Dispatch mit unbekannter Aktion schlägt fehl"

test_module_summary
