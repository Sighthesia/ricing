import QtQuick
import QtQuick.Effects
import "LazerSettingsLogic.js" as Logic
import "../../services" as Services

// Own the settings sidebar rail: collapse toggle, staggered nav, back entry.
Item {
    id: root

    property bool expanded: true
    property real expansionProgress: expanded ? 1 : 0
    property bool interactive: true
    property bool sessionActive: false
    property int selectedIndex: 0
    // Per-category search availability; an emptied category never highlights.
    property var categoryAvailable: [true, true, true]
    property var labels: [Services.Tr.q("settings.appearance"), Services.Tr.q("settings.bar"), Services.Tr.q("settings.notifications")]
    property var icons: ["icons/settings.svg", "icons/podium.svg", "icons/bell.svg"]
    readonly property bool showLabels: root.expanded && root.width >= Logic.sidebarContractedWidth + 60
    readonly property bool selectedAvailable: root.indexAvailable(root.selectedIndex)
    readonly property real indicatorY: 62 + root.selectedIndex * (46 + 4) + 23

    function indexAvailable(index) {
        return index >= 0 && index < root.categoryAvailable.length
                && root.categoryAvailable[index] !== false
    }
    property alias collapseButton: collapseButton
    property alias backButton: backButton
    property alias collapseSurfaceItem: collapseButton.surfaceItem
    property alias collapseIconItem: collapseButton.iconItem
    property alias backSurfaceItem: backButton.surfaceItem
    property alias backIconItem: backButton.iconItem
    property alias appearanceNav: appearanceNav
    property alias barNav: barNav
    property alias notificationNav: notificationNav
    property alias selectionIndicator: selectionIndicator

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

    // Move one shared accent strip between category entries, carrying the
    // workspace widget's dual-speed wake: the head runs `medium`/OutQuad to the
    // new category, the tail runs `slow * 2`/OutSine to the SAME target, and
    // the strip is drawn between them — so it stretches along the direction of
    // travel and contracts as the tail lands.
    TrailIndicator {
        id: selectionIndicator
        z: 2
        // Padding across the rail comes straight off `expansionProgress`, like
        // every other rail offset (nav icons, the selection pill). A Behavior
        // here would be a SECOND easing on top of the 300ms collapse already
        // animating that progress: the pill then sat still through the whole
        // collapse and only closed its inset after everything else had landed.
        crossAxis: 10 + 4 + 5 * root.expansionProgress
        markLength: 24
        markThickness: 4
        markRadius: 2
        markColor: LazerTheme.settingsAccent
        targetCenter: root.indicatorY
        targetKey: String(root.selectedIndex)
        targetValid: root.selectedAvailable
        opacity: root.sessionActive && root.selectedAvailable ? 1 : 0

        Behavior on opacity {
            enabled: !MotionTokens.reducedMotion
            NumberAnimation { duration: MotionTokens.settingsSidebarFade; easing.type: Easing.OutQuint }
        }
    }

    // Provide the manual collapse toggle in the bottom action slot. The whole
    // button - geometry, surface, flash, keyboard - is the shared rail control,
    // so the settings and launcher rails cannot drift apart again.
    RailActionButton {
        id: collapseButton
        x: 0
        y: root.height - height - 12
        width: root.width
        height: 40
        interactive: root.interactive
        accessibleName: root.expanded ? Services.Tr.q("settings.collapseSidebar") : Services.Tr.q("settings.expandSidebar")
        iconSource: root.expanded ? "icons/chevron-left.svg" : "icons/chevron-right.svg"
        onActivated: root.collapseToggleRequested()
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
            selected: root.selectedIndex === 0 && root.indexAvailable(0)
            interactive: root.interactive
            expansionProgress: root.expansionProgress
            sharedSelectionIndicator: root.selectionIndicator
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
            selected: root.selectedIndex === 1 && root.indexAvailable(1)
            interactive: root.interactive
            expansionProgress: root.expansionProgress
            sharedSelectionIndicator: root.selectionIndicator
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
            selected: root.selectedIndex === 2 && root.indexAvailable(2)
            interactive: root.interactive
            expansionProgress: root.expansionProgress
            sharedSelectionIndicator: root.selectionIndicator
            appearOpacity: 0
            onActivated: root.categorySelected(2)
            onMoveRequested: direction => root.moveRequested(direction)
        }
    }

    // Provide the back affordance in the top action slot - the same shared
    // rail control as the collapse toggle, so both ends of the rail agree.
    RailActionButton {
        id: backButton
        x: 0
        y: 10
        width: root.width
        height: 40
        interactive: root.interactive
        accessibleName: Services.Tr.q("settings.back")
        iconSource: "icons/close.svg"
        onActivated: root.closeRequested()
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
