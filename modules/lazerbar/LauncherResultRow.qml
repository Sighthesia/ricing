import QtQuick
import "../../services/LauncherLogic.js" as LauncherLogic

// Present one launcher result as a notification-like card: 6px rounded
// settingsCard surface with a 40px icon rail, colorful enlarged icon,
// title/description stack, accent selection strip, shared click-flash,
// and the notification parabolic fling exit on activation.
Item {
    id: root

    // Normalized result item consumed from LauncherService.results:
    // { id, displayName, description, icon } with every field optional.
    property var result: null
    property bool selected: false
    // Settings-style search folding: non-matching rows cascade their exit
    // while survivors glide, all through the same height/opacity/x contract.
    property string searchQuery: ""
    readonly property bool matchesSearch: LauncherLogic.resultMatches(result, searchQuery)
    readonly property bool searchHidden: !matchesSearch

    readonly property string displayName: result && result.displayName != null ? String(result.displayName) : ""
    readonly property string descriptionText: result && result.description != null ? String(result.description) : ""
    readonly property string iconSource: result && result.icon ? String(result.icon) : ""

    // Slightly taller than the old 56px to mirror the notification minimum and
    // comfortably host a 28px colorful icon.
    readonly property real rowHeight: 64
    implicitWidth: 480
    activeFocusOnTab: true
    Accessible.role: Accessible.ListItem
    Accessible.name: root.displayName

    readonly property bool hovered: rowHover.hovered
    readonly property alias surfaceItem: card
    readonly property alias selectionStripItem: selectionStrip
    readonly property alias titleItem: titleText
    readonly property alias descriptionItem: descriptionLabel
    readonly property alias iconItem: iconImage
    readonly property bool flashActive: flashAnimation.running || flashOverlay.opacity > 0
    readonly property Item flashOverlayItem: flashOverlay
    readonly property Animation flashAnimationItem: flashAnimation
    readonly property bool closing: _closing

    property bool _closing: false
    readonly property real gravity: 0.005

    signal activated()

    // Settings-panel reveal contract (mirrors LazerSettingsRow verbatim):
    // held rows fold to zero height with opacity and a leftward slide, then
    // release through the shared slow OutQuint behaviors. The outer list gap
    // lives inside the height so an exited row frees exactly zero space.
    readonly property real listGap: 8
    readonly property real bodyHeight: Math.max(0, root.height - root.listGap)
    property bool revealHeld: false
    property bool snapTransitions: true
    readonly property bool geometryHeld: revealHeld || searchHidden
    // Position-based reveal slot used by the page's entrance/refill waves.
    readonly property real entryExitDelay: Math.round(Math.min(150, Math.max(0, root.y / 6)))
    height: geometryHeld ? 0 : rowHeight + listGap
    visible: !geometryHeld || height > 0.5 || opacity > 0.01
    opacity: geometryHeld ? 0 : 1
    x: geometryHeld ? -8 : 0
    enabled: !geometryHeld && !root._closing

    // Search-driven folds animate immediately and together; staggering here
    // made every keystroke ripple the entire list (entrance stagger lives in
    // the wave scheduler, not in these behaviors).
    Behavior on height {
        enabled: !MotionTokens.reducedMotion && !root.snapTransitions
        NumberAnimation { duration: MotionTokens.slow; easing.type: Easing.OutQuint }
    }
    Behavior on opacity {
        enabled: !MotionTokens.reducedMotion && !root.snapTransitions
        NumberAnimation { duration: MotionTokens.slow; easing.type: Easing.OutQuint }
    }
    Behavior on x {
        enabled: !MotionTokens.reducedMotion && !root.snapTransitions
        NumberAnimation { duration: MotionTokens.slow; easing.type: Easing.OutQuint }
    }

    Timer {
        id: revealTimer
        interval: 0
        repeat: false
        onTriggered: {
            root.snapTransitions = false
            root.revealHeld = false
        }
    }

    // Collapse instantly for the open-session wave, then release on schedule.
    function holdInstantly() {
        revealTimer.stop()
        root.snapTransitions = true
        root.revealHeld = true
    }

    // Leave the held state without animation (wave cancelled).
    function releaseInstantly() {
        revealTimer.stop()
        root.snapTransitions = true
        root.revealHeld = false
        Qt.callLater(function () { root.snapTransitions = false })
    }

    // The timer owns the wave stagger so releases animate immediately.
    function playReveal(delayMs) {
        revealTimer.interval = Math.max(0, Math.round(Number(delayMs) || 0))
        revealTimer.restart()
    }

    // --- fling exit (parabolic, gravity-driven, like LazerNotificationPopup) ---
    FrameAnimation {
        id: fallAnim
        onTriggered: {
            const dt = frameTime * 1000
            dragContainer.velocityY += dt * root.gravity
            dragContainer.dragX += dragContainer.velocityX * dt
            dragContainer.dragY += dragContainer.velocityY * dt
        }
    }

    NumberAnimation {
        id: flingFade
        target: root
        property: "opacity"
        to: 0
        duration: 600
        easing.type: Easing.InQuad
    }

    NumberAnimation {
        id: quickFade
        target: root
        property: "opacity"
        to: 0
        duration: root.reducedMotion ? 0 : 100
    }

    readonly property bool reducedMotion: MotionTokens.reducedMotion

    // Physics, drag, and rotation owner — mirrors notification DragContainer.
    Item {
        id: dragContainer
        width: root.width
        height: root.bodyHeight
        x: dragX
        y: dragY
        rotation: Math.min(0, dragX * 0.1)
        transformOrigin: Item.Center

        property real dragX: 0
        property real dragY: 0
        property real velocityX: 0
        property real velocityY: 0
    }

    // Card surface — notification-like 6px rounded card.
    Rectangle {
        id: card
        parent: dragContainer
        anchors.fill: parent
        radius: 6
        color: root.selected ? LazerTheme.settingsSelected
                : rowHover.hovered && !root._closing ? LazerTheme.settingsCardHover : LazerTheme.settingsCard
        border.width: root.selected ? 1.5 : 0
        border.color: root.selected ? LazerTheme.settingsAccent : "transparent"
        Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
        Behavior on border.width { NumberAnimation { duration: 100 } }
        Behavior on border.color { ColorAnimation { duration: 100 } }
    }

    // Icon rail like notification's iconStrip — 40px wide, rail background.
    Rectangle {
        id: iconStrip
        parent: dragContainer
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 40
        radius: 6
        color: LazerTheme.settingsRail
    }

    // Selected indicator — thin sharp accent strip on the leading edge, above card.
    Rectangle {
        id: selectionStrip
        parent: dragContainer
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 4
        radius: 0
        color: LazerTheme.settingsAccent
        visible: root.selected && !root._closing
        opacity: root.selected ? 1 : 0
        Behavior on opacity { enabled: !MotionTokens.reducedMotion; ColorAnimation { duration: MotionTokens.fast } }
    }

    // Colorful enlarged icon — preserved original colors, no colorization.
    Image {
        id: iconImage
        parent: dragContainer
        visible: root.iconSource.length > 0
        anchors.left: parent.left
        anchors.leftMargin: (40 - width) / 2
        anchors.verticalCenter: parent.verticalCenter
        width: 28
        height: 28
        source: root.iconSource
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        scale: rowPress.pressed && !root._closing ? MotionTokens.pressScale : 1
        Behavior on scale {
            enabled: !MotionTokens.reducedMotion
            NumberAnimation { duration: MotionTokens.fast; easing.type: Easing.OutQuint }
        }
    }

    // Title: left of icon rail, vertically centered when no description.
    Text {
        id: titleText
        parent: dragContainer
        x: 52
        anchors.top: parent.top
        anchors.topMargin: root.descriptionText.length > 0 ? 12 : 0
        anchors.verticalCenter: root.descriptionText.length > 0 ? undefined : parent.verticalCenter
        width: Math.max(0, parent.width - x - 12)
        text: root.displayName
        color: LazerTheme.textPrimary
        font.pixelSize: 14
        font.weight: Font.DemiBold
        elide: Text.ElideRight
        verticalAlignment: Text.AlignVCenter
    }

    Text {
        id: descriptionLabel
        parent: dragContainer
        x: titleText.x
        anchors.top: titleText.bottom
        anchors.topMargin: 2
        width: titleText.width
        visible: root.descriptionText.length > 0
        text: root.descriptionText
        color: LazerTheme.textMuted
        font.pixelSize: 11
        elide: Text.ElideRight
        wrapMode: Text.NoWrap
    }

    // Confirm activation with the shared osu click-flash recipe without
    // owning input or changing the row's hit area.
    Rectangle {
        id: flashOverlay
        parent: dragContainer
        z: 2
        anchors.fill: parent
        radius: 6
        color: LazerTheme.textPrimary
        opacity: 0
        enabled: false
    }

    NumberAnimation {
        id: flashAnimation
        target: flashOverlay
        property: "opacity"
        from: MotionTokens.clickFlashOpacity
        to: 0
        duration: MotionTokens.clickFlashDuration
        easing.type: MotionTokens.clickFlashEasing
        running: false
    }

    // Keyboard-focus ring rides above content as a non-input layer.
    Rectangle {
        id: focusRing
        parent: dragContainer
        z: 3
        anchors.fill: parent
        radius: 6
        color: "transparent"
        border.width: root.activeFocus ? 1.5 : 0
        border.color: LazerTheme.settingsAccent
        enabled: false
        Behavior on border.width { NumberAnimation { duration: MotionTokens.fast } }
        Behavior on border.color { ColorAnimation { duration: MotionTokens.fast } }
    }

    function restartFlash() {
        if (MotionTokens.reducedMotion) {
            flashAnimation.stop()
            flashOverlay.opacity = 0
            return
        }
        flashAnimation.restart()
    }

    // Activate with notification-style parabolic fling and immediate emit
    // (visual fling runs in parallel so tests stay synchronous).
    function activate() {
        if (root._closing || root.geometryHeld)
            return
        root.restartFlash()
        root._closing = true
        rowHover.enabled = false
        if (!MotionTokens.reducedMotion) {
            if (dragContainer.velocityX > -0.3)
                dragContainer.velocityX = -0.3 - Math.random() * 0.5
            dragContainer.velocityY = 0
            fallAnim.start()
            flingFade.restart()
        } else {
            quickFade.restart()
        }
        root.activated()
    }

    HoverHandler {
        id: rowHover
        blocking: false
        enabled: !root._closing
    }
    TapHandler {
        id: rowPress
        enabled: !root._closing
        onTapped: root.activate()
    }
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            root.activate()
            event.accepted = true
        }
    }

    Connections {
        target: MotionTokens
        function onReducedMotionChanged() {
            if (MotionTokens.reducedMotion)
                root.restartFlash()
        }
    }
}
