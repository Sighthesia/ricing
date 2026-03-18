#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
bash tests/run-qml-harness.sh SystemMonitorSettingsSmoke
bash tests/run-qml-harness.sh SystemMetricsServiceSmoke
bash tests/run-qml-harness.sh AudioDeviceServiceSmoke
bash tests/run-qml-harness.sh BrightnessServiceSmoke
bash tests/run-qml-harness.sh SystemMonitorServiceSmoke
