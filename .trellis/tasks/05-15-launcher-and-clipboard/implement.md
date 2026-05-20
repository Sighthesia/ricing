# Implementation Plan

## Phase 1: Service Layer

- [ ] 1.1 Create `services/ClipboardService.qml`
  - Check cliphist availability on init
  - `list()` function: run `cliphist list`, parse into items model
  - `copyItem(id)`, `deleteItem(id)`
  - Periodic refresh timer (5s)
  - Properties: `available: bool`, `items: list`, `revision: int`

- [ ] 1.2 Create `services/LauncherService.qml`
  - Properties: `visible: bool`, `query: string`, `mode: string`
  - Functions: `open()`, `close()`, `toggle()`
  - Mode derived from query prefix (`>clip` → clipboard, `>key` → shortcuts)
  - IpcHandler target "launcher" with toggle/openClipboard/openShortcuts

- [ ] 1.3 Create `services/nirishortcuts/NiriShortcutParser.js`
  - `.pragma library` pure JS
  - Port from DymicShell: KDL binds block parser
  - Adapt IPC detection patterns from `dymicshell-ipc` to `afloat-ipc` / `qs ipc call`
  - Functions: `parseShortcutEntries(text)`, `applySequence(text, entries, id, seq)`

- [ ] 1.4 Create `services/NiriShortcutService.qml`
  - FileView watching `~/.config/niri/binds.kdl`
  - Parse via NiriShortcutParser on load/change
  - `shortcutsModel` ListModel for UI
  - `updateSequence(entryId, newSequence)` with validate-then-write flow
  - Error/status properties
  - Trigger `NiriService.reloadConfig()` on save (add reloadConfig to NiriService if missing)

- [ ] 1.5 Update `services/qmldir`
  - Register ClipboardService, LauncherService, NiriShortcutService

## Phase 2: UI — Launcher Window

- [ ] 2.1 Create `modules/launcher/LauncherWindow.qml`
  - `Variants { model: Quickshell.screens }`
  - PanelWindow with WlrLayershell overlay config
  - Bind visibility to `LauncherService.visible`

- [ ] 2.2 Create `modules/launcher/LauncherContent.qml`
  - TextInput for search query
  - Conditional loader: AppGrid vs ClipboardList vs ShortcutList based on mode
  - Keyboard handler (Escape, Enter, arrows)

- [ ] 2.3 Create `modules/launcher/AppGrid.qml` + `AppGridDelegate.qml`
  - GridView with DesktopEntries model filtered by query
  - Delegate: icon (IconImage) + app name
  - Launch on click/Enter

- [ ] 2.4 Create `modules/launcher/ClipboardList.qml` + `ClipboardDelegate.qml`
  - ListView bound to ClipboardService.items
  - Delegate: text preview or image indicator
  - Actions: copy, delete

- [ ] 2.5 Create `modules/launcher/ShortcutList.qml` + `ShortcutDelegate.qml`
  - ListView bound to NiriShortcutService.shortcutsModel
  - Filter by category and search text
  - Delegate: sequence display + action label + category badge
  - Inline edit: click sequence to enter edit mode, Enter to confirm, Escape to cancel
  - Visual distinction for shell-managed shortcuts

## Phase 3: Integration

- [ ] 3.1 Update `shell.qml` to instantiate `Launcher.LauncherWindow {}`
- [ ] 3.2 Add IPC handler or bar trigger for launcher toggle
- [ ] 3.3 Add `reloadConfig()` to existing NiriService if not present
- [ ] 3.4 Verify keyboard navigation works end-to-end
- [ ] 3.5 Test graceful degradation without cliphist / without binds.kdl

## Validation

- Open launcher → search apps → launch one
- Type `>clip` → see clipboard history → copy/delete
- Type `>key` → see shortcuts by category → edit a sequence → verify binds.kdl updated
- Remove cliphist from PATH → clipboard mode hidden, no errors
- Remove binds.kdl → shortcuts mode hidden, no errors
- Multi-screen: launcher appears on focused screen
