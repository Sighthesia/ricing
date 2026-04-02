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

remove_line_if_present() {
    local file="$1"
    local line="$2"
    local tmp

    if [ ! -f "$file" ]; then
        return
    fi

    tmp=$(mktemp "${file}.XXXXXX")
    grep -Fvx "$line" "$file" > "$tmp" || true
    mv "$tmp" "$file"
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

upsert_ini_key() {
    local file="$1"
    local section="$2"
    local key="$3"
    local value="$4"
    local tmp

    ensure_file "$file"
    tmp=$(mktemp "${file}.XXXXXX")

    awk -v section="$section" -v key="$key" -v value="$value" '
        BEGIN {
            in_section = 0
            saw_section = 0
            wrote_key = 0
        }

        function emit_missing() {
            if (!wrote_key)
                print key "=" value
        }

        $0 == "[" section "]" {
            if (in_section)
                emit_missing()

            in_section = 1
            saw_section = 1
            wrote_key = 0
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
                if ($0 ~ ("^" key "=")) {
                    print key "=" value
                    wrote_key = 1
                    next
                }
            }

            print
        }

        END {
            if (!saw_section) {
                if (NR > 0)
                    print ""
                print "[" section "]"
                print key "=" value
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
    local fuzzel_include='~/.config/fuzzel/colors.ini'
    local ghostty_theme='theme = "DymicShellMatugen"'
    local kitty_include='include kitty-colors.conf'
    local mako_include='include=~/.config/mako/mako-colors'
    local niri_include='include "./colors.kdl"'
    local firefox_import='@import url("colors.css");'
    local qt5_scheme="$home/.config/qt5ct/colors/DymicShellMatugen.conf"
    local qt6_scheme="$home/.config/qt6ct/colors/DymicShellMatugen.conf"
    local rofi_import='@import "colors.rasi"'

    prepend_line_if_missing "$home/.config/gtk-3.0/gtk.css" "$gtk_import"
    prepend_line_if_missing "$home/.config/gtk-4.0/gtk.css" "$gtk_import"

    upsert_ini_key "$home/.config/fuzzel/fuzzel.ini" "main" "include" "$fuzzel_include"

    append_line_if_missing "$home/.config/ghostty/config" "$ghostty_theme"

    remove_line_if_present "$home/.config/kitty/kitty.conf" 'include dymicshell-matugen.conf'
    append_line_if_missing "$home/.config/kitty/kitty.conf" "$kitty_include"

    append_line_if_missing "$home/.config/mako/config" "$mako_include"

    if [ -f "$home/.mozilla/firefox/profiles.ini" ]; then
        for profile_dir in "$home"/.mozilla/firefox/*.default* "$home"/.mozilla/firefox/*.default-release*; do
            [ -d "$profile_dir" ] || continue
            prepend_line_if_missing "$profile_dir/chrome/userContent.css" "$firefox_import"
        done
    fi

    upsert_ini_key "$home/.config/qt5ct/qt5ct.conf" "Appearance" "color_scheme_path" "$qt5_scheme"
    upsert_ini_key "$home/.config/qt5ct/qt5ct.conf" "Appearance" "custom_palette" "true"
    upsert_ini_key "$home/.config/qt6ct/qt6ct.conf" "Appearance" "color_scheme_path" "$qt6_scheme"
    upsert_ini_key "$home/.config/qt6ct/qt6ct.conf" "Appearance" "custom_palette" "true"

    # Niri's main config should not be created from scratch because a standalone
    # include file is not a valid full config for fresh installs.
    if [ -f "$home/.config/niri/config.kdl" ]; then
        remove_line_if_present "$home/.config/niri/config.kdl" 'include "./dymicshell-matugen.kdl"'
        append_line_if_missing "$home/.config/niri/config.kdl" "$niri_include"
    fi

    prepend_line_if_missing "$home/.config/rofi/config.rasi" "$rofi_import"

    if command -v kitty >/dev/null 2>&1; then
        pkill -SIGUSR1 kitty >/dev/null 2>&1 || true
    fi

    if command -v makoctl >/dev/null 2>&1; then
        makoctl reload >/dev/null 2>&1 || true
    fi

    if command -v niri >/dev/null 2>&1; then
        niri msg action load-config-file >/dev/null 2>&1 || true
    fi

    if command -v plasma-apply-colorscheme >/dev/null 2>&1; then
        plasma-apply-colorscheme DymicShellMatugen >/dev/null 2>&1 || true
    fi
}

main "$@"
