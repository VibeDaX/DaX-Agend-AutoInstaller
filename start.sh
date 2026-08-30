#!/usr/bin/env bash
# =============================================================================
# DAX COMMAND CENTER - START SCRIPT (Entry Point)
# =============================================================================
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if [[ ! -x "$SCRIPT_DIR/dax.sh" ]]; then
    chmod +x "$SCRIPT_DIR/dax.sh" 2>/dev/null || true
fi

exec "$SCRIPT_DIR/dax.sh" "$@"
