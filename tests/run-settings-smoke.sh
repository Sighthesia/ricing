#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
timeout 12 qs -p tests/qml/SettingsStructureSmoke.qml
