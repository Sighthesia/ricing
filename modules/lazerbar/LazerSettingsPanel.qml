import QtQuick
import "LazerSettingsLogic.js" as Logic

// Compose the independent sidebar and content layers of the settings panel.
Item {
    id: root

    // These inputs are owned by the host; navigation state is owned here.
    property var appearanceSettings: null
    property var barSettings: null
    property var notificationSettings: null
    property var saveCallback: null
    property var wallpaperService: null
    property var appearanceDefaults: ({})
    property var barDefaults: ({})
    property var notificationDefaults: ({})
    property var settingsReset: null
    property bool interactive: true
    property string selectedCategory: "appearance"
    property real availableWidth: 1040
    property real availableHeight: 760
    property bool sidePanel: false

    // Session state: sidebar expansion, search, and the shared open progress.
    property bool sidebarExpanded: true
    property string searchQuery: ""
    property real progress: 0
    property bool contentReady: false
    property real collapseProgress: sidebarExpanded ? 1 : 0

    readonly property int selectedIndex: categoryIndex(selectedCategory)
    readonly property int contentTransitionDirection: _transitionDirection
    readonly property real panelWidth: sidePanel ? Logic.sidePanelWidth(availableWidth) : Logic.panelWidth(availableWidth)
    readonly property real panelHeight: sidePanel ? Math.max(0, availableHeight) : Logic.panelHeight(availableHeight)
    readonly property real navigationWidth: sidePanel ? sidebarWidth : Logic.navigationWidth(width)
    readonly property real railWidth: navigationWidth
    readonly property int categoryTransitionDuration: 160
    readonly property var contentTransitionEasing: MotionTokens.outSoft
    readonly property int indicatorCount: 3
    readonly property int contentTop: 56
    readonly property Item currentNav: [appearanceNav, barNav, notificationNav][selectedIndex]
    readonly property Item currentPage: [appearancePage, barPage, notificationPage][selectedIndex]

    // Animate the 70..170px sidebar width through one collapse transition.
    readonly property real sidebarWidth: Math.max(0, Math.min(panelWidth,
        Logic.sidebarContractedWidth + (Logic.sidebarExpandedWidth - Logic.sidebarContractedWidth) * collapseProgress))
    readonly property real contentWidth: Logic.contentWidth(panelWidth, sidebarWidth)
    readonly property real sidebarLayerX: MotionTokens.reducedMotion ? 0 : Logic.interpolate(Logic.sidebarStartX(), 0, progress)
    readonly property real contentLayerX: MotionTokens.reducedMotion ? sidebarWidth : Logic.interpolate(Logic.contentStartX(panelWidth), sidebarWidth, progress)
    // Keep the panel surfaces opaque while progress owns their translation.
    readonly property real layerOpacity: 1

    signal escapeRequested
    signal closeRequested
    signal categoryChanged(string category)
    property alias appearancePage: appearancePage
    property alias barPage: barPage
    property alias notificationPage: notificationPage
    property alias appearanceNav: sidebarLayer.appearanceNav
    property alias barNav: sidebarLayer.barNav
    property alias notificationNav: sidebarLayer.notificationNav
    property alias searchField: contentLayer.searchEditor
    property alias sidebar: sidebarLayer
    property alias content: contentLayer

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

    // Reset session-local state on every fresh open.
    function beginSession() {
        sidebarExpanded = true
        searchQuery = ""
        sidebarLayer.beginSession()
    }

    // Cancel session animations without touching persisted settings.
    function endSession() {
        sidebarLayer.endSession()
    }

    function toggleExpanded() {
        if (root.interactive)
            root.sidebarExpanded = !root.sidebarExpanded
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

    function focusSearch() {
        if (root.interactive && root.contentReady)
            contentLayer.focusSearch()
    }

    function focusFirstControl() {
        if (!root.interactive)
            return
        if (root.contentReady)
            contentLayer.focusSearch()
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
            root.transitionToken += 1
            root.transitionsEnabled = false
            if (MotionTokens.reducedMotion) {
                appearancePage.x = 0
                barPage.x = 0
                notificationPage.x = 0
                appearancePage.opacity = root.selectedIndex === 0 ? 1 : 0
                barPage.opacity = root.selectedIndex === 1 ? 1 : 0
                notificationPage.opacity = root.selectedIndex === 2 ? 1 : 0
                root.transitionsEnabled = false
            } else {
                root.transitionsEnabled = true
            }
        }
    }

    // Slide the sidebar rail as one independently animated owner layer.
    // It must sit above the content layer (osu adds Sidebar last) so its rail
    // and nav entries stay visible over the content background extension.
    LazerSettingsSidebar {
        id: sidebarLayer
        z: 1
        x: root.sidebarLayerX
        y: 0
        width: root.sidebarWidth
        height: root.height
        expanded: root.sidebarExpanded
        interactive: root.interactive
        selectedIndex: root.selectedIndex
        opacity: root.layerOpacity
        onCategorySelected: index => root.selectCategory(root.categoryAt(index))
        onMoveRequested: direction => root.moveNavigation(direction)
        onCollapseToggleRequested: root.toggleExpanded()
        onCloseRequested: root.requestClose()
    }

    // Slide the content viewport as a second independent owner layer.
    LazerSettingsContent {
        id: contentLayer
        x: root.contentLayerX
        y: 0
        width: root.contentWidth
        height: root.height
        backgroundExtend: Math.max(0, root.panelWidth - root.contentWidth)
        title: ["外观", "顶部栏", "通知"][root.selectedIndex]
        searchQuery: root.searchQuery
        interactive: root.interactive
        contentReady: root.contentReady
        expanded: root.sidebarExpanded
        visibleResultCount: root.currentPage ? root.currentPage.visibleResultCount : 0
        currentPage: root.currentPage
        opacity: root.layerOpacity
        onSearchQueryEdited: query => root.searchQuery = query

        // Persist the appearance page so its scroll position survives navigation.
        // Positioned with explicit width/height (not anchors) so the transition owns x.
        LazerSettingsAppearance {
            id: appearancePage
            y: 0
            width: parent.width
            height: parent.height
            settingsObject: root.appearanceSettings
            saveCallback: root.saveCallback
            wallpaperService: root.wallpaperService
            defaults: root.appearanceDefaults
            resetCallback: function(key, value) { if (root.settingsReset) root.settingsReset("appearance", key, value) }
            searchQuery: root.searchQuery
            opacity: 0
            Behavior on opacity { enabled: root.transitionsEnabled; NumberAnimation { duration: root.categoryTransitionDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: MotionTokens.outSoft } }
            Behavior on x { enabled: root.transitionsEnabled && !MotionTokens.reducedMotion; NumberAnimation { duration: root.categoryTransitionDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: MotionTokens.outSoft } }
        }

        // Persist the bar page so its scroll position survives navigation.
        LazerSettingsBar {
            id: barPage
            y: 0
            width: parent.width
            height: parent.height
            settingsObject: root.barSettings
            saveCallback: root.saveCallback
            defaults: root.barDefaults
            resetCallback: function(key, value) { if (root.settingsReset) root.settingsReset("bar", key, value) }
            searchQuery: root.searchQuery
            opacity: 0
            Behavior on opacity { enabled: root.transitionsEnabled; NumberAnimation { duration: root.categoryTransitionDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: MotionTokens.outSoft } }
            Behavior on x { enabled: root.transitionsEnabled && !MotionTokens.reducedMotion; NumberAnimation { duration: root.categoryTransitionDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: MotionTokens.outSoft } }
        }

        // Persist the notification page so its scroll position survives navigation.
        LazerSettingsNotifications {
            id: notificationPage
            y: 0
            width: parent.width
            height: parent.height
            settingsObject: root.notificationSettings
            saveCallback: root.saveCallback
            defaults: root.notificationDefaults
            resetCallback: function(key, value) { if (root.settingsReset) root.settingsReset("notifications", key, value) }
            searchQuery: root.searchQuery
            opacity: 0
            Behavior on opacity { enabled: root.transitionsEnabled; NumberAnimation { duration: root.categoryTransitionDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: MotionTokens.outSoft } }
            Behavior on x { enabled: root.transitionsEnabled && !MotionTokens.reducedMotion; NumberAnimation { duration: root.categoryTransitionDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: MotionTokens.outSoft } }
        }
    }

    // Collapse the sidebar smoothly without resizing the fixed owner surface.
    Behavior on collapseProgress {
        enabled: !MotionTokens.reducedMotion
        NumberAnimation { duration: MotionTokens.settingsSidebarCollapse; easing.type: Easing.OutQuint }
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
