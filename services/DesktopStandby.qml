pragma Singleton

import QtQuick

// The desktop's stand-down for a lock capture.
//
// A lock request is routinely made from inside the launcher, so at the moment it
// is accepted the wave panel is still falling and the bar is still on screen.
// The lock's background is a photograph of the desktop (LockGrimCapture), so
// whatever is painted when grim runs is baked into the lock: the wave panel, the
// bar, the settings panel. The lock therefore asks the desktop to stand down and
// captures only once every surface that paints over the desktop has reported
// that it is clear.
//
// The lock owns both edges (see Lock.holdsDesktop): raised when a request is
// accepted, cleared when the lock has left the screen. Surfaces only read
// `standby` and report; nothing here decides anything by itself.
//
// Registration is lifetime-based rather than counted per request: a surface
// registers while it exists, so a screen that appears mid-request owes a report
// and one that disappears cannot leave a report owed forever. A surface that
// never reports cannot strand the lock either — the lock bounds its own
// preparation and commits without a capture if this never settles.
QtObject {
    id: root

    // A capture is waiting for the desktop to clear, and the desktop keeps
    // standing down for as long as it is set: the bar has to stay off the screen
    // until the lock's own exit wave has revealed the desktop again.
    readonly property bool standby: root._active

    // ...and whether that capture is a photograph of the desktop itself. A
    // photograph is only truthful if the desktop's own geometry is: space a
    // surface reserves on it has to be given back, or the lock would show a
    // strip no window is allowed to occupy — a hole where the bar used to be.
    // A request that reveals the wallpaper instead has no desktop geometry to be
    // faithful to and leaves the reservations alone.
    readonly property bool photographsDesktop: root._active && root._photographs

    property bool _active: false
    property bool _photographs: false
    // Key -> whether that surface has reported for the current request. A key's
    // presence is its registration, so one map carries both facts and no surface
    // can report into a request that never counted it.
    property var _state: ({})

    // Raise a request. Every registered surface now owes a report, so the capture
    // cannot be satisfied by whatever the previous request happened to leave
    // behind. `photographsDesktop` is what the request is going to do with the
    // desktop once it is clear (see the property above).
    function begin(photographsDesktop: bool): void {
        // Before `_active` below, so a surface reading it inside its own
        // notification already sees this request's value — and so the release
        // itself costs one geometry commit rather than two.
        root._photographs = photographsDesktop === true
        // Reset before the flag: surfaces react to `standby` below and report
        // inside that notification, and a report that landed before the reset
        // would be erased by it.
        const next = {}
        const keys = Object.keys(root._state)
        for (let i = 0; i < keys.length; ++i)
            next[keys[i]] = false
        root._state = next
        root._active = true
        // Nothing is registered, or every surface answers from its own
        // notification above: only the empty case still needs this.
        if (root.isClear())
            root.cleared()
    }

    // The lock has left the screen. Surfaces are free to come back, and a report
    // that arrives late is ignored until the next request.
    function end(): void {
        root._active = false
    }

    // Whether a capture may run now: no request outstanding, or every registered
    // surface has reported. A function rather than a property because the lock
    // asks this at the moment it decides, and a binding read could see a request
    // half-raised.
    function isClear(): bool {
        if (!root._active)
            return true
        const keys = Object.keys(root._state)
        for (let i = 0; i < keys.length; ++i) {
            if (root._state[keys[i]] !== true)
                return false
        }
        return true
    }

    // A surface is on screen and will answer every later request. Called while
    // that surface exists, from the component that owns it.
    function register(key: var): void {
        const name = root._key(key)
        if (!name)
            return
        const next = Object.assign({}, root._state)
        // A surface that registers while a capture is already waiting owes it a
        // report, or the lock would photograph a desktop it never asked to clear.
        next[name] = !root._active
        root._state = next
    }

    // A surface that is going away. Dropping the key is what keeps a removed
    // screen from leaving a report owed that can never arrive.
    function unregister(key: var): void {
        const name = root._key(key)
        if (!name || !(name in root._state))
            return
        const next = Object.assign({}, root._state)
        delete next[name]
        root._state = next
    }

    // One surface is off the desktop. Idempotent, and ignored for a key that was
    // never registered: what makes this service answerable is the registered set,
    // not the reports that happen to arrive.
    function report(key: var): void {
        const name = root._key(key)
        if (!name || !root._active || !(name in root._state))
            return
        if (root._state[name] === true)
            return
        const next = Object.assign({}, root._state)
        next[name] = true
        root._state = next
        if (root.isClear())
            root.cleared()
    }

    // Emitted when the request is satisfied — including in `begin()` itself, for
    // a desktop with nothing on it. The capture is deferred off this rather than
    // read as state, because a desktop that is already clear reports back from
    // inside the write that accepted the request.
    signal cleared()

    function _key(key: var): string {
        return key === undefined || key === null ? "" : String(key)
    }
}
