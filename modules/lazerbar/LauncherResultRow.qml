import QtQuick
import QtQuick.Effects

// Present one launcher result as a fixed-height sharp osu!lazer row: accent
// selection strip and tinted fill, settings-panel hover swap and focus ring,
// press scale, shared click-flash contract, and icon/title/description
// metadata. Selection is service-driven; the row never steals search focus.
Item {
    id: root

    // Normalized result item consumed from LauncherService.results:
    // { id, displayName, description, icon } with every field optional.
    property var result: null
    property bool selected: false

    readonly property string displayName: result && result.displayName != null ? String(result.displayName) : ""
    readonly property string descriptionText: result && result.description != null ? String(result.description) : ""
    readonly property string iconSource: result && result.icon ? String(result.icon) : ""

    readonly property real rowHeight: 56
    implicitWidth: 480
    height: rowHeight
    activeFocusOnTab: true
    Accessible.role: Accessible.ListItem
    Accessible.name: root.displayName

    readonly property bool hovered: rowHover.hovered
    readonly property alias surfaceItem: rowSurface
    readonly property alias selectionStripItem: selectionStrip
    readonly property alias titleItem: titleText
    readonly property alias descriptionItem: descriptionLabel
    readonly property alias iconItem: iconImage
    readonly property bool flashActive: flashAnimation.running || flashOverlay.opacity > 0
    readonly property Item flashOverlayItem: flashOverlay
    readonly property Animation flashAnimationItem: flashAnimation

    signal activated()

    // Sharp full-row surface: selected tint outranks the plain hover swap.
    Rectangle {
        id: rowSurface
        anchors.fill: parent
        radius: 0
        color: root.selected ? LazerTheme.settingsSelected
                : rowHover.hovered ? LazerTheme.hoverFill : "transparent"
        Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
    }

    // Selected indicator stays a thin sharp accent strip on the leading edge.
    Rectangle {
        id: selectionStrip
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 4
        radius: 0
        color: LazerTheme.settingsAccent
        visible: root.selected
        opacity: root.selected ? 1 : 0
        Behavior on opacity { enabled: !MotionTokens.reducedMotion; ColorAnimation { duration: MotionTokens.fast } }
    }

    // Result icon at osu's left margin, colorized with the muted text tone
    // until the row is selected or hovered.
    Image {
        id: iconImage
        visible: root.iconSource.length > 0
        x: 16
        anchors.verticalCenter: parent.verticalCenter
        width: 20
        height: 20
        source: root.iconSource
        fillMode: Image.PreserveAspectFit
        scale: rowPress.pressed ? MotionTokens.pressScale : 1
        Behavior on scale {
            enabled: !MotionTokens.reducedMotion
            NumberAnimation { duration: MotionTokens.fast; easing.type: Easing.OutQuint }
        }
    }

    MultiEffect {
        anchors.fill: iconImage
        source: iconImage
        visible: iconImage.visible
        colorization: 1
        colorizationColor: root.selected || rowHover.hovered ? LazerTheme.textPrimary : LazerTheme.textMuted
        Behavior on colorizationColor { ColorAnimation { duration: MotionTokens.fast } }
    }

    Text {
        id: titleText
        x: 52
        anchors.top: parent.top
        anchors.topMargin: root.descriptionText.length > 0 ? 9 : 0
        anchors.verticalCenter: root.descriptionText.length > 0 ? undefined : parent.verticalCenter
        width: Math.max(0, parent.width - x - 12)
        text: root.displayName
        color: LazerTheme.textPrimary
        font.pixelSize: 14
        elide: Text.ElideRight
    }

    Text {
        id: descriptionLabel
        x: titleText.x
        anchors.top: titleText.bottom
        anchors.topMargin: 2
        width: titleText.width
        visible: root.descriptionText.length > 0
        text: root.descriptionText
        color: LazerTheme.textMuted
        font.pixelSize: 11
        elide: Text.ElideRight
    }

    // Confirm activation with the shared osu click-flash recipe without
    // owning input or changing the row's hit area.
    Rectangle {
        id: flashOverlay
        z: 2
        anchors.fill: parent
        radius: 0
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
        z: 3
        anchors.fill: parent
        radius: 0
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

    // Activate without moving keyboard focus away from the search session.
    function activate() {
        root.restartFlash()
        root.activated()
    }

    HoverHandler {
        id: rowHover
        blocking: false
    }
    TapHandler {
        id: rowPress
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
