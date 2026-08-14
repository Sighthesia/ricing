import QtQuick

// Own the modal lifecycle while keeping the compositor-facing host geometry fixed.
Item {
    id: root

    property string phase: "closed"
    readonly property bool interactive: phase === "opening" || phase === "open"
    readonly property bool blocksDesktop: phase !== "closed"
    property real progress: 0
    property real scrimProgress: 0
    property int entryDirection: 1
    property Item opener: null
    readonly property real scrimTargetOpacity: 0.6
    readonly property int panelEnterDuration: 320
    readonly property int panelExitDuration: 240
    readonly property int scrimDuration: 180
    property alias panel: panel
    property alias scrim: scrim
    signal closed
    signal closeRequested

    visible: blocksDesktop
    enabled: blocksDesktop

    // Keep Escape modal even when focus belongs to a page control inside the panel.
    Shortcut {
        sequence: "Escape"
        enabled: root.interactive
        context: Qt.WindowShortcut
        onActivated: root.requestClose()
    }

    property int _motionToken: 0

    function openFrom(source, direction) {
        opener = source || null
        if (direction === -1 || direction === 1)
            entryDirection = direction
        else if (entryDirection !== -1 && entryDirection !== 1)
            entryDirection = 1

        _motionToken += 1
        phase = "opening"
        panelMotion.duration = MotionTokens.reducedMotion ? 1 : panelEnterDuration
        panelMotion.easing.type = Easing.OutQuint
        panelMotion.to = 1
        panelMotion.restart()
        scrimMotion.duration = MotionTokens.reducedMotion ? 1 : scrimDuration
        scrimMotion.easing.type = Easing.OutCubic
        scrimMotion.to = 1
        scrimMotion.restart()
        Qt.callLater(function() {
            if (root.interactive)
                panel.focusFirstControl()
        })
    }

    function closeAndRestoreFocus() {
        close(true)
    }

    function closeWithoutFocusRestore() {
        close(false)
    }

    function requestClose() {
        if (!interactive)
            return
        closeRequested()
        closeAndRestoreFocus()
    }

    // Keep the modal focus ring explicit instead of relying on child Keys handlers.
    function cycleFocus(backward) {
        if (!interactive)
            return
        if (panel.closeButton.activeFocus) {
            panel.currentNav.forceActiveFocus()
        } else if (panel.currentNav.activeFocus) {
            panel.closeButton.forceActiveFocus()
        } else if (backward) {
            panel.closeButton.forceActiveFocus()
        } else {
            panel.currentNav.forceActiveFocus()
        }
    }

    function close(restoreFocus) {
        if (phase === "closed" || phase === "closing")
            return
        _motionToken += 1
        phase = "closing"
        panelMotion.duration = MotionTokens.reducedMotion ? 1 : panelExitDuration
        panelMotion.easing.type = Easing.InCubic
        panelMotion.to = 0
        panelMotion.restart()
        scrimMotion.duration = MotionTokens.reducedMotion ? 1 : scrimDuration
        scrimMotion.easing.type = Easing.InCubic
        scrimMotion.to = 0
        scrimMotion.restart()
        _restoreFocus = restoreFocus
    }

    property bool _restoreFocus: true

    // Paint a blocking scrim below the panel; its pointer handler cannot reach panel children.
    Rectangle {
        id: scrim
        anchors.fill: parent
        color: "black"
        opacity: root.scrimProgress * root.scrimTargetOpacity
        visible: root.blocksDesktop

        TapHandler {
            onTapped: root.requestClose()
        }
    }

    // Keep panel dimensions derived from the fixed host, never from animated geometry.
    Item {
        id: panelHost
        anchors.horizontalCenter: parent.horizontalCenter
        width: panel.panelWidth
        height: panel.panelHeight
        y: 0

        // Close and navigation are the modal's tab boundary until page controls are extended.
        Keys.priority: Keys.BeforeItem
        Keys.onPressed: event => {
            if (!root.interactive)
                return
            if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                var backward = event.key === Qt.Key_Backtab
                        || (event.key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier))
                root.cycleFocus(backward)
                event.accepted = true
            }
        }

        // Shield empty panel clicks at the host boundary without intercepting child controls.
        TapHandler {
            acceptedButtons: Qt.AllButtons
            gesturePolicy: TapHandler.WithinBounds
            onTapped: event => event.accepted = true
        }

        LazerSettingsPanel {
            id: panel
            anchors.fill: parent
            z: 1
            availableWidth: root.width
            availableHeight: root.height
            interactive: root.interactive
            opacity: root.progress
            y: MotionTokens.reducedMotion ? 0 : root.entryDirection * height * (1 - root.progress)
            onCloseRequested: root.requestClose()
        }
    }

    // Route every visible navigation entry into the modal close affordance.
    Binding { target: panel.appearanceNav; property: "KeyNavigation.tab"; value: panel.closeButton }
    Binding { target: panel.appearanceNav; property: "KeyNavigation.backtab"; value: panel.closeButton }
    Binding { target: panel.barNav; property: "KeyNavigation.tab"; value: panel.closeButton }
    Binding { target: panel.barNav; property: "KeyNavigation.backtab"; value: panel.closeButton }
    Binding { target: panel.notificationNav; property: "KeyNavigation.tab"; value: panel.closeButton }
    Binding { target: panel.notificationNav; property: "KeyNavigation.backtab"; value: panel.closeButton }

    // Keep the return edge tied to whichever category is currently selected.
    Binding { target: panel.closeButton; property: "KeyNavigation.tab"; value: panel.currentNav }
    Binding { target: panel.closeButton; property: "KeyNavigation.backtab"; value: panel.currentNav }

    NumberAnimation {
        id: panelMotion
        target: root
        property: "progress"
        easing.type: Easing.BezierSpline
        onFinished: {
            if (root.phase === "opening" && root.progress >= 1) {
                root.phase = "open"
            } else if (root.phase === "closing" && root.progress <= 0) {
                root.phase = "closed"
                if (root._restoreFocus && root.opener)
                    root.opener.forceActiveFocus()
                root.closed()
            }
        }
    }

    NumberAnimation {
        id: scrimMotion
        target: root
        property: "scrimProgress"
        easing.type: Easing.BezierSpline
    }

    Connections {
        target: MotionTokens
        function onReducedMotionChanged() {
            if (!MotionTokens.reducedMotion)
                return
            panel.x = panel.x
            panel.y = 0
        }
    }
}
