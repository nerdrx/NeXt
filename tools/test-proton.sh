#!/usr/bin/env bash
# Export and exercise Windows gameplay without opening desktop windows.
set -euo pipefail
mode="normal"
case "$#:${1-}" in
	0:) ;;
	1:--crew) mode="crew" ;;
	*) echo 'Usage: tools/test-proton.sh [--crew]' >&2; exit 2 ;;
esac
project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
steam_root="${STEAM_ROOT:-$HOME/.local/share/Steam}"
proton_bin="${PROTON_BIN:-$steam_root/steamapps/common/Proton - Experimental/proton}"
duration="${NEXT_SMOKE_TIMEOUT:-90}"
[[ "$duration" =~ ^[1-9][0-9]*$ ]] || { echo 'NEXT_SMOKE_TIMEOUT must be positive seconds.' >&2; exit 1; }
[[ -x "$proton_bin" ]] || { echo 'Set PROTON_BIN to an installed Proton launcher.' >&2; exit 1; }
command -v gamescope >/dev/null
command -v timeout >/dev/null
mkdir -p "$project_dir/build/windows"
executable="$project_dir/build/windows/NeXt.exe"
if [[ "$mode" == crew ]]; then
	printf 'Validation mode: crew gameplay on the release Windows export\n'
fi
run_dir="$(mktemp -d "$project_dir/build/proton-smoke.XXXXXX")"
printf 'Validation evidence: %s\n' "$run_dir"
timeout -k 3 90 "$project_dir/run-next.sh" --headless --export-release 'Windows Desktop' "$executable" >"$run_dir/export.log" 2>&1
if grep -Eq 'SCRIPT ERROR:|ERROR:|Failed to export' "$run_dir/export.log"; then
    echo 'Windows export failed; inspect export.log.' >&2
    exit 1
fi
sha256sum "$executable" "${executable%.exe}.pck" >"$run_dir/build.sha256"
mkdir -p "$run_dir/prefix"
if [[ "$mode" == crew ]]; then
	# The gameplay test captures to res://build/*.png under the executable's directory.
	mkdir -p "$project_dir/build/windows/build"
	expected_marker='^SHIP_CREW_GAMEPLAY_OK:'
	validation_name='Crew gameplay integration'
else
	expected_marker='^NEXT_INTEGRATION_OK:'
	validation_name='Windows integration'
fi
godot_args=(--audio-driver Dummy --log-file "Z:$run_dir/godot.log")
if [[ "$mode" == crew ]]; then
    godot_args+=(-s res://tests/test_ship_crew_gameplay.gd -- --capture-only)
else
    godot_args+=(-- --smoke)
fi
status=0
timeout -k 3 "$duration" gamescope --backend headless -W 1440 -H 900 -- \
    env STEAM_COMPAT_CLIENT_INSTALL_PATH="$steam_root" STEAM_COMPAT_DATA_PATH="$run_dir/prefix" \
    "$proton_bin" run "$executable" "${godot_args[@]}" >"$run_dir/wrapper.log" 2>&1 || status=$?
printf 'Wrapper exit: %s\n' "$status"
if [[ ! -f "$run_dir/godot.log" ]] || ! grep -q "$expected_marker" "$run_dir/godot.log"; then
    echo "$validation_name did not complete; inspect godot.log and wrapper.log." >&2
    exit 1
fi
if grep -Eq 'SCRIPT ERROR:|ERROR:' "$run_dir/godot.log"; then
    echo "$validation_name logged errors; inspect godot.log." >&2
    exit 1
fi
if [[ "$status" != 0 ]]; then
    echo "$validation_name passed; wrapper exit was nonzero. Clean shutdown is not verified."
else
    echo "$validation_name passed and wrapper exited cleanly."
fi
if [[ "$mode" == normal ]]; then
    echo 'This smoke check does not establish multiplayer interoperability or performance targets.'
fi
