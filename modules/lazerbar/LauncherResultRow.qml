import QtQuick
import "../../services/LauncherLogic.js" as LauncherLogic

// Present one launcher result as a notification-like card: 6px rounded
// settingsCard surface with a 40px icon rail, colorful enlarged icon,
// title/description stack, accent selection strip, shared click-flash.
// Activation hands this card's geometry/content to a higher ghost layer
// (exitFlingRequested) which replays the notification parabolic fling
// above the closing panel; the row itself vanishes instantly.
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

    readonly property real rowHeight: 64
    implicitWidth: 480
    activeFocusOnTab: true
    Accessible.role: Accessible.ListItem
    Accessible.name: root.displayName

    readonly property bool hovered: rowHover.hovered
    readonly property alias surfaceItem: card
    readonly property alias titleItem: titleText
    readonly property alias descriptionItem: descriptionLabel
    readonly property alias iconItem: iconImage
    readonly property bool flashActive: flashAnimation.running || flashOverlay.opacity > 0
    readonly property Item flashOverlayItem: flashOverlay
    readonly property Animation flashAnimationItem: flashAnimation
    readonly property bool closing: _closing

    property bool _closing: false

    signal activated()
    // Window-coordinate geometry plus content, consumed by the owning
    // surface's ghost layer to replay the parabolic fling above the panel.
    signal exitFlingRequested(var spec)

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
    visible: !_closing && (!geometryHeld || height > 0.5 || opacity > 0.01)
    opacity: geometryHeld ? 0 : 1
    x: geometryHeld ? -8 : 0
    enabled: !geometryHeld && !_closing

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
        onTriggered: {            root.snapTransitions = false
            root.revealHeld = false
        }
    }

    function holdInstantly() {
        revealTimer.stop()
        root.snapTransitions = true
        root.revealHeld = true
    }

    function releaseInstantly() {
        revealTimer.stop()
        root.snapTransitions = true
        root.revealHeld = false
        Qt.callLater(function () { root.snapTransitions = false })
    }

    function playReveal(delayMs) {
        revealTimer.interval = Math.max(1, Math.round(Number(delayMs) || 0))
        revealTimer.restart()    }

    // Physics, drag, and rotation owner. All visuals nest here in explicit
    // z order: card, rail, strip, icon, text, flash, focus ring.
    Item {
        id: dragContainer
        width: root.width
        height: root.bodyHeight
        x: 0
        y: 0

        // Card surface: selected tint outranks hover swap.
        Rectangle {
            id: card
            anchors.fill: parent
            radius: 6
            color: rowHover.hovered && !root._closing ? LazerTheme.settingsCardHover
                    : LazerTheme.settingsCard
            Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
        }

        // Icon rail background like the notification icon column.
        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 40
            radius: 6
            color: LazerTheme.settingsRail
        }


        // Colorful enlarged icon: original colors preserved.
        Image {
            id: iconImage
            visible: root.iconSource.length > 0
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            width: 28
            height: 28
            source: root.iconSource
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            scale: rowPress.pressed ? MotionTokens.pressScale : 1
            Behavior on scale {
                enabled: !MotionTokens.reducedMotion
                NumberAnimation { duration: MotionTokens.fast; easing.type: Easing.OutQuint }
            }
        }

        Text {
            id: titleText
            x: 52
            width: Math.max(0, parent.width - x - 12)
            anchors.top: root.descriptionText.length > 0 ? parent.top : undefined
            anchors.topMargin: 12
            anchors.verticalCenter: root.descriptionText.length > 0 ? undefined : parent.verticalCenter
            text: root.displayName
            color: LazerTheme.textPrimary
            font.pixelSize: 14
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }

        Text {
            id: descriptionLabel
            x: titleText.x
            width: titleText.width
            anchors.top: titleText.bottom
            anchors.topMargin: 2
            visible: root.descriptionText.length > 0
            text: root.descriptionText
            color: LazerTheme.textMuted
            font.pixelSize: 11
            elide: Text.ElideRight
        }

        // Click-flash overlay above content.
        Rectangle {
            id: flashOverlay
            z: 2
            anchors.fill: parent
            radius: 6
            color: LazerTheme.textPrimary
            opacity: 0
            enabled: false
        }
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

    function restartFlash() {
        if (MotionTokens.reducedMotion) {
            flashAnimation.stop()
            flashOverlay.opacity = 0
            return
        }
        flashAnimation.restart()
    }

    // Activate per the panel-exit contract: report this card's window-space
    // geometry and content to the higher ghost layer, vanish instantly, then
    // fire execution synchronously so launch and panel close happen at once.
    function activate() {
        if (_closing || geometryHeld)
            return
        restartFlash()
        _closing = true
        var origin = mapToItem(null, 0, 0)
        exitFlingRequested({
            x: origin.x,
            y: origin.y,
            width: width - listGap,
            height: bodyHeight,
            title: displayName,
            description: descriptionText,
            icon: iconSource,
            accent: selected
        })
        activated()
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
