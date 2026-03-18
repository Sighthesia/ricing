#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

bash tests/run-qml-harness.sh MediaServiceSmoke
bash tests/run-qml-harness.sh CavaServiceSmoke
bash tests/run-qml-harness.sh MediaControlServiceSmoke
bash tests/run-qml-harness.sh MediaVisualPartsSmoke
bash tests/run-qml-harness.sh MediaControlWidgetSmoke
bash tests/run-qml-harness.sh MediaControlPanelSmoke
bash tests/run-qml-harness.sh MediaControlSettingsSmoke
