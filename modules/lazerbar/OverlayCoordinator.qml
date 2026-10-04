import QtQuick
import "OverlayCoordinatorLogic.js" as Logic

// Serialize requests across the three overlay owners: settings, music, and the launcher wave.
QtObject {
    id: root

    property string activeTarget: ""
    property string activeOwner: ""
    property string pendingTarget: ""
    property bool transitioning: false
    property Item opener: null
    property string _closingOwner: ""

    signal openRequested(string owner, string target)
    signal closeRequested(string owner)

    function request(target, source, resetOpener, ensureOpen) {
        var normalized = Logic.normalizeTarget(target)
        if (!normalized)
            return false

        if (resetOpener === true)
            opener = source || null
        else if (source)
            opener = source

        if (transitioning) {
            pendingTarget = normalized
            return true
        }

        if (!activeOwner) {
            activeTarget = normalized
            activeOwner = Logic.ownerFor(normalized)
            openRequested(activeOwner, activeTarget)
            return true
        }

        if (normalized === activeTarget) {
            if (ensureOpen === true)
                return true
            pendingTarget = ""
            transitioning = true
            _closingOwner = activeOwner
            closeRequested(activeOwner)
            return true
        }

        pendingTarget = normalized
        transitioning = true
        _closingOwner = activeOwner
        closeRequested(activeOwner)
        return true
    }

    // Drop a queued hand-off while keeping the active owner open; used when
    // the newest request recalls a surface that was mid-hand-off to another
    // owner, so the recalled surface never fires a stale completion.
    function cancelPending() {
        if (!transitioning)
            return
        pendingTarget = ""
        transitioning = false
        _closingOwner = ""
    }

    // Settle an owner's finished close and report what it settled: "reopened"
    // when the queued target belongs to this same owner, so it is being
    // dispatched right now and the owner must stay live; "released" when
    // ownership ended, either because nothing was queued or because another
    // owner took the queued target; "ignored" when this owner's close was not
    // the transition being awaited, so nothing changed.
    //
    // The distinction is load-bearing because a close is not always a hide. One
    // owner serves several routes, so handing it a sibling route closes the
    // surface and immediately reopens it on the new route - and a caller that
    // mirrors every close into its own visible state would then shut the route
    // it had just asked for.
    function ownerClosed(owner) {
        if (!transitioning) {
            if (owner !== activeOwner)
                return "ignored"
            activeTarget = ""
            activeOwner = ""
            if (opener)
                opener.forceActiveFocus()
            opener = null
            return "released"
        }

        if (owner !== _closingOwner)
            return "ignored"

        var nextTarget = pendingTarget
        pendingTarget = ""
        transitioning = false
        _closingOwner = ""

        if (nextTarget) {
            activeTarget = nextTarget
            activeOwner = Logic.ownerFor(nextTarget)
            openRequested(activeOwner, activeTarget)
            return activeOwner === owner ? "reopened" : "released"
        }

        activeTarget = ""
        activeOwner = ""
        if (opener)
            opener.forceActiveFocus()
        opener = null
        return "released"
    }
}
