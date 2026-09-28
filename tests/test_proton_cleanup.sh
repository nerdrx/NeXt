#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
helper="$project_dir/tools/run-proton-isolated.sh"
tmp_dir="$(mktemp -d)"
trap 'rm -rf -- "$tmp_dir"' EXIT
proton="$tmp_dir/fake proton"
wineserver="$tmp_dir/fake wineserver"

cat >"$proton" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
{
	printf 'WINEPREFIX=<%s>\n' "${WINEPREFIX-}"
	for arg in "$@"; do printf '<%s>\n' "$arg"; done
} >"$PROTON_LOG"
exit "${FAKE_PROTON_EXIT:-0}"
EOF
cat >"$wineserver" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'WINEPREFIX=<%s> arg=<%s>\n' "${WINEPREFIX-}" "$1" >>"$WINESERVER_LOG"
if [[ "${FAIL_WINESERVER_ARG:-}" == "$1" ]]; then exit "${FAIL_WINESERVER_STATUS:-11}"; fi
EOF
chmod +x "$proton" "$wineserver"

steam_data="$tmp_dir/isolated data"
expected_prefix="$steam_data/pfx"

run_case() {
	local expected_status="$1"
	shift
	local actual_status=0
	if env \
		STEAM_COMPAT_DATA_PATH="$steam_data" \
		WINEPREFIX="$tmp_dir/host-prefix-must-stay" \
		PROTON_LOG="$tmp_dir/proton.log" \
		WINESERVER_LOG="$tmp_dir/wineserver.log" \
		"$@" "$helper" "$proton" "$wineserver" "$tmp_dir/game executable.exe" --alpha 'arg with spaces' >"$tmp_dir/output.log" 2>&1; then
		actual_status=0
	else
		actual_status=$?
	fi
	if [[ "$actual_status" != "$expected_status" ]]; then
		cat "$tmp_dir/output.log" >&2
		echo "expected helper status $expected_status, got $actual_status" >&2
		exit 1
	fi
}

# Successful launch preserves arguments and does not change the host prefix.
run_case 0 env FAKE_PROTON_EXIT=0
cat >"$tmp_dir/expected-proton.log" <<EOF
WINEPREFIX=<$tmp_dir/host-prefix-must-stay>
<run>
<$tmp_dir/game executable.exe>
<--alpha>
<arg with spaces>
EOF
cmp "$tmp_dir/expected-proton.log" "$tmp_dir/proton.log"
cat >"$tmp_dir/expected-wineserver.log" <<EOF
WINEPREFIX=<$expected_prefix> arg=<-k>
WINEPREFIX=<$expected_prefix> arg=<-w>
EOF
cmp "$tmp_dir/expected-wineserver.log" "$tmp_dir/wineserver.log"
grep -q 'Proton exit: 0' "$tmp_dir/output.log"
grep -q "Proton prefix cleanup: wineserver -k=0 -w=0 (WINEPREFIX=$expected_prefix)" "$tmp_dir/output.log"

# Cleanup runs after Proton fails, and Proton's status takes precedence.
: >"$tmp_dir/wineserver.log"
run_case 37 env FAKE_PROTON_EXIT=37 FAIL_WINESERVER_ARG=-k FAIL_WINESERVER_STATUS=11
[[ "$(wc -l <"$tmp_dir/wineserver.log")" -eq 2 ]]
grep -q 'Proton exit: 37' "$tmp_dir/output.log"

# Both cleanup operations run; a cleanup failure is returned after app success.
: >"$tmp_dir/wineserver.log"
run_case 11 env FAKE_PROTON_EXIT=0 FAIL_WINESERVER_ARG=-k FAIL_WINESERVER_STATUS=11
[[ "$(wc -l <"$tmp_dir/wineserver.log")" -eq 2 ]]
grep -q 'wineserver -k=11 -w=0' "$tmp_dir/output.log"

echo 'PROTON_CLEANUP_TEST_OK: args, isolated prefix, error statuses, and cleanup'
