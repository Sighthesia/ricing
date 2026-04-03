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

apply_live_terminal_sequences() {
    local sequences_file="$1"
    local sequences_text
    local tty

    [ -f "$sequences_file" ] || return 0

    sequences_text=$(<"$sequences_file")

    shopt -s nullglob
    for tty in /dev/pts/[0-9]*; do
        [ -w "$tty" ] || continue
        printf '%b' "$sequences_text" > "$tty" 2>/dev/null || true
    done
    shopt -u nullglob
}

reload_kitty() {
    local kitty_colors_file="$1"
    local kitty_remote_socket="$2"

    if ! command -v kitty >/dev/null 2>&1; then
        return 0
    fi

    kitty_reload_all() {
        kitty +runpy "from kitty.utils import reload_conf_in_all_kitties; reload_conf_in_all_kitties()" >/dev/null 2>&1
    }

    if [ -S /tmp/kitty ]; then
        printf '[matugen-apply] kitty branch=set-colors socket=%s\n' "$kitty_remote_socket"
        if kitty @ --to "$kitty_remote_socket" set-colors --all --configured "$kitty_colors_file"; then
            printf '[matugen-apply] kitty set-colors rc=0\n'
        else
            printf '[matugen-apply] kitty set-colors rc=%s\n' "$?"
            printf '[matugen-apply] kitty falling back to reload_conf_in_all_kitties\n'
            if kitty_reload_all; then
                printf '[matugen-apply] kitty reload-conf rc=0\n'
            else
                printf '[matugen-apply] kitty reload-conf rc=1\n'
            fi
        fi
    else
        printf '[matugen-apply] kitty socket missing at %s; restart kitty once to enable live reload\n' "$kitty_remote_socket"
        printf '[matugen-apply] kitty branch=reload-conf\n'
        if kitty_reload_all; then
            printf '[matugen-apply] kitty reload-conf rc=0\n'
        else
            printf '[matugen-apply] kitty reload-conf rc=1\n'
        fi
    fi
}

main() {
    local home="${HOME:?}"
    local kitty_colors_file="$home/.config/kitty/kitty-colors.conf"
    local kitty_remote_socket="unix:/tmp/kitty"
    local mode="${1:-}"
    local apply_scope="${2:-full}"
    local gtk_import='@import url("colors.css");'
    local gtk_dark_preference
    local fuzzel_include='~/.config/fuzzel/colors.ini'
    local gsettings_color_scheme
    local ghostty_theme='theme = "DymicShellMatugen"'
    local kitty_include='include kitty-colors.conf'
    local mako_include='include=~/.config/mako/mako-colors'
    local niri_include='include "./colors.kdl"'
    local qt5_scheme="$home/.config/qt5ct/colors/DymicShellMatugen.conf"
    local qt6_scheme="$home/.config/qt6ct/colors/DymicShellMatugen.conf"
    local rofi_import='@import "colors.rasi"'
    local terminal_sequences_file="$home/.cache/terminal-sequences"

    case "$mode" in
        dark)
            gtk_dark_preference="1"
            gsettings_color_scheme="prefer-dark"
            ;;
        light)
            gtk_dark_preference="0"
            gsettings_color_scheme="prefer-light"
            ;;
        *)
            printf 'usage: %s <dark|light>\n' "${0##*/}" >&2
            return 1
            ;;
    esac

    case "$apply_scope" in
        full|--full)
            apply_scope="full"
            ;;
        --system-only)
            apply_scope="system-only"
            ;;
        *)
            printf 'usage: %s <dark|light> [--system-only]\n' "${0##*/}" >&2
            return 1
            ;;
    esac

    printf '[matugen-apply] mode=%s scope=%s\n' "$mode" "$apply_scope"

    prepend_line_if_missing "$home/.config/gtk-3.0/gtk.css" "$gtk_import"
    prepend_line_if_missing "$home/.config/gtk-4.0/gtk.css" "$gtk_import"
    upsert_ini_key "$home/.config/gtk-3.0/settings.ini" "Settings" "gtk-application-prefer-dark-theme" "$gtk_dark_preference"
    upsert_ini_key "$home/.config/gtk-4.0/settings.ini" "Settings" "gtk-application-prefer-dark-theme" "$gtk_dark_preference"

    if command -v gsettings >/dev/null 2>&1; then
        gsettings set org.gnome.desktop.interface color-scheme "$gsettings_color_scheme" >/dev/null 2>&1 || true
    fi

    if [ "$apply_scope" = "system-only" ]; then
        reload_kitty "$kitty_colors_file" "$kitty_remote_socket"
        return 0
    fi

    upsert_ini_key "$home/.config/fuzzel/fuzzel.ini" "main" "include" "$fuzzel_include"

    append_line_if_missing "$home/.config/ghostty/config" "$ghostty_theme"

    remove_line_if_present "$home/.config/kitty/kitty.conf" 'include dymicshell-matugen.conf'
    append_line_if_missing "$home/.config/kitty/kitty.conf" "$kitty_include"

    append_line_if_missing "$home/.config/mako/config" "$mako_include"

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

    reload_kitty "$kitty_colors_file" "$kitty_remote_socket"

    if command -v makoctl >/dev/null 2>&1; then
        makoctl reload >/dev/null 2>&1 || true
    fi

    if command -v btop >/dev/null 2>&1; then
        if pkill -SIGUSR2 btop >/dev/null 2>&1; then
            printf '[matugen-apply] btop sigusr2 rc=0\n'
        else
            printf '[matugen-apply] btop sigusr2 rc=1\n'
        fi
    fi

    if command -v niri >/dev/null 2>&1; then
        niri msg action load-config-file >/dev/null 2>&1 || true
    fi

    if command -v plasma-apply-colorscheme >/dev/null 2>&1; then
        plasma-apply-colorscheme DymicShellMatugen >/dev/null 2>&1 || true
    fi

}

main "$@"
