# Launcher and Clipboard Modules

## Summary

Add an app launcher overlay and clipboard history manager to afloat, following noctalia-shell's proven architecture adapted to afloat's simpler, service-oriented patterns.

## Requirements

### Launcher

1. Full-screen overlay window (one per screen) with keyboard-exclusive focus
2. App search via `DesktopEntries` Quickshell API — filter by name/description
3. Grid layout for app results with icon + name
4. Keyboard navigation: arrow keys, Enter to launch, Escape to close
5. Text input field for search query at the top
6. Triggered from bar widget click or global keybind

### Clipboard

7. Clipboard history service backed by `cliphist` CLI tool
8. Integrated as a provider/tab within the launcher (prefix `>clip` or dedicated tab)
9. List view showing text previews and image thumbnails
10. Actions: copy to clipboard, paste directly, delete entry, wipe all
11. Graceful degradation when `cliphist` is not installed

### Niri Shortcut Management

12. Parse `~/.config/niri/binds.kdl` into a structured model (key sequence, action, category)
13. Display shortcuts in a dedicated launcher mode (prefix `>key` or tab)
14. Allow editing key sequences inline — validate via `niri validate` before writing back
15. Categorize shortcuts: shell, workspaces, windows, display, apps, system
16. Identify shell-managed shortcuts (IPC calls to afloat) vs native niri actions
17. Watch `binds.kdl` for external changes and auto-reload

## Constraints

- Must follow afloat directory conventions: `modules/launcher/` for UI, `services/` for singletons
- Overlay uses `PanelWindow` + `WlrLayershell` (Overlay layer, exclusive keyboard focus)
- External deps: `cliphist`, `wl-copy`, `wtype`, `niri` (document in README or toast on missing)
- No settings UI in this iteration — hardcode sensible defaults
- Keep files under 300 lines each
- NiriShortcutParser.js must be a `.pragma library` pure-JS module (no QML dependencies)

## Acceptance Criteria

- [ ] Launcher opens/closes via bar widget and Escape key
- [ ] Typing filters apps by name; Enter launches selected app
- [ ] Arrow keys navigate the grid
- [ ] `>clip` prefix switches to clipboard results
- [ ] Clipboard items display text preview (truncated) or image thumbnail
- [ ] Copy/paste/delete actions work on clipboard items
- [ ] Missing `cliphist` shows warning, clipboard tab is hidden
- [ ] `>key` prefix switches to shortcut management view
- [ ] Shortcuts are parsed from binds.kdl with correct categories
- [ ] Editing a key sequence validates and writes back to binds.kdl
- [ ] Shell-managed shortcuts are visually distinguished
- [ ] All new services registered in `services/qmldir`
- [ ] `shell.qml` updated to instantiate launcher window

## Out of Scope

- Plugin/provider registry (noctalia-shell's extensibility layer)
- Settings panel for launcher configuration
- Calculator, emoji, or other provider types
- Drag-and-drop
