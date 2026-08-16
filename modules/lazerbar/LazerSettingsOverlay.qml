import QtQuick
import "LazerSettingsLogic.js" as Logic

// Own the fixed left settings surface; its sidebar and content layers move apart.
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
    property alias panel: panel
    property alias panelHost: panelHost
    property alias sidebarLayer: panel.sidebar
    property alias contentLayer: panel.content
    signal closed()
    signal closeRequested()
    property bool _restoreFocus: true
    property int _contentToken: 0
    property int readyToken: 0

    visible: blocksDesktop
    enabled: blocksDesktop
    focus: root.interactive
    Keys.onEscapePressed: event => { root.requestClose(); event.accepted = true }

    function openFrom(source) {
        opener = source || opener
        panel.beginSession()
        panelMotion.stop()
        phase = "opening"
        panelMotion.duration = MotionTokens.reducedMotion ? MotionTokens.fast : panelEnterDuration
        panelMotion.easing.type = Easing.OutQuint
        panelMotion.to = 1
        panelMotion.restart()
        scheduleContentReady()
    }
    function closeAndRestoreFocus() { close(true) }
    function closeWithoutFocusRestore() { close(false) }
    function requestClose() { if (interactive) { closeRequested(); closeAndRestoreFocus() } }
    function close(restoreFocus) {
        if (phase === "closed" || phase === "closing") return
        _contentToken += 1
        panel.contentReady = false
        panelMotion.stop(); phase = "closing"; _restoreFocus = restoreFocus
        panelMotion.duration = MotionTokens.reducedMotion ? MotionTokens.fast : panelExitDuration
        panelMotion.easing.type = Easing.InQuad; panelMotion.to = 0; panelMotion.restart()
    }
    function resetImmediately() {
        _contentToken += 1
        panelMotion.stop(); phase = "closed"; progress = 0; opener = null; _restoreFocus = false
        panel.endSession()
        panel.contentReady = false
    }

    // Defer content activation so the initial slide never competes for the first frames.
    function scheduleContentReady() {
        _contentToken += 1
        panel.contentReady = false
        readyToken = _contentToken
        readyTimer.restart()
    }

    // Keep the panel host at fixed owner size; the two layers translate inside it.
    Item {
        id: panelHost
        width: root.requiredWidth
        height: root.height
        focus: root.interactive

        LazerSettingsPanel {
            id: panel
            anchors.fill: parent
            availableWidth: root.width
            availableHeight: root.height
            sidePanel: true
            interactive: root.interactive
            progress: root.progress
            onCloseRequested: root.requestClose()
        }
    }

    Timer {
        id: readyTimer
        interval: MotionTokens.settingsContentDelay
        repeat: false
        onTriggered: {
            if (!root.interactive || root.readyToken !== root._contentToken)
                return
            panel.contentReady = true
            panel.focusSearch()
        }
    }

    NumberAnimation {
        id: panelMotion; target: root; property: "progress"
        onFinished: {
            if (root.phase === "opening" && root.progress >= 1) root.phase = "open"
            else if (root.phase === "closing" && root.progress <= 0) {
                root.phase = "closed"
                root.panel.endSession()
                if (root._restoreFocus && root.opener) root.opener.forceActiveFocus()
                root.closed()
            }
        }
    }
}
