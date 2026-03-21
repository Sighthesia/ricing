#!/usr/bin/env sh
set -eu

MODE="${1:-all}"
QS_BAR_TRANSIENT_REVEAL_MODE="$MODE" timeout 5 qs -p tests/qml/bar/BarTransientRevealHostHarnessRoot.qml
