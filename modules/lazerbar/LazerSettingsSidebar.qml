import QtQuick
import QtQuick.Effects
import "LazerSettingsLogic.js" as Logic

// Own the settings sidebar rail: collapse toggle, staggered nav, back entry.
Item {
    id: root

    property bool expanded: true
    property real expansionProgress: expanded ? 1 : 0
    property bool interactive: true
    property bool sessionActive: false
    property int selectedIndex: 0
    property var labels: ["外观", "顶部栏", "通知"]
    property var icons: ["icons/settings.svg", "icons/podium.svg", "icons/bell.svg"]
    readonly property bool showLabels: root.expanded && root.width >= Logic.sidebarContractedWidth + 60
    property alias collapseButton: collapseButton
    property alias backButton: backButton
    property alias collapseSurfaceItem: collapseSurface
    property alias collapseIconItem: collapseIcon
    property alias backSurfaceItem: backSurface
    property alias backIconItem: backIcon
    property alias appearanceNav: appearanceNav
    property alias barNav: barNav
    property alias notificationNav: notificationNav

    signal categorySelected(int index)
    signal moveRequested(int direction)
    signal collapseToggleRequested()
    signal closeRequested()

    // Restart the per-item appear stagger or cancel it on session teardown.
    function beginSession() {
        _staggerToken += 1
        sessionActive = true
        if (MotionTokens.reducedMotion) {
            item0Stagger.stop(); item1Stagger.stop(); item2Stagger.stop()
            appearanceNav.appearOpacity = 1
            barNav.appearOpacity = 1
            notificationNav.appearOpacity = 1
            return
        }
        item0Stagger.restart()
        item1Stagger.restart()
        item2Stagger.restart()
    }

    function endSession() {
        _staggerToken += 1
        sessionActive = false
        item0Stagger.stop(); item1Stagger.stop(); item2Stagger.stop()
        appearanceNav.appearOpacity = 0
        barNav.appearOpacity = 0
        notificationNav.appearOpacity = 0
    }

    property int _staggerToken: 0

    // Paint the darker sidebar surface behind every nav element.
    Rectangle {
        anchors.fill: parent
        color: LazerTheme.settingsRail
    }

    // Provide the manual collapse toggle in the bottom action slot.
    Item {
        id: collapseButton
        x: 0
        y: root.height - height - 12
        width: root.width
        height: 40
        enabled: root.interactive
        activeFocusOnTab: root.interactive
        Accessible.role: Accessible.Button
        Accessible.name: root.expanded ? "收起侧栏" : "展开侧栏"

        scale: collapsePress.pressed ? MotionTokens.pressScale : 1
        Behavior on scale { enabled: !MotionTokens.reducedMotion; NumberAnimation { duration: MotionTokens.fast } }

        Rectangle {
            id: collapseSurface
            anchors.fill: parent
            radius: 12
            color: collapseHover.hovered ? LazerTheme.settingsRowHover : "transparent"
            border.width: 0
            border.color: "transparent"
            Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
        }

        Image {
            id: collapseIcon
            anchors.centerIn: collapseSurface
            width: 20
            height: 20
            source: root.expanded ? "icons/chevron-left.svg" : "icons/chevron-right.svg"
            fillMode: Image.PreserveAspectFit
        }
        MultiEffect {
            anchors.fill: collapseIcon
            source: collapseIcon
            visible: collapseIcon.visible
            colorization: 1
            colorizationColor: collapseHover.hovered ? LazerTheme.textPrimary : LazerTheme.textMuted
            Behavior on colorizationColor { ColorAnimation { duration: MotionTokens.fast } }
        }

        HoverHandler { id: collapseHover; enabled: collapseButton.enabled }
        TapHandler {
            id: collapsePress
            enabled: collapseButton.enabled
            onTapped: { collapseButton.forceActiveFocus(); root.collapseToggleRequested() }
        }
        Keys.onPressed: event => {
            if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) && collapseButton.enabled) {
                root.collapseToggleRequested()
                event.accepted = true
            }
        }
    }

    // List the three persistent category entries with osu's 40ms stagger.
    Column {
        id: rail
        x: 10
        y: 62
        width: Math.max(0, root.width - 20)
        spacing: 4

        LazerSettingsNavItem {
            id: appearanceNav
            width: rail.width
            label: root.labels[0]
            iconSource: root.icons[0]
            expanded: root.expanded
            selected: root.selectedIndex === 0
            interactive: root.interactive
            expansionProgress: root.expansionProgress
            appearOpacity: 0
            onActivated: root.categorySelected(0)
            onMoveRequested: direction => root.moveRequested(direction)
        }
        LazerSettingsNavItem {
            id: barNav
            width: rail.width
            label: root.labels[1]
            iconSource: root.icons[1]
            expanded: root.expanded
            selected: root.selectedIndex === 1
            interactive: root.interactive
            expansionProgress: root.expansionProgress
            appearOpacity: 0
            onActivated: root.categorySelected(1)
            onMoveRequested: direction => root.moveRequested(direction)
        }
        LazerSettingsNavItem {
            id: notificationNav
            width: rail.width
            label: root.labels[2]
            iconSource: root.icons[2]
            expanded: root.expanded
            selected: root.selectedIndex === 2
            interactive: root.interactive
            expansionProgress: root.expansionProgress
            appearOpacity: 0
            onActivated: root.categorySelected(2)
            onMoveRequested: direction => root.moveRequested(direction)
        }
    }

    // Provide the back affordance in the top action slot.
    Item {
        id: backButton
        x: 0
        y: 10
        width: root.width
        height: 40
        enabled: root.interactive
        activeFocusOnTab: root.interactive
        Accessible.role: Accessible.Button
        Accessible.name: "返回"

        scale: backPress.pressed ? MotionTokens.pressScale : 1
        Behavior on scale { enabled: !MotionTokens.reducedMotion; NumberAnimation { duration: MotionTokens.fast } }

        Rectangle {
            id: backSurface
            anchors.fill: parent
            anchors.margins: 2
            radius: 12
            color: backHover.hovered ? LazerTheme.settingsRowHover : "transparent"
            border.width: 0
            border.color: "transparent"
            Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
        }

        Image {
            id: backIcon
            anchors.centerIn: backSurface
            width: 20
            height: 20
            source: "icons/sidebar-return.svg"
            fillMode: Image.PreserveAspectFit
        }
        MultiEffect {
            anchors.fill: backIcon
            source: backIcon
            visible: backIcon.visible
            colorization: 1
            colorizationColor: backHover.hovered ? LazerTheme.textPrimary : LazerTheme.textMuted
            Behavior on colorizationColor { ColorAnimation { duration: MotionTokens.fast } }
        }
        HoverHandler { id: backHover; enabled: backButton.enabled }
        TapHandler {
            id: backPress
            enabled: backButton.enabled
            onTapped: { backButton.forceActiveFocus(); root.closeRequested() }
        }
        Keys.onPressed: event => {
            if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) && backButton.enabled) {
                root.closeRequested()
                event.accepted = true
            }
        }
    }

    // Reveal each nav entry with osu's per-item 40ms delay and 500ms fade.
    SequentialAnimation {
        id: item0Stagger
        running: false
        PauseAnimation { duration: 0 }
        NumberAnimation { target: appearanceNav; property: "appearOpacity"; from: 0; to: 1; duration: MotionTokens.settingsSidebarFade; easing.type: Easing.OutQuint }
    }
    SequentialAnimation {
        id: item1Stagger
        running: false
        PauseAnimation { duration: MotionTokens.settingsSidebarStagger }
        NumberAnimation { target: barNav; property: "appearOpacity"; from: 0; to: 1; duration: MotionTokens.settingsSidebarFade; easing.type: Easing.OutQuint }
    }
    SequentialAnimation {
        id: item2Stagger
        running: false
        PauseAnimation { duration: MotionTokens.settingsSidebarStagger * 2 }
        NumberAnimation { target: notificationNav; property: "appearOpacity"; from: 0; to: 1; duration: MotionTokens.settingsSidebarFade; easing.type: Easing.OutQuint }
    }
}
