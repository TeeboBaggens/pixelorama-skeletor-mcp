#!/usr/bin/env bash
# Launch Pixelorama from source (macOS) with the pix-MCP bridge + Skeletor extensions.
# Verified against: Pixelorama v1.2.4-stable, Godot 4.7.2, Skeletor v0.19, ExtensionsApi v10.
set -euo pipefail

PIXELORAMA_SRC="${PIXELORAMA_SRC:-$HOME/development/tools/pixelorama}"
USER_DIR="$HOME/Library/Application Support/pixelorama"

[ -f "$PIXELORAMA_SRC/project.godot" ] || { echo "No Pixelorama source at $PIXELORAMA_SRC" >&2; exit 1; }

pkill -f "godot --path $PIXELORAMA_SRC" 2>/dev/null || true
# Clear crash markers, otherwise Pixelorama quarantines the extensions on next start.
rm -f "$USER_DIR/.running" "$USER_DIR/extensions/Monitoring.ini"

godot --path "$PIXELORAMA_SRC" >"${TMPDIR:-/tmp}/pixelorama.log" 2>&1 &
echo "Pixelorama starting (log: ${TMPDIR:-/tmp}/pixelorama.log)"

if curl -s --retry 40 --retry-delay 1 --retry-connrefused --max-time 60 http://127.0.0.1:7373/health; then
  echo; echo "Bridge is up."
else
  echo "Bridge did not come up on :7373" >&2; exit 1
fi
