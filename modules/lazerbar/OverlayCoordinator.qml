import QtQuick
import "OverlayCoordinatorLogic.js" as Logic

// Serialize route requests across the three independently animated overlay owners.
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
    signal routeRequested(string target)

    function request(target, source) {
        var normalized = Logic.normalizeTarget(target)
        if (!normalized)
            return false

        if (source)
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
            pendingTarget = ""
            transitioning = true
            _closingOwner = activeOwner
            closeRequested(activeOwner)
            return true
        }

        if (Logic.isSameOwner(activeTarget, normalized)) {
            activeTarget = normalized
            routeRequested(normalized)
            return true
        }

        pendingTarget = normalized
        transitioning = true
        _closingOwner = activeOwner
        closeRequested(activeOwner)
        return true
    }

    function ownerClosed(owner) {
        if (!transitioning || owner !== _closingOwner)
            return

        var nextTarget = pendingTarget
        pendingTarget = ""
        transitioning = false
        _closingOwner = ""

        if (nextTarget) {
            activeTarget = nextTarget
            activeOwner = Logic.ownerFor(nextTarget)
            openRequested(activeOwner, activeTarget)
            return
        }

        activeTarget = ""
        activeOwner = ""
        if (opener)
            opener.forceActiveFocus()
        opener = null
    }
}
