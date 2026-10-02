#!/usr/bin/env bash
# Headless-first test runner for Afloat.
#
# Why this exists: the suite used to be run by pointing QtTest and Quickshell at
# the live session, which damages the desktop twice over.
#
#   1. Every root-level harness that instantiates a PanelWindow (BarPopupHost,
#      the visual probes) maps a real layer-shell surface over the running
#      screen.
#   2. Every tests/qml file gets its own real, niri-focused Wayland window. The
#      damage there is not visual, which is why it survived so long: each focus
#      change is an input-method focus change, and one suite run produced 1228
#      fcitx5 FocusOut against 0 FocusIn, so the IME was deactivated and the
#      user's typing discarded over and over, with nothing on screen to explain
#      it. This is the reason the QtTest tier goes through scripts/qmltest.sh,
#      which owns the platform and refuses to run on a graphical one.
#
# Offscreen closes both: no layer-shell backend, so window-based harnesses fail
# to load instead of painting; and no window at all, so there is nothing to
# focus.
#
# Usage:
#   scripts/run-tests.sh                # whole suite, zero windows
#   scripts/run-tests.sh tst_bar tst_osu # only harnesses/tests matching a name
#   scripts/run-tests.sh -g             # also run the window-based harnesses
#   scripts/run-tests.sh --suite        # QtTest tier as ONE process: ~5x faster,
#                                      # and 1 window in the worst case, not ~70
#   scripts/run-tests.sh --no-python    # skip the Python bridge tests
#
# Environment:
#   AFLOAT_TEST_TIMEOUT   per-test timeout in seconds (default 120)
#   AFLOAT_GUI_TIMEOUT    per-harness timeout for --gui (default 180)

set -uo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT" || exit 1

QMLTESTRUNNER=/usr/lib/qt6/bin/qmltestrunner
QMLTEST="$REPO_ROOT/scripts/qmltest.sh"
QML_IMPORT_DIR=/usr/lib/qt6/qml
TEST_TIMEOUT=${AFLOAT_TEST_TIMEOUT:-120}
GUI_TIMEOUT=${AFLOAT_GUI_TIMEOUT:-180}

# Offscreen is the whole isolation story: no window can be mapped, and the
# offscreen font database is empty unless QT_QPA_FONTDIR points at real fonts.
# QML_XHR_ALLOW_FILE_READ lets the harnesses that assert on repo assets (the
# lock PAM asset) read them; without it every one of those throws
# "Invalid state" and reports a phantom failure.
#
# scripts/qmltest.sh owns that environment for the QtTest tier and refuses to
# run on a graphical platform — a bare qmltestrunner inherits wayland from the
# session, focuses a real window per file and storms fcitx5 with FocusOut. It
# is invoked here rather than reimplemented so there is exactly one place where
# the platform is decided.
HEADLESS_ENV=(QT_QPA_PLATFORM=offscreen QT_QPA_FONTDIR=/usr/share/fonts
    QML_XHR_ALLOW_FILE_READ=1)

RUN_GUI=0
RUN_PYTHON=1
SUITE=0
FILTERS=()

while [ $# -gt 0 ]; do
    case "$1" in
        -g|--gui)
            RUN_GUI=1
            ;;
        -1|--suite)
            SUITE=1
            ;;
        --no-python)
            RUN_PYTHON=0
            ;;
        -h|--help)
            sed -n '22,33p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        -*)
            echo "unknown option: $1" >&2
            exit 2
            ;;
        *)
            FILTERS+=("$1")
            ;;
    esac
    shift
done

[ ${#FILTERS[@]} -eq 0 ] || [ "$SUITE" -eq 0 ] || {
    echo "--suite runs the whole QtTest tier in one process; it takes no filters" >&2
    exit 2
}

matches_filter() {
    [ ${#FILTERS[@]} -eq 0 ] && return 0
    local name=$1 filter
    for filter in "${FILTERS[@]}"; do
        case "$name" in
            *"$filter"*) return 0 ;;
        esac
    done
    return 1
}

PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0
QS_MODULE_COUNT=0
FAILED_NAMES=()
GUI_ONLY_NAMES=()
QS_MODULE_NAMES=()

# AppThemeService is a test seam: without this prefix it runs
# apply_app_themes.py against the REAL ~/.config/kitty + gtk-3.0, so a test run
# would restyle the live desktop apps (and tst_app_theme_sync reports red).
APP_THEME_SANDBOX=$(mktemp -d "${TMPDIR:-/tmp}/afloat-test-home.XXXXXX")
trap 'rm -rf "$APP_THEME_SANDBOX"' EXIT
mkdir -p "$APP_THEME_SANDBOX/.config"
export AFLOAT_APP_THEME_PREFIX=${AFLOAT_APP_THEME_PREFIX:-$APP_THEME_SANDBOX}

# `Totals: 31 passed, 0 failed` / `Totals: all passed` / `Totals: PASS` are all
# in circulation, so failure is detected from the harness's own FAIL output.
harness_reported_failure() {
    local log=$1
    grep -qE 'Totals:.*[1-9][0-9]* failed' "$log" && return 0
    grep -q 'FAIL:' "$log" && return 0
    return 1
}

section() {
    printf '\n\033[1m%s\033[0m\n' "$1"
}

# Run a command with output captured and a hard timeout. The whole group is
# wrapped in a subshell so the shell's own "Terminated" job message lands in the
# log instead of the user's terminal.
run_capture() {
    local log=$1 timeout_s=$2
    shift 2
    ( timeout --kill-after=5 "$timeout_s" "$@" ) >"$log" 2>&1
    return $?
}

# 124 = timeout fired, 143 = child died on the timeout SIGTERM.
timed_out() {
    [ "$1" -eq 124 ] || [ "$1" -eq 143 ]
}

# ---------------------------------------------------------------- QtTest tier
# tests/qml/tst_*.qml: pure JS/QML logic, no Quickshell singletons.
#
# Two lanes. --suite hands the whole directory to one qmltestrunner process:
# ~5x faster and, more to the point, one window in the worst case instead of
# one per file, so even a misconfigured run cannot storm the input method. The
# default lane runs one process per file, which keeps the n/a-vs-red
# classification and per-file isolation.
run_qml_tests() {
    if [ "$SUITE" -eq 1 ]; then
        run_qml_suite
        return 0
    fi

    local files=()
    while IFS= read -r file; do
        matches_filter "$(basename "$file")" && files+=("$file")
    done < <(find tests/qml -maxdepth 1 -name 'tst_*.qml' | sort)

    [ ${#files[@]} -eq 0 ] && return 0

    section "QtTest (offscreen) — ${#files[@]} file(s)"
    for file in "${files[@]}"; do
        local name log report rc totals
        name=$(basename "$file")
        log=$(mktemp)
        report=$(mktemp)
        run_capture "$log" "$TEST_TIMEOUT" \
            env "AFLOAT_TEST_TIMEOUT=$(( TEST_TIMEOUT * ${#files[@]} + 60 ))" \
            "$QMLTEST" "$file" -o "$report,txt"
        rc=$?
        totals=$(grep -oP '^Totals: .*' "$report" | tail -1)
        if timed_out "$rc"; then
            printf '  \033[33mTIMEOUT\033[0m %-42s >%ss\n' "$name" "$TEST_TIMEOUT"
            FAIL_COUNT=$((FAIL_COUNT + 1))
            FAILED_NAMES+=("$name (timeout)")
        elif grep -qE 'plugin "quickshell-[a-z-]*plugin" not found' "$report" \
                && grep -qE '^FAIL!.*compile\(\)' "$report"; then
            # qmltestrunner has no Quickshell plugin (it is linked into the `qs`
            # binary), so any file touching Quickshell.* cannot load. Not a
            # regression — report it as a coverage gap instead of red.
            printf '  \033[35mn/a\033[0m     %-42s needs the Quickshell module\n' "$name"
            QS_MODULE_COUNT=$((QS_MODULE_COUNT + 1))
            QS_MODULE_NAMES+=("$name")
        elif [ -n "$totals" ] && ! grep -qE '^FAIL' "$report"; then
            printf '  \033[32mok\033[0m     %-42s %s\n' "$name" "$totals"
            PASS_COUNT=$((PASS_COUNT + 1))
        else
            printf '  \033[31mFAIL\033[0m   %-42s %s\n' "$name" "${totals:-no report}"
            { grep -E '^FAIL' "$report"; grep -E 'ERROR|error' "$log" | head -3; } \
                | sed 's/^/           /' | head -8
            FAIL_COUNT=$((FAIL_COUNT + 1))
            FAILED_NAMES+=("$name")
        fi
        rm -f "$log" "$report"
    done
}

# One process for the whole tests/qml directory. Cross-file interference is not
# a concern here — verified green against the per-file lane — but the report
# loses per-file attribution, so failures are listed by test name and the files
# that need the Quickshell module are named separately.
run_qml_suite() {
    local log report rc totals real_fails qs_fails stem
    log=$(mktemp)
    report=$(mktemp)
    section "QtTest (offscreen) — whole tests/qml in ONE process"

    run_capture "$log" $(( TEST_TIMEOUT * 4 )) \
        env "AFLOAT_TEST_TIMEOUT=$(( TEST_TIMEOUT * 4 ))" \
        "$QMLTEST" --suite -o "$report,txt"
    rc=$?
    totals=$(grep -oP '^Totals: .*' "$report" | tail -1)
    # A compile() failure is the known "QtTest cannot load Quickshell.*" gap, not
    # a regression, so it must not turn the lane red.
    qs_fails=$(grep -cE '^FAIL!.*compile\(\)' "$report" || true)
    real_fails=$(grep -cE '^FAIL!' "$report" || true)
    real_fails=$(( real_fails - qs_fails ))

    if timed_out "$rc"; then
        printf '  \033[33mTIMEOUT\033[0m the suite exceeded its budget\n'
        FAIL_COUNT=$((FAIL_COUNT + 1))
        FAILED_NAMES+=("tests/qml (suite timeout)")
    elif [ -z "$totals" ]; then
        # An empty report is not a green run: the process died before writing
        # one. Reporting "ok" here is how a suite silently stops testing.
        printf '  \033[31mERROR\033[0m   qmltestrunner wrote no report (exit %s)\n' "$rc"
        tail -5 "$log" | sed 's/^/           /'
        FAIL_COUNT=$((FAIL_COUNT + 1))
        FAILED_NAMES+=("tests/qml (suite produced no report)")
    elif [ "$real_fails" -gt 0 ]; then
        printf '  \033[31mFAIL\033[0m   %s (%s real failure(s))\n' "$totals" "$real_fails"
        grep -E '^FAIL!' "$report" | grep -vE 'compile\(\)' | sed 's/^/           /' | head -20
        FAIL_COUNT=$((FAIL_COUNT + 1))
        FAILED_NAMES+=("tests/qml (suite)")
    else
        printf '  \033[32mok\033[0m     %s\n' "$totals"
        PASS_COUNT=$((PASS_COUNT + 1))
    fi

    if [ "${qs_fails:-0}" -gt 0 ]; then
        QS_MODULE_COUNT=$((QS_MODULE_COUNT + qs_fails ))
        # No pipeline here: a `while read` in a subshell would drop the appends.
        for stem in $(grep -oP '^FAIL!.*qmltestrunner::\K[A-Za-z0-9_]+(?=::compile\(\))' "$report" | sort -u); do
            QS_MODULE_NAMES+=("$stem.qml")
        done
    fi
    rm -f "$log" "$report"
}

# ---------------------------------------------------- Quickshell harness tier
# Root-level tst_*.qml need real singletons, so they run under `qs -p` and must
# live at the repo root. A harness that instantiates a PanelWindow cannot load
# headless; that is the intended, non-disruptive outcome, not a broken test.
collect_gui_only() {
    local name log rc
    while IFS= read -r file; do
        name=$(basename "$file")
        matches_filter "$name" || continue
        log=$(mktemp)
        run_capture "$log" "$TEST_TIMEOUT" env "${HEADLESS_ENV[@]}" \
            qs -p "$file"
        rc=$?
        if grep -q 'No PanelWindow backend loaded\|No PopupWindow backend loaded' "$log"; then
            GUI_ONLY_NAMES+=("$name")
            SKIP_COUNT=$((SKIP_COUNT + 1))
        elif timed_out "$rc"; then
            printf '  \033[33mTIMEOUT\033[0m %-42s >%ss\n' "$name" "$TEST_TIMEOUT"
            FAIL_COUNT=$((FAIL_COUNT + 1))
            FAILED_NAMES+=("$name (timeout)")
        elif [ "$rc" -ne 0 ]; then
            printf '  \033[31mERROR\033[0m   %-42s exit %s\n' "$name" "$rc"
            grep -E 'ERROR|caused by' "$log" | sed 's/^/           /' | head -4
            FAIL_COUNT=$((FAIL_COUNT + 1))
            FAILED_NAMES+=("$name")
        elif harness_reported_failure "$log"; then
            printf '  \033[31mFAIL\033[0m   %-42s %s\n' "$name" \
                "$(grep -oP 'Totals: .*' "$log" | tail -1)"
            grep -E '^FAIL|FAIL:' "$log" | sed 's/^/           /' | head -8
            FAIL_COUNT=$((FAIL_COUNT + 1))
            FAILED_NAMES+=("$name")
        else
            printf '  \033[32mok\033[0m     %-42s %s\n' "$name" \
                "$(grep -oP 'Totals: .*' "$log" | tail -1)"
            PASS_COUNT=$((PASS_COUNT + 1))
        fi
        rm -f "$log"
    done < <(find . -maxdepth 1 -name 'tst_*.qml' | sort)
}

run_gui_tier() {
    [ "$RUN_GUI" -eq 1 ] || return 0
    [ ${#GUI_ONLY_NAMES[@]} -eq 0 ] && return 0

    printf '\n\033[33m\033[1m--gui: the next harnesses map real layer-shell surfaces on\033[0m\n'
    printf '\033[33m\033[1m       your CURRENT session. Windows will flash over it.\033[0m\n'
    for name in "${GUI_ONLY_NAMES[@]}"; do
        printf '         %s\n' "$name"
    done

    local attempted=()
    for name in "${GUI_ONLY_NAMES[@]}"; do
        attempted+=("$name")
        local log rc
        log=$(mktemp)
        run_capture "$log" "$GUI_TIMEOUT" qs -p "$name"
        rc=$?
        if timed_out "$rc"; then
            printf '  \033[33mTIMEOUT\033[0m %-42s >%ss\n' "$name" "$GUI_TIMEOUT"
            FAIL_COUNT=$((FAIL_COUNT + 1))
            FAILED_NAMES+=("$name (timeout)")
        elif [ "$rc" -ne 0 ] || harness_reported_failure "$log"; then
            printf '  \033[31mFAIL\033[0m   %-42s %s\n' "$name" \
                "$(grep -oP 'Totals: .*' "$log" | tail -1)"
            grep -E 'ERROR|caused by|^FAIL|FAIL:' "$log" | sed 's/^/           /' | head -6
            FAIL_COUNT=$((FAIL_COUNT + 1))
            FAILED_NAMES+=("$name")
        else
            printf '  \033[32mok\033[0m     %-42s %s\n' "$name" \
                "$(grep -oP 'Totals: .*' "$log" | tail -1)"
            PASS_COUNT=$((PASS_COUNT + 1))
        fi
        rm -f "$log"
    done

    # Every window-only harness was attempted, so none is "skipped" any more; a
    # failure already landed in FAILED_NAMES instead.
    GUI_ONLY_NAMES=()
    SKIP_COUNT=$(( SKIP_COUNT - ${#attempted[@]} ))
    [ "$SKIP_COUNT" -lt 0 ] && SKIP_COUNT=0
}

run_python_tests() {
    [ "$RUN_PYTHON" -eq 1 ] || return 0
    section "Python bridges (pytest)"
    if python3 -m pytest scripts/tests/ -q 2>&1 | tail -12; then
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        FAIL_COUNT=$((FAIL_COUNT + 1))
        FAILED_NAMES+=("pytest scripts/tests/")
    fi
}

run_qml_tests
section "Quickshell harnesses (offscreen) — root tst_*.qml"
collect_gui_only
run_gui_tier
run_python_tests

section "Summary"
printf '  passed   %s\n  failed   %s\n  n/a      %s (need the Quickshell module)\n  skipped  %s (need a window; re-run with -g)\n' \
    "$PASS_COUNT" "$FAIL_COUNT" "$QS_MODULE_COUNT" "$SKIP_COUNT"
if [ ${#FAILED_NAMES[@]} -gt 0 ]; then
    printf '\n  red:\n'
    for name in "${FAILED_NAMES[@]}"; do
        printf '    - %s\n' "$name"
    done
fi
if [ ${#QS_MODULE_NAMES[@]} -gt 0 ]; then
    printf '\n  never ran (QtTest cannot load Quickshell.* — these need a root-level\n  `qs -p` harness instead; the contracts below are currently uncovered):\n'
    for name in "${QS_MODULE_NAMES[@]}"; do
        printf '    - %s\n' "$name"
    done
fi
if [ ${#GUI_ONLY_NAMES[@]} -gt 0 ]; then
    printf '\n  window-only (skipped, desktop untouched):\n'
    for name in "${GUI_ONLY_NAMES[@]}"; do
        printf '    - %s\n' "$name"
    done
fi

[ "$FAIL_COUNT" -eq 0 ]
