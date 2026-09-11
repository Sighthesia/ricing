"""Tests for apply_app_themes.py: sandboxed render + include hooks."""

import json
import subprocess
import sys
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parents[2]
SCRIPT = REPO / "scripts" / "theming" / "apply_app_themes.py"

# Minimal matugen-schema palette (snake_case), Catppuccin-dark-like.
PALETTE = {
    "dark": {
        "primary": "#cba6f7", "on_primary": "#11111b",
        "secondary": "#fab387", "on_secondary": "#11111b",
        "tertiary": "#94e2d5", "on_tertiary": "#11111b",
        "error": "#f38ba8", "on_error": "#11111b",
        "surface": "#1e1e2e", "on_surface": "#cdd6f4",
        "surface_variant": "#313244", "on_surface_variant": "#a3b4eb",
        "outline": "#4c4f69", "shadow": "#11111b",
    },
    "light": {
        "primary": "#8839ef", "on_primary": "#eff1f5",
        "secondary": "#fe640b", "on_secondary": "#eff1f5",
        "tertiary": "#40a02b", "on_tertiary": "#eff1f5",
        "error": "#d20f39", "on_error": "#dce0e8",
        "surface": "#eff1f5", "on_surface": "#4c4f69",
        "surface_variant": "#ccd0da", "on_surface_variant": "#6c6f85",
        "outline": "#8c8fa1", "shadow": "#dce0e8",
    },
}


@pytest.fixture()
def sandbox(tmp_path):
    palette = tmp_path / "palette.json"
    palette.write_text(json.dumps(PALETTE))
    return tmp_path, palette


def run_apply(palette, mode, home_prefix, extra=None):
    cmd = [sys.executable, str(SCRIPT), "--palette", str(palette),
           "--mode", mode, "--home-prefix", str(home_prefix)]
    if extra:
        cmd.extend(extra)
    return subprocess.run(cmd, capture_output=True, text=True, timeout=60)


def test_dark_render_and_includes(sandbox):
    tmp, palette = sandbox
    result = run_apply(palette, "dark", tmp / "home")
    assert result.returncode == 0, result.stderr

    home = tmp / "home"
    kitty_colors = home / ".config/kitty/kitty-colors.conf"
    assert kitty_colors.exists()
    # Normalize the template's column alignment before matching.
    content = " ".join(kitty_colors.read_text().split())
    # Dark surface mapped to background.
    assert "background #1e1e2e" in content
    assert "foreground #cdd6f4" in content

    # Include line appended to kitty.conf exactly once.
    kitty_conf = home / ".config/kitty/kitty.conf"
    assert kitty_conf.read_text().count("include kitty-colors.conf") == 1

    # GTK css files for both majors with the import wired.
    for major in ("gtk-3.0", "gtk-4.0"):
        colors = home / f".config/{major}/colors.css"
        gtkcss = home / f".config/{major}/gtk.css"
        assert colors.exists(), major
        assert f"@define-color window_bg_color #1e1e2e" in colors.read_text()
        assert "@import 'colors.css';" in gtkcss.read_text(), major

    # qtct palette written for both majors.
    for major in ("qt5ct", "qt6ct"):
        conf = home / f".config/{major}/colors/Afloat.conf"
        assert conf.exists(), major
        assert "#1e1e2e" in conf.read_text()


def test_light_variant_switch(sandbox):
    tmp, palette = sandbox
    home = tmp / "home"
    assert run_apply(palette, "dark", home).returncode == 0
    assert run_apply(palette, "light", home).returncode == 0
    content = " ".join((home / ".config/kitty/kitty-colors.conf").read_text().split())
    assert "background #eff1f5" in content
    assert "background #1e1e2e" not in content


def test_include_idempotent(sandbox):
    tmp, palette = sandbox
    home = tmp / "home"
    assert run_apply(palette, "dark", home).returncode == 0
    assert run_apply(palette, "dark", home).returncode == 0
    kitty_conf = home / ".config/kitty/kitty.conf"
    assert kitty_conf.read_text().count("include kitty-colors.conf") == 1
    gtkcss = home / ".config/gtk-3.0/gtk.css"
    assert gtkcss.read_text().count("@import 'colors.css';") == 1


def test_missing_palette_fails(sandbox):
    tmp, _ = sandbox
    result = run_apply(tmp / "missing.json", "dark", tmp / "home")
    assert result.returncode == 1


def test_opencode_dual_variant(sandbox):
    import json as _json
    tmp, palette = sandbox
    home = tmp / "home"
    # Light apply must still carry the dark variant (opencode picks at runtime).
    assert run_apply(palette, "light", home).returncode == 0
    theme = _json.loads((home / ".config/opencode/themes/Afloat.json").read_text())
    text = theme["theme"]["text"]
    assert text["light"] == "#4c4f69", text
    assert text["dark"] == "#cdd6f4", text
    assert theme["theme"]["background"] == "none"
    # Dark apply keeps the light variant too.
    assert run_apply(palette, "dark", home).returncode == 0
    theme = _json.loads((home / ".config/opencode/themes/Afloat.json").read_text())
    assert theme["theme"]["text"]["light"] == "#4c4f69"
    assert theme["theme"]["text"]["dark"] == "#cdd6f4"


def test_terminal_clear_text_on_by_default(sandbox):
    tmp, palette = sandbox
    home = tmp / "home"
    assert run_apply(palette, "dark", home).returncode == 0
    conf = (home / ".config/kitty/kitty.conf").read_text()
    assert "dim_opacity 1.0" in conf
    # Background tint is intentionally unmanaged (user opt-out).
    assert "background_tint" not in conf
    # Idempotent: second apply keeps exactly one managed block.
    assert run_apply(palette, "dark", home).returncode == 0
    conf = (home / ".config/kitty/kitty.conf").read_text()
    assert conf.count(">>> Afloat managed") == 1
    assert conf.count("<<< Afloat managed") == 1
    assert conf.count("dim_opacity") == 1


def test_terminal_clear_text_off_removes_block(sandbox):
    tmp, palette = sandbox
    home = tmp / "home"
    assert run_apply(palette, "dark", home).returncode == 0
    assert run_apply(palette, "dark", home,
                      ["--no-terminal-clear-text"]).returncode == 0
    conf = (home / ".config/kitty/kitty.conf").read_text()
    assert "dim_opacity" not in conf
    assert "background_tint" not in conf
    assert "Afloat managed" not in conf


def test_terminal_clear_text_replaces_legacy_lines(sandbox):
    tmp, palette = sandbox
    home = tmp / "home"
    kitty_dir = home / ".config/kitty"
    kitty_dir.mkdir(parents=True)
    (kitty_dir / "kitty.conf").write_text(
        "background_opacity 0.7\n"
        "# Tint the wallpaper bleed toward the background color so text stays\n"
        "background_tint             0.35\n"
        "dim_opacity 0.8\n"
        "shell fish\n")
    assert run_apply(palette, "dark", home).returncode == 0
    conf = (kitty_dir / "kitty.conf").read_text()
    assert "background_opacity 0.7" in conf
    assert "shell fish" in conf
    assert "Tint the wallpaper bleed" not in conf
    assert conf.count("dim_opacity") == 1
    assert "dim_opacity 1.0" in conf


def test_only_kitty_text_needs_no_palette(sandbox):
    tmp, _ = sandbox
    home = tmp / "home"
    result = run_apply(tmp / "missing.json", "dark", home, ["--only-kitty-text"])
    assert result.returncode == 0, result.stderr
    conf = (home / ".config/kitty/kitty.conf").read_text()
    assert "dim_opacity 1.0" in conf


def _slot(content, name):
    import re
    match = re.search(rf"^{name}\s+(#[0-9a-fA-F]{{6}})", content, re.MULTILINE)
    assert match, name
    return match.group(1).lower()


def test_kitty_greys_track_modes(sandbox):
    tmp, palette = sandbox
    home = tmp / "home"
    assert run_apply(palette, "dark", home).returncode == 0
    dark = (home / ".config/kitty/kitty-colors.conf").read_text()
    assert run_apply(palette, "light", home).returncode == 0
    light = (home / ".config/kitty/kitty-colors.conf").read_text()
    assert "{{" not in dark and "{{" not in light
    # Black slot is a true dark distinct from the background in both modes.
    assert _slot(dark, "color0") != _slot(dark, "background")
    assert _slot(light, "color0") != _slot(light, "background")
    # Bright-black stays apart from the foreground in both modes.
    assert _slot(dark, "color8") != _slot(dark, "foreground")
    assert _slot(light, "color8") != _slot(light, "foreground")


def test_kitty_accents_are_distinct(sandbox):
    tmp, palette = sandbox
    home = tmp / "home"
    assert run_apply(palette, "dark", home).returncode == 0
    dark = (home / ".config/kitty/kitty-colors.conf").read_text()
    assert run_apply(palette, "light", home).returncode == 0
    light = (home / ".config/kitty/kitty-colors.conf").read_text()
    for content in (dark, light):
        accents = {_slot(content, f"color{i}") for i in (1, 2, 3, 4, 5, 6)}
        assert len(accents) == 6, accents
