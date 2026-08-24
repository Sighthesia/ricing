#!/bin/bash
# Regression loop for the media pill's per-char lyric transition.
# Red when a lyric change leaves any invisible Text behind (i.e. the
# primary label fails to come back). See harness_media_char.qml.
#
# NOTE: `qs -p tests/qml/tst_*.qml` does NOT execute QtTest functions in
# this environment (a failing canary still exits 0) — this qs-entrypoint
# harness is the only working executable seam for widget-level QML here.
cd "$(dirname "$0")/.." || exit 1
timeout -k 2 25 qs -p harness_media_char.qml >/dev/null 2>&1
latest=$(ls -t /run/user/1000/quickshell/by-id/ | head -1)
log="/run/user/1000/quickshell/by-id/$latest/log.qslog"
strings "$log" | grep -a "DEBUG-mce2"
if strings "$log" | grep -aq "DEBUG-mce2.*FAIL"; then
    echo "RED: lyric transition lost the primary label"
    exit 1
fi
echo "GREEN"
