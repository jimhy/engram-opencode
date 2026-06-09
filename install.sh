#!/usr/bin/env bash
# engram x opencode installer (macOS / Linux).
# Copies the plugin into opencode's auto-loaded plugin dir and the bundled assets (engine
# binaries + reviewer prompt + skill) next to it, so opencode picks them up with no config edit.
#   plugin -> <config>/plugin/engram.ts        (auto-loaded by opencode)
#   assets -> <config>/engram-data/{bin,scripts,skills}
# Default config dir: $HOME/.config/opencode (override with OPENCODE_CONFIG_DIR).
set -euo pipefail

config_dir="${OPENCODE_CONFIG_DIR:-$HOME/.config/opencode}"
src="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
plugin_src="$src/opencode-plugin"
plugin_dir="$config_dir/plugin"
data_dir="$config_dir/engram-data"

mkdir -p "$plugin_dir" "$data_dir"
cp "$plugin_src/plugin/engram.ts" "$plugin_dir/engram.ts"
for d in bin scripts skills; do
  rm -rf "${data_dir:?}/$d"
  cp -R "$plugin_src/$d" "$data_dir/$d"
done
chmod +x "$data_dir"/bin/engram-linux-* "$data_dir"/bin/engram-macos-* 2>/dev/null || true

# The reviewer/query agents and /engram-* commands are self-provisioned at runtime via the plugin's
# `config` hook — no agent/command files to install. Remove any leftover file from older versions so
# it does not shadow the injected one.
rm -f "$config_dir/agent/engram-reviewer.md" 2>/dev/null || true

echo "engram x opencode installed:"
echo "  plugin -> $plugin_dir/engram.ts"
echo "  assets -> $data_dir"
echo "Open opencode; the memory hot-index is injected at session start, and an independent"
echo "reviewer consolidates memory when a session goes idle (increment >= ENGRAM_REVIEW_MIN_LINES)."
