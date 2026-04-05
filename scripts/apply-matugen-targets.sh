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

upsert_plain_key() {
    local file="$1"
    local key="$2"
    local value="$3"
    local tmp

    ensure_file "$file"
    tmp=$(mktemp "${file}.XXXXXX")

    awk -v key="$key" -v value="$value" '
        BEGIN {
            wrote_key = 0
        }

        {
            if ($0 ~ ("^" key " *= *")) {
                print key " = " value
                wrote_key = 1
                next
            }

            print
        }

        END {
            if (!wrote_key)
                print key " = " value
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
    local kitty_socket_path="${kitty_remote_socket#unix:}"
    local kitty_socket
    local kitty_reloaded=0
    local kitty_signal_sent=0

    if ! command -v kitty >/dev/null 2>&1; then
        return 0
    fi

    kitty_reload_all() {
        kitty +runpy "from kitty.utils import reload_conf_in_all_kitties; reload_conf_in_all_kitties()" >/dev/null 2>&1
    }

    kitty_signal_all() {
        if [ "$kitty_signal_sent" -eq 1 ]; then
            return 0
        fi

        if pgrep -x kitty >/dev/null 2>&1; then
            pkill -USR1 -x kitty >/dev/null 2>&1 || true
            kitty_signal_sent=1
            printf '[matugen-apply] kitty sigusr1 rc=0\n'
        fi
    }

    shopt -s nullglob
    for kitty_socket in /tmp/kitty-*; do
        [ -S "$kitty_socket" ] || continue
        printf '[matugen-apply] kitty branch=set-colors socket=unix:%s\n' "$kitty_socket"
        if kitty @ --to "unix:$kitty_socket" set-colors --all --configured "$kitty_colors_file" >/dev/null 2>&1; then
            kitty_reloaded=1
            printf '[matugen-apply] kitty set-colors rc=0 socket=unix:%s\n' "$kitty_socket"
        else
            printf '[matugen-apply] kitty set-colors rc=1 socket=unix:%s\n' "$kitty_socket"
        fi
    done
    shopt -u nullglob

    if [ "$kitty_reloaded" -eq 1 ]; then
        kitty_signal_all
        return 0
    fi

    if [ -S "$kitty_socket_path" ]; then
        printf '[matugen-apply] kitty branch=set-colors socket=%s\n' "$kitty_remote_socket"
        if kitty @ --to "$kitty_remote_socket" set-colors --all --configured "$kitty_colors_file" >/dev/null 2>&1; then
            printf '[matugen-apply] kitty set-colors rc=0\n'
            kitty_signal_all
            return 0
        fi
        printf '[matugen-apply] kitty set-colors rc=1\n'
    else
        printf '[matugen-apply] kitty socket missing at %s; scanning /tmp/kitty-* found no live target\n' "$kitty_remote_socket"
    fi

    printf '[matugen-apply] kitty branch=reload-conf\n'
    if kitty_reload_all; then
        printf '[matugen-apply] kitty reload-conf rc=0\n'
    else
        printf '[matugen-apply] kitty reload-conf rc=1\n'
    fi
    kitty_signal_all
}

reload_btop() {
    local btop_pid
    local btop_reloaded=1

    if ! command -v btop >/dev/null 2>&1; then
        return 0
    fi

    while IFS= read -r btop_pid; do
        [ -n "$btop_pid" ] || continue
        if kill -USR2 "$btop_pid" >/dev/null 2>&1; then
            printf '[matugen-apply] btop sigusr2 rc=0 pid=%s\n' "$btop_pid"
        else
            btop_reloaded=0
            printf '[matugen-apply] btop sigusr2 rc=1 pid=%s\n' "$btop_pid"
        fi
    done <<EOF
$(pgrep -x btop || true)
EOF

    if ! pgrep -x btop >/dev/null 2>&1; then
        printf '[matugen-apply] btop sigusr2 rc=1 pid=none\n'
        return 0
    fi

    return "$btop_reloaded"
}

reload_yazi() {
    if ! command -v ya >/dev/null 2>&1; then
        return 0
    fi

    if ! pgrep -x yazi >/dev/null 2>&1; then
        return 0
    fi

    if ya emit-to 0 refresh >/dev/null 2>&1; then
        printf '[matugen-apply] yazi refresh rc=0\n'
    else
        printf '[matugen-apply] yazi refresh rc=1\n'
    fi

    if ya emit-to 0 render >/dev/null 2>&1; then
        printf '[matugen-apply] yazi render rc=0\n'
    else
        printf '[matugen-apply] yazi render rc=1\n'
    fi

    printf '[matugen-apply] yazi note=runtime theme file reload depends on upstream support\n'
}

cleanup_old_theme_artifacts() {
    rm -f \
        "$HOME/.config/qt5ct/colors/DymicShellMatugen.conf" \
        "$HOME/.config/qt6ct/colors/DymicShellMatugen.conf" \
        "$HOME/.config/ghostty/themes/DymicShellMatugen" \
        "$HOME/.config/wezterm/colors/DymicShellMatugen.toml" \
        "$HOME/.local/share/color-schemes/MatugenAlt.colors"
}

reload_kde_colorscheme() {
    local primary_scheme="$1"
    local state_file="$2"
    if ! command -v plasma-apply-colorscheme >/dev/null 2>&1; then
        return 0
    fi

    if plasma-apply-colorscheme "$primary_scheme" >/dev/null 2>&1; then
        ensure_parent "$state_file"
        printf '%s\n' "$primary_scheme" > "$state_file"
        printf '[matugen-apply] kde colorscheme=%s rc=0\n' "$primary_scheme"
    else
        printf '[matugen-apply] kde colorscheme=%s rc=1\n' "$primary_scheme"
    fi
}

main() {
    local home="${HOME:?}"
    local btop_theme_name="matugen"
    local kde_primary_scheme="Matugen"
    local kde_primary_scheme_file="$home/.local/share/color-schemes/${kde_primary_scheme}.colors"
    local kde_state_file="$home/.cache/DymicShell/plasma-colorscheme-name"
    local kitty_colors_file="$home/.config/kitty/kitty-colors.conf"
    local kitty_remote_socket="unix:/tmp/kitty"
    local kvantum_theme_name="matugen"
    local mode="${1:-}"
    local apply_scope="${2:-full}"
    local gtk_import='@import url("colors.css");'
    local gtk_dark_preference
    local gtk_theme_name
    local fuzzel_include='~/.config/fuzzel/colors.ini'
    local gsettings_color_scheme
    local ghostty_theme='theme = "Matugen"'
    local kitty_include='include kitty-colors.conf'
    local mako_include='include=~/.config/mako/mako-colors'
    local niri_include='include "./colors.kdl"'
    local qt5_scheme="$home/.config/qt5ct/colors/Matugen.conf"
    local qt6_scheme="$home/.config/qt6ct/colors/Matugen.conf"
    local rofi_import='@import "colors.rasi"'
    local terminal_sequences_file="$home/.cache/terminal-sequences"

    case "$mode" in
        dark)
            gtk_dark_preference="1"
            gtk_theme_name="adw-gtk3-dark"
            gsettings_color_scheme="prefer-dark"
            ;;
        light)
            gtk_dark_preference="0"
            gtk_theme_name="adw-gtk3"
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
    upsert_ini_key "$home/.config/gtk-3.0/settings.ini" "Settings" "gtk-theme-name" "$gtk_theme_name"
    upsert_ini_key "$home/.config/gtk-4.0/settings.ini" "Settings" "gtk-theme-name" "$gtk_theme_name"
    upsert_ini_key "$home/.config/gtk-3.0/settings.ini" "Settings" "gtk-application-prefer-dark-theme" "$gtk_dark_preference"
    upsert_ini_key "$home/.config/gtk-4.0/settings.ini" "Settings" "gtk-application-prefer-dark-theme" "$gtk_dark_preference"

    if command -v gsettings >/dev/null 2>&1; then
        gsettings set org.gnome.desktop.interface gtk-theme "$gtk_theme_name" >/dev/null 2>&1 || true
        gsettings set org.gnome.desktop.interface color-scheme "$gsettings_color_scheme" >/dev/null 2>&1 || true
    fi

    if [ "$apply_scope" = "system-only" ]; then
        reload_kitty "$kitty_colors_file" "$kitty_remote_socket"
        cleanup_old_theme_artifacts
        return 0
    fi

    upsert_ini_key "$home/.config/fuzzel/fuzzel.ini" "main" "include" "$fuzzel_include"

    append_line_if_missing "$home/.config/ghostty/config" "$ghostty_theme"

    remove_line_if_present "$home/.config/kitty/kitty.conf" 'include dymicshell-matugen.conf'
    append_line_if_missing "$home/.config/kitty/kitty.conf" "$kitty_include"

    append_line_if_missing "$home/.config/mako/config" "$mako_include"

    upsert_plain_key "$home/.config/btop/btop.conf" "color_theme" "\"$btop_theme_name\""

    upsert_ini_key "$home/.config/qt5ct/qt5ct.conf" "Appearance" "color_scheme_path" "$qt5_scheme"
    upsert_ini_key "$home/.config/qt5ct/qt5ct.conf" "Appearance" "custom_palette" "true"
    upsert_ini_key "$home/.config/qt6ct/qt6ct.conf" "Appearance" "color_scheme_path" "$qt6_scheme"
    upsert_ini_key "$home/.config/qt6ct/qt6ct.conf" "Appearance" "custom_palette" "true"
    upsert_ini_key "$home/.config/Kvantum/kvantum.kvconfig" "General" "theme" "$kvantum_theme_name"

    # Niri's main config should not be created from scratch because a standalone
    # include file is not a valid full config for fresh installs.
    if [ -f "$home/.config/niri/config.kdl" ]; then
        remove_line_if_present "$home/.config/niri/config.kdl" 'include "./dymicshell-matugen.kdl"'
        append_line_if_missing "$home/.config/niri/config.kdl" "$niri_include"
    fi

    prepend_line_if_missing "$home/.config/rofi/config.rasi" "$rofi_import"

    apply_live_terminal_sequences "$terminal_sequences_file"

    reload_kitty "$kitty_colors_file" "$kitty_remote_socket"

    if command -v makoctl >/dev/null 2>&1; then
        makoctl reload >/dev/null 2>&1 || true
    fi

    reload_btop || true

    reload_yazi

    if command -v niri >/dev/null 2>&1; then
        niri msg action load-config-file >/dev/null 2>&1 || true
    fi

    reload_kde_colorscheme "$kde_primary_scheme" "$kde_state_file"

    cleanup_old_theme_artifacts

}

main "$@"
