#!/usr/bin/env bash
set -euo pipefail

# Discovers all subdirectories with an install.sh and runs them.
# Usage: ./install-all.sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALLED=0
SKIPPED=0

for agent_dir in "$SCRIPT_DIR"/*/; do
  agent_name=$(basename "$agent_dir")
  install_script="${agent_dir}install.sh"

  if [ -f "$install_script" ]; then
    echo ""
    echo "════════════════════════════════════════"
    echo "  Installing: $agent_name"
    echo "════════════════════════════════════════"
    bash "$install_script" && INSTALLED=$((INSTALLED + 1)) || {
      echo "  FAILED: $agent_name"
      SKIPPED=$((SKIPPED + 1))
    }
  fi
done

echo ""
echo "════════════════════════════════════════"
echo "  Done. Installed: $INSTALLED  Failed: $SKIPPED"
echo "════════════════════════════════════════"
