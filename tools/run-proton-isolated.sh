#!/usr/bin/env bash
set -uo pipefail

if (( $# < 3 )); then
	echo 'Usage: tools/run-proton-isolated.sh PROTON_BIN WINESERVER_BIN EXECUTABLE [ARG ...]' >&2
	exit 2
fi
if [[ -z "${STEAM_COMPAT_DATA_PATH:-}" ]]; then
	echo 'STEAM_COMPAT_DATA_PATH must name the isolated Proton data directory.' >&2
	exit 2
fi

proton_bin="$1"
wineserver_bin="$2"
executable="$3"
shift 3

"$proton_bin" run "$executable" "$@"
proton_status=$?
printf 'Proton exit: %s\n' "$proton_status"

prefix="$STEAM_COMPAT_DATA_PATH/pfx"
WINEPREFIX="$prefix" "$wineserver_bin" -k
kill_status=$?
WINEPREFIX="$prefix" "$wineserver_bin" -w
wait_status=$?
printf 'Proton prefix cleanup: wineserver -k=%s -w=%s (WINEPREFIX=%s)\n' "$kill_status" "$wait_status" "$prefix"

if (( proton_status != 0 )); then
	exit "$proton_status"
fi
if (( kill_status != 0 )); then
	exit "$kill_status"
fi
exit "$wait_status"
