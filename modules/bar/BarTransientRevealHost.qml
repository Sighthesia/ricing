import QtQuick
import qs.config
import qs.services
import qs.modules.bar

// Host transient reveal geometry and registry lifetime for bar overlays.
Item {
    id: root

    required property real collapsedHeight
    required property real expandedHeight
    required property bool expanded
    required property string extensionOwnerKey

    property bool animateSurface: true
    property var sharedTransition: null

    readonly property string state: _state
    readonly property var _geometryTransition: sharedTransition || _surfaceTransition
    readonly property bool _usesSharedTransition: !!sharedTransition
    readonly property real surfaceHeight: _geometryTransition.animatedHeight
    readonly property real clipHeight: _usesSharedTransition ? _geometryTransition.animatedHeight : _clipHeight
    readonly property real progress: {
        const revealRange = expandedHeight - collapsedHeight
        if (revealRange <= 0)
            return expanded ? 1 : 0

        const normalized = (surfaceHeight - collapsedHeight) / revealRange
        return Math.max(0, Math.min(1, normalized))
    }
    readonly property real reservedExtension: _reservedExtension
    readonly property bool running: _transitionRunning
        || (!_usesSharedTransition && (_clipAnimation.running || _surfaceTransition.running))
        || (_usesSharedTransition && _geometryTransition && _geometryTransition.running)

    property string _state: "closed"
    property real _clipHeight: 0
    property real _reservedExtension: 0
    property bool _ready: false
    property bool _clipBehaviorEnabled: false
    property bool _transitionRunning: false
    property bool _closeAwaitingClipAnimation: false
    property string _activeExtensionOwnerKey: ""

    Behavior on _clipHeight {
        enabled: root._clipBehaviorEnabled
        NumberAnimation {
            id: _clipAnimation
            duration: Theme.anim.moveDuration
            easing.type: Theme.anim.moveType

            onRunningChanged: {
                if (!root._ready) {
                    return
                }

                if (running) {
                    root._closeAwaitingClipAnimation = false
                    return
                }

                if (root._state === "closing" && !root.expanded) {
                    root._maybeFinalizeClose()
                    return
                }
            }
        }
    }

    Connections {
        target: root._geometryTransition

        function onRunningChanged() {
            if (!root._ready) {
                return
            }

            if (root._state === "opening" && root.expanded && !target.running) {
                root._finalizeOpen()
                return
            }

            if (root._closeAwaitingClipAnimation && !root._usesSharedTransition) {
                return
            }

            if (root._state === "closing" && !root.expanded && !target.running) {
                root._maybeFinalizeClose()
            }
        }
    }

    BarExpandTransition {
        id: _surfaceTransition

        collapsedWidth: 1
        expandedWidth: 1
        collapsedHeight: root.collapsedHeight
        expandedHeight: root.expandedHeight
        expanded: root.expanded
        animateWidth: false
        animateHeight: root.animateSurface
        pulseEnabled: false
    }

    function _targetReservedExtension() {
        return Math.max(0, expandedHeight - collapsedHeight)
    }

    function _clearActiveReservation() {
        if (_activeExtensionOwnerKey) {
            BarLayoutService.clearTransientExtension(_activeExtensionOwnerKey)
            _activeExtensionOwnerKey = ""
        }
    }

    function _setReservedExtension(nextExtension) {
        let clampedExtension = Math.max(0, Number(nextExtension) || 0)

        if (!extensionOwnerKey) {
            return
        }

        if (_reservedExtension === clampedExtension && _activeExtensionOwnerKey === extensionOwnerKey) {
            return
        }

        _reservedExtension = clampedExtension
        _activeExtensionOwnerKey = extensionOwnerKey

        if (clampedExtension > 0) {
            BarLayoutService.setTransientExtension(extensionOwnerKey, clampedExtension)
            return
        }

        BarLayoutService.clearTransientExtension(extensionOwnerKey)
    }

    function _registerReservedExtension(ownerKey, nextExtension) {
        let clampedOwnerKey = ownerKey || ""
        let clampedExtension = Math.max(0, Number(nextExtension) || 0)
        let ownerChanged = _activeExtensionOwnerKey && _activeExtensionOwnerKey !== clampedOwnerKey

        if (ownerChanged) {
            BarLayoutService.clearTransientExtension(_activeExtensionOwnerKey)
        }

        if (!clampedOwnerKey) {
            if (_activeExtensionOwnerKey) {
                BarLayoutService.clearTransientExtension(_activeExtensionOwnerKey)
            }
            _reservedExtension = 0
            _activeExtensionOwnerKey = ""
            return
        }

        if (ownerChanged) {
            _activeExtensionOwnerKey = clampedOwnerKey
        }

        if (ownerChanged) {
            _reservedExtension = 0
        }

        if (_reservedExtension !== clampedExtension) {
            _setReservedExtension(clampedExtension)
            return
        }

        BarLayoutService.setTransientExtension(clampedOwnerKey, clampedExtension)
    }

    function _finalizeClose() {
        _setReservedExtension(0)
        _surfaceTransition.snapToCollapsed()
        _state = "closed"
        _closeAwaitingClipAnimation = false
        _transitionRunning = false
    }

    function _maybeFinalizeClose() {
        if (_state !== "closing" || expanded) {
            return
        }

        if (!_usesSharedTransition && _clipAnimation.running) {
            return
        }

        if (_geometryTransition.running
            && _geometryTransition.animatedHeight > collapsedHeight + 0.5) {
            return
        }

        _finalizeClose()
    }

    function _finalizeOpen() {
        if (!expanded || _state !== "opening") {
            return
        }

        _state = "open"
        _transitionRunning = false
    }

    function _syncToTruthWithoutAnimation() {
        if (!_usesSharedTransition)
            _surfaceTransition.expanded = expanded
        _clipBehaviorEnabled = false
        _clipHeight = expanded ? expandedHeight : collapsedHeight
        _clipBehaviorEnabled = true
        _registerReservedExtension(extensionOwnerKey, expanded ? _targetReservedExtension() : 0)
        _state = expanded ? "open" : "closed"
        _closeAwaitingClipAnimation = false
        _transitionRunning = false
    }

    function _beginOpen() {
        _registerReservedExtension(extensionOwnerKey, _targetReservedExtension())
        _state = "opening"
        _closeAwaitingClipAnimation = false
        _transitionRunning = true

        if (!_usesSharedTransition) {
            _surfaceTransition.expanded = true
            _clipBehaviorEnabled = true
            _clipHeight = expandedHeight
        }
    }

    function _beginClose() {
        _registerReservedExtension(extensionOwnerKey, _targetReservedExtension())
        _state = "closing"
        _closeAwaitingClipAnimation = !_usesSharedTransition
        _transitionRunning = true

        if (!_usesSharedTransition) {
            _surfaceTransition.expanded = false
            _clipHeight = collapsedHeight
        }
    }

    onExpandedChanged: {
        if (!_ready) {
            return
        }

        if (expanded) {
            _beginOpen()
            return
        }

        _beginClose()
    }

    onCollapsedHeightChanged: {
        if (!_ready || expanded)
            return

        if (_transitionRunning) {
            _clipHeight = collapsedHeight
            return
        }

        _syncToTruthWithoutAnimation()
    }

    onExpandedHeightChanged: {
        if (!_ready || !expanded)
            return

        _registerReservedExtension(extensionOwnerKey, _targetReservedExtension())

        if (!_usesSharedTransition)
            _clipHeight = expandedHeight

        if (!_transitionRunning)
            _syncToTruthWithoutAnimation()
    }

    onExtensionOwnerKeyChanged: {
        if (!_ready) {
            return
        }

        _registerReservedExtension(extensionOwnerKey, expanded ? _targetReservedExtension() : 0)
    }

    Component.onCompleted: {
        _ready = true
        _syncToTruthWithoutAnimation()
    }

    Component.onDestruction: {
        _clearActiveReservation()
    }
}
