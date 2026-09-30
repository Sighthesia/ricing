pragma Singleton
import QtQuick

// Read-only mirror of each bar's fullscreen reveal state, so the live shell can
// be inspected from outside. Exists because the state lives inside the bar's
// per-screen Scope, which an IPC target cannot reach, and a collapse that
// silently fails is otherwise indistinguishable from one that never triggered.
//
// Debug-only. Nothing reads this except the debugFullscreenBar IPC target.
QtObject {
    id: root

    property var bars: []

    // Replace or drop one bar's entry by screen name. Assigned as a new array so
    // a binding reader sees the change.
    function sync(screenName, entry) {
        const name = screenName == null ? "" : String(screenName)
        if (!name)
            return
        const next = []
        let replaced = false
        for (let i = 0; i < root.bars.length; i++) {
            if (String(root.bars[i].screenName) === name) {
                next.push(entry)
                replaced = true
                continue
            }
            next.push(root.bars[i])
        }
        if (!replaced)
            next.push(entry)
        root.bars = next
    }

    // A bar unmounts when its screen goes away; leaving it behind would let a
    // stale entry masquerade as a live one.
    function remove(screenName) {
        const name = screenName == null ? "" : String(screenName)
        if (!name)
            return
        const next = []
        for (let i = 0; i < root.bars.length; i++) {
            if (String(root.bars[i].screenName) === name)
                continue
            next.push(root.bars[i])
        }
        root.bars = next
    }
}
