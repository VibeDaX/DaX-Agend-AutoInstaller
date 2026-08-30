#!/usr/bin/env bash
# =============================================================================
# DAX CONTROL PLANE — CONSOLE ENTRY POINT
# =============================================================================
set -Eeuo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if [[ ! -x "$SCRIPT_DIR/dax.sh" ]]; then
    chmod +x "$SCRIPT_DIR/dax.sh" 2>/dev/null || true
fi
exec "$SCRIPT_DIR/dax.sh" "$@"
