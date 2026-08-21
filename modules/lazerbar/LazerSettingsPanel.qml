import QtQuick
import "LazerSettingsLogic.js" as Logic

// Compose the sidebar rail and the flat, scrollable section stack of the
// settings panel. The sidebar only navigates; browsing follows the scroll.
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
    readonly property real panelWidth: sidePanel ? Logic.sidePanelWidth(availableWidth) : Logic.panelWidth(availableWidth)
    readonly property real panelHeight: sidePanel ? Math.max(0, availableHeight) : Logic.panelHeight(availableHeight)
    readonly property real navigationWidth: sidePanel ? sidebarWidth : Logic.navigationWidth(width)
    readonly property real railWidth: navigationWidth
    readonly property int categoryTransitionDuration: 160
    readonly property var contentTransitionEasing: MotionTokens.outSoft
    readonly property int indicatorCount: 3
    readonly property int contentTop: 56
    readonly property Item currentNav: [appearanceNav, barNav, notificationNav][selectedIndex]
    readonly property Item currentPage: sectionsItem

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
    property alias appearancePage: appearanceSection
    property alias barPage: barSection
    property alias notificationPage: notificationSection
    property alias appearanceNav: sidebarLayer.appearanceNav
    property alias barNav: sidebarLayer.barNav
    property alias notificationNav: sidebarLayer.notificationNav
    property alias searchField: contentLayer.searchEditor
    property alias sidebar: sidebarLayer
    property alias content: contentLayer
    property alias sections: sectionsItem

    implicitWidth: panelWidth
    implicitHeight: panelHeight
    enabled: root.interactive
    focus: root.interactive
    activeFocusOnTab: root.interactive

    property bool _syncingCategory: false
    property int transitionToken: 0

    function _rect(item) {
        if (!item)
            return { "x": 0, "y": 0, "width": 0, "height": 0 }
        var pos = item.mapToItem(root, 0, 0)
        return { "x": Number(pos.x), "y": Number(pos.y),
            "width": Math.max(0, Number(item.width)), "height": Math.max(0, Number(item.height)) }
    }

    function debugSnapshot() {
        return {
            "rect": root._rect(root), "sidebar": { "rect": root._rect(sidebarLayer), "x": Number(sidebarLayer.x), "width": Number(sidebarLayer.width), "z": Number(sidebarLayer.z) },
            "content": { "rect": root._rect(contentLayer), "x": Number(contentLayer.x), "width": Number(contentLayer.width), "z": Number(contentLayer.z) },
            "selectedCategory": root.selectedCategory, "currentIndex": root.selectedIndex,
            "interactive": root.interactive, "visible": root.visible, "enabled": root.enabled,
            "opacity": Number(root.opacity), "z": Number(root.z),
            "contentSnapshot": contentLayer.debugSnapshot(),
        }
    }

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
        sectionsItem.resetScrollState()
        sectionsItem.playEntranceWave()
    }

    // Cancel session animations without touching persisted settings.
    function endSession() {
        sidebarLayer.endSession()
        sectionsItem.cancelEntranceWave()
    }

    function toggleExpanded() {
        if (root.interactive)
            root.sidebarExpanded = !root.sidebarExpanded
    }

    // Navigate by scrolling the target section into view.
    function selectCategory(category) {
        if (!root.interactive || categoryIndex(category) < 0)
            return
        if (category === root.selectedCategory) {
            sectionsItem.scrollTo(root.selectedIndex)
            return
        }
        var maximumY = Math.max(0, sectionsItem.contentHeight - sectionsItem.height)
        if (maximumY > 0 && sectionsItem.contentY >= maximumY - 0.5 && category !== "notifications")
            sectionsItem.bottomBoundarySuppressed = true
        else if (category === "notifications")
            sectionsItem.bottomBoundarySuppressed = false
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

    // Keep the selected category and the browsed section in sync both ways.
    onSelectedCategoryChanged: {
        if (_syncingCategory)
            return
        var index = categoryIndex(selectedCategory)
        if (index < 0) {
            root.selectedCategory = "appearance"
            return
        }
        if (selectedCategory === "notifications")
            sectionsItem.bottomBoundarySuppressed = false
        sectionsItem.scrollTo(index)
    }

    Connections {
        target: sectionsItem
        function onCurrentIndexChanged() {
            if (sectionsItem.dropdownOpen)
                return
            var index = sectionsItem.currentIndex
            var category = root.categoryAt(index)
            if (category !== root.selectedCategory) {
                if (category === "notifications")
                    sectionsItem.bottomBoundarySuppressed = false
                root._syncingCategory = true
                root.selectedCategory = category
                root._syncingCategory = false
                root.categoryChanged(category)
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
        expansionProgress: root.collapseProgress
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
        searchQuery: root.searchQuery
        interactive: root.interactive
        contentReady: root.contentReady
        expanded: root.sidebarExpanded
        currentSectionIndex: root.selectedIndex
        sections: sectionsItem
        opacity: root.layerOpacity
        onSearchQueryEdited: query => root.searchQuery = query

        // Stack every category as one flat, scrollable section block.
        LazerSettingsSections {
            id: sectionsItem
            width: parent.width
            height: parent.height
            interactive: root.interactive
            searchQuery: root.searchQuery
            dropdownOpen: contentLayer.dropdownOpen

            LazerSettingsAppearance {
                id: appearanceSection
                settingsObject: root.appearanceSettings
                saveCallback: root.saveCallback
                wallpaperService: root.wallpaperService
                defaults: root.appearanceDefaults
                resetCallback: function(key, value) { if (root.settingsReset) root.settingsReset("appearance", key, value) }
                onActivated: root.selectCategory("appearance")
            }

            LazerSettingsBar {
                id: barSection
                settingsObject: root.barSettings
                saveCallback: root.saveCallback
                defaults: root.barDefaults
                resetCallback: function(key, value) { if (root.settingsReset) root.settingsReset("bar", key, value) }
                onActivated: root.selectCategory("bar")
            }

            LazerSettingsNotifications {
                id: notificationSection
                settingsObject: root.notificationSettings
                saveCallback: root.saveCallback
                defaults: root.notificationDefaults
                resetCallback: function(key, value) { if (root.settingsReset) root.settingsReset("notifications", key, value) }
                onActivated: root.selectCategory("notifications")
            }
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
