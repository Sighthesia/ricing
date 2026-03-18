#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
bash tests/run-qml-harness.sh SettingsStructureSmoke
bash tests/run-qml-harness.sh SystemMonitorSettingsSmoke
