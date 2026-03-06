# Launcher & Clipboard Widget — Design

## Overview

A native QML application launcher with embedded clipboard history, triggered via
Quickshell IPC (no bar widget). Architecture closely mirrors noctalia-shell's
provider pattern, adapted to DymicShell's `AnimatedPanelBase` and singleton
service conventions.

---

## Trigger Mechanism

**Quickshell IPC** — no bar button is added.

The user binds a key in their niri config:
```
bindsym Super+Space exec qs msg -i DymicShell call toggleLauncher
bindsym Super+V      exec qs msg -i DymicShell call openClipboard
```

`LauncherService` exposes a `toggle()` / `openClipboard()` function decorated
with `@ipc` (Quickshell `IpcHandler`). This inverts `isOpen` or forces the panel
open with the `>clip ` prefix already typed.

---

## Panel Placement

`LauncherPanel.qml` is an `AnimatedPanelBase` window:
- `anchors { top: true; horizontalCenter: true }` — centred below the bar
- `margins { top: Theme.barHeight }` — flush with bar bottom edge
- `implicitWidth: 640`, `implicitHeight: 480` — fixed size, no per-frame resize
- `focusable: true` — keyboard navigation

The panel is declared in `shell.qml` (same pattern as `SettingsPanelWindow`,
`NotificationHistoryPanel`, etc.).

---

## Mode System

`LauncherCore` drives its provider by inspecting `searchText`:

| `searchText` prefix | Active provider        |
| ------------------- | ---------------------- |
| *(anything else)*   | `ApplicationsProvider` |
| `>clip `            | `ClipboardProvider`    |

When searching, `LauncherCore` calls `getResults(text)` on the active provider
and merges results into a single `ListModel`. Prefixes are stripped before they
are passed to `getResults`.

---

## Component Hierarchy

```
shell.qml
└── LauncherPanel.qml            (AnimatedPanelBase, IPC-controlled)
    └── LauncherCore.qml         (search bar + results list + provider router)
        ├── ApplicationsProvider.qml  (DesktopEntries.applications)
        └── ClipboardProvider.qml     (ClipboardService results)

services/
  LauncherService.qml            (Singleton: isOpen, mode, IPC funcs)
  ClipboardService.qml           (Singleton: cliphist wrapper)
```

### LauncherService (Singleton)

```
property bool isOpen: false
property string prefillText: ""   // pre-types text when opening via IPC

function toggle()                 // @ipc: toggle open/close
function openClipboard()          // @ipc: open with ">clip " pre-filled
```

### ClipboardService (Singleton)

Wraps `cliphist` via `Quickshell.Process`:

| Method                | Shell command                     |
| --------------------- | --------------------------------- |
| `list(n)`             | `cliphist list -preview-width 80` |
| `copyToClipboard(id)` | `cliphist decode <id> \| wl-copy` |
| `decode(id, cb)`      | `cliphist decode <id>` → callback |

Parsed items: `{ id, preview, isImage }`.

### Provider Interface

Each provider is a QML `Item` child of `LauncherCore` and exposes:

```qml
property bool handleSearch: true    // participate in normal search?
function onOpened()                 // preload, called when panel opens
function getResults(text): Array    // return [{name, description, icon, onActivate}]
```

### Result Item Shape

```js
{
  name:        string,   // primary label
  description: string,   // subtitle / secondary text
  icon:        string,   // XDG icon name or "" for clipboard items
  onActivate:  function  // action when user presses Enter / clicks
}
```

### LauncherCore

- `TextField` at top (single line, always focused when panel opens)
- `ListView` below — delegates render each result with icon + name + description
- Keyboard: `Up`/`Down` navigate, `Enter` activates, `Esc` closes panel
- Tab-style mode badge shows current provider name ("应用" / "剪切板")

---

## Parallel Worktree Plan

| Branch                   | Scope                                                              |
| ------------------------ | ------------------------------------------------------------------ |
| `feat/launcher-core`     | LauncherService, LauncherPanel, LauncherCore, ApplicationsProvider |
| `feat/clipboard-service` | ClipboardService, ClipboardProvider                                |

**Integration sequence:**
1. Both branches develop independently.
2. `feat/clipboard-service` is merged into `feat/launcher-core` first.
3. `LauncherCore` registers `ClipboardProvider` in its provider list.
4. `feat/launcher-core` is merged to `main` and both worktrees removed.

---

## Out of Scope (v1)

- Command execution provider (`>cmd`)
- Fuzzy scoring / sorting
- Emoji picker
- Window switcher
- Preview pane for clipboard images
