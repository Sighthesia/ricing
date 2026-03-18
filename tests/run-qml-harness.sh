#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

if [ "$#" -ne 1 ]; then
    printf 'usage: %s <HarnessBaseName>\n' "$0" >&2
    exit 1
fi

env DYMICSHELL_TEST_HARNESS="$1" timeout 12 qs --path TestHarnessRunner.qml
