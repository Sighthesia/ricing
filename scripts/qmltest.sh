#!/usr/bin/env bash
# The only supported way to run Afloat's QtTest files. Read this before
# bypassing it — the gate below is not ceremony, it is the whole isolation
# mechanism.
#
# WHY (measured on this machine, not theoretical):
#
#   A bare `qmltestrunner -input tests/qml/foo.qml` inherits
#   QT_QPA_PLATFORM=wayland from the session and creates a REAL Wayland window
#   for every test file, which niri then focuses. Each focus change is an
#   input-method focus change: during one suite run fcitx5 logged 1228 FocusOut
#   and 0 FocusIn, so every flip deactivated the IME and discarded whatever was
#   being typed. Nothing appears on screen — the windows are undecorated and
#   offscreen-ish in size — but they are fully live for keyboard input, which is
#   why the damage is invisible and looks like a random IME glitch.
#
#   `QT_QPA_PLATFORM=offscreen` has no window at all, so there is nothing to
#   focus. That only works if the platform is set at the invocation site: no
#   in-QML guard can help, because qmltestrunner creates the window *before* it
#   loads the test file. This script therefore owns the platform, and there is
#   deliberately no flag to opt out.
#
#   No tests/qml file may need a window (an Item root is mandatory there; a
#   Window root maps on the live desktop the moment it becomes visible), so
#   nothing legitimate is lost. The eight window-only harnesses are root-level
#   `qs -p` files and are driven by scripts/run-tests.sh -g.
#
# Usage:
#   scripts/qmltest.sh tests/qml/tst_foo.qml    # one file
#   scripts/qmltest.sh tst_foo                  # same, resolved under tests/qml
#   scripts/qmltest.sh --suite                  # every tests/qml/tst_*.qml in ONE
#                                                # process: 1 window in the worst
#                                                # case instead of ~70, and ~5x faster
#   scripts/qmltest.sh -i path.qml -o -,txt     # raw qmltestrunner flags pass through
#
# Environment:
#   AFLOAT_APP_THEME_PREFIX   honoured if already set; otherwise a throwaway
#                             sandbox is used so AppThemeService cannot restyle
#                             the real kitty/GTK configuration.
#   AFLOAT_TEST_TIMEOUT       seconds before the run is killed (default 900).

set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

# Qt6 only. /usr/bin/qmltestrunner is Qt5 on this machine and fails silently,
# reporting a green run that executed nothing.
QMLTESTRUNNER=/usr/lib/qt6/bin/qmltestrunner
QML_IMPORT_DIR=/usr/lib/qt6/qml
TIMEOUT=${AFLOAT_TEST_TIMEOUT:-900}

if [ ! -x "$QMLTESTRUNNER" ]; then
    echo "qmltest: $QMLTESTRUNNER is missing (expected the Qt6 runner)" >&2
    exit 127
fi

# --- the gate ---------------------------------------------------------------
# A GUI platform is never honoured, whatever the caller asked for. Report the
# override instead of silently ignoring it, so nobody debugs a test that "went
# invisible" for a reason we did not say out loud.
incoming_platform=${QT_QPA_PLATFORM:-}
case "$incoming_platform" in
    ""|offscreen|minimal) ;;
    *)
        cat >&2 <<EOF
qmltest: overriding QT_QPA_PLATFORM=$incoming_platform with offscreen.
         On this session that platform makes every test file create a real
         focused Wayland window, which interrupts fcitx5 (FocusOut storm, typed
         text discarded). Use scripts/run-tests.sh -g for the harnesses that
         genuinely need a surface.
EOF
        ;;
esac
export QT_QPA_PLATFORM=offscreen
# The offscreen font database is empty unless this points at real fonts, so
# text metrics silently collapse without it.
export QT_QPA_FONTDIR=${QT_QPA_FONTDIR:-/usr/share/fonts}
# Without this, the tests that assert on repo assets (the lock PAM asset) throw
# "Invalid state" and report phantom failures.
export QML_XHR_ALLOW_FILE_READ=1
export QML_IMPORT_PATH="$QML_IMPORT_DIR"

# AppThemeService is a test seam: with no prefix it runs apply_app_themes.py
# against the real ~/.config/kitty and gtk-3.0, restyling live desktop apps.
if [ -z "${AFLOAT_APP_THEME_PREFIX:-}" ]; then
    sandbox=$(mktemp -d "${TMPDIR:-/tmp}/afloat-qmltest-home.XXXXXX")
    trap 'rm -rf "$sandbox"' EXIT
    mkdir -p "$sandbox/.config"
    export AFLOAT_APP_THEME_PREFIX="$sandbox"
fi
# ----------------------------------------------------------------------------

suite=0
case "${1:-}" in
    --suite) suite=1; shift ;;
    -h|--help) sed -n '2,42p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac

# Bare file names resolve under tests/qml, which is where a QtTest file belongs.
# The suffix is appended because qmltestrunner requires it: given
# `tests/qml/tst_foo` it exits 1 with NO output at all, which reads exactly like a
# crash and sends you looking at the test instead of at the invocation. `-i` is
# the documented shorthand, and `run-tests.sh` passes the full name.
# An explicit -o from the caller wins, so the suite runner can capture a report
# file instead of stdout; passing two -o makes qmltestrunner pick arbitrarily.
args=()
has_output=0
for arg in "$@"; do
    case "$arg" in
        -o|--output) has_output=1; args+=("$arg") ;;
        */*)          args+=("$arg") ;;
        *.qml)        args+=("tests/qml/$arg") ;;
        *)            args+=("tests/qml/$arg.qml") ;;
    esac
done
[ "$has_output" -eq 1 ] || args=( "${args[@]}" -o -,txt )

if [ "$suite" -eq 1 ]; then
    echo "qmltest: one process, whole tests/qml directory" >&2
    exec timeout --kill-after=5 "$TIMEOUT" \
        "$QMLTESTRUNNER" -input tests/qml "${args[@]}"
fi

exec timeout --kill-after=5 "$TIMEOUT" \
    "$QMLTESTRUNNER" -input "${args[@]}"
