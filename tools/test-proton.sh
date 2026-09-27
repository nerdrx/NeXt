#!/usr/bin/env bash
# Export and exercise the normal Windows entrypoint without opening desktop windows.
set -euo pipefail
project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
steam_root="${STEAM_ROOT:-$HOME/.local/share/Steam}"
proton_bin="${PROTON_BIN:-$steam_root/steamapps/common/Proton - Experimental/proton}"
duration="${NEXT_SMOKE_TIMEOUT:-90}"
[[ "$duration" =~ ^[1-9][0-9]*$ ]] || { echo 'NEXT_SMOKE_TIMEOUT must be positive seconds.' >&2; exit 1; }
[[ -x "$proton_bin" ]] || { echo 'Set PROTON_BIN to an installed Proton launcher.' >&2; exit 1; }
command -v gamescope >/dev/null
command -v timeout >/dev/null
mkdir -p "$project_dir/build/windows"
run_dir="$(mktemp -d "$project_dir/build/proton-smoke.XXXXXX")"
printf 'Validation evidence: %s\n' "$run_dir"
timeout -k 3 90 "$project_dir/run-next.sh" --headless --export-release 'Windows Desktop' "$project_dir/build/windows/NeXt.exe" >"$run_dir/export.log" 2>&1
if grep -Eq 'SCRIPT ERROR:|ERROR:|Failed to export' "$run_dir/export.log"; then
    echo 'Windows export failed; inspect export.log.' >&2
    exit 1
fi
sha256sum "$project_dir/build/windows/NeXt.exe" "$project_dir/build/windows/NeXt.pck" >"$run_dir/build.sha256"
mkdir -p "$run_dir/prefix"
status=0
timeout -k 3 "$duration" gamescope --backend headless -W 1440 -H 900 -- \
    env STEAM_COMPAT_CLIENT_INSTALL_PATH="$steam_root" STEAM_COMPAT_DATA_PATH="$run_dir/prefix" \
    "$proton_bin" run "$project_dir/build/windows/NeXt.exe" --audio-driver Dummy \
    --log-file "Z:$run_dir/godot.log" -- --smoke >"$run_dir/wrapper.log" 2>&1 || status=$?
printf 'Wrapper exit: %s\n' "$status"
if [[ ! -f "$run_dir/godot.log" ]] || ! grep -q '^NEXT_INTEGRATION_OK:' "$run_dir/godot.log"; then
    echo 'Windows integration did not complete; inspect godot.log and wrapper.log.' >&2
    exit 1
fi
if grep -Eq 'SCRIPT ERROR:|ERROR:' "$run_dir/godot.log"; then
    echo 'Windows integration logged errors; inspect godot.log.' >&2
    exit 1
fi
if [[ "$status" != 0 ]]; then
    echo 'Integration passed; wrapper exit was nonzero. Clean shutdown is not verified.'
else
    echo 'Integration passed and wrapper exited cleanly.'
fi
echo 'This smoke check does not establish multiplayer interoperability or performance targets.'
