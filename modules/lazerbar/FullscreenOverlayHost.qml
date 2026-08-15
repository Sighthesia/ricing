import QtQuick
import "FullscreenOverlayLogic.js" as Logic

// Own one fixed fullscreen route surface; only its inner scene animates.
Item {
    id: root
    property string route: ""
    property string phase: "closed"
    property real openProgress: 0
    property bool loading: false
    property bool inputActive: false
    property bool pageCanGoBack: false
    property Item opener: null
    property Component settingsComponent
    property Component musicComponent
    property alias interactiveSurface: surface
    property alias routeItem: routeLoader.item
    readonly property bool interactive: phase === "opening" || phase === "open"
    readonly property int sidebarWidth: Logic.sidebarWidth(220)
    readonly property real surfaceWidth: Logic.surfaceWidth(width)
    readonly property real surfaceHeight: Logic.surfaceHeight(height)
    signal routeChangedByUser(string route)
    signal closed()

    function openRoute(nextRoute, source) {
        var normalized = Logic.normalizeRoute(nextRoute)
        if (!normalized)
            return
        closeAnimation.stop()
        route = normalized
        opener = source || opener
        phase = "opening"
        openProgress = 0
        openAnimation.restart()
        forceActiveFocus()
    }

    function close() {
        if (!interactive)
            return
        openAnimation.stop()
        phase = "closing"
        closeAnimation.restart()
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
        openProgress = 0
        if (opener)
            opener.forceActiveFocus()
        closed()
    }

    visible: phase !== "closed"
    enabled: visible
    focus: visible
    Keys.onEscapePressed: handleEscape()

    // Click-away is limited to the visible backdrop while the route is active.
    MouseArea { anchors.fill: parent; enabled: root.interactive; z: 1; onClicked: root.close() }

    // Keep the backdrop full-screen while the compositor-facing host remains fixed.
    Rectangle { anchors.fill: parent; color: "#99050910"; opacity: root.openProgress * 0.72; Behavior on opacity { NumberAnimation { duration: MotionTokens.backdropEnter } } }

    // Animate the centered surface, never the PanelWindow dimensions.
    Rectangle {
        id: surface
        z: 2
        anchors.centerIn: parent
        width: root.surfaceWidth
        height: root.surfaceHeight
        radius: 16
        color: "#F21A1B24"
        border.color: "#38FFFFFF"
        opacity: root.openProgress
        scale: MotionTokens.reducedMotion ? 1 : 0.96 + root.openProgress * 0.04
        transform: Translate { y: MotionTokens.reducedMotion ? 0 : (1 - root.openProgress) * 18 }
        Behavior on opacity { NumberAnimation { duration: MotionTokens.page } }

        // Keep route identity stable while page content is replaced in one slot.
        FullscreenHeader { id: header; anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right; title: root.route === "wiki" ? "Wiki" : root.route === "news" ? "News" : root.route === "beatmap" ? "Beatmaps" : root.route === "music" ? "Music" : "Settings"; breadcrumb: "Afloat / " + title; onCloseRequested: root.close() }
        Item { id: viewport; anchors.top: header.bottom; anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; clip: true
            Loader {
                id: routeLoader
                anchors.fill: parent
                sourceComponent: root.route === "wiki" ? wikiPage : root.route === "news" ? newsPage : root.route === "beatmap" ? beatmapPage : root.route === "settings" ? root.settingsComponent : root.musicComponent
                onLoaded: {
                    if (item && typeof item.open === "function")
                        item.open()
                }
            }
            Rectangle { anchors.fill: parent; visible: root.loading; color: "#CC11131A"; Text { anchors.centerIn: parent; text: "Loading…"; color: "white" } }
        }
    }

    Component { id: wikiPage; WikiLikePage { anchors.fill: parent } }
    Component { id: newsPage; NewsLikePage { anchors.fill: parent } }
    Component { id: beatmapPage; BeatmapLikePage { anchors.fill: parent } }
    NumberAnimation { id: openAnimation; target: root; property: "openProgress"; to: 1; duration: MotionTokens.reducedMotion ? 1 : MotionTokens.page; easing.type: Easing.OutCubic; onFinished: root.phase = "open" }
    NumberAnimation { id: closeAnimation; target: root; property: "openProgress"; to: 0; duration: MotionTokens.reducedMotion ? 1 : MotionTokens.page - 60; easing.type: Easing.InCubic; onFinished: root.finishClose() }
}
