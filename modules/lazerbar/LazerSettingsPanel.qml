import QtQuick
import "LazerSettingsLogic.js" as Logic

// Keep the settings shell stable while category content cross-fades in place.
Item {
    id: root

    property var appearanceSettings: null
    property var barSettings: null
    property var notificationSettings: null
    property var saveCallback: null
    property var wallpaperService: null
    property bool interactive: true
    property int selectedCategory: 0
    readonly property real railWidth: Logic.navigationWidth(width)
    readonly property int categoryTransitionDuration: 160
    readonly property int indicatorCount: 1
    readonly property int contentTop: 64
    signal escapeRequested
    property alias appearancePage: appearancePage
    property alias barPage: barPage
    property alias notificationPage: notificationPage
    property alias appearanceNav: appearanceNav
    property alias barNav: barNav
    property alias notificationNav: notificationNav

    enabled: root.interactive
    focus: root.interactive
    activeFocusOnTab: root.interactive

    function selectCategory(index) {
        if (!root.interactive)
            return
        var next = Math.max(0, Math.min(2, Number(index)))
        if (next === root.selectedCategory)
            return
        var direction = Logic.categoryDirection(root.selectedCategory, next)
        root.selectedCategory = next
        setPageState(appearancePage, 0, direction)
        setPageState(barPage, 1, direction)
        setPageState(notificationPage, 2, direction)
    }

    function setPageState(page, index, direction) {
        var active = index === root.selectedCategory
        page.enabled = active && root.interactive
        page.activeFocusOnTab = page.enabled
        page.opacity = active ? 1 : 0
        if (active) {
            page.x = 0
        } else {
            page.x = MotionTokens.reducedMotion ? 0
                                                : (direction === 0 ? 0 : (index < root.selectedCategory ? -8 : 8))
        }
    }

    Component.onCompleted: {
        setPageState(appearancePage, 0, 0)
        setPageState(barPage, 1, 0)
        setPageState(notificationPage, 2, 0)
    }

    // Draw the glass panel body behind the persistent rail and viewport.
    Rectangle {
        anchors.fill: parent
        radius: LazerTheme.settingsRadius
        color: LazerTheme.settingsPanel
        border.width: 1
        border.color: LazerTheme.settingsPanelBorder
    }

    // Provide a compact header with a fixed-size close affordance.
    Item {
        id: header
        x: root.railWidth
        width: root.width - root.railWidth
        height: root.contentTop

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            text: ["外观", "顶部栏", "通知"][root.selectedCategory]
            color: LazerTheme.textPrimary
            font.pixelSize: 20
        }

        // Use a familiar fixed-size close button while keeping the panel dependency-free.
        Rectangle {
            id: closeButton
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            width: 32
            height: 32
            radius: 16
            color: closeMouse.containsMouse ? LazerTheme.settingsRowHover : "transparent"
            Text { anchors.centerIn: parent; text: "×"; color: LazerTheme.textPrimary; font.pixelSize: 22 }
            MouseArea { id: closeMouse; anchors.fill: parent; enabled: root.interactive; hoverEnabled: true; onClicked: root.escapeRequested() }
        }
    }

    // Keep all category controls mounted under one visual viewport.
    Item {
        id: viewport
        x: root.railWidth
        y: root.contentTop
        width: root.width - root.railWidth
        height: root.height - root.contentTop
        clip: true

        // Persist the appearance page so its scroll position survives navigation.
        LazerSettingsAppearance {
            id: appearancePage
            width: viewport.width
            height: viewport.height
            settingsObject: root.appearanceSettings
            saveCallback: root.saveCallback
            wallpaperService: root.wallpaperService
            opacity: 0
            Behavior on opacity { NumberAnimation { duration: root.categoryTransitionDuration; easing.type: Easing.OutCubic } }
            Behavior on x { NumberAnimation { duration: root.categoryTransitionDuration; easing.type: Easing.OutCubic } }
        }

        // Persist the bar page so its scroll position survives navigation.
        LazerSettingsBar {
            id: barPage
            width: viewport.width
            height: viewport.height
            settingsObject: root.barSettings
            saveCallback: root.saveCallback
            opacity: 0
            Behavior on opacity { NumberAnimation { duration: root.categoryTransitionDuration; easing.type: Easing.OutCubic } }
            Behavior on x { NumberAnimation { duration: root.categoryTransitionDuration; easing.type: Easing.OutCubic } }
        }

        // Persist the notification page so its scroll position survives navigation.
        LazerSettingsNotifications {
            id: notificationPage
            width: viewport.width
            height: viewport.height
            settingsObject: root.notificationSettings
            saveCallback: root.saveCallback
            opacity: 0
            Behavior on opacity { NumberAnimation { duration: root.categoryTransitionDuration; easing.type: Easing.OutCubic } }
            Behavior on x { NumberAnimation { duration: root.categoryTransitionDuration; easing.type: Easing.OutCubic } }
        }
    }

    // Present the single shared pink selection indicator beside the active item.
    Rectangle {
        id: indicator
        x: 6
        y: root.contentTop + 10 + root.selectedCategory * 48
        width: 4
        height: 24
        radius: 2
        color: LazerTheme.osuPink
        Behavior on y { NumberAnimation { duration: root.categoryTransitionDuration; easing.type: Easing.OutCubic } }
    }

    // Host the three persistent category controls in the navigation rail.
    Column {
        id: rail
        x: 10
        y: root.contentTop + 4
        width: root.railWidth - 20
        spacing: 4

        LazerSettingsNavItem { id: appearanceNav; width: rail.width; label: "外观"; index: 0; selected: root.selectedCategory === 0; interactive: root.interactive; onActivated: root.selectCategory(index) }
        LazerSettingsNavItem { id: barNav; width: rail.width; label: "顶部栏"; index: 1; selected: root.selectedCategory === 1; interactive: root.interactive; onActivated: root.selectCategory(index) }
        LazerSettingsNavItem { id: notificationNav; width: rail.width; label: "通知"; index: 2; selected: root.selectedCategory === 2; interactive: root.interactive; onActivated: root.selectCategory(index) }
    }

    Keys.onPressed: event => {
        if (!root.interactive)
            return
        if (event.key === Qt.Key_Up || event.key === Qt.Key_Down) {
            root.selectCategory(root.selectedCategory + (event.key === Qt.Key_Down ? 1 : -1))
            event.accepted = true
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.selectCategory(root.selectedCategory)
            event.accepted = true
        } else if (event.key === Qt.Key_Escape) {
            root.escapeRequested()
            event.accepted = true
        }
    }

    onInteractiveChanged: {
        appearancePage.enabled = interactive && selectedCategory === 0
        barPage.enabled = interactive && selectedCategory === 1
        notificationPage.enabled = interactive && selectedCategory === 2
    }
    onSelectedCategoryChanged: {
        if (MotionTokens.reducedMotion) {
            appearancePage.x = 0
            barPage.x = 0
            notificationPage.x = 0
        }
    }
}
