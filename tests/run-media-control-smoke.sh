#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

timeout 12 qs -p tests/qml/MediaServiceSmoke.qml
timeout 12 qs -p tests/qml/CavaServiceSmoke.qml
timeout 12 qs -p tests/qml/MediaControlServiceSmoke.qml
timeout 12 qs -p tests/qml/MediaVisualPartsSmoke.qml
timeout 12 qs -p tests/qml/MediaControlWidgetSmoke.qml
timeout 12 qs -p tests/qml/MediaControlPanelSmoke.qml
timeout 12 qs -p tests/qml/MediaControlSettingsSmoke.qml
