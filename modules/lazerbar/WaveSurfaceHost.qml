import QtQuick
import "WaveSurfaceLogic.js" as Logic

// Own the fixed wave viewport as a content-agnostic surface for launcher and future routes.
Item {
    id: root

    property string route: ""
    property string phase: "closed"
    property real bodyProgress: 0
    property real waveProgress: 0
    property bool loading: false
    property bool inputActive: false
    property bool pageCanGoBack: false
    property Item opener: null
    property string title: ""
    property string description: ""
    property var sidebarEntries: []
    property string activeSidebarId: ""
    // Collapsible settings-style rail; the width eases between the two
    // canonical settings sidebar sizes.
    property bool sidebarExpanded: true
    readonly property int sidebarWidth: root.sidebarExpanded
            ? LazerTheme.settingsSidebarExpandedWidth : LazerTheme.settingsSidebarContractedWidth
    property var palette: ({})
    property Component contentComponent: null
    property string _pendingRoute: ""
    readonly property bool interactive: phase === "opening" || phase === "open"
    readonly property real surfaceWidth: Logic.surfaceWidth(width)
    property alias surface: body
    property alias outsideLeft: outsideLeft
    property alias outsideRight: outsideRight
    property alias sidebar: sidebar
    property alias contentItem: routeLoader.item
    property alias waveRepeater: waveRepeater

    signal closed()
    signal opened()
    signal sidebarSelected(string id)

    function openRoute(nextRoute, source) {        var normalized = Logic.normalizeRoute(nextRoute)
        if (!normalized)
            return false

        if (source)
            opener = source

        if (phase === "open" && route && normalized !== route) {
            _pendingRoute = normalized
            routeSwap.restart()
            return true
        }

        closeBody.stop()
        closeWaves.stop()
        if (phase === "closed") {
            bodyProgress = 0
            waveProgress = 0
        }
        route = normalized
        phase = "opening"
        openBody.restart()
        openWaves.restart()
        forceActiveFocus()
        // Announce after the surface focus grab so listeners can land
        // content focus (search) without losing it back to the shell.
        opened()
        return true
    }

    function close() {        if (!interactive)
            return
        openBody.stop()
        openWaves.stop()
        routeSwap.stop()
        _pendingRoute = ""
        phase = "closing"
        closeBody.restart()
        closeWaves.restart()
    }

    function handleEscape() {
        var action = Logic.escapeAction(inputActive, pageCanGoBack, interactive)
        if (action === "input") { inputActive = false; return true }
        if (action === "back") { pageCanGoBack = false; return true }
        if (action === "close") { close(); return true }
        return false
    }

    function finishClose() {
        phase = "closed"
        route = ""
        bodyProgress = 0
        waveProgress = 0
        _pendingRoute = ""
        if (opener)
            opener.forceActiveFocus()
        opener = null
        closed()
    }

    // Invisible while closed so the window mask can release the desktop underneath.
    visible: phase !== "closed"
    enabled: visible
    focus: visible
    Keys.onEscapePressed: handleEscape()

    // Capture the exposed left side without passing the closing click to the desktop.
    MouseArea {
        id: outsideLeft
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        width: Math.max(0, (root.width - root.surfaceWidth) / 2)
        enabled: root.interactive
        onClicked: root.close()
    }

    // Capture the exposed right side without expanding the visible body.
    MouseArea {
        id: outsideRight
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        width: outsideLeft.width
        enabled: root.interactive
        onClicked: root.close()
    }

    // Clip all angled layers to the exact 85% osu overlay viewport below the top bar.
    Item {
        id: clippedViewport
        x: (root.width - width) / 2
        width: root.surfaceWidth
        height: root.height
        clip: true

        Repeater {
            id: waveRepeater
            model: 4
            delegate: FullscreenWave {
                required property int index
                anchors.fill: parent
                progress: root.waveProgress
                angle: Logic.waveAngle(index)
                colour: index === 0 ? (root.palette.light4 || "transparent")
                        : index === 1 ? (root.palette.light3 || "transparent")
                        : index === 2 ? (root.palette.dark4 || "transparent")
                        : (root.palette.dark3 || "transparent")
                restOffset: -parent.height * ([0.72, 0.5, 0.32, 0.16][index])
            }
        }

        // Move the continuous body inside the fixed compositor-facing owner.
        // The body uses the settings-panel surface hierarchy; the palette
        // drives only the wave backdrop behind it.
        Rectangle {
            id: body
            z: 5
            x: 0
            y: MotionTokens.reducedMotion ? 0 : root.height * (1 - root.bodyProgress)
            width: parent.width
            height: root.height
            radius: 0
            color: LazerTheme.settingsPanel
            opacity: root.bodyProgress

            FullscreenHeader {
                id: header
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                title: root.title
                description: root.description
                onCloseRequested: root.close()
            }

            Rectangle {
                anchors.top: header.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: 1
                color: LazerTheme.divider
            }

            FullscreenSidebar {
                id: sidebar
                anchors.top: header.bottom
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                entries: root.sidebarEntries
                selected: root.activeSidebarId
                expanded: root.sidebarExpanded
                width: root.sidebarWidth
                visible: root.sidebarEntries.length > 0
                Behavior on width {
                    enabled: !MotionTokens.reducedMotion
                    NumberAnimation { duration: MotionTokens.settingsSidebarCollapse; easing.type: Easing.OutQuint }
                }
                onSelectedChangedByUser: id => root.sidebarSelected(id)
                onCollapseToggled: root.sidebarExpanded = !root.sidebarExpanded
            }

            // Hairline divider between the navigation rail and the content column.
            Rectangle {
                anchors.top: header.bottom
                anchors.bottom: parent.bottom
                anchors.left: sidebar.visible ? sidebar.right : parent.left
                width: 1
                color: LazerTheme.divider
            }

            Item {
                id: viewport
                anchors.top: header.bottom
                anchors.left: sidebar.visible ? sidebar.right : parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                clip: true

                Loader {
                    id: routeLoader
                    anchors.fill: parent
                    sourceComponent: root.contentComponent
                }

                Rectangle {
                    anchors.fill: parent
                    visible: root.loading
                    color: LazerTheme.settingsPanel
                    Text { anchors.centerIn: parent; text: "Loading..."; color: LazerTheme.textMuted }
                }
            }
        }
    }

    NumberAnimation {
        id: openBody
        target: root
        property: "bodyProgress"
        to: 1
        duration: MotionTokens.reducedMotion ? MotionTokens.fast : MotionTokens.waveEnter
        easing.type: Easing.OutQuint
        onFinished: if (root.phase === "opening") root.phase = "open"
    }
    // Backdrop waves lead the body so they stay visible while content slides over them.
    NumberAnimation { id: openWaves; target: root; property: "waveProgress"; to: 1; duration: MotionTokens.reducedMotion ? MotionTokens.fast : MotionTokens.waveBackdropEnter; easing.type: Easing.OutQuad }
    NumberAnimation {
        id: closeBody
        target: root
        property: "bodyProgress"
        to: 0
        duration: MotionTokens.reducedMotion ? MotionTokens.fast : MotionTokens.waveExit
        easing.type: Easing.InQuad
        onFinished: if (root.phase === "closing") root.finishClose()
    }
    NumberAnimation { id: closeWaves; target: root; property: "waveProgress"; to: 0; duration: MotionTokens.reducedMotion ? MotionTokens.fast : MotionTokens.waveExit; easing.type: Easing.InSine }

    SequentialAnimation {
        id: routeSwap
        NumberAnimation { target: routeLoader; property: "opacity"; to: 0; duration: MotionTokens.waveRoute / 2; easing.type: Easing.InQuad }
        ScriptAction { script: { root.route = root._pendingRoute; root._pendingRoute = "" } }
        NumberAnimation { target: routeLoader; property: "opacity"; to: 1; duration: MotionTokens.waveRoute / 2; easing.type: Easing.OutQuad }
    }
}
