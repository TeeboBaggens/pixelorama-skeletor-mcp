#!/usr/bin/env bash
# One-time macOS setup: install the pix-MCP bridge + Skeletor extensions and enable them.
# Pixelorama ships extensions DISABLED by default; they must be enabled in config.ini
# (or ticked in Edit > Preferences > Extensions) or they load but never start.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
USER_DIR="$HOME/Library/Application Support/pixelorama"   # lowercase: Godot custom_user_dir_name
EXT_DIR="$USER_DIR/extensions"
SKELETOR_VERSION="${SKELETOR_VERSION:-v0.19}"

mkdir -p "$EXT_DIR"

echo "[1/3] Installing PixMcpBridge.pck"
cp -f "$ROOT_DIR/pixelorama-plugin/PixMcpBridge.pck" "$EXT_DIR/PixMcpBridge.pck"

echo "[2/3] Installing Skeletor.pck ($SKELETOR_VERSION)"
if [ ! -f "$EXT_DIR/Skeletor.pck" ] || [ -n "${FORCE_SKELETOR:-}" ]; then
  tmp="$(mktemp -d)"
  gh release download "$SKELETOR_VERSION" -R Variable-Interactive/Skeletor \
     -p 'Skeletor.pck' -D "$tmp" --clobber
  cp -f "$tmp/Skeletor.pck" "$EXT_DIR/Skeletor.pck"
  rm -rf "$tmp"
fi

echo "[3/3] Enabling both extensions in config.ini"
python3 -I - "$USER_DIR/config.ini" <<'PY'
import os, re, sys
p = sys.argv[1]
s = open(p).read() if os.path.exists(p) else ""
for name in ("PixMcpBridge", "Skeletor"):
    if re.search(rf'^{name}=', s, re.M):
        s = re.sub(rf'^{name}=.*$', f'{name}=true', s, flags=re.M)
    elif '[extensions]' in s:
        s = s.replace('[extensions]', f'[extensions]\n\n{name}=true', 1)
    else:
        s = s.rstrip('\n') + f'\n\n[extensions]\n\n{name}=true\n'
open(p, 'w').write(s)
PY

echo "Done. Now run: scripts/dev/run-pixelorama.sh"
