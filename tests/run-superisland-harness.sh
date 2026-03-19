#!/usr/bin/env sh
set -eu

timeout 5 qs -p SuperIslandHarnessRoot.qml -- "$@"
