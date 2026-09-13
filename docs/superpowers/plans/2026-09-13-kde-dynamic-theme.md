# KDE Dynamic Theme Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Generate and apply an Afloat KDE color scheme from the active Material palette during app-theme synchronization.

**Architecture:** Add a KDE `.colors` template to the existing template processor, then extend `apply_app_themes.py` with a case-preserving INI merge into `~/.config/kdeglobals` and a best-effort KDE global-settings notification. The generated scheme remains independently available at `~/.local/share/color-schemes/Afloat.colors`, while unrelated KDE configuration stays intact.

**Tech Stack:** Python 3, configparser, Afloat template-processor, TOML template registry, pytest, D-Bus (`jeepney` or `dbus-send`).

## Global Constraints

- Use Afloat's existing Material token names and template syntax.
- Preserve existing GTK, Qt, Kitty, system-theme, and sandbox behavior.
- Keep unrelated `kdeglobals` sections and keys intact.
- Do not send D-Bus notifications when `--home-prefix` is used.
- KDE notification failure must not fail color-file generation or the overall app-theme sync.
- Manual edits must use `apply_patch`.
- Run `python3 -m pytest scripts/tests/` before completion.
- Commit each functional change with a conventional commit message.

---

### Task 1: Add KDE Color Template

**Files:**
- Create: `scripts/theming/templates/kde-colors.conf`
- Modify: `scripts/theming/templates/app-themes.toml:1-108`
- Test: `scripts/tests/test_apply_app_themes.py`

**Interfaces:**
- Consumes: template processor expressions such as `{{colors.surface.default.hex}}`.
- Produces: `~/.local/share/color-schemes/Afloat.colors` through the `templates.kde` registry entry.

- [ ] **Step 1: Add template-rendering assertions**

Extend the sandbox render test with:

```python
kde_colors = home / ".local/share/color-schemes/Afloat.colors"
assert kde_colors.exists()
kde_content = kde_colors.read_text()
assert "BackgroundNormal=#1e1e2e" in kde_content
assert "ForegroundNormal=#cdd6f4" in kde_content
assert "DecorationFocus=#cba6f7" in kde_content
assert "ForegroundNegative=#f38ba8" in kde_content
```

- [ ] **Step 2: Run the focused test and verify failure**

Run: `python3 -m pytest scripts/tests/test_apply_app_themes.py::test_dark_render_and_includes -q`

Expected: FAIL because the KDE template is not registered and no `.colors` file exists.

- [ ] **Step 3: Create `kde-colors.conf`**

Use KDE color groups and Afloat tokens:

```ini
[ColorEffects:Disabled]
Color=#{{colors.on_surface_variant.default.hex_stripped}}
ColorAmount=0
ColorEffect=0
ContrastAmount=0
IntensityAmount=0

[Colors:Button]
BackgroundAlternate={{colors.surface_container_high.default.hex}}
BackgroundNormal={{colors.surface_container.default.hex}}
DecorationFocus={{colors.primary.default.hex}}
DecorationHover={{colors.primary_container.default.hex}}
ForegroundActive={{colors.on_primary.default.hex}}
ForegroundInactive={{colors.on_surface_variant.default.hex}}
ForegroundNormal={{colors.on_surface.default.hex}}

[Colors:Selection]
BackgroundAlternate={{colors.primary_container.default.hex}}
BackgroundNormal={{colors.primary.default.hex}}
DecorationFocus={{colors.primary.default.hex}}
ForegroundActive={{colors.on_primary.default.hex}}
ForegroundInactive={{colors.on_primary.default.hex}}
ForegroundNormal={{colors.on_primary.default.hex}}

[Colors:View]
BackgroundAlternate={{colors.surface_container_low.default.hex}}
BackgroundNormal={{colors.surface.default.hex}}
DecorationFocus={{colors.primary.default.hex}}
DecorationHover={{colors.primary_container.default.hex}}
ForegroundActive={{colors.primary.default.hex}}
ForegroundInactive={{colors.on_surface_variant.default.hex}}
ForegroundNormal={{colors.on_surface.default.hex}}

[Colors:Window]
BackgroundAlternate={{colors.surface_container_low.default.hex}}
BackgroundNormal={{colors.surface.default.hex}}
DecorationFocus={{colors.primary.default.hex}}
DecorationHover={{colors.primary_container.default.hex}}
ForegroundActive={{colors.primary.default.hex}}
ForegroundInactive={{colors.on_surface_variant.default.hex}}
ForegroundNormal={{colors.on_surface.default.hex}}

[Colors:Tooltip]
BackgroundAlternate={{colors.surface_container.default.hex}}
BackgroundNormal={{colors.surface.default.hex}}
DecorationFocus={{colors.primary.default.hex}}
DecorationHover={{colors.primary_container.default.hex}}
ForegroundActive={{colors.primary.default.hex}}
ForegroundInactive={{colors.on_surface_variant.default.hex}}
ForegroundNormal={{colors.on_surface.default.hex}}

[Colors:Complementary]
BackgroundAlternate={{colors.surface_container_low.default.hex}}
BackgroundNormal={{colors.surface.default.hex}}
DecorationFocus={{colors.primary.default.hex}}
DecorationHover={{colors.primary_container.default.hex}}
ForegroundActive={{colors.primary.default.hex}}
ForegroundInactive={{colors.on_surface_variant.default.hex}}
ForegroundNormal={{colors.on_surface.default.hex}}

[Colors:Header]
BackgroundAlternate={{colors.surface_container_high.default.hex}}
BackgroundNormal={{colors.surface_container.default.hex}}
DecorationFocus={{colors.primary.default.hex}}
DecorationHover={{colors.primary_container.default.hex}}
ForegroundActive={{colors.primary.default.hex}}
ForegroundInactive={{colors.on_surface_variant.default.hex}}
ForegroundNormal={{colors.on_surface.default.hex}}

[General]
ColorScheme=Afloat
Name=Afloat
shadeSortColumn=true

[WM]
activeBackground={{colors.surface_container.default.hex}}
activeBlend={{colors.primary.default.hex}}
activeForeground={{colors.on_surface.default.hex}}
inactiveBackground={{colors.surface_container_low.default.hex}}
inactiveBlend={{colors.outline.default.hex}}
inactiveForeground={{colors.on_surface_variant.default.hex}}
```

- [ ] **Step 4: Register the template**

Add:

```toml
[templates.kde]
input_path = "./kde-colors.conf"
output_path = "~/.local/share/color-schemes/Afloat.colors"
```

- [ ] **Step 5: Run the focused test and verify it passes**

Run: `python3 -m pytest scripts/tests/test_apply_app_themes.py::test_dark_render_and_includes -q`

Expected: PASS, including the KDE file assertions.

- [ ] **Step 6: Commit the template change**

```bash
git add scripts/theming/templates/kde-colors.conf scripts/theming/templates/app-themes.toml scripts/tests/test_apply_app_themes.py
git commit -m "feat(theming): add kde color scheme template"
```

### Task 2: Merge KDE Scheme Into `kdeglobals`

**Files:**
- Modify: `scripts/theming/apply_app_themes.py`
- Test: `scripts/tests/test_apply_app_themes.py`

**Interfaces:**
- Consumes: rendered `~/.local/share/color-schemes/Afloat.colors`.
- Produces: `sync_kde_theme(home: Path) -> bool`, which merges rendered KDE sections into `~/.config/kdeglobals`.

- [ ] **Step 1: Add a preservation test**

Add a test that seeds `kdeglobals` before running the sandbox command:

```python
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
    assert "BackgroundNormal=#1e1e2e" in content
```

- [ ] **Step 2: Run the test and verify failure**

Run: `python3 -m pytest scripts/tests/test_apply_app_themes.py::test_kdeglobals_preserves_unrelated_settings -q`

Expected: FAIL because the apply script does not currently merge the generated KDE scheme.

- [ ] **Step 3: Implement case-preserving KDE merge**

Add:

```python
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
```

- [ ] **Step 4: Invoke the merge after rendering**

In `main()`, after `sync_kitty_clear_text(...)`, call:

```python
sync_kde_theme(home)
```

The existing `home = Path.home()` assignment should be reused so sandbox runs write only below `--home-prefix`.

- [ ] **Step 5: Run the preservation test and verify it passes**

Run: `python3 -m pytest scripts/tests/test_apply_app_themes.py::test_kdeglobals_preserves_unrelated_settings -q`

Expected: PASS.

- [ ] **Step 6: Commit the merge change**

```bash
git add scripts/theming/apply_app_themes.py scripts/tests/test_apply_app_themes.py
git commit -m "feat(theming): merge kde colors into kdeglobals"
```

### Task 3: Notify KDE Applications

**Files:**
- Modify: `scripts/theming/apply_app_themes.py`
- Test: `scripts/tests/test_apply_app_themes.py`

**Interfaces:**
- Consumes: `home: Path` and the current session D-Bus environment.
- Produces: `notify_kde_theme() -> bool`, a best-effort notifier using `jeepney` first and `dbus-send` as fallback.

- [ ] **Step 1: Add a testable notifier boundary**

Add a test that monkeypatches the notifier and verifies sandbox execution does not call it:

```python
def test_sandbox_skips_kde_notification(sandbox, monkeypatch):
    import importlib.util
    spec = importlib.util.spec_from_file_location("apply_app_themes", SCRIPT)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    calls = []
    monkeypatch.setattr(module, "notify_kde_theme", lambda: calls.append(True) or True)

    result = run_apply(sandbox[1], "dark", sandbox[0] / "home")
    assert result.returncode == 0
    assert calls == []
```

- [ ] **Step 2: Run the test and verify failure**

Run: `python3 -m pytest scripts/tests/test_apply_app_themes.py::test_sandbox_skips_kde_notification -q`

Expected: FAIL because `notify_kde_theme` is not yet defined.

- [ ] **Step 3: Implement best-effort D-Bus notification**

Add:

```python
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
```

- [ ] **Step 4: Trigger notification only outside sandbox**

After rendering and KDE merge in `main()`:

```python
sync_kde_theme(home)
if args.home_prefix is None:
    notify_kde_theme()
```

- [ ] **Step 5: Run the notifier boundary test and verify it passes**

Run: `python3 -m pytest scripts/tests/test_apply_app_themes.py::test_sandbox_skips_kde_notification -q`

Expected: PASS.

- [ ] **Step 6: Commit the notification change**

```bash
git add scripts/theming/apply_app_themes.py scripts/tests/test_apply_app_themes.py
git commit -m "feat(theming): notify kde after color sync"
```

### Task 4: Full Verification

**Files:**
- Test: `scripts/tests/test_apply_app_themes.py`
- Test: `scripts/tests/`

- [ ] **Step 1: Verify light-mode KDE rendering**

Add assertions to the existing light-mode test:

```python
kde = (home / ".local/share/color-schemes/Afloat.colors").read_text()
assert "BackgroundNormal=#eff1f5" in kde
assert "ForegroundNormal=#4c4f69" in kde
```

- [ ] **Step 2: Run the complete Python test suite**

Run: `python3 -m pytest scripts/tests/`

Expected: all tests pass.

- [ ] **Step 3: Inspect the final diff and worktree**

Run: `git diff --check` and `git status --short`.

Expected: no whitespace errors; only intended tracked files are committed. Existing unrelated untracked files remain untouched.

- [ ] **Step 4: Commit final test updates if needed**

```bash
git add scripts/tests/test_apply_app_themes.py
git commit -m "test(theming): cover kde light and dark sync"
```
