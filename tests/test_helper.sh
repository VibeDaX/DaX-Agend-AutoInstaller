#!/usr/bin/env bash
# =============================================================================
# DAX AUTOMATED TEST SUITE — TEST HELPER & ASSERTION ENGINE
# =============================================================================
set -uo pipefail

CLR_PASS=$'\033[38;2;0;255;127m'
CLR_FAIL=$'\033[38;2;255;69;0m'
CLR_INFO=$'\033[38;2;0;210;255m'
CLR_WARN=$'\033[38;2;212;175;55m'
CLR_BOLD=$'\033[1;37m'
CLR_DIM=$'\033[2;37m'
CLR_RST=$'\033[0m'

TOTAL_ASSERTIONS=0
PASSED_ASSERTIONS=0
FAILED_ASSERTIONS=0

CURRENT_TEST_NAME=""

test_suite_header(){
  set +e
  set +E
  local name="$1"
  echo -e "\n${CLR_INFO}══════════════════════════════════════════════════════════════════════${CLR_RST}"
  echo -e "${CLR_INFO} 🧪 TEST MODULE: ${CLR_BOLD}${name}${CLR_RST}"
  echo -e "${CLR_INFO}══════════════════════════════════════════════════════════════════════${CLR_RST}"
}

it(){
  set +e
  set +E
  CURRENT_TEST_NAME="$1"
  echo -e "\n${CLR_DIM}▶ ${CURRENT_TEST_NAME}${CLR_RST}"
}

pass(){
  local msg="${1:-$CURRENT_TEST_NAME}"
  TOTAL_ASSERTIONS=$((TOTAL_ASSERTIONS + 1))
  PASSED_ASSERTIONS=$((PASSED_ASSERTIONS + 1))
  echo -e "  ${CLR_PASS}[✔ PASS]${CLR_RST} $msg"
}

fail(){
  local msg="${1:-$CURRENT_TEST_NAME}"
  local expected="${2:-}"
  local actual="${3:-}"
  TOTAL_ASSERTIONS=$((TOTAL_ASSERTIONS + 1))
  FAILED_ASSERTIONS=$((FAILED_ASSERTIONS + 1))
  echo -e "  ${CLR_FAIL}[✖ FAIL]${CLR_RST} $msg"
  if [[ -n "$expected" || -n "$actual" ]]; then
    echo -e "    ${CLR_WARN}Expected:${CLR_RST} '$expected'"
    echo -e "    ${CLR_FAIL}Actual  :${CLR_RST} '$actual'"
  fi
}

assert_eq(){
  local expected="$1"
  local actual="$2"
  local msg="${3:-Values should be equal}"
  if [[ "$expected" == "$actual" ]]; then
    pass "$msg"
  else
    fail "$msg" "$expected" "$actual"
  fi
}

assert_not_eq(){
  local unexpected="$1"
  local actual="$2"
  local msg="${3:-Values should not be equal}"
  if [[ "$unexpected" != "$actual" ]]; then
    pass "$msg"
  else
    fail "$msg" "Not '$unexpected'" "$actual"
  fi
}

assert_match(){
  local pattern="$1"
  local text="$2"
  local msg="${3:-Pattern should match}"
  if [[ "$text" =~ $pattern ]]; then
    pass "$msg"
  else
    fail "$msg" "Regex match '$pattern'" "$text"
  fi
}

assert_not_match(){
  local pattern="$1"
  local text="$2"
  local msg="${3:-Pattern should not match}"
  if [[ ! "$text" =~ $pattern ]]; then
    pass "$msg"
  else
    fail "$msg" "Should not match '$pattern'" "$text"
  fi
}

assert_true(){
  local status="$1"
  local msg="${2:-Condition should be true}"
  if [[ "$status" -eq 0 ]]; then
    pass "$msg"
  else
    fail "$msg" "Exit code 0" "Exit code $status"
  fi
}

assert_false(){
  local status="$1"
  local msg="${2:-Condition should be false}"
  if [[ "$status" -ne 0 ]]; then
    pass "$msg"
  else
    fail "$msg" "Non-zero exit code" "Exit code 0"
  fi
}

assert_file_exists(){
  local file="$1"
  local msg="${2:-File should exist: $file}"
  if [[ -e "$file" ]]; then
    pass "$msg"
  else
    fail "$msg" "Existing file" "File not found: $file"
  fi
}

test_module_summary(){
  echo -e "${CLR_DIM}──────────────────────────────────────────────────────────────────────${CLR_RST}"
  if [[ "$FAILED_ASSERTIONS" -eq 0 ]]; then
    echo -e "Module Result: ${CLR_PASS}${PASSED_ASSERTIONS}/${TOTAL_ASSERTIONS} Passed (100%)${CLR_RST}"
    return 0
  else
    echo -e "Module Result: ${CLR_FAIL}${PASSED_ASSERTIONS}/${TOTAL_ASSERTIONS} Passed, ${FAILED_ASSERTIONS} Failed${CLR_RST}"
    return 1
  fi
}
