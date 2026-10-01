"""Tests for apply_app_themes.py: sandboxed render + include hooks."""

import json
import re
import subprocess
import sys
import types
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


def test_sandbox_skips_kde_notification(sandbox, monkeypatch):
    import importlib.util
    spec = importlib.util.spec_from_file_location("apply_app_themes", SCRIPT)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    calls = []
    monkeypatch.setattr(module, "notify_kde_theme", lambda: calls.append(True) or True)

    monkeypatch.setattr(sys, "argv", [
        str(SCRIPT), "--palette", str(sandbox[1]), "--mode", "dark",
        "--home-prefix", str(sandbox[0] / "home"),
    ])
    monkeypatch.setenv("HOME", str(Path.home()))
    assert module.main() == 0
    assert calls == []


def test_notify_kde_theme_uses_jeepney_signal(monkeypatch):
    from unittest.mock import Mock

    address = object()
    signal = object()
    connection = Mock()
    context = Mock()
    context.__enter__ = Mock(return_value=connection)
    context.__exit__ = Mock(return_value=False)
    def assert_address(path, *, interface):
        assert path == "/KGlobalSettings"
        assert interface == "org.kde.KGlobalSettings"
        return address

    dbus_address = Mock(side_effect=assert_address)
    new_signal = Mock(return_value=signal)
    open_connection = Mock(return_value=context)
    jeepney = types.ModuleType("jeepney")
    jeepney.DBusAddress = dbus_address
    jeepney.new_signal = new_signal
    jeepney_io = types.ModuleType("jeepney.io")
    jeepney_blocking = types.ModuleType("jeepney.io.blocking")
    jeepney_blocking.open_dbus_connection = open_connection

    import importlib.util
    spec = importlib.util.spec_from_file_location("apply_app_themes", SCRIPT)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    monkeypatch.setitem(sys.modules, "jeepney", jeepney)
    monkeypatch.setitem(sys.modules, "jeepney.io", jeepney_io)
    monkeypatch.setitem(sys.modules, "jeepney.io.blocking", jeepney_blocking)

    assert module.notify_kde_theme() is True
    dbus_address.assert_called_once_with(
        "/KGlobalSettings", interface="org.kde.KGlobalSettings")
    open_connection.assert_called_once_with(bus="SESSION")
    new_signal.assert_called_once_with(address, "notifyChange", "ii", (0, 0))
    connection.send.assert_called_once_with(signal)


def test_notify_kde_theme_falls_back_to_dbus_send(monkeypatch):
    from unittest.mock import Mock, patch

    import importlib.util
    spec = importlib.util.spec_from_file_location("apply_app_themes", SCRIPT)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    completed = Mock(returncode=0)
    monkeypatch.setattr(module, "_which", Mock(return_value="/usr/bin/dbus-send"))
    with patch.dict(sys.modules, {
        "jeepney": None,
        "jeepney.io": None,
        "jeepney.io.blocking": None,
    }), patch.object(module.subprocess, "run", return_value=completed) as run:
        assert module.notify_kde_theme() is True

    run.assert_called_once_with(
        ["dbus-send", "/KGlobalSettings",
         "org.kde.KGlobalSettings.notifyChange", "int32:0", "int32:0"],
        capture_output=True,
        timeout=5,
    )


def test_notify_kde_theme_falls_back_after_jeepney_runtime_failure(monkeypatch):
    from unittest.mock import Mock, patch

    import importlib.util
    spec = importlib.util.spec_from_file_location("apply_app_themes", SCRIPT)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    jeepney = types.ModuleType("jeepney")
    jeepney.DBusAddress = Mock(side_effect=RuntimeError("broken jeepney"))
    jeepney_io = types.ModuleType("jeepney.io")
    jeepney_blocking = types.ModuleType("jeepney.io.blocking")
    jeepney_blocking.open_dbus_connection = Mock()
    completed = Mock(returncode=0)
    monkeypatch.setattr(module, "_which", Mock(return_value="/usr/bin/dbus-send"))
    with patch.dict(sys.modules, {
        "jeepney": jeepney,
        "jeepney.io": jeepney_io,
        "jeepney.io.blocking": jeepney_blocking,
    }), patch.object(module.subprocess, "run", return_value=completed) as run:
        assert module.notify_kde_theme() is True
    run.assert_called_once()


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

    kde_colors = home / ".local/share/color-schemes/Afloat.colors"
    assert kde_colors.exists()
    kde_content = kde_colors.read_text()
    assert "BackgroundNormal=30,30,46" in kde_content
    assert "ForegroundNormal=205,214,244" in kde_content
    assert "DecorationFocus=203,166,247" in kde_content
    assert "ForegroundNegative=243,139,168" in kde_content

    niri = home / ".config/niri/config.kdl"
    niri.write_text('include "./DymicShell-colors.kdl"\nlayout {\n    gaps 8\n}\n')
    result = run_apply(palette, "dark", home)
    assert result.returncode == 0, result.stderr
    niri_content = niri.read_text()
    assert "DymicShell-colors.kdl" not in niri_content
    assert 'include "./afloat-colors.kdl"' in niri_content
    assert "gaps 8" in niri_content


def test_kdeglobals_preserves_unrelated_settings(sandbox):
    tmp, palette = sandbox
    home = tmp / "home"
    kdeglobals = home / ".config/kdeglobals"
    kdeglobals.parent.mkdir(parents=True)
    kdeglobals.write_text("[KDE]\nwidgetStyle=oxygen\n\n[Fonts]\nfixed=Monospace,10\n")

    result = run_apply(palette, "dark", home)
    assert result.returncode == 0, result.stderr

    content = kdeglobals.read_text()
    assert "widgetStyle=oxygen" in content
    assert "fixed=Monospace,10" in content
    assert "BackgroundNormal=30,30,46" in content


def test_light_variant_switch(sandbox):
    tmp, palette = sandbox
    home = tmp / "home"
    assert run_apply(palette, "dark", home).returncode == 0
    assert run_apply(palette, "light", home).returncode == 0
    content = " ".join((home / ".config/kitty/kitty-colors.conf").read_text().split())
    assert "background #eff1f5" in content
    assert "background #1e1e2e" not in content
    kde = (home / ".local/share/color-schemes/Afloat.colors").read_text()
    assert "BackgroundNormal=239,241,245" in kde
    assert "ForegroundNormal=76,79,105" in kde


def test_malformed_kdeglobals_does_not_abort_other_sync(sandbox):
    tmp, palette = sandbox
    home = tmp / "home"
    kdeglobals = home / ".config/kdeglobals"
    kdeglobals.parent.mkdir(parents=True)
    kdeglobals.write_text("[KDE]\nwidgetStyle=oxygen\nwidgetStyle=plastique\n")

    result = run_apply(palette, "dark", home)
    assert result.returncode == 0, result.stderr
    assert "Warning: KDE theme sync failed:" in result.stderr
    assert "background #1e1e2e" in " ".join(
        (home / ".config/kitty/kitty-colors.conf").read_text().split())
    assert (home / ".config/gtk-3.0/colors.css").exists()
    assert kdeglobals.read_text() == "[KDE]\nwidgetStyle=oxygen\nwidgetStyle=plastique\n"


def test_kde_source_read_failure_does_not_abort_other_sync(sandbox, monkeypatch, capsys):
    import importlib.util

    tmp, palette = sandbox
    home = tmp / "home"
    spec = importlib.util.spec_from_file_location("apply_app_themes", SCRIPT)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)

    original_read_text = Path.read_text

    def fail_kde_source(path, *args, **kwargs):
        if path == home / ".local/share/color-schemes/Afloat.colors":
            raise OSError("simulated KDE source read failure")
        return original_read_text(path, *args, **kwargs)

    monkeypatch.setattr(Path, "read_text", fail_kde_source)
    monkeypatch.setattr(sys, "argv", [
        str(SCRIPT), "--palette", str(palette), "--mode", "dark",
        "--home-prefix", str(home),
    ])

    assert module.main() == 0
    assert "Warning: KDE theme sync failed: simulated KDE source read failure" in capsys.readouterr().err
    assert (home / ".config/kitty/kitty-colors.conf").exists()
    assert (home / ".config/gtk-3.0/colors.css").exists()


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


def _kitty_background(home: Path) -> str:
    """The colour kitty's window background was rendered to for this apply."""
    conf = (home / ".config/kitty/kitty-colors.conf").read_text()
    match = re.search(r"^background\s+(\S+)", conf, re.MULTILINE)
    assert match, conf
    return match.group(1)


def _relative_luminance(colour: str) -> float:
    channels = [int(colour[i:i + 2], 16) / 255 for i in (1, 3, 5)]
    linear = [c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in channels]
    return 0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2]


def _contrast(a: str, b: str) -> float:
    la, lb = _relative_luminance(a), _relative_luminance(b)
    return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)


# opencode's native theme tree. The legacy flat format (one {dark, light} pair
# per token) cannot express the action / form-field / feedback roles, and
# opencode filled the gaps from its own defaults: a hardcoded white in light
# mode and black in dark mode — invisible text on either surface. Every role
# below must therefore be present and hold a real colour.
_ACTION_STATES = ("base", "$hovered", "$focused", "$pressed", "$selected", "$disabled")
_ACTION_VARIANTS = ("primary", "secondary", "destructive")
_FEEDBACK = ("error", "warning", "success", "info")


def _action_group() -> dict:
    return dict.fromkeys(_ACTION_STATES, str)


def opencode_token_tree() -> dict:
    """The shape opencode accepts, mirrored from its own schema."""
    return {
        "text": {
            "base": str,
            "muted": str,
            "action": {v: _action_group() for v in _ACTION_VARIANTS},
            "formfield": _action_group(),
            "feedback": {f: {"base": str, "muted": str} for f in _FEEDBACK},
        },
        "background": {
            "base": str,
            "raised": {"base": str, "high": str, "max": str},
            "action": {v: _action_group() for v in _ACTION_VARIANTS},
            "formfield": _action_group(),
            "feedback": {f: {"base": str} for f in _FEEDBACK},
        },
        "border": {"base": str},
        "scrollbar": {"base": str},
        "diff": {
            "text": {k: str for k in ("added", "removed", "context", "hunkHeader")},
            "background": {k: str for k in ("added", "removed", "context")},
            "highlight": {k: str for k in ("added", "removed")},
            "lineNumber": {
                "text": str,
                "background": {k: str for k in ("added", "removed")},
            },
        },
        "syntax": {k: str for k in (
            "comment", "keyword", "function", "variable", "string", "number",
            "type", "operator", "punctuation")},
        "markdown": {k: str for k in (
            "text", "heading", "link", "linkText", "code", "blockQuote",
            "emphasis", "strong", "horizontalRule", "listItem",
            "listEnumeration", "image", "imageText", "codeBlock")},
    }


def _opencode_theme(home: Path) -> dict:
    import json as _json
    return _json.loads((home / ".config/opencode/themes/Afloat.json").read_text())


def test_opencode_theme_defines_every_role(sandbox):
    """No role may be left for opencode to fill with its own default.

    A missing or malformed leaf is not a cosmetic problem: opencode substitutes
    a hardcoded white (light mode) or black (dark mode) for it, which is exactly
    the "some text is white on light / black on dark" report.
    """
    tmp, palette = sandbox
    home = tmp / "home"
    assert run_apply(palette, "light", home).returncode == 0
    theme = _opencode_theme(home)
    assert "light" in theme or "dark" in theme, "theme must provide at least one mode"

    spec = opencode_token_tree()
    problems: list[str] = []

    def walk(node, expected, path):
        if isinstance(expected, dict):
            if not isinstance(node, dict):
                problems.append(f"{path}: expected an object")
                return
            for key, sub in expected.items():
                if key not in node:
                    problems.append(f"{path}.{key}: missing")
                else:
                    walk(node[key], sub, f"{path}.{key}")
            for key in node:
                if key not in expected and key not in ("hue", "categorical", "@dialog"):
                    problems.append(f"{path}.{key}: unknown role")
            return
        if not isinstance(node, str):
            problems.append(f"{path}: expected a colour")
        elif node != "transparent" and not re.fullmatch(r"#[0-9a-fA-F]{6}", node):
            problems.append(f"{path}: {node!r} is not a colour")

    for mode in ("base", "light", "dark"):
        if mode in theme:
            walk(theme[mode], spec, mode)
    assert not problems, "\n".join(problems)


def test_opencode_theme_text_is_readable_in_both_modes(sandbox):
    """Every colour opencode paints as text must clear 4.5:1 on its surface.

    Material's light tones assume a near-neutral surface. Afloat's light surface
    is a strongly tinted wallpaper colour, so the stock light accents land at
    2.5-3.8:1 on it — headings, bullets, links, code and the footer all wash
    out. The template grades the light accents to compensate; this locks the
    result in so a palette change cannot quietly reintroduce it.
    """
    tmp, palette = sandbox
    home = tmp / "home"
    assert run_apply(palette, "light", home).returncode == 0
    theme = _opencode_theme(home)
    spec = opencode_token_tree()

    def luminance(colour: str) -> float:
        if colour == "transparent":
            return -1.0
        channels = [int(colour[i:i + 2], 16) / 255 for i in (1, 3, 5)]
        linear = [c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in channels]
        return 0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2]

    def contrast(fg: str, bg: str) -> float:
        lf, lb = luminance(fg), luminance(bg)
        if lf < 0 or lb < 0:
            return 99.0  # transparent: whatever is underneath, checked elsewhere
        return (max(lf, lb) + 0.05) / (min(lf, lb) + 0.05)

    for mode in ("light", "dark"):
        block = theme[mode]
        pairs = [
            ("text.base on page", block["text"]["base"], block["background"]["base"]),
            ("text.base on raised", block["text"]["base"], block["background"]["raised"]["base"]),
            ("text.base on form field", block["text"]["base"], block["background"]["formfield"]["base"]),
            ("text.muted", block["text"]["muted"], block["background"]["base"]),
            ("formfield ink on fill", block["text"]["formfield"]["base"], block["background"]["formfield"]["base"]),
            ("action.primary label on plate",
             block["text"]["action"]["primary"]["base"], block["background"]["action"]["primary"]["base"]),
            ("action.destructive label on plate",
             block["text"]["action"]["destructive"]["base"], block["background"]["action"]["destructive"]["base"]),
            ("action.secondary on raised",
             block["text"]["action"]["secondary"]["base"], block["background"]["raised"]["base"]),
            ("diff.added", block["diff"]["text"]["added"], block["diff"]["background"]["added"]),
            ("diff.removed", block["diff"]["text"]["removed"], block["diff"]["background"]["removed"]),
            ("diff.context", block["diff"]["text"]["context"], block["diff"]["background"]["context"]),
            ("diff.hunkHeader", block["diff"]["text"]["hunkHeader"], block["diff"]["background"]["context"]),
            ("diff.lineNumber", block["diff"]["lineNumber"]["text"],
             block["diff"]["lineNumber"]["background"]["added"]),
            ("diff.highlight.added", block["diff"]["highlight"]["added"], block["diff"]["background"]["added"]),
            ("diff.highlight.removed", block["diff"]["highlight"]["removed"],
             block["diff"]["background"]["removed"]),
        ]
        for role in _FEEDBACK:
            fill = block["background"]["feedback"][role]["base"]
            pairs.append((f"feedback.{role}", block["text"]["feedback"][role]["base"], fill))
            pairs.append((f"feedback.{role}.muted", block["text"]["feedback"][role]["muted"], fill))
        pairs += [(f"syntax.{k}", block["syntax"][k], block["background"]["base"]) for k in spec["syntax"]]
        pairs += [(f"markdown.{k}", block["markdown"][k], block["background"]["base"])
                  for k in spec["markdown"] if k != "horizontalRule"]

        for name, fg, bg in pairs:
            ratio = contrast(fg, bg)
            assert ratio >= 4.5, f"{mode} {name}: {fg} on {bg} = {ratio:.2f}:1"


def test_generated_files_are_replaced_atomically(sandbox):
    """A live reader must never catch a half-written theme file.

    Consumers (opencode, kitty, niri) watch these files while the desktop is
    live. `write_text` truncates first, so a reader that lands in that window
    sees invalid content and reverts to its own defaults — the "theme randomly
    went back to default" symptom. Renaming over the target means a reader
    holding the old file keeps reading the old, complete content.
    """
    sys.path.insert(0, str(REPO / "scripts" / "theming"))
    from lib.renderer import _atomic_write

    target = Path(str(sandbox[0])) / "theme.json"
    target.write_text('{"old": true}')
    held = target.open()  # a reader that already has the file open
    _atomic_write(target, '{"new": true}')
    assert held.read() == '{"old": true}'  # untouched, still complete
    held.close()
    assert json.loads(target.read_text()) == {"new": True}
    assert [p.name for p in target.parent.iterdir() if p.name.endswith(".tmp")] == []


def test_opencode_dual_variant(sandbox):
    tmp, palette = sandbox
    home = tmp / "home"
    # Light apply must still carry the dark variant (opencode picks by terminal
    # background at runtime).
    assert run_apply(palette, "light", home).returncode == 0
    rendered = (home / ".config/opencode/themes/Afloat.json").read_text()
    theme = _opencode_theme(home)
    assert theme["light"]["text"]["base"] == "#4c4f69", theme["light"]["text"]["base"]
    assert theme["dark"]["text"]["base"] == "#cdd6f4", theme["dark"]["text"]["base"]
    # The window surface tracks the terminal background (kitty renders
    # colors.surface), so opencode still reads as one piece with the terminal.
    assert theme["light"]["background"]["base"] == _kitty_background(home)
    # Dark apply keeps the light variant too: the dual-variant file is
    # mode-independent, so the bytes must not move.
    assert run_apply(palette, "dark", home).returncode == 0
    assert (home / ".config/opencode/themes/Afloat.json").read_text() == rendered
    assert theme["dark"]["background"]["base"] == _kitty_background(home)


def test_herdr_snippet(sandbox):
    import tomllib
    tmp, palette = sandbox
    home = tmp / "home"
    assert run_apply(palette, "light", home).returncode == 0
    snippet = tomllib.loads((home / ".config/afloat/app-themes/herdr-theme.toml").read_text())
    custom = snippet["theme"]["custom"]
    assert custom["accent"] == custom["blue"]
    assert len({custom["red"], custom["green"], custom["yellow"], custom["blue"],
                custom["mauve"], custom["teal"], custom["peach"]}) == 7
    assert custom["light"]["text"] == "#4c4f69", custom["light"]
    assert custom["dark"]["text"] == "#cdd6f4", custom["dark"]
    assert custom["light"]["panel_bg"] == "reset"
    assert custom["dark"]["sidebar_bg"] == "reset"
    # 选中行/光标行对齐 kitty 非活动 tab 色。light 下 accent 按用户要求
    # 同取该色（与行合流）；dark 下 accent 保持 primary 强色、与行解耦
    #（Herdr 里边框和顶部 tab 共用 accent，行是独立键）。
    assert custom["light"]["active_row_bg"] == custom["light"]["selection_bg"]
    assert custom["light"]["accent"] == custom["light"]["active_row_bg"]
    # dark 下三键同取 color4（primary 加深 10%，沙盒色板下为 #b077f3）。
    assert custom["dark"]["accent"] == custom["dark"]["active_row_bg"]
    assert custom["dark"]["accent"] == custom["dark"]["selection_bg"]
    assert custom["dark"]["accent"] == "#b077f3", custom["dark"]
    # 表面阶梯与次级文字按明暗一次写全，阶梯单调、不与正文重合。
    for mode in ("light", "dark"):
        sub = custom[mode]
        assert sub["subtext0"] != sub["text"]
        ladder = [sub["surface_dim"], sub["surface0"], sub["surface1"],
                  sub["overlay0"], sub["overlay1"]]
        assert len(set(ladder)) == 5, (mode, ladder)


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


def test_only_kitty_text_does_not_touch_kdeglobals(sandbox):
    tmp, _ = sandbox
    home = tmp / "home"
    source = home / ".local/share/color-schemes/Afloat.colors"
    source.parent.mkdir(parents=True)
    source.write_text("[Colors:Window]\nBackgroundNormal=#1e1e2e\n")
    kdeglobals = home / ".config/kdeglobals"
    kdeglobals.parent.mkdir(parents=True)
    original = "[KDE]\nwidgetStyle=oxygen\n"
    kdeglobals.write_text(original)

    result = run_apply(tmp / "missing.json", "dark", home, ["--only-kitty-text"])
    assert result.returncode == 0, result.stderr
    assert kdeglobals.read_text() == original


def test_only_kitty_text_does_not_touch_niri(sandbox):
    tmp, _ = sandbox
    home = tmp / "home"
    niri = home / ".config/niri/config.kdl"
    niri.parent.mkdir(parents=True)
    original = 'include "./DymicShell-colors.kdl"\n'
    niri.write_text(original)

    result = run_apply(tmp / "missing.json", "dark", home, ["--only-kitty-text"])
    assert result.returncode == 0, result.stderr
    assert niri.read_text() == original


def test_only_system_theme_needs_no_palette(sandbox):
    tmp, _ = sandbox
    home = tmp / "home"
    result = run_apply(tmp / "missing.json", "dark", home, ["--only-system-theme"])
    assert result.returncode == 0, result.stderr
    assert "System theme applied: mode=dark" in result.stdout
    # Sandbox path renders no templates and touches no app configs.
    assert not (home / ".config/kitty/kitty-colors.conf").exists()


def _slot(content, name):
    import re
    match = re.search(rf"^{name}\s+(#[0-9a-fA-F]{{6}})", content, re.MULTILINE)
    assert match, name
    return match.group(1).lower()


def _saturation(hex_color):
    import colorsys
    r, g, b = (int(hex_color[i:i + 2], 16) / 255 for i in (1, 3, 5))
    return colorsys.rgb_to_hls(r, g, b)[2]


def test_kitty_ansi_mapping_matches_noctalia_template(sandbox):
    tmp, palette = sandbox
    home = tmp / "home"
    assert run_apply(palette, "dark", home).returncode == 0
    dark = (home / ".config/kitty/kitty-colors.conf").read_text()
    assert run_apply(palette, "light", home).returncode == 0
    light = (home / ".config/kitty/kitty-colors.conf").read_text()
    assert "{{" not in dark and "{{" not in light
    assert _slot(dark, "color0") == _slot(dark, "background")
    assert _slot(light, "color0") == _slot(light, "background")
    assert _slot(dark, "color1") == _slot(dark, "color9")
    assert _slot(light, "color1") == _slot(light, "color9")
    assert _slot(dark, "color2") == _slot(dark, "color10")
    assert _slot(light, "color2") == _slot(light, "color10")
    assert _slot(dark, "color3") == _slot(dark, "color11")
    assert _slot(light, "color3") == _slot(light, "color11")
    assert _slot(dark, "color4") == _slot(dark, "color12")
    assert _slot(light, "color4") == _slot(light, "color12")
    assert _slot(dark, "color5") == _slot(dark, "color13")
    assert _slot(light, "color5") == _slot(light, "color13")
    assert _slot(dark, "color6") == _slot(dark, "color14")
    assert _slot(light, "color6") == _slot(light, "color14")
    assert _slot(dark, "color7") == _slot(dark, "color15")
    assert _slot(light, "color7") == _slot(light, "color15")


def test_kitty_ansi_mapping_preserves_slot_order(sandbox):
    tmp, palette = sandbox
    home = tmp / "home"
    assert run_apply(palette, "dark", home).returncode == 0
    dark = (home / ".config/kitty/kitty-colors.conf").read_text()
    assert run_apply(palette, "light", home).returncode == 0
    light = (home / ".config/kitty/kitty-colors.conf").read_text()
    for content in (dark, light):
        assert _slot(content, "color1") != _slot(content, "color2")
        assert _slot(content, "color2") != _slot(content, "color3")
        assert _slot(content, "color3") != _slot(content, "color4")


def test_single_mode_palette_renders_dual_variant(tmp_path):
    """Live-wallpaper shape (one mode only): dual-variant templates must still
    render exit-0 with the missing variant falling back to the active mode."""
    import json as _json
    import tomllib
    palette = tmp_path / "palette.json"
    palette.write_text(_json.dumps({"light": PALETTE["light"]}))
    home = tmp_path / "home"
    result = run_apply(palette, "light", home)
    assert result.returncode == 0, result.stderr
    snippet = tomllib.loads((home / ".config/afloat/app-themes/herdr-theme.toml").read_text())
    custom = snippet["theme"]["custom"]
    assert custom["light"]["text"] == "#4c4f69"
    assert custom["dark"]["text"] == "#4c4f69"
    theme = _json.loads((home / ".config/opencode/themes/Afloat.json").read_text())
    # Both mode blocks render, and the missing variant falls back to the active
    # mode rather than dropping a block.
    assert theme["light"]["text"]["base"] == "#4c4f69"
    assert theme["dark"]["text"]["base"] == "#4c4f69"
