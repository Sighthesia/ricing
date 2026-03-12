#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

timeout 12 qs -p MediaServiceSmoke.qml
timeout 12 qs -p CavaServiceSmoke.qml
timeout 12 qs -p MediaControlServiceSmoke.qml
timeout 12 qs -p MediaVisualPartsSmoke.qml
timeout 12 qs -p MediaControlWidgetSmoke.qml
timeout 12 qs -p MediaControlPanelSmoke.qml
timeout 12 qs -p MediaControlSettingsSmoke.qml