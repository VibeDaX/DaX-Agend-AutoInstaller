#!/usr/bin/env bash
# =============================================================================
# TEST: TEMPLATE ENGINE
# =============================================================================
TEST_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "$TEST_DIR/.." && pwd)"
cd "$ROOT_DIR"

source "$TEST_DIR/test_helper.sh"
source "$ROOT_DIR/dax.sh"
set +e
set +E

test_suite_header "Template Engine (Compose, Agents, VM, Remote)"

it "Template-Verzeichnisstruktur"
assert_file_exists "$TEMPLATE_DIR" "templates/ Verzeichnis muss existieren"
assert_file_exists "$TEMPLATE_DIR/compose" "templates/compose Verzeichnis muss existieren"
assert_file_exists "$TEMPLATE_DIR/agents" "templates/agents Verzeichnis muss existieren"
assert_file_exists "$TEMPLATE_DIR/vm" "templates/vm Verzeichnis muss existieren"
assert_file_exists "$TEMPLATE_DIR/remote" "templates/remote Verzeichnis muss existieren"

it "Existenz der Standard-Templates"
assert_file_exists "$TEMPLATE_DIR/compose/ollama-comfyui.yaml" "ollama-comfyui.yaml Template muss existieren"
assert_file_exists "$TEMPLATE_DIR/compose/full-stack.yaml" "full-stack.yaml Template muss existieren"
assert_file_exists "$TEMPLATE_DIR/agents/hermes-stack.yaml" "hermes-stack.yaml Template muss existieren"
assert_file_exists "$TEMPLATE_DIR/agents/openclaw-stack.yaml" "openclaw-stack.yaml Template muss existieren"
assert_file_exists "$TEMPLATE_DIR/vm/ubuntu-small.yaml" "ubuntu-small.yaml Template muss existieren"
assert_file_exists "$TEMPLATE_DIR/vm/ubuntu-gpu.yaml" "ubuntu-gpu.yaml Template muss existieren"
assert_file_exists "$TEMPLATE_DIR/remote/lab01-hermes.yaml" "lab01-hermes.yaml Template muss existieren"

it "Compose-Template Anwenden (template_apply_compose)"
template_apply_compose "ollama-comfyui.yaml" >/dev/null 2>&1
assert_true $? "template_apply_compose ollama-comfyui.yaml ist erfolgreich"
assert_file_exists "$DOCKER_DIR/compose.yml" "docker/compose.yml muss nach Apply existieren"

# Inhalt prüfen
COMPOSE_CONTENT="$(cat "$DOCKER_DIR/compose.yml")"
assert_match "ollama" "$COMPOSE_CONTENT" "compose.yml enthält ollama Definition"
assert_match "comfyui" "$COMPOSE_CONTENT" "compose.yml enthält comfyui Definition"

template_apply_compose "full-stack.yaml" >/dev/null 2>&1
assert_true $? "template_apply_compose full-stack.yaml ist erfolgreich"
FULL_CONTENT="$(cat "$DOCKER_DIR/compose.yml")"
assert_match "openwebui" "$FULL_CONTENT" "full-stack compose.yml enthält openwebui Definition"

it "Fehlerbehandlung bei fehlendem Template"
template_apply_compose "non_existent_template.yaml" >/dev/null 2>&1
assert_false $? "Nicht existierendes Template wird abgewiesen"

test_module_summary
