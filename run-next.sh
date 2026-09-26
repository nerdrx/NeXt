#!/usr/bin/env bash
set -euo pipefail
project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
godot_bin="${GODOT_BIN:-}"
if [[ -z "$godot_bin" ]]; then
    for candidate in "$HOME/.local/share/Steam/steamapps/common/Godot Engine/godot.x11.opt.tools.64" "$HOME/.steam/steam/steamapps/common/Godot Engine/godot.x11.opt.tools.64"; do
        if [[ -x "$candidate" ]]; then godot_bin="$candidate"; break; fi
    done
fi
if [[ -z "$godot_bin" ]]; then
    godot_bin="$(command -v godot || command -v godot4 || true)"
fi
if [[ -z "$godot_bin" || ! -x "$godot_bin" ]]; then
    printf '%s\n' 'Godot not found. Set GODOT_BIN to your Godot 4.7.2 executable.' >&2
    exit 1
fi
exec "$godot_bin" --path "$project_dir" "$@"
