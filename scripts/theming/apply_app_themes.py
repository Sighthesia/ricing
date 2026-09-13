#!/usr/bin/env python3
"""
Apply Afloat's palette to system apps (noctalia/DymicShell model).

Renders the app template targets (kitty, GTK 3/4, qt5ct/qt6ct) from the
active palette for the effective light/dark mode, then applies them:

- gsettings org.gnome.desktop.interface color-scheme  -> system light/dark
- kitty.conf include line + SIGUSR1 reload            -> live kitty colors
- gtk-3.0/gtk-4.0 gtk.css @import                     -> GTK css pickup

Usage:
    python3 apply_app_themes.py --palette PATH --mode dark|light
        [--config app-themes.toml] [--home-prefix PATH]

--home-prefix redirects ~ expansion to a sandbox root and disables the
system hooks (gsettings/kitty signals); it exists for tests.
"""

from __future__ import annotations

import argparse
import configparser
import subprocess
import sys
from pathlib import Path

PROCESSOR = Path(__file__).resolve().parent / "template-processor.py"
DEFAULT_CONFIG = Path(__file__).resolve().parent / "templates" / "app-themes.toml"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        prog='apply-app-themes',
        description='Render Afloat app theme templates and apply them',
    )
    parser.add_argument('--palette', type=Path, default=None,
                        help='Palette JSON: {"dark": {...}, "light": {...}} (matugen schema)')
    parser.add_argument('--scheme-name', type=str, default=None,
                        help='Resolve a color scheme preset by name (user dir, then bundled)')
    parser.add_argument('--mode', choices=['dark', 'light'], required=True)
    parser.add_argument('--config', type=Path, default=DEFAULT_CONFIG)
    parser.add_argument('--home-prefix', type=Path, default=None,
                        help='Redirect ~ to this root for testing (disables system hooks)')
    parser.add_argument('--terminal-clear-text', dest='terminal_clear_text',
                        action='store_true', default=True,
                        help='Full-brightness terminal text for translucent backgrounds '
                             '(manages dim_opacity in kitty.conf; default: on)')
    parser.add_argument('--no-terminal-clear-text', dest='terminal_clear_text',
                        action='store_false',
                        help='Remove the managed clear-text lines from kitty.conf')
    parser.add_argument('--only-kitty-text', action='store_true', default=False,
                        help='Only sync the kitty.conf clear-text block, skip template rendering')
    parser.add_argument('--only-system-theme', action='store_true', default=False,
                        help='Only push the system light/dark preference (gsettings '
                             'color-scheme + gtk-theme), skip template rendering')
    return parser.parse_args()


def ensure_line(path: Path, line: str) -> bool:
    """Append line to path when missing. Returns True when file changed."""
    path.parent.mkdir(parents=True, exist_ok=True)
    existing = path.read_text() if path.exists() else ""
    if line in existing:
        return False
    with open(path, "a") as f:
        if existing and not existing.endswith("\n"):
            f.write("\n")
        f.write(line + "\n")
    return True


def _which(name: str) -> str | None:
    from shutil import which
    return which(name)


def notify_kde_theme() -> bool:
    """Tell KDE applications that global colors changed."""
    try:
        from jeepney import DBusAddress, new_signal
        from jeepney.io.blocking import open_dbus_connection

        address = DBusAddress(
            path="/KGlobalSettings",
            interface="org.kde.KGlobalSettings",
        )
        with open_dbus_connection(bus="SESSION") as connection:
            connection.send(new_signal(address, "notifyChange", "ii", (0, 0)))
        return True
    except ModuleNotFoundError:
        if not _which("dbus-send"):
            return False
        try:
            result = subprocess.run(
                ["dbus-send", "/KGlobalSettings",
                 "org.kde.KGlobalSettings.notifyChange", "int32:0", "int32:0"],
                capture_output=True,
                timeout=5,
            )
            return result.returncode == 0
        except (OSError, subprocess.TimeoutExpired):
            return False
    except Exception:
        return False


# Managed kitty.conf block for the "transparent-terminal clear text" setting:
# dim text is drawn translucent by kitty (0.75 default), which compounds with
# a translucent background and washes TUI secondary rows out. Full brightness
# keeps hierarchy readable on transparency (hierarchy reads via color).
# background_tint is intentionally NOT managed (user opted out); any stray
# background_tint line is removed as legacy.
_MANAGED_BEGIN = "# >>> Afloat managed: transparent-terminal clear text. Do not edit."
_MANAGED_END = "# <<< Afloat managed."
_MANAGED_BODY = ("dim_opacity 1.0\n")
# Stale hand-written comment lines from the manual fix (removed on sync).
_LEGACY_COMMENTS = {
    "# Tint the wallpaper bleed toward the background color so text stays",
    "# readable on translucent background (Afloat: keeps the glow, kills the washout)",
    "# Dim (SGR 2) text is drawn translucent by default (0.75); on a translucent",
    "# background that compounds and washes TUI secondary rows out entirely.",
    "# 1.0 = dim text at full brightness, fixes all terminal apps at once.",
    "# Drop to 0.9 if you want a hint of hierarchy back.",
    "# 1.0 = dim text at full brightness (applies to every terminal app, no",
    "# per-app templates needed). Drop to 0.9 if you want a hint of hierarchy back.",
}


def sync_kitty_clear_text(home: Path, enabled: bool) -> bool:
    """Sync the managed clear-text block in kitty.conf. Returns True on change."""
    conf = home / ".config/kitty/kitty.conf"
    conf.parent.mkdir(parents=True, exist_ok=True)
    existing = conf.read_text() if conf.exists() else ""

    kept: list[str] = []
    skip = False
    for raw in existing.splitlines():
        stripped = raw.strip()
        if stripped == _MANAGED_BEGIN:
            skip = True
            continue
        if stripped == _MANAGED_END:
            skip = False
            continue
        if skip:
            continue
        key = stripped.split()[0] if stripped.split() else ""
        if key in ("dim_opacity", "background_tint"):
            continue
        if stripped in _LEGACY_COMMENTS:
            continue
        kept.append(raw)

    if enabled:
        block = _MANAGED_BEGIN + "\n" + _MANAGED_BODY + _MANAGED_END
        text = "\n".join(kept).rstrip("\n")
        text = (text + "\n\n" if text else "") + block + "\n"
    else:
        text = "\n".join(kept)
        if text:
            text += "\n"
    if text == existing or (not text and not conf.exists()):
        return False
    conf.write_text(text)
    return True


def sync_kde_theme(home: Path) -> bool:
    """Merge the rendered Afloat scheme into kdeglobals."""
    source = home / ".local/share/color-schemes/Afloat.colors"
    target = home / ".config/kdeglobals"
    if not source.exists():
        return False

    parser = configparser.RawConfigParser()
    parser.optionxform = str
    parser.read(target)

    scheme = configparser.RawConfigParser()
    scheme.optionxform = str
    scheme.read(source)

    for section in scheme.sections():
        if not parser.has_section(section):
            parser.add_section(section)
        for key, value in scheme.items(section):
            parser.set(section, key, value)

    target.parent.mkdir(parents=True, exist_ok=True)
    with target.open("w") as output:
        parser.write(output, space_around_delimiters=False)
    return True


def _theme_exists(name: str) -> bool:
    """Check a GTK theme exists in the standard lookup locations."""
    import os
    bases = [
        Path.home() / ".themes",
        Path.home() / ".local/share/themes",
        Path("/usr/share/themes"),
        Path("/usr/local/share/themes"),
    ]
    for path in os.environ.get("XDG_DATA_DIRS", "").split(":"):
        if path:
            bases.append(Path(path) / "themes")
    return any((base / name).is_dir() for base in bases)


def _sync_gtk_theme(gsettings: str, mode: str) -> None:
    """Pair gtk-theme with the mode (adw-gtk3 <-> adw-gtk3-dark style).

    Derives the base name from the current value so any -dark-suffixed
    family works, and only sets when the counterpart actually exists.
    """
    try:
        current = subprocess.run(
            [gsettings, "get", "org.gnome.desktop.interface", "gtk-theme"],
            capture_output=True, text=True, timeout=5).stdout.strip().strip("'")
    except (OSError, subprocess.TimeoutExpired) as e:
        print(f"Warning: gtk-theme read failed: {e}", file=sys.stderr)
        return
    base = current[:-5] if current.endswith("-dark") else current
    target = base + ("" if mode == "light" else "-dark")
    if target == current or not _theme_exists(target):
        return
    try:
        subprocess.run(
            [gsettings, "set", "org.gnome.desktop.interface", "gtk-theme", target],
            capture_output=True, text=True, timeout=5)
    except (OSError, subprocess.TimeoutExpired) as e:
        print(f"Warning: gtk-theme set failed: {e}", file=sys.stderr)


def sync_system_theme(mode: str) -> None:
    """Push the system light/dark preference (portals, libadwaita, Electron).

    Standalone so a mode flip reaches Electron/Chromium even when full app
    template sync is disabled (noctalia syncGsettings model).
    """
    gsettings = _which("gsettings")
    if not gsettings:
        return
    value = "prefer-dark" if mode == "dark" else "prefer-light"
    try:
        current = subprocess.run(
            [gsettings, "get", "org.gnome.desktop.interface", "color-scheme"],
            capture_output=True, text=True, timeout=5).stdout.strip()
        if current != f"'{value}'":
            subprocess.run(
                [gsettings, "set", "org.gnome.desktop.interface",
                 "color-scheme", value],
                capture_output=True, text=True, timeout=5)
    except (OSError, subprocess.TimeoutExpired) as e:
        print(f"Warning: gsettings sync failed: {e}", file=sys.stderr)
        return
    # GTK3 visual theme pairs with the scheme (adw-gtk3 family).
    _sync_gtk_theme(gsettings, mode)


def run_hooks(mode: str) -> None:
    """System-level application hooks (never run under --home-prefix)."""
    sync_system_theme(mode)

    # Live kitty reload: the config include is ensured below in main().
    if _which("pkill"):
        try:
            subprocess.run(["pkill", "-USR1", "-x", "kitty"],
                           capture_output=True, timeout=5)
        except (OSError, subprocess.TimeoutExpired) as e:
            print(f"Warning: kitty reload failed: {e}", file=sys.stderr)


def main() -> int:
    args = parse_args()

    if args.home_prefix is not None:
        # Sandbox ~ for both the renderer and the include-ensure step.
        args.home_prefix.mkdir(parents=True, exist_ok=True)
        import os
        os.environ["HOME"] = str(args.home_prefix)

    if args.only_kitty_text:
        # Kitty-only fast path: no palette or template config needed.
        home = Path.home()
        sync_kitty_clear_text(home, args.terminal_clear_text)
        state = "on" if args.terminal_clear_text else "off"
        print(f"Kitty clear text {state}")
        return 0

    if args.only_system_theme:
        # System-theme-only fast path: no palette or template config needed.
        # Lets the shell push light/dark to portals/Electron even when full
        # app template sync is off.
        if args.home_prefix is None:
            sync_system_theme(args.mode)
        else:
            print("System theme sync skipped (sandbox)")
        print(f"System theme applied: mode={args.mode}")
        return 0

    if args.scheme_name:
        home = Path.home()
        candidates = [
            home / ".config/afloat/colorschemes" / args.scheme_name / f"{args.scheme_name}.json",
            Path(__file__).resolve().parents[2] / "Assets/ColorScheme"
                / args.scheme_name / f"{args.scheme_name}.json",
        ]
        args.palette = next((c for c in candidates if c.exists()), None)
        if args.palette is None:
            print(f"Error: scheme not found: {args.scheme_name}", file=sys.stderr)
            return 1
    if args.palette is None or not args.palette.exists():
        print(f"Error: palette not found: {args.palette}", file=sys.stderr)
        return 1
    if not args.config.exists():
        print(f"Error: config not found: {args.config}", file=sys.stderr)
        return 1

    render = subprocess.run(
        [sys.executable, str(PROCESSOR),
         "--scheme", str(args.palette),
         "--mode", args.mode,
         "--default-mode", args.mode,
         "--config", str(args.config)],
        capture_output=True, text=True,
        # Matugen semantics: template input_path is relative to the config.
        cwd=args.config.parent)
    if render.returncode != 0:
        sys.stderr.write(render.stderr)
        return render.returncode

    home = Path.home()
    ensure_line(home / ".config/kitty/kitty.conf", "include kitty-colors.conf")
    ensure_line(home / ".config/gtk-3.0/gtk.css", "@import 'colors.css';")
    ensure_line(home / ".config/gtk-4.0/gtk.css", "@import 'colors.css';")
    sync_kitty_clear_text(home, args.terminal_clear_text)
    sync_kde_theme(home)

    if args.home_prefix is None:
        notify_kde_theme()
        run_hooks(args.mode)

    print(f"App themes applied: palette={args.palette} mode={args.mode}")
    return 0


if __name__ == '__main__':
    sys.exit(main())
