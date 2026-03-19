#!/usr/bin/env sh
set -eu

if [ ! -f "shell.qml" ] || [ ! -f "tests/run-bar-motion-harness.sh" ]; then
    printf '%s\n' "tests/test-bar-motion-harness-aggregate.sh must run from the repo root" >&2
    exit 2
fi

stub_dir="$(mktemp -d ./bar-motion-harness-stubs.XXXXXX)"
output_file="$(mktemp ./bar-motion-harness-aggregate.XXXXXX.log)"
trap 'rm -rf "$stub_dir" "$output_file"' EXIT HUP INT TERM

cat > "$stub_dir/qs" <<'EOF'
#!/usr/bin/env sh
mode="${DYMICSHELL_BAR_MOTION_MODE:-unknown}"

if [ "$mode" = "timeline" ]; then
    printf '%s\n' "BAR_MOTION_HARNESS_STATUS:FAIL:$mode"
    exit 0
fi

printf '%s\n' "BAR_MOTION_HARNESS_STATUS:PASS:$mode"
EOF
chmod +x "$stub_dir/qs"

status=0
PATH="$stub_dir:$PATH" sh tests/run-bar-motion-harness.sh all >"$output_file" 2>&1 || status=$?

if [ "$status" -eq 0 ]; then
    printf '%s\n' "expected aggregate runner to exit non-zero when a suite fails" >&2
    cat "$output_file" >&2
    exit 1
fi

if grep -Fq "BAR_MOTION_HARNESS_STATUS:PASS:all" "$output_file"; then
    printf '%s\n' "aggregate runner printed PASS:all despite a failing suite" >&2
    cat "$output_file" >&2
    exit 1
fi

printf '%s\n' "bar motion aggregate failure propagation verified"
