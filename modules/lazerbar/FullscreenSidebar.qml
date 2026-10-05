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

    // Entries partition the rail by KIND, not by position: a `footer` entry is
    // an action that leaves the rail's own section (jumping to another page),
    // while a primary entry is a filter of what this page shows. They share one
    // rail and one accent indicator, and a hairline separates them, so the
    // difference reads without a second component or a second column.
    function isFooterEntry(entry) {
        return entry !== undefined && entry !== null
                && String(entry.section || "") === "footer"
    }

    readonly property var primaryEntries: {
        var out = []
        for (var i = 0; i < entries.length; i++)
            if (!isFooterEntry(entries[i]))
                out.push(entries[i])
        return out
    }

    readonly property var footerEntries: {
        var out = []
        for (var i = 0; i < entries.length; i++)
            if (isFooterEntry(entries[i]))
                out.push(entries[i])
        return out
    }

    readonly property bool hasFooter: footerEntries.length > 0

    // Index of `selected` WITHIN primaryEntries, or -1. The indicator asks
    // this first: a selected footer entry must not move the strip up into the
    // primary column, where the y formula would place it on the wrong row.
    function selectedIndex() {
        for (var i = 0; i < primaryEntries.length; i++)
            if (primaryEntries[i].id === selected)
                return i
        return -1
    }

    // The same lookup in the footer band, or -1 when nothing there is selected.
    function selectedFooterIndex() {
        for (var i = 0; i < footerEntries.length; i++)
            if (footerEntries[i].id === selected)
                return i
        return -1
    }

    // True while either band owns the selection, so the strip stays visible
    // across the whole rail instead of blinking out between the two.
    readonly property bool anySelected: selectedIndex() >= 0 || selectedFooterIndex() >= 0

    color: LazerTheme.settingsRail

    // Move one shared accent strip between category entries exactly like the
    // settings sidebar does; NavItems render transparently under it.
    Rectangle {
        id: selectionIndicator
        z: 2
        x: 10 + 4 + 5 * root.expansionProgress
        // One strip, two bands: whichever owns the selection places it, and the
        // anchor is a real y rather than a row number so a footer selection does
        // not inherit the primary column's top-down arithmetic.
        y: root.selectedIndex() >= 0
            ? root.railTop + root.selectedIndex() * (root.itemHeight + root.itemSpacing)
                + root.itemHeight / 2 - height / 2
            : footerRail.y + root.selectedFooterIndex() * (root.itemHeight + root.itemSpacing)
                + root.itemHeight / 2 - height / 2
        visible: root.anySelected
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
            model: root.primaryEntries

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

    // Footer band: the rail's own actions, stacked above the collapse toggle
    // and set apart by a hairline so "filter this page" and "go somewhere else"
    // are not read as one list. Anchored to the bottom, so a rail with a short
    // primary column keeps both bands on their own edges.
    Column {
        id: footerRail
        visible: root.hasFooter
        anchors.bottom: collapseButton.top
        anchors.bottomMargin: 8
        x: 10
        width: Math.max(0, root.width - 20)
        spacing: root.itemSpacing

        // Section hairline. Sharp language: a 1px rule, never a rounded
        // container around the footer.
        Rectangle {
            width: parent.width
            height: 1
            color: LazerTheme.divider
            visible: root.hasFooter
        }

        Repeater {
            model: root.footerEntries

            delegate: LazerSettingsNavItem {
                required property var modelData
                required property int index
                width: footerRail.width
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
