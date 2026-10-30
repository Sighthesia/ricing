pragma Singleton
import QtQuick

// Screen-space position of each bar's free edge, for the desktop layer.
//
// The bar's seam fillets are painted by the wallpaper surface instead of by the
// bar's own: they hang past the bar's rectangle and must sit UNDER tiled windows,
// so a window that reaches the bar covers the seam rather than the seam painting
// over the window. Two surfaces in the same layer cannot be ordered against each
// other by the client, so the seam has to be painted by the surface that already
// owns those pixels — the background wallpaper (see
// modules/lazerbar/WallpaperBackground.qml).
//
// That surface cannot work the position out for itself. The painted bar slides on
// its own arrival/auto-hide curve, so its free edge is not a function of settings
// alone; it is a number only the bar knows, and it changes frame by frame while
// the bar travels. Publishing the resolved edge keeps the slide's arithmetic in
// one place, next to the state that drives it.
//
// A missing entry means "nowhere on this screen": the painter treats it as off
// screen, so a bar that never published (still staging, or unmounted) leaves the
// desktop alone instead of parking a seam at the top of the display.
QtObject {
    id: root

    // screenName -> the free edge's y in that screen's coordinates, descending.
    property var edges: ({})

    // Record where one screen's bar free edge currently is. Assigning a new map
    // is what invalidates a reader's binding; unchanged values are dropped so a
    // resting bar does not churn the property every frame.
    function publish(screenName, edgeY) {
        const name = screenName == null ? "" : String(screenName)
        const value = Number(edgeY)
        if (!name || !isFinite(value))
            return
        if ((root.edges || {})[name] === value)
            return
        const next = Object.assign({}, root.edges)
        next[name] = value
        root.edges = next
    }

    // A bar unmounts when its screen goes away; a stale edge would keep the seam
    // painted for a bar that no longer exists.
    function remove(screenName) {
        const name = screenName == null ? "" : String(screenName)
        if (!name || !(name in (root.edges || {})))
            return
        const next = Object.assign({}, root.edges)
        delete next[name]
        root.edges = next
    }

    // Read from a binding, never from an imperative call site: the property read
    // inside is what subscribes the caller to the next publish.
    function edgeFor(screenName) {
        const name = screenName == null ? "" : String(screenName)
        const value = Number((root.edges || {})[name])
        return isFinite(value) ? value : -1e6
    }
}
