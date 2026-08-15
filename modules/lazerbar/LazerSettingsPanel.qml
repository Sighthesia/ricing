import QtQuick
import "LazerSettingsLogic.js" as Logic

// Keep the settings shell stable while category content cross-fades in place.
Item {
    id: root

    // These inputs are owned by the host; navigation state is owned here.
    property var appearanceSettings: null
    property var barSettings: null
    property var notificationSettings: null
    property var saveCallback: null
    property var wallpaperService: null
    property bool interactive: true
    property string selectedCategory: "appearance"
    property real availableWidth: 1040
    property real availableHeight: 760
    readonly property int selectedIndex: categoryIndex(selectedCategory)
    readonly property int contentTransitionDirection: _transitionDirection
    readonly property real panelWidth: Logic.panelWidth(availableWidth)
    readonly property real panelHeight: Logic.panelHeight(availableHeight)
    readonly property real navigationWidth: Logic.navigationWidth(width)
    readonly property real railWidth: navigationWidth
    readonly property int categoryTransitionDuration: 160
    readonly property var contentTransitionEasing: MotionTokens.outSoft
    readonly property int indicatorCount: 1
    readonly property int contentTop: 64
    readonly property Item currentNav: [appearanceNav, barNav, notificationNav][selectedIndex]
    signal escapeRequested
    signal closeRequested
    signal categoryChanged(string category)
    property alias appearancePage: appearancePage
    property alias barPage: barPage
    property alias notificationPage: notificationPage
    property alias appearanceNav: appearanceNav
    property alias barNav: barNav
    property alias notificationNav: notificationNav
    property alias closeButton: closeButton
    property alias indicator: indicator

    implicitWidth: panelWidth
    implicitHeight: panelHeight
    enabled: root.interactive
    focus: root.interactive
    activeFocusOnTab: root.interactive

    property int _transitionDirection: 0
    property bool _syncingCategory: false
    property int _lastSelectedIndex: 0
    property bool transitionsEnabled: true
    property int transitionToken: 0

    function categoryIndex(category) {
        return category === "appearance" ? 0 : category === "bar" ? 1 : category === "notifications" ? 2 : -1
    }

    function categoryAt(index) {
        return ["appearance", "bar", "notifications"][Math.max(0, Math.min(2, index))]
    }

    function selectCategory(category) {
        if (!root.interactive || categoryIndex(category) < 0)
            return
        var nextIndex = categoryIndex(category)
        if (nextIndex === root.selectedIndex)
            return
        var previousIndex = root.selectedIndex
        _transitionDirection = Logic.categoryDirection(previousIndex, nextIndex)
        root.selectedCategory = category
        categoryChanged(category)
    }

    // Move navigation focus with the newly selected category, not the old item.
    function moveNavigation(direction) {
        if (!root.interactive)
            return
        root.selectCategory(root.categoryAt(root.selectedIndex + Number(direction)))
        Qt.callLater(function() { root.focusNavigation() })
    }

    // Keep every persistent page synchronized through one state transition path.
    function syncPages(previousIndex, nextIndex) {
        var direction = Logic.categoryDirection(previousIndex, nextIndex)
        _transitionDirection = direction
        transitionToken += 1
        var token = transitionToken
        var pages = [appearancePage, barPage, notificationPage]
        var incoming = pages[nextIndex]
        transitionsEnabled = false
        for (var i = 0; i < pages.length; i++) {
            pages[i].enabled = i === nextIndex && root.interactive
            pages[i].activeFocusOnTab = pages[i].enabled
        }
        if (incoming.opacity <= 0) {
            incoming.x = MotionTokens.reducedMotion ? 0 : direction * 8
            incoming.opacity = 0
        }
        Qt.callLater(function() {
            if (token !== root.transitionToken)
                return
            transitionsEnabled = !MotionTokens.reducedMotion
            for (var j = 0; j < pages.length; j++) {
                if (j === nextIndex) {
                    pages[j].x = 0
                    pages[j].opacity = 1
                } else if (j === previousIndex && pages[j].opacity > 0) {
                    pages[j].x = MotionTokens.reducedMotion ? 0 : -direction * 8
                    pages[j].opacity = 0
                } else {
                    pages[j].opacity = 0
                    if (MotionTokens.reducedMotion)
                        pages[j].x = 0
                }
            }
        })
    }

    function focusNavigation() {
        if (!root.interactive)
            return
        currentNav.forceActiveFocus()
    }

    function focusFirstControl() {
        if (!root.interactive)
            return
        if (currentNav)
            currentNav.forceActiveFocus()
        else
            root.forceActiveFocus()
    }

    function requestClose() {
        if (!root.interactive)
            return
        closeRequested()
        escapeRequested()
    }

    Component.onCompleted: syncPages(0, selectedIndex)

    onSelectedCategoryChanged: {
        if (_syncingCategory)
            return
        var normalized = categoryIndex(selectedCategory) >= 0 ? selectedCategory : "appearance"
        var previousIndex = _lastSelectedIndex
        if (normalized !== selectedCategory) {
            _syncingCategory = true
            selectedCategory = normalized
            _syncingCategory = false
        }
        var nextIndex = categoryIndex(normalized)
        syncPages(previousIndex, nextIndex)
        _lastSelectedIndex = nextIndex
    }

    onInteractiveChanged: syncPages(selectedIndex, selectedIndex)

    // Reduced motion must cancel any in-flight translation immediately.
    Connections {
        target: MotionTokens
        function onReducedMotionChanged() {
            transitionToken += 1
            transitionsEnabled = false
            if (MotionTokens.reducedMotion) {
                appearancePage.x = 0
                barPage.x = 0
                notificationPage.x = 0
                appearancePage.opacity = root.selectedIndex === 0 ? 1 : 0
                barPage.opacity = root.selectedIndex === 1 ? 1 : 0
                notificationPage.opacity = root.selectedIndex === 2 ? 1 : 0
                transitionsEnabled = false
            } else {
                transitionsEnabled = true
            }
        }
    }

    // Draw the glass panel body behind the persistent rail and viewport.
    Rectangle {
        anchors.fill: parent
        radius: LazerTheme.settingsRadius
        color: root.appearanceSettings
               ? Qt.rgba(root.appearanceSettings.colorScheme === "light" ? 0.95 : 0.114,
                         root.appearanceSettings.colorScheme === "light" ? 0.94 : 0.11,
                         root.appearanceSettings.colorScheme === "light" ? 0.96 : 0.133,
                         Math.max(0.35, Math.min(1, root.appearanceSettings.panelOpacity)))
               : LazerTheme.settingsPanel
        border.width: 1
        border.color: root.appearanceSettings
                ? Qt.rgba(root.appearanceSettings.colorScheme === "light" ? 0 : 1,
                          root.appearanceSettings.colorScheme === "light" ? 0 : 1,
                          root.appearanceSettings.colorScheme === "light" ? 0 : 1,
                          Math.max(0.08, root.appearanceSettings.glassHighlightIntensity
                                   * Math.max(1, root.appearanceSettings.glassHighlightWidth) * 0.125
                                   + root.appearanceSettings.glassGlowIntensity * 0.05))
                : LazerTheme.settingsPanelBorder

        Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
        Behavior on border.color { ColorAnimation { duration: MotionTokens.fast } }
    }

    // Provide a compact header with a keyboard-accessible close affordance.
    Item {
        id: header
        x: root.navigationWidth
        width: Math.max(0, root.width - root.navigationWidth)
        height: root.contentTop

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            text: ["外观", "顶部栏", "通知"][root.selectedIndex]
            color: LazerTheme.textPrimary
            font.pixelSize: 20
        }

        // Keep the close affordance fixed-size and independent of page layout.
        Item {
            id: closeButton
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            width: 32
            height: 32
            enabled: root.interactive
            activeFocusOnTab: root.interactive
            Accessible.role: Accessible.Button
            Accessible.name: "关闭"

            Rectangle {
                anchors.fill: parent
                radius: 16
                color: closeHover.hovered ? LazerTheme.settingsRowHover : "transparent"
            }
            Text { anchors.centerIn: parent; text: "×"; color: LazerTheme.textPrimary; font.pixelSize: 22 }
            HoverHandler { id: closeHover; enabled: closeButton.enabled }
            TapHandler {
                id: closeTap
                enabled: closeButton.enabled
                onTapped: { closeButton.forceActiveFocus(); root.requestClose() }
            }
            Keys.onPressed: event => {
                if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) && closeButton.enabled) {
                    root.requestClose()
                    event.accepted = true
                }
            }
        }
    }

    // Keep all category controls mounted under one visual viewport.
    Item {
        id: viewport
        x: root.navigationWidth
        y: root.contentTop
        width: Math.max(0, root.width - root.navigationWidth)
        height: Math.max(0, root.height - root.contentTop)
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
            Behavior on opacity { enabled: root.transitionsEnabled; NumberAnimation { duration: root.categoryTransitionDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: MotionTokens.outSoft } }
            Behavior on x { enabled: root.transitionsEnabled && !MotionTokens.reducedMotion; NumberAnimation { duration: root.categoryTransitionDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: MotionTokens.outSoft } }
        }

        // Persist the bar page so its scroll position survives navigation.
        LazerSettingsBar {
            id: barPage
            width: viewport.width
            height: viewport.height
            settingsObject: root.barSettings
            saveCallback: root.saveCallback
            opacity: 0
            Behavior on opacity { enabled: root.transitionsEnabled; NumberAnimation { duration: root.categoryTransitionDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: MotionTokens.outSoft } }
            Behavior on x { enabled: root.transitionsEnabled && !MotionTokens.reducedMotion; NumberAnimation { duration: root.categoryTransitionDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: MotionTokens.outSoft } }
        }

        // Persist the notification page so its scroll position survives navigation.
        LazerSettingsNotifications {
            id: notificationPage
            width: viewport.width
            height: viewport.height
            settingsObject: root.notificationSettings
            saveCallback: root.saveCallback
            opacity: 0
            Behavior on opacity { enabled: root.transitionsEnabled; NumberAnimation { duration: root.categoryTransitionDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: MotionTokens.outSoft } }
            Behavior on x { enabled: root.transitionsEnabled && !MotionTokens.reducedMotion; NumberAnimation { duration: root.categoryTransitionDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: MotionTokens.outSoft } }
        }
    }

    // Present the single shared pink selection indicator beside the active item.
    Rectangle {
        id: indicator
        x: 6
        y: root.contentTop + 14 + root.selectedIndex * 48
        width: 4
        height: 24
        radius: 2
        color: LazerTheme.osuPink
        Behavior on y { enabled: root.transitionsEnabled && !MotionTokens.reducedMotion; NumberAnimation { duration: root.categoryTransitionDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: MotionTokens.outSoft } }
    }

    // Host the three persistent category controls in the navigation rail.
    Column {
        id: rail
        x: 10
        y: root.contentTop + 4
        width: Math.max(0, root.navigationWidth - 20)
        spacing: 4

        LazerSettingsNavItem { id: appearanceNav; width: rail.width; label: "外观"; category: "appearance"; selected: root.selectedIndex === 0; interactive: root.interactive; onActivated: root.selectCategory(category); onMoveRequested: direction => root.moveNavigation(direction) }
        LazerSettingsNavItem { id: barNav; width: rail.width; label: "顶部栏"; category: "bar"; selected: root.selectedIndex === 1; interactive: root.interactive; onActivated: root.selectCategory(category); onMoveRequested: direction => root.moveNavigation(direction) }
        LazerSettingsNavItem { id: notificationNav; width: rail.width; label: "通知"; category: "notifications"; selected: root.selectedIndex === 2; interactive: root.interactive; onActivated: root.selectCategory(category); onMoveRequested: direction => root.moveNavigation(direction) }
    }

    Keys.priority: Keys.AfterItem
    Keys.onPressed: event => {
        if (!root.interactive || !root.activeFocus)
            return
        if (event.key === Qt.Key_Up || event.key === Qt.Key_Down) {
            var next = root.selectedIndex + (event.key === Qt.Key_Down ? 1 : -1)
            root.selectCategory(categoryAt(next))
            event.accepted = true
        }
    }
}
