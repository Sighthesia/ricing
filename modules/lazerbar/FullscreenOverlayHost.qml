import QtQuick
import "FullscreenOverlayLogic.js" as Logic
import "OsuOverlayPalette.js" as Palette

// Own the fixed wave viewport for Wiki, News, and Beatmap routes only.
Item {
    id: root

    property string route: ""
    property string phase: "closed"
    property string barPosition: "top"
    property real barHeight: 46
    property real bodyProgress: 0
    property real waveProgress: 0
    property bool loading: false
    property bool inputActive: false
    property bool pageCanGoBack: false
    property Item opener: null
    property string _pendingRoute: ""
    readonly property bool interactive: phase === "opening" || phase === "open"
    readonly property real surfaceWidth: Logic.surfaceWidth(width)
    readonly property real surfaceTop: Logic.surfaceTop(barPosition, barHeight)
    readonly property var palette: Palette.forRoute(route)
    readonly property int sidebarWidth: Logic.sidebarWidth(220)
    property alias surface: body
    property alias outsideLeft: outsideLeft
    property alias outsideRight: outsideRight
    property alias routeItem: routeLoader.item
    property alias waveRepeater: waveRepeater

    signal routeChangedByUser(string route)
    signal closed()

    function openRoute(nextRoute, source) {
        var normalized = Logic.normalizeRoute(nextRoute)
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
        return true
    }

    function close() {
        if (!interactive)
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

    // Clip all angled layers to the exact 85% osu overlay viewport.
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
        Rectangle {
            id: body
            z: 5
            x: 0
            y: MotionTokens.reducedMotion ? root.surfaceTop
                    : root.height + (root.surfaceTop - root.height) * root.bodyProgress
            width: parent.width
            height: Math.max(0, root.height - root.surfaceTop)
            radius: 0
            color: root.palette.body || "#282036"
            opacity: root.bodyProgress

            FullscreenHeader {
                id: header
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                title: root.route === "wiki" ? "Wiki" : root.route === "news" ? "News" : "Beatmaps"
                breadcrumb: "osu! / " + title
                onCloseRequested: root.close()
            }

            Item {
                id: viewport
                anchors.top: header.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                clip: true

                Loader {
                    id: routeLoader
                    anchors.fill: parent
                    sourceComponent: root.route === "wiki" ? wikiPage
                            : root.route === "news" ? newsPage : beatmapPage
                }

                Rectangle {
                    anchors.fill: parent
                    visible: root.loading
                    color: root.palette.body || "#282036"
                    Text { anchors.centerIn: parent; text: "Loading..."; color: root.palette.text || "white" }
                }
            }
        }
    }

    Component { id: wikiPage; WikiLikePage { anchors.fill: parent } }
    Component { id: newsPage; NewsLikePage { anchors.fill: parent } }
    Component { id: beatmapPage; BeatmapLikePage { anchors.fill: parent } }

    NumberAnimation {
        id: openBody
        target: root
        property: "bodyProgress"
        to: 1
        duration: MotionTokens.reducedMotion ? MotionTokens.fast : MotionTokens.waveEnter
        easing.type: Easing.OutQuint
        onFinished: if (root.phase === "opening") root.phase = "open"
    }
    NumberAnimation { id: openWaves; target: root; property: "waveProgress"; to: 1; duration: MotionTokens.reducedMotion ? MotionTokens.fast : MotionTokens.waveEnter; easing.type: Easing.OutSine }
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
