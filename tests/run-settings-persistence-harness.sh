#!/usr/bin/env sh
set -eu

tmp_home=$(mktemp -d)
trap 'rm -rf "$tmp_home"' EXIT

mkdir -p "$tmp_home/.config/dymicshell"
cp config/settings-default.json "$tmp_home/.config/dymicshell/settings.json"

HOME="$tmp_home" timeout 5 qs -p SettingsServicePersistenceHarnessRoot.qml -- "$@"
