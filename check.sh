#!/usr/bin/env bash
# Runs every check CI runs. Tools come from PATH (aftman install) or $TOOLS.
set -euo pipefail
cd "$(dirname "$0")"
T=${TOOLS:-}
bin() { if [ -n "$T" ]; then echo "$T/$1"; else echo "$1"; fi; }
DEFS=${LUAU_DEFS:-globalTypes.d.luau}
mkdir -p out
echo "== selene";   "$(bin selene)" src examples
echo "== rojo";     "$(bin rojo)" build default.project.json -o out/Harness.rbxm
                    "$(bin rojo)" build examples.project.json -o out/examples.rbxlx
echo "== luau-lsp"; "$(bin rojo)" sourcemap examples.project.json -o sourcemap.json
if [ ! -f "$DEFS" ]; then curl -fsSL -o "$DEFS" https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.d.luau; fi
out=$("$(bin luau-lsp)" analyze --sourcemap=sourcemap.json --definitions="$DEFS" src examples 2>&1 || true)
if echo "$out" | grep -q "Error"; then echo "$out" | grep "Error"; exit 1; fi
echo "== lune tests"; "$(bin lune)" run tests/run.luau
echo "== fuzz";       "$(bin lune)" run tests/fuzz.luau 3000
echo "== export examples"; "$(bin lune)" run tools/export_examples.luau
echo "ALL CHECKS PASSED"
