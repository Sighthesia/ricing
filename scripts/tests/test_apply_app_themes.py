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


def run_apply(palette, mode, home_prefix):
    return subprocess.run(
        [sys.executable, str(SCRIPT), "--palette", str(palette),
         "--mode", mode, "--home-prefix", str(home_prefix)],
        capture_output=True, text=True, timeout=60)


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
