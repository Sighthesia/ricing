import QtQuick
import QtQuick.Effects
import "../../services" as Services

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

    // ONE column of peer entries. The three mode filters and the control-center
    // view are the same KIND of thing to the user - each one changes what this
    // page's content area shows - so they share a single list, a single accent
    // indicator and a single row arithmetic. Nothing here partitions by entry
    // kind: a `section` field, if a caller ever adds one, is data the rail does
    // not read, because a second band would be a second layout for a difference
    // the content area already shows.
    function selectedIndex() {
        for (var i = 0; i < entries.length; i++)
            if (entries[i].id === selected)
                return i
        return -1
    }

    color: LazerTheme.settingsRail

    // Move one shared accent strip between category entries exactly like the
    // settings sidebar does, wake included — NavItems render transparently
    // under it.
    TrailIndicator {
        id: selectionIndicator
        z: 2
        crossAxis: 10 + 4 + 5 * root.expansionProgress
        markLength: 24
        markThickness: 4
        markRadius: 2
        markColor: LazerTheme.settingsAccent
        // One strip, two bands: whichever owns the selection places it, and the
        // anchor is a real y rather than a row number so a footer selection
        // does not inherit the primary column's top-down arithmetic. A CENTRE,
        // not a top edge — the mark owns its own length, because that length is
        // the wake and a host that subtracted it would subtract the wake too.
        targetCenter: root.selectedIndex() >= 0
            ? root.railTop + root.selectedIndex() * (root.itemHeight + root.itemSpacing)
                + root.itemHeight / 2
            : root.railTop + root.itemHeight / 2
        targetKey: String(root.selected)
        targetValid: root.selectedIndex() >= 0
        visible: root.selectedIndex() >= 0

        Behavior on crossAxis {
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
    // Sized like a category chip (26px tall, 4px radius) and inset like the
    // nav column above it, so it reads as one more rail element rather than
    // a separate bar.
    Item {
        id: collapseButton
        x: 10
        y: root.height - height - 8
        width: Math.max(0, root.width - 20)
        height: 26
        Accessible.role: Accessible.Button
        Accessible.name: root.expanded ? Services.Tr.q("settings.collapseSidebar") : Services.Tr.q("settings.expandSidebar")

        scale: collapsePress.pressed ? MotionTokens.pressScale : 1
        Behavior on scale { enabled: !MotionTokens.reducedMotion; NumberAnimation { duration: MotionTokens.fast } }

        Rectangle {
            anchors.fill: parent
            radius: 4
            color: collapseHover.hovered ? LazerTheme.settingsRowHover : "transparent"
            Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
        }

        Rectangle {
            id: collapseFlashOverlay
            z: 1
            anchors.fill: parent
            radius: 4
            color: LazerTheme.textPrimary
            opacity: 0
            enabled: false
        }

        Image {
            id: collapseIcon
            anchors.centerIn: parent
            width: 16
            height: 16
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
