#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-preflight}"

HARNESS_MODE="$MODE" timeout 5 qs -p tests/qml/harnesses/SystemTrayServiceHarness.qml
