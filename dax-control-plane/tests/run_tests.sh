#!/usr/bin/env bash
# =============================================================================
# DAX COMMAND CENTER — MASTER AUTOMATED TEST RUNNER
# =============================================================================
set -uo pipefail

TEST_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "$TEST_DIR/.." && pwd)"
cd "$ROOT_DIR"

CLR_BLUE=$'\033[38;2;0;210;255m'
CLR_GOLD=$'\033[38;2;212;175;55m'
CLR_GREEN=$'\033[38;2;0;255;127m'
CLR_RED=$'\033[38;2;255;69;0m'
CLR_WHITE=$'\033[1;37m'
CLR_RESET=$'\033[0m'
CLR_DIM=$'\033[2;37m'

echo -e "${CLR_BLUE}╔══════════════════════════════════════════════════════════════════════╗${CLR_RESET}"
echo -e "${CLR_BLUE}║${CLR_GOLD}        DAX CONTROL PLANE — AUTOMATED TEST SUITE (v6.3)        ${CLR_BLUE}║${CLR_RESET}"
echo -e "${CLR_BLUE}║${CLR_WHITE}         Vollständige Validierung aller System-Module & Usecases       ${CLR_BLUE}║${CLR_RESET}"
echo -e "${CLR_BLUE}╚══════════════════════════════════════════════════════════════════════╝${CLR_RESET}"

TEST_MODULES=(
  "tests/test_preflight.sh"
  "tests/test_policy.sh"
  "tests/test_secrets.sh"
  "tests/test_volumes.sh"
  "tests/test_templates.sh"
  "tests/test_adapters.sh"
  "tests/test_watchdog.sh"
)

TOTAL_MODULES=${#TEST_MODULES[@]}
PASSED_MODULES=0
FAILED_MODULES=0

MODULE_RESULTS=()

START_TIME=$(date +%s)

for test_script in "${TEST_MODULES[@]}"; do
  if [[ -x "$test_script" || -f "$test_script" ]]; then
    bash "$test_script"
    EXIT_CODE=$?
    if [[ $EXIT_CODE -eq 0 ]]; then
      PASSED_MODULES=$((PASSED_MODULES + 1))
      MODULE_RESULTS+=("${CLR_GREEN}✔ PASS${CLR_RESET} : $(basename "$test_script")")
    else
      FAILED_MODULES=$((FAILED_MODULES + 1))
      MODULE_RESULTS+=("${CLR_RED}✖ FAIL${CLR_RESET} : $(basename "$test_script")")
    fi
  else
    FAILED_MODULES=$((FAILED_MODULES + 1))
    MODULE_RESULTS+=("${CLR_RED}✖ MISSING${CLR_RESET} : $test_script")
  fi
done

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo -e "\n${CLR_BLUE}══════════════════════════════════════════════════════════════════════${CLR_RESET}"
echo -e "${CLR_GOLD}📊 TEST SUITE ZUSAMMENFASSUNG & ERGEBNIS-REPORT${CLR_RESET}"
echo -e "${CLR_BLUE}══════════════════════════════════════════════════════════════════════${CLR_RESET}"

for res in "${MODULE_RESULTS[@]}"; do
  echo -e "  $res"
done

echo -e "${CLR_DIM}──────────────────────────────────────────────────────────────────────${CLR_RESET}"
echo -e "Module gesamt: ${CLR_WHITE}$TOTAL_MODULES${CLR_RESET} | Bestanden: ${CLR_GREEN}$PASSED_MODULES${CLR_RESET} | Fehlgeschlagen: ${CLR_RED}$FAILED_MODULES${CLR_RESET} | Dauer: ${DURATION}s"

if [[ $FAILED_MODULES -eq 0 ]]; then
  echo -e "\n${CLR_GREEN}🎉 100% FEHLERFREIHEIT ERREICHT! Alle Tests erfolgreich bestanden.${CLR_RESET}\n"
  exit 0
else
  echo -e "\n${CLR_RED}⚠ TEST-FEHLER ERKANNT: $FAILED_MODULES Modul(e) sind fehlgeschlagen.${CLR_RESET}\n"
  exit 1
fi
