#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
bash tests/run-qml-harness.sh NotificationStructureSmoke
bash tests/run-qml-harness.sh LauncherStructureSmoke
bash tests/run-qml-harness.sh BarLayoutGeometrySmoke
