import QtQuick
import QtQuick.Effects

// Own the launcher navigation rail using the settings-sidebar contract:
// collapsible width, icon nav items with staggered appear, one shared accent
// indicator moved between entries, and a bottom collapse toggle.
Rectangle {
    id: root

    property var entries: []
    property string selected: ""
    property bool expanded: true
    readonly property real expansionProgress: expanded ? 1 : 0
    signal selectedChangedByUser(string value)
    signal collapseToggled()

    // Rail geometry mirrors the settings sidebar: padded column of 46px items.
    readonly property int itemSpacing: 4
    readonly property int railTop: 12
    readonly property int itemHeight: 46
    readonly property bool showLabels: expanded && width >= 130
    property alias selectionIndicatorItem: selectionIndicator

    function selectedIndex() {
        for (var i = 0; i < entries.length; i++)
            if (entries[i].id === selected)
                return i
        return -1
    }

    color: LazerTheme.settingsRail

    // Move one shared accent strip between category entries exactly like the
    // settings sidebar does; NavItems render transparently under it.
    Rectangle {
        id: selectionIndicator
        z: 2
        x: 10 + 4 + 5 * root.expansionProgress
        y: root.railTop + root.selectedIndex() * (root.itemHeight + root.itemSpacing) + root.itemHeight / 2 - height / 2
        visible: root.selectedIndex() >= 0
        width: 4
        height: 24
        radius: 2
        color: LazerTheme.settingsAccent

        Behavior on x {
            enabled: !MotionTokens.reducedMotion
            NumberAnimation { duration: MotionTokens.settingsSidebarFade; easing.type: Easing.OutQuint }
        }
        Behavior on y {
            enabled: !MotionTokens.reducedMotion
            NumberAnimation { duration: MotionTokens.settingsSidebarFade; easing.type: Easing.OutQuint }
        }
    }

    Column {
        id: rail
        x: 10
        y: root.railTop
        width: Math.max(0, root.width - 20)
        spacing: root.itemSpacing

        Repeater {
            model: root.entries

            delegate: LazerSettingsNavItem {
                required property var modelData
                required property int index
                width: rail.width
                label: modelData.label
                iconSource: modelData.icon || ""
                expanded: root.expanded
                expansionProgress: root.expansionProgress
                selected: root.selected === modelData.id
                sharedSelectionIndicator: root.selectionIndicatorItem
                onActivated: root.selectedChangedByUser(modelData.id)
            }
        }
    }

    // Bottom collapse toggle carrying the settings sidebar's flash contract.
    Item {
        id: collapseButton
        x: 0
        y: root.height - height - 8
        width: root.width
        height: 40
        Accessible.role: Accessible.Button
        Accessible.name: root.expanded ? "收起侧栏" : "展开侧栏"

        scale: collapsePress.pressed ? MotionTokens.pressScale : 1
        Behavior on scale { enabled: !MotionTokens.reducedMotion; NumberAnimation { duration: MotionTokens.fast } }

        Rectangle {
            anchors.fill: parent
            radius: 12
            color: collapseHover.hovered ? LazerTheme.settingsRowHover : "transparent"
            Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
        }

        Rectangle {
            id: collapseFlashOverlay
            z: 1
            anchors.fill: parent
            radius: 12
            color: LazerTheme.textPrimary
            opacity: 0
            enabled: false
        }

        Image {
            id: collapseIcon
            anchors.centerIn: parent
            width: 20
            height: 20
            source: root.expanded ? "icons/chevron-left.svg" : "icons/chevron-right.svg"
            fillMode: Image.PreserveAspectFit
        }
        MultiEffect {
            anchors.fill: collapseIcon
            source: collapseIcon
            colorization: 1
            colorizationColor: collapseHover.hovered ? LazerTheme.textPrimary : LazerTheme.textMuted
            Behavior on colorizationColor { ColorAnimation { duration: MotionTokens.fast } }
        }

        HoverHandler { id: collapseHover }
        TapHandler { id: collapsePress; onTapped: collapseButton.activate() }

        function activate() {
            collapseButton.forceActiveFocus()
            if (!MotionTokens.reducedMotion)
                collapseFlashAnimation.restart()
            root.collapseToggled()
        }

        NumberAnimation {
            id: collapseFlashAnimation
            target: collapseFlashOverlay
            property: "opacity"
            from: MotionTokens.clickFlashOpacity
            to: 0
            duration: MotionTokens.clickFlashDuration
            easing.type: MotionTokens.clickFlashEasing
        }
    }
}
