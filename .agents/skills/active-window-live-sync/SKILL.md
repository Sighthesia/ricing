---
name: active-window-live-sync
description: Use when Afloat's active-window title or app identity stops updating after Niri window focus changes, workspace switches, or event-stream updates.
---

# Active Window Live Sync

Keep Niri event payloads and derived QML state synchronized at the service boundary.

## Verified Traps

- `niri msg -j windows` and `event-stream` emit a `WindowsChanged` object containing a `windows` array. Do not pass the wrapper object to a function that expects an array.
- Handle `WindowsChanged` directly in the event stream. Relying only on `WindowOpenedOrChanged`, `WindowClosed`, or `WindowFocusChanged` misses focus/workspace changes.
- A `ListModel` role mutation inside `get()` is not a dependable invalidation source for derived properties that scan rows. Increment an explicit revision whenever window focus or the window snapshot changes, and reference it from `activeTitle`/`activeAppId`.
- Workspace activation must refresh the window snapshot because the active window can change without a `WindowFocusChanged` event reaching the shell in the same ordering.

## Correct Pattern

```qml
function updateWindows(payload) {
    if (payload && payload.WindowsChanged)
        payload = payload.WindowsChanged.windows
    // Rebuild model...
    root._windowsRevision++
}

if (event.WindowsChanged)
    root.updateWindows(event.WindowsChanged.windows)
```

## Verification

- Run `niri msg -j windows` and confirm the top-level `WindowsChanged.windows` wrapper.
- Run `qs -p tst_niri_active_window.qml` and require all title propagation checks to pass.
- Exercise both a window focus switch and a workspace switch while watching `ActiveWindow`.
