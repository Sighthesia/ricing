import QtQuick
import QtQuick.Effects

// One horizontal section tab in the overlay's page band — the launcher modes
// (Apps / Clipboard / Shortcuts) after the vertical rail became a tab row.
//
// Sharp by construction: the tab is a full-height strip with square ends, its
// hover state is a tone block rather than a rounded wash, and the selected state
// is a lazer indicator strip bottom-anchored to the band's own edge (the same
// "细矩形条带" language the settings sidebar uses for its vertical strip, turned
// 90°). Nothing here animates shape: radius is static and selection reads as
// ink + strip only.
//
// Laid out absolutely rather than with a Row/Column on purpose. A positioner
// forbids anchors on its children, and the icon's colorizing MultiEffect has to
// track the icon exactly — which needs `anchors.fill`. Inside a Row the icon
// item contributes its size to the positioner while the effect contributes
// nothing, so the row's implicit width collapses to the label alone: every tab
// then claims one width and the labels pile up on the same x. Positioning the
// parts by hand costs three lines and keeps the reported width honest.
Item {
    id: root

    property string label: ""
    property string iconSource: ""
    property bool selected: false
    property bool interactive: true
    signal activated()
    signal moveRequested(int direction)

    readonly property bool flashActive: flashAnimation.running || flashOverlay.opacity > 0
    readonly property Item flashOverlayItem: flashOverlay
    readonly property Animation flashAnimationItem: flashAnimation
    readonly property alias labelItem: labelText
    readonly property alias indicatorItem: indicator
    readonly property alias iconItem: iconImage

    readonly property int horizontalPadding: 14
    readonly property int glyphSize: 17
    readonly property int glyphGap: 7
    readonly property int glyphInset: root.iconSource.length > 0
            ? root.glyphSize + root.glyphGap : 0

    implicitHeight: 40
    width: horizontalPadding * 2 + glyphInset + labelText.implicitWidth
    enabled: root.interactive
    activeFocusOnTab: root.interactive
    Accessible.role: Accessible.PageTab
    Accessible.name: root.label

    // Section glyph, tinted with the active or muted text tone.
    Image {
        id: iconImage
        visible: root.iconSource.length > 0
        x: root.horizontalPadding
        anchors.verticalCenter: parent.verticalCenter
        width: root.glyphSize
        height: root.glyphSize
        source: root.iconSource
        fillMode: Image.PreserveAspectFit
        scale: tapHandler.pressed ? MotionTokens.pressScale : 1
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
        colorizationColor: root.selected
            ? LazerTheme.textPrimary
            : (hoverHandler.hovered ? LazerTheme.textPrimary : LazerTheme.settingsNavInactive)
        Behavior on colorizationColor { ColorAnimation { duration: MotionTokens.fast } }
    }

    // Tab label, sharing the icon's optical centre rather than its own box: a
    // 13px line and a 17px glyph only look aligned when their centres match.
    Text {
        id: labelText
        x: root.horizontalPadding + root.glyphInset
        anchors.verticalCenter: parent.verticalCenter
        text: root.label
        color: root.selected
            ? LazerTheme.textPrimary
            : (hoverHandler.hovered ? LazerTheme.textPrimary : LazerTheme.settingsNavInactive)
        font.pixelSize: 13
        font.bold: root.selected
        Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
    }

    // Hover wash sits UNDER the content and is a square band, so it reads as the
    // tab's own surface lifting rather than as a floating rounded chip. The
    // selected tab keeps its ink and strip instead — a tone wash under a selected
    // tab would fight the strip for the same "you are here" job.
    Rectangle {
        anchors.fill: parent
        radius: 0
        color: hoverHandler.hovered && !root.selected ? LazerTheme.settingsRowHover : "transparent"
        Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
    }

    // Click flash, the shared recipe: an inert white overlay faded back out.
    Rectangle {
        id: flashOverlay
        z: 1
        anchors.fill: parent
        radius: 0
        color: LazerTheme.textPrimary
        opacity: 0
        enabled: false
    }

    // Selected state as a lazer strip, bottom-anchored so it underlines the tab
    // against the band's own lower edge instead of floating inside it.
    Rectangle {
        id: indicator
        z: 2
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.max(16, labelText.implicitWidth + 8)
        height: 3
        color: LazerTheme.settingsAccent
        opacity: root.selected ? 1 : 0
        Behavior on opacity {
            enabled: !MotionTokens.reducedMotion
            NumberAnimation { duration: MotionTokens.settingsSidebarFade; easing.type: Easing.OutQuint }
        }
    }

    HoverHandler { id: hoverHandler; enabled: root.interactive }
    TapHandler {
        id: tapHandler
        enabled: root.interactive
        onTapped: root.activate()
    }

    function restartFlash() {
        if (!root.interactive || MotionTokens.reducedMotion) {
            flashAnimation.stop()
            flashOverlay.opacity = 0
            return
        }
        flashAnimation.restart()
    }

    function activate() {
        if (!root.interactive)
            return
        root.forceActiveFocus()
        root.restartFlash()
        root.activated()
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

    Connections {
        target: MotionTokens
        function onReducedMotionChanged() {
            if (MotionTokens.reducedMotion)
                root.restartFlash()
        }
    }

    Keys.onPressed: event => {
        if (!root.interactive)
            return
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            root.activate()
            event.accepted = true
        } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Right) {
            root.moveRequested(event.key === Qt.Key_Right ? 1 : -1)
            event.accepted = true
        }
    }
}