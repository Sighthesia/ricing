# DymicShell Agent Guide
Wayland shell built with Quickshell. Keep the repo layered, token-driven, and safe for hot-reload.
Repo-local editor rules: no `.cursor/rules/`, `.cursorrules`, or `.github/copilot-instructions.md` exist here as of 2026-03-14.
No repo-local `.github/skills/` entries are checked in right now.

## Repository Layout
```text
shell.qml                  # Entry point; instantiate top-level windows only
config/                    # Semantic colors + structural theme tokens
services/                  # Singleton state, persistence, compositor/process integration
modules/                   # UI windows, panels, and reusable module-local components
tests/
  qml/                     # Smoke harnesses; run with `qs -p tests/qml/<Name>.qml`
  qml/{config,services,modules} # Symlink roots so harnesses can resolve `qs.*` imports
  run-settings-smoke.sh
  run-ui-structure-smoke.sh
  run-super-island-smoke.sh
  run-media-control-smoke.sh
docs/plans/               # Design and implementation history
null/dymicshell/          # Checked-in sample/runtime artifacts; not the canonical live config
```
Key entry points: `shell.qml`, `config/Theme.qml`, `config/Colors.qml`, `services/SettingsService.qml`, `services/BarLayoutService.qml`, `modules/bar/BarContent.qml`.

## Build, Lint, and Test Commands
Use `qs` unless the user explicitly asks for `quickshell`.
The repo does not define `npm`, `pnpm`, `yarn`, `make`, `just`, `pytest`, `qmllint`, `qmlformat`, or CI workflow commands. Do not invent those commands unless you first verify local availability.

### Whole-Shell Validation
```bash
timeout 10 qs --path .
timeout 10 qs -p .
```
Prefer `qs --path .` for a full-shell load check.

### Full Smoke Suites
```bash
bash tests/run-settings-smoke.sh
bash tests/run-ui-structure-smoke.sh
bash tests/run-super-island-smoke.sh
bash tests/run-media-control-smoke.sh
```

### Single Smoke Harnesses
```bash
bash tests/run-qml-harness.sh SettingsStructureSmoke
bash tests/run-qml-harness.sh NotificationStructureSmoke
bash tests/run-qml-harness.sh LauncherStructureSmoke
bash tests/run-qml-harness.sh BarLayoutGeometrySmoke
timeout 12 qs -p tests/qml/SuperIslandServiceSmoke.qml
timeout 12 qs -p tests/qml/MediaServiceSmoke.qml
timeout 12 qs -p tests/qml/CavaServiceSmoke.qml
timeout 12 qs -p tests/qml/MediaControlServiceSmoke.qml
timeout 12 qs -p tests/qml/MediaVisualPartsSmoke.qml
timeout 12 qs -p tests/qml/MediaControlWidgetSmoke.qml
timeout 12 qs -p tests/qml/MediaControlPanelSmoke.qml
timeout 12 qs -p tests/qml/MediaControlSettingsSmoke.qml
```

### Harness Prerequisites
- Keep `tests/qml/{config,services,modules}` intact; the harnesses rely on those symlinks.
- When you add or move a harness, update the matching `tests/run-*.sh` script in the same change.
- For QML features, bug fixes, behavior changes, or regressions, load the repo-local `qml-testing-strategy` skill before choosing verification commands.
- Start with the smallest harness that proves the change, then escalate to broader smoke suites only when a narrower layer no longer supports the claim.

## Architecture Rules
- Preserve the three-layer flow: `services/` -> `config/` -> `modules/`.
- `shell.qml` stays declarative and only wires top-level windows together.
- `services/` own IO, persistence, timers, process integration, and shared state.
- `config/` derives semantic tokens from settings and service-backed data.
- `modules/` render UI and forward actions back into services instead of duplicating state.
- Promote reused behavior into services or shared base components.

## Token System
### Colors: `Colors.*`
- Never hardcode feature-level hex colors.
- Prefer `Colors.background`, `Colors.surface`, `Colors.text`, `Colors.textMuted`, `Colors.border`, `Colors.highlight`, and `Colors.destructive`.
- If a semantic color is missing, extend `config/Colors.qml` instead of adding a local literal.

### Animation: `Theme.anim.*`
- All duration and easing choices should derive from `Theme.anim.*`.
- Prefer `Theme.anim.move*` for layout motion, `Theme.anim.highlight*` for emphasis, and `Theme.anim.spring*` / `Theme.anim.pulseSpring*` for expressive size changes.
- Known legacy exceptions: `modules/bar/AnimatedPanelBase.qml` and `modules/bar/ClickRipple.qml` still hardcode some timings.
- Any unavoidable new timing literal must be marked with `// FIXME: use Theme.anim.*`.

### Sizes and Typography: `Theme.*`
- Use `Theme.barHeight`, `Theme.cornerRadius`, `Theme.fontFamily`, `Theme.fontSizeBody`, etc.
- For bar-internal micro-layout, prefer `Theme.barWidget.*`.
- If a shared spacing or icon size token is missing, extend `Theme.barWidget.*` first.

## Settings and Persistence
- Read settings only through `SettingsService.data.<section>.<key>`.
- Write settings by mutating `SettingsService.data.*`; persistence is already debounced.
- Do not add ad-hoc save timers in UI code unless you are changing persistence semantics.
- When adding a setting, update both `config/settings-default.json` and `services/SettingsService.qml` to keep the schema/defaults aligned.
- Do not treat `null/dymicshell/*.json` as the live runtime source of truth.

## Preferred Base Components
- `modules/bar/AnimatedPanelBase.qml` - dropdown/panel base with safe surface lifecycle.
- `modules/bar/StaggerItem.qml` - enter/exit stagger wrapper.
- `modules/bar/HoverRevealHighlight.qml` - standard hover affordance.
- `modules/bar/ClickRipple.qml` - standard click feedback.
- `modules/bar/BarWidgetWrapper.qml` - bar widget container, drag support, shared animation contract.

### Interactive Surface Pattern
```qml
HoverRevealHighlight { anchors.fill: parent; hovered: area.containsMouse }
ClickRipple { id: ripple; anchors.fill: parent }
MouseArea {
    id: area
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: (mouse) => { ripple.triggerRipple(mouse.x, mouse.y); /* action */ }
}
```
If the surface uses custom fills or highlights, enable adaptive contrast so hover feedback stays visible.

## QML File Structure
Keep each QML file ordered as:
1. imports
2. top-level English comment explaining purpose/usage
3. root `id`
4. `required property`
5. public mutable `property`
6. `readonly property`
7. private `property _...`
8. `signal`
9. child declarations
10. functions
11. `Component.onCompleted`
12. `Connections`

## Import, Naming, and Formatting
- Import order: `Quickshell*` -> `Qt*` -> `qs.config` -> `qs.services` -> `qs.modules` -> relative imports.
- Use 4-space indentation and multiline bindings when one line becomes hard to scan.
- Use typed properties (`bool`, `int`, `real`, `string`, `color`) when the type is known; reserve `var` for dynamic payloads.
- Private members must start with `_`; public API must not.
- Prefer descriptive domain names such as `MediaControlService`, `WidgetSettingsPanel`, or `NotificationHistoryPanel`.
- Avoid grab-bag files named `utils`, `helpers`, `common`, or `shared`.
- Add short English comments only where the role of a layout, visual, or input element is not obvious.

## State Management
- Shared cross-window state belongs in a singleton service.
- Animated panels/windows should use `_state: "closed" | "opening" | "open" | "closing"` instead of toggling `visible` directly.
- Use guard clauses and early returns in JS helpers.
- Keep component-local JS small; move reusable behavior into services or base components.

## Error Handling
- Treat file IO, JSON parsing, compositor data, and external process output as recoverable failures.
- Log concise diagnostics and fall back to default or empty state instead of breaking the UI.
- Restore a consistent service state before returning from recoverable failures.
- Clamp untrusted numeric input and guard against missing object keys.

## Testing and Documentation Hygiene
- Keep smoke harnesses in `tests/qml/`, not the repository root.
- Extend the nearest smoke harness first for regressions; avoid overlapping duplicate coverage.
- Update `tests/run-*.sh` when harness names or paths change.
- Don't `docs/plans/` references even when files or commands move.
- Use the smoke suites plus a full-shell load check before claiming the repo still loads cleanly.
