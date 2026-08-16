import QtQuick
import QtQuick.Effects

// Represent one keyboard-accessible settings category in the sidebar rail.
Item {
    id: root

    property string label: ""
    property string iconSource: ""
    property bool selected: false
    property bool interactive: true
    property bool expanded: true
    property real appearOpacity: 1
    property string category: "appearance"
    signal activated
    signal moveRequested(int direction)

    implicitWidth: 184
    implicitHeight: 46
    enabled: root.interactive
    activeFocusOnTab: root.interactive
    opacity: root.appearOpacity
    Accessible.role: Accessible.ListItem
    Accessible.name: root.label

    // Paint the selected category surface without owning the shared indicator.
    Rectangle {
        anchors.fill: parent
        anchors.margins: 2
        radius: 10
        color: hoverHandler.hovered ? LazerTheme.settingsRowHover : "transparent"
        Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
    }

    readonly property alias selectionIndicatorItem: selectionIndicator
    readonly property alias labelItem: labelText

    // Show the category icon at osu's left margin, centered when contracted.
    Image {
        id: iconImage
        visible: root.iconSource.length > 0
        x: root.expanded ? 25 : Math.max(0, (root.width - width) / 2)
        anchors.verticalCenter: parent.verticalCenter
        width: 20
        height: 20
        source: root.iconSource
        fillMode: Image.PreserveAspectFit
        Behavior on x { enabled: !MotionTokens.reducedMotion; NumberAnimation { duration: MotionTokens.settingsSidebarCollapse; easing.type: Easing.OutQuint } }
        scale: tapHandler.pressed ? MotionTokens.pressScale : 1
        Behavior on scale { enabled: !MotionTokens.reducedMotion; NumberAnimation { duration: MotionTokens.fast } }
    }

    // Colorize the monochrome icon with the active or muted text tone.
    MultiEffect {
        anchors.fill: iconImage
        source: iconImage
        visible: iconImage.visible
        colorization: 1
        colorizationColor: root.selected ? LazerTheme.textPrimary : (hoverHandler.hovered ? LazerTheme.textPrimary : LazerTheme.settingsNavInactive)

        Behavior on colorizationColor { ColorAnimation { duration: MotionTokens.fast } }
    }

    // Keep category text visible only while the sidebar is expanded, fading
    // with the collapse transition instead of hard-cutting.
    Text {
        id: labelText
        visible: root.expanded || opacity > 0
        opacity: root.expanded ? 1 : 0
        Behavior on opacity {
            enabled: !MotionTokens.reducedMotion
            NumberAnimation { duration: MotionTokens.settingsSidebarCollapse; easing.type: Easing.OutQuint }
        }
        x: 60
        anchors.verticalCenter: parent.verticalCenter
        text: root.label
        color: root.selected ? LazerTheme.textPrimary : (hoverHandler.hovered ? LazerTheme.textPrimary : LazerTheme.settingsNavInactive)
        font.pixelSize: 14
        Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
    }

    // Show an accent pill only for the selected category.
    Rectangle {
        id: selectionIndicator
        x: 9
        anchors.verticalCenter: parent.verticalCenter
        width: 4
        height: root.selected ? 24 : 0
        radius: 2
        color: LazerTheme.settingsAccent
        opacity: root.selected ? 1 : 0

        Behavior on height {
            enabled: !MotionTokens.reducedMotion
            NumberAnimation { duration: MotionTokens.settingsSidebarCollapse; easing.type: Easing.OutElastic; easing.amplitude: 1; easing.period: 0.5 }
        }
        Behavior on opacity {
            enabled: !MotionTokens.reducedMotion
            NumberAnimation { duration: MotionTokens.settingsSidebarFade; easing.type: Easing.OutQuint }
        }
    }

    // Capture pointer hover and activation without a competing visual parent.
    HoverHandler { id: hoverHandler; enabled: root.interactive }
    TapHandler {
        id: tapHandler
        enabled: root.interactive
        onTapped: { root.forceActiveFocus(); root.activated() }
    }

    Keys.onPressed: event => {
        if (!root.interactive)
            return
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            root.activated()
            event.accepted = true
        } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Down) {
            root.moveRequested(event.key === Qt.Key_Down ? 1 : -1)
            event.accepted = true
        }
    }
}
