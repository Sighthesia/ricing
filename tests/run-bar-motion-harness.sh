#!/usr/bin/env sh
set -u

if [ ! -f "shell.qml" ] || [ ! -d "tests/qml/bar" ]; then
    printf '%s\n' "tests/run-bar-motion-harness.sh must run from the repo root" >&2
    exit 2
fi

mode="${1:-all}"
if [ "$#" -gt 1 ]; then
    printf '%s\n' "usage: sh tests/run-bar-motion-harness.sh [mode]" >&2
    exit 2
fi

if [ "$mode" = "all" ]; then
    aggregate_status=0

    for suite in settings timeline super-island workspace; do
        printf '%s\n' "==> bar motion suite: $suite"
        suite_status=0
        sh tests/run-bar-motion-harness.sh "$suite" || suite_status=$?

        if [ "$suite_status" -ne 0 ] && [ "$aggregate_status" -eq 0 ]; then
            aggregate_status="$suite_status"
        fi
    done

    if [ "$aggregate_status" -ne 0 ]; then
        printf '%s\n' "BAR_MOTION_HARNESS_STATUS:FAIL:all"
        exit "$aggregate_status"
    fi

    printf '%s\n' "BAR_MOTION_HARNESS_STATUS:PASS:all"
    exit 0
fi

loader="$(mktemp ./bar-motion-harness-loader.XXXXXX.qml)"
output_file="$(mktemp ./bar-motion-harness-output.XXXXXX.log)"
trap 'rm -f "$loader" "$output_file"' EXIT HUP INT TERM

cat > "$loader" <<'EOF'
import Quickshell
import QtQuick
import "./tests/qml/bar" as Harness

ShellRoot {
    Harness.BarExpandTransitionHarness {}
}
EOF

status=0
DYMICSHELL_BAR_MOTION_MODE="$mode" timeout 5 qs -p "$loader" >"$output_file" 2>&1 || status=$?
cat "$output_file"

if [ "$status" -ne 0 ]; then
    exit "$status"
fi

if grep -Fq "BAR_MOTION_HARNESS_STATUS:FAIL:" "$output_file"; then
    exit 1
fi

if grep -Fq "BAR_MOTION_HARNESS_STATUS:PASS:" "$output_file"; then
    exit 0
fi

printf '%s\n' "bar motion harness did not report a terminal status" >&2
exit 1
