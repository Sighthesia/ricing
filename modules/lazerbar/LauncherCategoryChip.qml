import QtQuick

// One category chip in the launcher's filter bar: a compact label + count
// pill carrying the settings-panel interaction contract - hover surface
// swap, an accent strip for the active chip, press scale, the shared click
// flash, and keyboard activation with arrow browsing between chips.
//
// Chips whose category currently holds no match stay in place (dimmed, not
// focusable) instead of disappearing: the bar must not reflow while the
// user is typing.
Item {
    id: root

    property string label: ""
    property int count: 0
    property bool selected: false
    // Empty categories keep their slot but refuse activation; the active chip
    // stays live so it can always be switched back off.
    readonly property bool available: count > 0
    readonly property bool interactive: available || selected

    signal activated()
    signal moveRequested(int direction)

    readonly property bool flashActive: flash.flashActive
    readonly property Item flashOverlayItem: flash.flashOverlayItem
    readonly property Animation flashAnimationItem: flash.flashAnimationItem
    readonly property alias labelItem: labelText
    readonly property alias countItem: countText
    readonly property alias indicatorItem: indicator

    implicitHeight: 26
    implicitWidth: content.implicitWidth + 20
    // Small-radius detail surface, kept on the root so the flash overlay
    // matches without reaching for a non-existent property on the parent.
    readonly property int chipRadius: 4
    activeFocusOnTab: root.interactive
    // Disabled chips dim as a whole so the dimmed state covers label and
    // count together, matching the settings panel's disabled treatment.
    opacity: root.interactive ? 1 : LazerTheme.settingsDisabledAlpha
    Behavior on opacity {
        enabled: !MotionTokens.reducedMotion
        NumberAnimation { duration: MotionTokens.fast; easing.type: Easing.OutQuint }
    }
    scale: chipPress.pressed ? MotionTokens.pressScale : 1
    Behavior on scale {
        enabled: !MotionTokens.reducedMotion
        NumberAnimation { duration: MotionTokens.fast; easing.type: Easing.OutQuint }
    }
    Accessible.role: Accessible.Button
    Accessible.name: root.count > 0 ? root.label + " " + root.count : root.label

    // Chip surface: selected tint outranks the hover swap; press feedback is
    // the scale above, not a third color stop.
    Rectangle {
        anchors.fill: parent
        radius: root.chipRadius
        color: root.selected ? LazerTheme.settingsSelected
             : (chipHover.hovered ? LazerTheme.settingsRowHover : "transparent")
        Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
    }

    // Selected state reads as a sharp accent band under the label, the same
    // rectangle-strip language the settings sidebar indicator uses.
    Rectangle {
        id: indicator
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.max(0, parent.width - 14)
        height: 2
        radius: 0
        color: LazerTheme.settingsAccent
        opacity: root.selected ? 1 : 0
        Behavior on opacity {
            enabled: !MotionTokens.reducedMotion
            NumberAnimation { duration: MotionTokens.fast; easing.type: Easing.OutQuint }
        }
    }

    // Label plus live match count; the count is what tells a chip apart from
    // a plain label when several categories are empty.
    Row {
        id: content
        anchors.centerIn: parent
        spacing: 5

        Text {
            id: labelText
            text: root.label
            color: root.selected || chipHover.hovered
                   ? LazerTheme.textPrimary : LazerTheme.settingsNavInactive
            font.pixelSize: 12
            font.weight: root.selected ? Font.DemiBold : Font.Normal
            Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
        }

        Text {
            id: countText
            text: root.count > 0 ? root.count : ""
            color: LazerTheme.textMuted
            font.pixelSize: 10
        }
    }

    // Click-flash overlay above content, following the shared recipe.
    ClickFlash {
        id: flash
        z: 1
        anchors.fill: parent
        radius: root.chipRadius
    }


    function restartFlash() {
        flash.restart()
    }

    function activate() {
        if (!root.interactive)
            return
        root.restartFlash()
        root.activated()
    }

    HoverHandler {
        id: chipHover
        enabled: root.interactive
    }
    TapHandler {
        id: chipPress
        enabled: root.interactive
        onTapped: root.activate()
    }

    Keys.onPressed: event => {
        if (!root.interactive)
            return
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter
                || event.key === Qt.Key_Space) {
            root.activate()
            event.accepted = true
        } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Right) {
            root.moveRequested(event.key === Qt.Key_Right ? 1 : -1)
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