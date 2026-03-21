#!/usr/bin/env sh
set -eu
mode=${1:-battery-contract}
SYSTEM_MONITOR_HARNESS_MODE="$mode" timeout 5 qs --path .
