#!/usr/bin/env bash
# Catch a reference to a theme token that does not exist.
#
# Why this exists: `qmllint` does not resolve property names on a singleton, and
# the runtime does not warn either - an unknown name on a QML singleton is simply
# `undefined`. Bound into geometry it becomes NaN and the surface paints nothing,
# which reads exactly like "the feature did nothing". One such typo
# (`LazerTheme.coverSize`, a property of the widget rather than of the theme) cost
# a build of a glow that rendered no glow at all, and `check-shell.sh` reported a
# clean log throughout.
#
# Usage: scripts/check-theme-tokens.sh            # report unknown tokens
#        scripts/check-theme-tokens.sh --list     # also list what is declared
# Exits non-zero when a reference names nothing declared on the singleton.

set -uo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT" || exit 1

THEME=modules/lazerbar/LazerTheme.qml
[ -f "$THEME" ] || { echo "check-theme-tokens: $THEME is missing" >&2; exit 2; }

LIST=0
[ "${1:-}" = "--list" ] && LIST=1

# Declared names: properties (optionally readonly/alias), functions, and the
# `id` of the root object, which QML exposes as a property too.
declared=$( {
    sed -n 's/^[[:space:]]*\(readonly \)\?property[[:space:]]\+[A-Za-z0-9_.<>]*[[:space:]]\+\([A-Za-z_][A-Za-z0-9_]*\).*/\2/p' "$THEME"
    sed -n 's/^[[:space:]]*function[[:space:]]\+\([A-Za-z_][A-Za-z0-9_]*\).*/\1/p' "$THEME"
} | sort -u )

[ "$LIST" -eq 1 ] && printf '%s\n' "$declared"

# Every `LazerTheme.<name>` in the tree, with the file it came from. Full-line
# comments are skipped: prose like "LazerTheme.overlay*Surface" is not a
# reference, and counting it would make the check cry wolf until someone stops
# running it.
refs=$(grep -rnE 'LazerTheme\.[A-Za-z_][A-Za-z0-9_]*' \
        --include='*.qml' --include='*.js' modules services shell.qml 2>/dev/null \
       | awk -F: '
           {
               file = $1; text = $0
               sub(/^[^:]*:[0-9]+:/, "", text)
               if (text ~ /^[[:space:]]*\/\//) next
               while (match(text, /LazerTheme\.[A-Za-z_][A-Za-z0-9_]*/)) {
                   print substr(text, RSTART, RLENGTH), file
                   text = substr(text, RSTART + RLENGTH)
               }
           }' | sort -u)

missing=0
while read -r name file; do
    bare=${name#LazerTheme.}
    printf '%s\n' "$declared" | grep -qx "$bare" && continue
    printf '  %s  (in %s)\n' "$name" "$file"
    missing=$((missing + 1))
done <<< "$refs"

if [ "$missing" -eq 0 ]; then
    echo "check-theme-tokens: every LazerTheme reference names a declared member"
    exit 0
fi

echo "check-theme-tokens: $missing reference(s) name nothing on LazerTheme" >&2
exit 1
