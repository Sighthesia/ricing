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

    function ownerClosed(owner) {
        if (!transitioning) {
            if (owner !== activeOwner)
                return
            activeTarget = ""
            activeOwner = ""
            if (opener)
                opener.forceActiveFocus()
            opener = null
            return
        }

        if (owner !== _closingOwner)
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
