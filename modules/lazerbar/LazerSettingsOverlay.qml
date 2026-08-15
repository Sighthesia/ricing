import QtQuick
import "LazerSettingsLogic.js" as Logic

// Own the fixed left settings surface while only its inner panel translates.
Item {
    id: root
    property string phase: "closed"
    readonly property bool interactive: phase === "opening" || phase === "open"
    readonly property bool blocksDesktop: phase !== "closed"
    property real progress: 0
    property Item opener: null
    readonly property real requiredWidth: Logic.sidePanelWidth(width)
    readonly property int panelEnterDuration: MotionTokens.settingsSlide
    readonly property int panelExitDuration: MotionTokens.settingsSlide
    readonly property real panelOffsetX: MotionTokens.reducedMotion ? 0 : -panelHost.width * (1 - progress)
    readonly property real panelOpacity: progress
    property alias panel: panel
    property alias panelHost: panelHost
    signal closed()
    signal closeRequested()
    property bool _restoreFocus: true

    visible: blocksDesktop
    enabled: blocksDesktop

    function openFrom(source) {
        opener = source || opener
        panelMotion.stop()
        phase = "opening"
        panelMotion.duration = MotionTokens.reducedMotion ? MotionTokens.fast : panelEnterDuration
        panelMotion.easing.type = Easing.OutQuint
        panelMotion.to = 1
        panelMotion.restart()
        Qt.callLater(function() { if (root.interactive) panel.focusFirstControl() })
    }
    function closeAndRestoreFocus() { close(true) }
    function closeWithoutFocusRestore() { close(false) }
    function requestClose() { if (interactive) { closeRequested(); closeAndRestoreFocus() } }
    function close(restoreFocus) {
        if (phase === "closed" || phase === "closing") return
        panelMotion.stop(); phase = "closing"; _restoreFocus = restoreFocus
        panelMotion.duration = MotionTokens.reducedMotion ? MotionTokens.fast : panelExitDuration
        panelMotion.easing.type = Easing.InQuad; panelMotion.to = 0; panelMotion.restart()
    }
    function resetImmediately() {
        panelMotion.stop(); phase = "closed"; progress = 0; opener = null; _restoreFocus = false
    }
    function cycleFocus(backward) {
        if (!interactive) return
        if (panel.closeButton.activeFocus) panel.currentNav.forceActiveFocus()
        else panel.closeButton.forceActiveFocus()
    }

    // Keep the panel host at fixed owner size and move only its scene-graph content.
    Item {
        id: panelHost
        x: root.panelOffsetX
        y: 0
        width: root.requiredWidth
        height: root.height
        focus: root.interactive
        Keys.priority: Keys.BeforeItem
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                root.cycleFocus(event.key === Qt.Key_Backtab || (event.modifiers & Qt.ShiftModifier)); event.accepted = true
            }
        }
        Keys.onEscapePressed: event => { root.requestClose(); event.accepted = true }

        LazerSettingsPanel {
            id: panel
            anchors.fill: parent
            availableWidth: root.width
            availableHeight: root.height
            sidePanel: true
            interactive: root.interactive
            opacity: root.panelOpacity
            onCloseRequested: root.requestClose()
        }
    }

    Binding { target: panel.appearanceNav; property: "KeyNavigation.tab"; value: panel.closeButton }
    Binding { target: panel.barNav; property: "KeyNavigation.tab"; value: panel.closeButton }
    Binding { target: panel.notificationNav; property: "KeyNavigation.tab"; value: panel.closeButton }
    Binding { target: panel.closeButton; property: "KeyNavigation.tab"; value: panel.currentNav }

    NumberAnimation {
        id: panelMotion; target: root; property: "progress"
        onFinished: {
            if (root.phase === "opening" && root.progress >= 1) root.phase = "open"
            else if (root.phase === "closing" && root.progress <= 0) {
                root.phase = "closed"
                if (root._restoreFocus && root.opener) root.opener.forceActiveFocus()
                root.closed()
            }
        }
    }
}
