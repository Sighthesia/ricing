#!/usr/bin/env bash
set -eu

# DymicShell matugen target wiring helper.
# Reference inspiration: Noctalia Shell multi-target theming registry
# https://github.com/noctalia-dev/noctalia-shell/blob/main/Services/Theming/TemplateRegistry.qml

ensure_parent() {
    mkdir -p "$(dirname "$1")"
}

ensure_file() {
    ensure_parent "$1"
    if [ ! -f "$1" ]; then
        : > "$1"
    fi
}

append_line_if_missing() {
    local file="$1"
    local line="$2"

    ensure_file "$file"
    if grep -Fqx "$line" "$file"; then
        return
    fi

    printf '%s\n' "$line" >> "$file"
}

prepend_line_if_missing() {
    local file="$1"
    local line="$2"
    local tmp

    ensure_file "$file"
    if grep -Fqx "$line" "$file"; then
        return
    fi

    tmp=$(mktemp "${file}.XXXXXX")
    printf '%s\n' "$line" > "$tmp"
    cat "$file" >> "$tmp"
    mv "$tmp" "$file"
}

upsert_qt_appearance() {
    local file="$1"
    local scheme_path="$2"
    local tmp

    ensure_file "$file"
    tmp=$(mktemp "${file}.XXXXXX")

    awk -v scheme_path="$scheme_path" '
        BEGIN {
            in_section = 0
            saw_section = 0
            wrote_scheme = 0
            wrote_palette = 0
        }

        function emit_missing() {
            if (!wrote_scheme)
                print "color_scheme_path=" scheme_path
            if (!wrote_palette)
                print "custom_palette=true"
        }

        /^\[Appearance\]$/ {
            if (in_section)
                emit_missing()

            in_section = 1
            saw_section = 1
            wrote_scheme = 0
            wrote_palette = 0
            print
            next
        }

        /^\[/ {
            if (in_section) {
                emit_missing()
                in_section = 0
            }

            print
            next
        }

        {
            if (in_section) {
                if ($0 ~ /^color_scheme_path=/) {
                    print "color_scheme_path=" scheme_path
                    wrote_scheme = 1
                    next
                }

                if ($0 ~ /^custom_palette=/) {
                    print "custom_palette=true"
                    wrote_palette = 1
                    next
                }
            }

            print
        }

        END {
            if (!saw_section) {
                if (NR > 0)
                    print ""
                print "[Appearance]"
                print "color_scheme_path=" scheme_path
                print "custom_palette=true"
            } else if (in_section) {
                emit_missing()
            }
        }
    ' "$file" > "$tmp"

    mv "$tmp" "$file"
}

main() {
    local home="${HOME:?}"
    local gtk_import='@import url("colors.css");'
    local kitty_include='include dymicshell-matugen.conf'
    local niri_include='include "./dymicshell-matugen.kdl"'
    local qt5_scheme="$home/.config/qt5ct/colors/DymicShellMatugen.conf"
    local qt6_scheme="$home/.config/qt6ct/colors/DymicShellMatugen.conf"

    prepend_line_if_missing "$home/.config/gtk-3.0/gtk.css" "$gtk_import"
    prepend_line_if_missing "$home/.config/gtk-4.0/gtk.css" "$gtk_import"

    append_line_if_missing "$home/.config/kitty/kitty.conf" "$kitty_include"

    upsert_qt_appearance "$home/.config/qt5ct/qt5ct.conf" "$qt5_scheme"
    upsert_qt_appearance "$home/.config/qt6ct/qt6ct.conf" "$qt6_scheme"

    # Niri's main config should not be created from scratch because a standalone
    # include file is not a valid full config for fresh installs.
    if [ -f "$home/.config/niri/config.kdl" ]; then
        append_line_if_missing "$home/.config/niri/config.kdl" "$niri_include"
    fi

    if command -v kitty >/dev/null 2>&1; then
        pkill -SIGUSR1 kitty >/dev/null 2>&1 || true
    fi

    if command -v niri >/dev/null 2>&1; then
        niri msg action load-config-file >/dev/null 2>&1 || true
    fi

    if command -v plasma-apply-colorscheme >/dev/null 2>&1; then
        plasma-apply-colorscheme DymicShellMatugen >/dev/null 2>&1 || true
    fi
}

main "$@"
