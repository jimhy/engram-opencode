#!/usr/bin/env bash
# Extract engram-opencode into a self-contained bundle to hand to the opencode desktop project
# (so it can ship engram inside the app instead of via npm). Output layout:
#   <out>/plugin/engram.ts
#   <out>/engram-data/{bin,scripts,skills}
#   <out>/DESKTOP_INTEGRATION.md
# Usage: ./export-desktop-bundle.sh [output-dir]   (default: ./engram-desktop-bundle)
set -euo pipefail

src="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
pkg="$src/opencode-plugin"
out="${1:-$src/engram-desktop-bundle}"

rm -rf "$out"
mkdir -p "$out/plugin" "$out/engram-data/bin" "$out/engram-data/scripts" "$out/engram-data/skills/engram"

cp "$pkg/plugin/engram.ts"            "$out/plugin/engram.ts"
cp "$pkg"/bin/engram-*                "$out/engram-data/bin/"
cp "$pkg/scripts/reviewer-prompt.md"  "$out/engram-data/scripts/reviewer-prompt.md"
cp "$pkg/skills/engram/SKILL.md"      "$out/engram-data/skills/engram/SKILL.md"
cp "$src/DESKTOP_INTEGRATION.md"      "$out/DESKTOP_INTEGRATION.md"
chmod +x "$out"/engram-data/bin/engram-linux-* "$out"/engram-data/bin/engram-macos-* 2>/dev/null || true

echo "engram-opencode desktop bundle ->"
echo "  $out"
( cd "$out" && find . -type f | sort | sed 's#^\./#  #' )
echo
echo "Copy the whole '$out' folder to the opencode desktop project; follow DESKTOP_INTEGRATION.md."
