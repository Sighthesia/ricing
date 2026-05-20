# Design: Launcher and Clipboard

## Architecture

```
shell.qml
  └─ Launcher.LauncherWindow {}   ← new top-level surface

modules/launcher/
  ├── LauncherWindow.qml          ← PanelWindow overlay (Variants per screen)
  ├── LauncherContent.qml         ← search field + results area
  ├── AppGrid.qml                 ← grid of app results
  ├── AppGridDelegate.qml         ← single app icon+name cell
  ├── ClipboardList.qml           ← list of clipboard entries
  ├── ClipboardDelegate.qml       ← single clipboard entry row
  ├── ShortcutList.qml            ← list of niri shortcuts (editable)
  └── ShortcutDelegate.qml        ← single shortcut row with inline edit

services/
  ├── ClipboardService.qml        ← singleton: cliphist interaction
  ├── LauncherService.qml         ← singleton: open/close state, search query, mode
  ├── NiriShortcutService.qml     ← singleton: parse/edit/write binds.kdl
  ├── nirishortcuts/
  │   └── NiriShortcutParser.js   ← .pragma library: KDL parser for binds block
  └── qmldir                      ← updated with new singletons
```

## Key Decisions

### 1. Overlay Window Strategy
Use `Variants { model: Quickshell.screens }` with `PanelWindow` + `WlrLayershell`:
- Layer: `WlrLayer.Overlay`
- Keyboard: `WlrKeyboardFocus.Exclusive`
- Exclusion: `ExclusionMode.Ignore`

This matches noctalia-shell's overlay mode and ensures the launcher appears above all windows with keyboard grab.

### 2. Service Separation
- `LauncherService` — owns visibility state, current search query, active mode (apps vs clipboard vs shortcuts). Thin coordination layer.
- `ClipboardService` — owns clipboard history items, handles all cliphist subprocess calls. Independent of launcher UI.
- `NiriShortcutService` — owns parsed shortcut entries from `binds.kdl`, provides edit/save API. Independent of launcher UI.

Rationale: Each service may be consumed by other modules later. Keeping them separate follows afloat's existing service pattern.

### 3. Mode Switching (Apps vs Clipboard vs Shortcuts)
Simple string-based mode in LauncherService:
- Default mode: `"apps"` — shows DesktopEntries filtered by query
- Clipboard mode: `"clipboard"` — activated when query starts with `>clip ` prefix
- Shortcuts mode: `"shortcuts"` — activated when query starts with `>key ` prefix

No provider registry needed — three hardcoded modes with if/else in LauncherContent.

### 4. App Search
Use Quickshell's `DesktopEntries` API directly. Filter client-side by matching query against `name` and `comment` fields (case-insensitive). No external tool needed.

### 5. Clipboard Backend
Subprocess calls via `Quickshell.Io.Process`:
- `cliphist list` → parse into items array
- `cliphist decode <id> | wl-copy` → copy action
- `cliphist decode <id> | wtype -M ctrl -M shift v` → paste action
- `echo <id> | cliphist delete` → delete action

Watch for new entries via periodic timer (5s) calling `cliphist list`.

### 6. Niri Shortcut Management (Reference: DymicShell NiriShortcutService)

**Parser** (`services/nirishortcuts/NiriShortcutParser.js`):
- Pure JS `.pragma library` — no QML dependencies
- Parses KDL `binds { ... }` block into structured entries
- Each entry: `{ id, sequence, title, detail, actionId, category, managedByShell }`
- `applySequence(text, entries, entryId, newSequence)` → returns modified source text
- Categories: shell, workspaces, windows, display, apps, system, other
- Shell IPC detection: recognizes `afloat-ipc` / `qs ipc call` patterns

**Service** (`services/NiriShortcutService.qml`):
- Reads `~/.config/niri/binds.kdl` via `FileView` (watches for external changes)
- Exposes `shortcutsModel` (ListModel) for UI binding
- `updateSequence(entryId, newSequence)` → validates via temp-dir + `niri validate`, then atomic write
- Triggers `NiriService.reloadConfig()` after successful save
- Error/status reporting via `errorText` / `statusText` properties

**Validation flow** (safe write-back):
1. Copy niri config dir to temp dir
2. Write modified `binds.kdl` to temp dir
3. Run `niri validate --config <temp>/config.kdl`
4. If valid: atomic rename to real `binds.kdl`
5. If invalid: report error, discard changes

### 7. Keyboard Navigation
Managed in LauncherContent via `Keys.onPressed`:
- Arrow keys move `currentIndex` in grid/list
- Enter activates current item (or confirms edit in shortcuts mode)
- Escape closes launcher (or cancels edit)
- Tab switches between modes (alternative to prefix)

## Data Flow

```
User types in search field
  → LauncherService.query updates
  → LauncherContent reads mode from query prefix
  → If "apps": AppGrid filters DesktopEntries by query
  → If "clipboard": ClipboardList filters ClipboardService.items by query
  → If "shortcuts": ShortcutList filters NiriShortcutService.shortcutsModel by query
```

## Trigger

Launcher is triggered via IPC (`qs ipc call launcher toggle`) or bar context menu.

## Visual Style

Simple semi-transparent background (`#cc1a1a1a` or similar). No blur/glass effects in this iteration.

## Compatibility

- Wayland-only (wlr-layer-shell protocol required)
- cliphist/wl-copy/wtype are optional; clipboard mode hidden if cliphist unavailable
- niri is required for shortcut management; mode hidden if binds.kdl not found
- DesktopEntries API available in Quickshell ≥ 0.5
