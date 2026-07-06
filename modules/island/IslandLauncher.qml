import QtQuick
import Quickshell
import Quickshell.Widgets
import "../bar/MenuVisuals.js" as MenuVisuals
import "../../services/SettingsSearchEntries.js" as SettingsSearch
import "../../services" as Services

// Expanded island content: search input + app list or clipboard list.
Item {
    id: root

    property bool compact: false
    // Local search text when embedded in the overview (compact mode).
    // Keeps the query separate from IslandService.query so typing in the
    // overview card does not trigger page navigation to the full launcher.
    property string _localQuery: ""
    property int _openRevealToken: 0
    readonly property bool focusAllowed: root.visible
        && root.width > 0
        && root.height > 0
        && Services.IslandService.expanded
        && ((root.compact && Services.IslandService.panelPage === "overview")
            || (!root.compact && Services.IslandService.panelPage === "launcher"))

    function focusSearch() {
        if (!searchInput.visible || !searchInput.enabled)
            return

        searchInput.forceActiveFocus()
        searchInput.deselect()
        searchInput.cursorPosition = searchInput.text.length
    }

    function clearSearchFocus() {
        if (searchInput.activeFocus || searchInput.focus)
            searchInput.focus = false
    }

    function triggerOpenReveal() {
        if (root.compact || !root.focusAllowed)
            return

        root._openRevealToken += 1
    }

    function focusSearchWhenReady() {
        Qt.callLater(() => {
            if (root.focusAllowed) {
                Qt.callLater(() => {
                    if (root.focusAllowed)
                        focusSearch()
                })
            }
        })
    }

    Component.onCompleted: focusSearchWhenReady()

    Connections {
        target: Services.IslandService

        function onExpandedChanged() {
            if (root.focusAllowed) {
                root.focusSearchWhenReady()
                root.triggerOpenReveal()
            } else {
                // Reset the local search text when the island collapses
                // so the compact launcher starts clean on next open.
                root._localQuery = ""
                root.clearSearchFocus()
            }
        }

        function onPanelPageChanged() {
            if (root.focusAllowed) {
                root.focusSearchWhenReady()
                root.triggerOpenReveal()
            } else {
                root.clearSearchFocus()
            }
        }

        function onModeChanged() {
            if (root.focusAllowed)
                root.triggerOpenReveal()
        }

        function onQueryChanged() {
            if (root.focusAllowed && Services.IslandService.query.startsWith(">clip ")) {
                root.focusSearchWhenReady()
            }
        }
    }

    onFocusAllowedChanged: {
        if (focusAllowed) {
            focusSearchWhenReady()
            triggerOpenReveal()
        } else
            clearSearchFocus()
    }

    Column {
        anchors.fill: parent
        spacing: 8

        // Search input bar.
        Rectangle {
            id: searchBar
            anchors.left: parent.left
            anchors.right: parent.right
            height: 40
            radius: 12
            // When compact (embedded in the overview card wrapper), the card
            // provides the glass background so this search bar becomes
            // transparent to avoid a double-background visual layer.
            color: root.compact
                ? "transparent"
                : Qt.rgba(Services.Color.mOnSurface.r, Services.Color.mOnSurface.g, Services.Color.mOnSurface.b, MenuVisuals.hoverOpacity)

            TextInput {
                id: searchInput
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                verticalAlignment: TextInput.AlignVCenter
                color: Services.Color.mOnSurface
                font.family: Services.SettingsService.appearance.fontDefault || Qt.application.font.family
                font.pixelSize: Math.round(14 * (Services.SettingsService.appearance.fontDefaultScale || 1.0))
                text: root.compact ? root._localQuery : Services.IslandService.query
                onTextChanged: {
                    if (root.compact) {
                        // In compact (overview-embedded) mode, keep the query
                        // local so it does not switch the full island page to
                        // the launcher. Results appear inline within the card.
                        root._localQuery = text
                    } else {
                        Services.IslandService.query = text
                        if (text.trim().length > 0)
                            Services.IslandService.openPage("launcher")
                    }
                }
                focus: root.focusAllowed
                Keys.onEscapePressed: Services.IslandService.close()

                // Navigate list with Up/Down/Enter keys.
                // In compact mode the compact results list handles navigation;
                // in full launcher mode the app/clipboard list handles it.
                Keys.onUpPressed: {
                    if (root.compact && compactResultsLoader.active && compactResultsLoader.item) {
                        var compactUpIndex = compactResultsLoader.item.nextVisibleIndex(compactResultsLoader.item.currentIndex, "up")
                        compactResultsLoader.item.currentIndex = compactUpIndex
                        compactResultsLoader.item.positionViewAtIndex(compactUpIndex, ListView.Contain)
                    } else {
                        var loader = Services.IslandService.mode === "clipboard" ? clipLoader : appLoader
                        if (loader.item && loader.item.count > 0) {
                            var upIndex = loader.item.nextVisibleIndex(loader.item.currentIndex, "up")
                            loader.item.currentIndex = upIndex
                            loader.item.positionViewAtIndex(upIndex, ListView.Contain)
                        }
                    }
                }
                Keys.onDownPressed: {
                    if (root.compact && compactResultsLoader.active && compactResultsLoader.item) {
                        var compactDownIndex = compactResultsLoader.item.nextVisibleIndex(compactResultsLoader.item.currentIndex, "down")
                        compactResultsLoader.item.currentIndex = compactDownIndex
                        compactResultsLoader.item.positionViewAtIndex(compactDownIndex, ListView.Contain)
                    } else {
                        var loader = Services.IslandService.mode === "clipboard" ? clipLoader : appLoader
                        if (loader.item && loader.item.count > 0) {
                            var downIndex = loader.item.nextVisibleIndex(loader.item.currentIndex, "down")
                            loader.item.currentIndex = downIndex
                            loader.item.positionViewAtIndex(downIndex, ListView.Contain)
                        }
                    }
                }
                Keys.onReturnPressed: {
                    if (root.compact && compactResultsLoader.active && compactResultsLoader.item) {
                        var idx = compactResultsLoader.item.currentIndex
                        var entries = compactResultsLoader.item.combinedEntries
                        if (idx >= 0 && idx < entries.length) {
                            var entry = entries[idx]
                            if (entry.type === "app") {
                                Services.LaunchCountService.recordLaunch(entry.appData.id || "")
                                entry.appData.execute()
                                Services.IslandService.close()
                            } else if (entry.type === "setting") {
                                // Pass the concrete setting label so the
                                // settings search lands on a visible row.
                                Services.IslandService.settingsInitialFilter = entry.settingData.label
                                Services.IslandService.showSettingsCenter()
                            }
                        }
                    } else {
                        var loader = Services.IslandService.mode === "clipboard" ? clipLoader : appLoader
                        var listView = loader.item
                        if (listView) {
                            var idx2 = listView.currentIndex
                            if (Services.IslandService.mode === "clipboard") {
                                var items = listView.allItems
                                if (idx2 >= 0 && idx2 < items.length) {
                                    Services.ClipboardService.copyItem(items[idx2].id)
                                    Services.IslandService.close()
                                }
                            } else {
                                var apps = listView.sortedApps
                                if (idx2 >= 0 && idx2 < apps.length) {
                                    Services.LaunchCountService.recordLaunch(apps[idx2].id || "")
                                    apps[idx2].execute()
                                    Services.IslandService.close()
                                }
                            }
                        }
                    }
                }
                Keys.onEnterPressed: Keys.onReturnPressed(null)

                // Placeholder text.
                Services.FluidText {
                    text: "Search apps or >clip for clipboard..."
                    color: Services.Color.mOnSurfaceVariant
                    opacity: 0.6
                    font.pixelSize: parent.font.pixelSize
                    anchors.verticalCenter: parent.verticalCenter
                    visible: parent.text.length === 0
                }
            }
        }

        // Results area.  In compact (overview-embedded) mode the area is
        // hidden when the local query is empty; when text is entered it shows
        // a combined list of matching apps and settings entries inline.
        // In full launcher mode the existing per-mode delegates are used.
        Item {
            anchors.left: parent.left
            anchors.right: parent.right
            height: root.compact && root._localQuery.trim().length === 0
                ? 0
                : root.height - searchBar.height - 8
            clip: true
            visible: height > 1

            // Compact (overview) mode: combined app + settings results.
            Loader {
                id: compactResultsLoader
                anchors.fill: parent
                active: root.compact && root._localQuery.trim().length > 0
                sourceComponent: compactResultsList
            }

            // Full launcher mode: app list.
            Loader {
                id: appLoader
                anchors.fill: parent
                active: !root.compact && Services.IslandService.mode === "apps"
                sourceComponent: islandAppList

                onLoaded: {
                    if (item && Services.IslandService.query.trim().length === 0) {
                        item.currentIndex = 0
                    }
                }
            }

            // Full launcher mode: clipboard list.
            Loader {
                id: clipLoader
                anchors.fill: parent
                active: !root.compact && Services.IslandService.mode === "clipboard"
                sourceComponent: islandClipboard

                onLoaded: {
                    if (item && Services.IslandService.query.trim().length === 0) {
                        item.currentIndex = 0
                    }
                }
            }
        }
    }

    // --- App list component ---
    Component {
        id: islandAppList

        ListView {
            id: appListView
            anchors.fill: parent
            anchors.margins: 4
            clip: true
            spacing: 0

            property string query: {
                var raw = root.compact ? root._localQuery : Services.IslandService.query
                var q = raw.toLowerCase()
                if (q.startsWith(">")) return ""
                return q
            }
            property var sortedApps: {
                const all = DesktopEntries.applications.values
                if (!all || all.length === 0) return []
                return all.slice().sort((a, b) => {
                    const ca = Services.LaunchCountService.getLaunchCount(a.id || "")
                    const cb = Services.LaunchCountService.getLaunchCount(b.id || "")
                    return cb - ca
                })
            }

            property int openStaggerStep: 28
            property int openStaggerCount: 8
            property int openRevealToken: 0
            property bool openRevealArmed: false

            function triggerOpenReveal() {
                openRevealToken = root._openRevealToken
                openRevealArmed = true
                openRevealResetTimer.restart()
            }

            Connections {
                target: root

                function on_OpenRevealTokenChanged() {
                    appListView.triggerOpenReveal()
                }
            }

            onQueryChanged: {
                var apps = sortedApps
                for (var i = 0; i < apps.length; i++) {
                    if (appMatches(apps[i], query)) {
                        appListView.currentIndex = i
                        appListView.positionViewAtBeginning()
                        return
                    }
                }
                appListView.currentIndex = 0
            }

            function appMatches(app, q) {
                if (!q) return true
                const name = (app.name || "").toLowerCase()
                const comment = (app.comment || "").toLowerCase()
                const genericName = (app.genericName || "").toLowerCase()
                const appId = (app.id || "").toLowerCase()
                const keywords = (app.keywords || []).join(" ").toLowerCase()
                return name.includes(q) || comment.includes(q)
                    || genericName.includes(q) || appId.includes(q)
                    || keywords.includes(q)
            }

            function nextVisibleIndex(from, direction) {
                var step = direction === "down" ? 1 : -1
                var i = from + step
                while (i >= 0 && i < sortedApps.length) {
                    if (appMatches(sortedApps[i], query))
                        return i
                    i += step
                }
                return from
            }

            model: sortedApps

            add: Transition {
                ParallelAnimation {
                    NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 180; easing.type: Easing.OutCubic }
                    NumberAnimation { property: "x"; from: 26; to: 0; duration: 220; easing.type: Easing.OutCubic }
                }
            }

            remove: Transition {
                ParallelAnimation {
                    NumberAnimation { property: "opacity"; to: 0; duration: 150; easing.type: Easing.InCubic }
                    NumberAnimation { property: "x"; to: 30; duration: 180; easing.type: Easing.InCubic }
                }
            }

            displaced: Transition {
                NumberAnimation { properties: "x,y"; duration: 220; easing.type: Easing.OutCubic }
            }

            delegate: Rectangle {
                id: appDelegate
                required property var modelData
                required property int index
                readonly property bool matchesFilter: appListView.appMatches(modelData, appListView.query)
                property bool _contentRevealVisible: true
                property int _seenOpenRevealToken: 0

                width: ListView.view ? ListView.view.width : 200
                height: matchesFilter ? 52 : 0
                opacity: matchesFilter ? 1 : 0
                x: matchesFilter ? 0 : 30
                visible: height > 1 || opacity > 0.01
                radius: MenuVisuals.rowRadius
                color: delegateMouse.containsMouse || ListView.view.currentIndex === index
                    ? Qt.rgba(Services.Color.mOnSurface.r, Services.Color.mOnSurface.g, Services.Color.mOnSurface.b, MenuVisuals.hoverOpacity)
                    : "transparent"

                Behavior on height { NumberAnimation { duration: 220; easing.type: Easing.InOutCubic } }
                Behavior on x { NumberAnimation { duration: 190; easing.type: appDelegate.matchesFilter ? Easing.OutCubic : Easing.InCubic } }
                Behavior on opacity { NumberAnimation { duration: 190; easing.type: appDelegate.matchesFilter ? Easing.OutCubic : Easing.InCubic } }

                Component.onCompleted: maybeQueueOpenReveal()

                function maybeQueueOpenReveal() {
                    if (!ListView.view || !ListView.view.openRevealArmed || !matchesFilter)
                        return
                    if (_seenOpenRevealToken === ListView.view.openRevealToken)
                        return

                    _seenOpenRevealToken = ListView.view.openRevealToken
                    _contentRevealVisible = false
                    openRevealTimer.restart()
                }

                Connections {
                    target: ListView.view

                    function onOpenRevealTokenChanged() {
                        appDelegate.maybeQueueOpenReveal()
                    }
                }

                Timer {
                    id: openRevealTimer
                    interval: Math.min(appDelegate.index, appListView.openStaggerCount) * appListView.openStaggerStep
                    repeat: false
                    onTriggered: appDelegate._contentRevealVisible = true
                }

                Item {
                    id: appContent
                    anchors.fill: parent
                    opacity: appDelegate._contentRevealVisible ? 1 : 0
                    x: appDelegate._contentRevealVisible ? 0 : 18

                    Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    Behavior on x { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

                    Row {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        height: 48
                        anchors.leftMargin: MenuVisuals.listContentInset
                        anchors.rightMargin: MenuVisuals.listContentInset
                        spacing: 12

                        IconImage {
                            anchors.verticalCenter: parent.verticalCenter
                            source: "image://icon/" + (modelData.icon || "application-x-executable")
                            implicitSize: 32
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 32
                            spacing: 2

                            Services.FluidText {
                                text: modelData.name || ""
                                color: Services.Color.mOnSurface
                                basePixelSize: 13
                                elide: Text.ElideRight
                                width: parent.width
                            }

                            Services.FluidText {
                                text: modelData.comment || modelData.genericName || ""
                                color: Services.Color.mOnSurfaceVariant
                                basePixelSize: 11
                                opacity: 0.7
                                elide: Text.ElideRight
                                width: parent.width
                                visible: text.length > 0
                            }
                        }
                    }
                }

                MouseArea {
                    id: delegateMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        var app = appDelegate.modelData
                        var idx = appDelegate.index
                        if (ListView.view) ListView.view.currentIndex = idx
                        Services.LaunchCountService.recordLaunch(app.id || "")
                        app.execute()
                        Services.IslandService.close()
                    }
                }
            }

            Timer {
                id: openRevealResetTimer
                interval: appListView.openStaggerCount * appListView.openStaggerStep + 260
                repeat: false
                onTriggered: appListView.openRevealArmed = false
            }
        }
    }

    // Combined app + settings results list for compact (overview-embedded)
    // mode.  Shows matching desktop entries and settings entries in a single
    // scrollable list, similar to a Windows start menu search result pane.
    // Wrapped in a background rectangle so the launcher card's glass styling
    // (gradient, highlight strip, border) does not peek through transparent
    // gaps between list items — the entire results region reads as one
    // continuous surface below the search bar.
    Component {
        id: compactResultsList

        // Opaque surface layer that inherits the card's rest-state
        // opacity so the list feels like an extension of the card
        // rather than a floating overlay with see-through gaps.
        Rectangle {
            id: compactResultsSurface
            anchors.fill: parent
            color: Qt.rgba(Services.Color.mOnSurface.r, Services.Color.mOnSurface.g, Services.Color.mOnSurface.b, MenuVisuals.hoverOpacity)
            radius: 6
            property alias currentIndex: compactListView.currentIndex
            property alias combinedEntries: compactListView.combinedEntries

            function nextVisibleIndex(from, direction) {
                return compactListView.nextVisibleIndex(from, direction)
            }

            function positionViewAtIndex(index, mode) {
                compactListView.positionViewAtIndex(index, mode)
            }

            ListView {
            id: compactListView
            anchors.fill: parent
            anchors.margins: 4
            clip: true
            spacing: 0

            // Derive sorted apps (same logic as islandAppList).
            property var sortedApps: {
                const all = DesktopEntries.applications.values
                if (!all || all.length === 0) return []
                return all.slice().sort((a, b) => {
                    const ca = Services.LaunchCountService.getLaunchCount(a.id || "")
                    const cb = Services.LaunchCountService.getLaunchCount(b.id || "")
                    return cb - ca
                })
            }

            // Check whether an app matches the given query.
            function appMatches(app, q) {
                if (!q) return false
                const name = (app.name || "").toLowerCase()
                const comment = (app.comment || "").toLowerCase()
                const genericName = (app.genericName || "").toLowerCase()
                const appId = (app.id || "").toLowerCase()
                const keywords = (app.keywords || []).join(" ").toLowerCase()
                return name.includes(q) || comment.includes(q)
                    || genericName.includes(q) || appId.includes(q)
                    || keywords.includes(q)
            }

            // Build the complete app + settings candidate pool. Filtering is
            // handled by delegates so rows can smoothly collapse instead of
            // being destroyed on every query change.
            property var combinedEntries: {
                var results = []

                // App candidates.
                var apps = sortedApps
                for (var i = 0; i < apps.length; i++) {
                    results.push({
                        type: "app",
                        appData: apps[i],
                        label: apps[i].name || "",
                        description: apps[i].comment || apps[i].genericName || ""
                    })
                }

                // Settings candidates.
                var settingsEntries = SettingsSearch.allEntries()
                for (var j = 0; j < settingsEntries.length; j++) {
                    var entry = settingsEntries[j]
                    results.push({
                        type: "setting",
                        settingData: entry,
                        label: entry.label,
                        description: entry.category + " \u00B7 " + entry.description
                    })
                }

                return results
            }

            function entryMatches(entry, q) {
                if (!q) return false
                if (entry.type === "app")
                    return appMatches(entry.appData, q)
                if (entry.type === "setting")
                    return SettingsSearch.matches(entry.settingData, q)
                return false
            }

            function firstVisibleIndex() {
                var q = root._localQuery.trim().toLowerCase()
                var entries = combinedEntries
                for (var i = 0; i < entries.length; i++) {
                    if (entryMatches(entries[i], q))
                        return i
                }
                return 0
            }

            function hasVisibleEntries() {
                var q = root._localQuery.trim().toLowerCase()
                var entries = combinedEntries
                for (var i = 0; i < entries.length; i++) {
                    if (entryMatches(entries[i], q))
                        return true
                }
                return false
            }

            function nextVisibleIndex(from, direction) {
                var q = root._localQuery.trim().toLowerCase()
                var step = direction === "down" ? 1 : -1
                var entries = combinedEntries
                var i = from + step
                while (i >= 0 && i < entries.length) {
                    if (entryMatches(entries[i], q))
                        return i
                    i += step
                }
                return from
            }

            Connections {
                target: root
                function on_LocalQueryChanged() {
                    compactListView.currentIndex = compactListView.firstVisibleIndex()
                    compactListView.positionViewAtBeginning()
                }
            }

            onCombinedEntriesChanged: currentIndex = firstVisibleIndex()
            currentIndex: 0
            model: combinedEntries

            add: Transition {
                ParallelAnimation {
                    NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 180; easing.type: Easing.OutCubic }
                    NumberAnimation { property: "x"; from: 26; to: 0; duration: 220; easing.type: Easing.OutCubic }
                }
            }

            remove: Transition {
                ParallelAnimation {
                    NumberAnimation { property: "opacity"; to: 0; duration: 150; easing.type: Easing.InCubic }
                    NumberAnimation { property: "x"; to: 30; duration: 180; easing.type: Easing.InCubic }
                }
            }

            displaced: Transition {
                NumberAnimation { properties: "x,y"; duration: 220; easing.type: Easing.OutCubic }
            }

            delegate: Rectangle {
                id: compactDelegate
                required property var modelData
                required property int index

                width: ListView.view ? ListView.view.width : 200
                readonly property bool matchesFilter: compactListView.entryMatches(modelData, root._localQuery.trim().toLowerCase())
                height: matchesFilter ? 52 : 0
                opacity: matchesFilter ? 1 : 0
                x: matchesFilter ? 0 : 30
                visible: height > 1 || opacity > 0.01
                radius: 6
                color: compactMouse.containsMouse || compactListView.currentIndex === index
                    ? Qt.rgba(Services.Color.mOnSurface.r, Services.Color.mOnSurface.g, Services.Color.mOnSurface.b, MenuVisuals.hoverOpacity)
                    : "transparent"

                Behavior on height { NumberAnimation { duration: 220; easing.type: Easing.InOutCubic } }
                Behavior on x { NumberAnimation { duration: 190; easing.type: compactDelegate.matchesFilter ? Easing.OutCubic : Easing.InCubic } }
                Behavior on opacity { NumberAnimation { duration: 190; easing.type: compactDelegate.matchesFilter ? Easing.OutCubic : Easing.InCubic } }

                Row {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    height: 48
                    anchors.leftMargin: MenuVisuals.listContentInset
                    anchors.rightMargin: MenuVisuals.listContentInset
                    spacing: 12

                    // App icon or settings indicator.
                    IconImage {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: modelData.type === "app"
                        source: modelData.type === "app"
                            ? "image://icon/" + (modelData.appData.icon || "application-x-executable")
                            : ""
                        implicitSize: 32
                    }

                    // Settings icon fallback (gear character).
                    Services.FluidText {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: modelData.type === "setting"
                        text: "\u2699"
                        color: Services.Color.mPrimary
                        basePixelSize: 22
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 32 - (parent.spacing || 12)
                        spacing: 2

                        Services.FluidText {
                            text: modelData.label || ""
                            color: Services.Color.mOnSurface
                            basePixelSize: 13
                            elide: Text.ElideRight
                            width: parent.width
                        }

                        Services.FluidText {
                            text: modelData.description || ""
                            color: Services.Color.mOnSurfaceVariant
                            basePixelSize: 11
                            opacity: 0.7
                            elide: Text.ElideRight
                            width: parent.width
                            visible: text.length > 0
                        }
                    }
                }

                MouseArea {
                    id: compactMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        compactListView.currentIndex = index
                        if (modelData.type === "app") {
                            var app = modelData.appData
                            Services.LaunchCountService.recordLaunch(app.id || "")
                            app.execute()
                            Services.IslandService.close()
                        } else if (modelData.type === "setting") {
                            var sEntry = modelData.settingData
                            // Pre-filter the settings page with the entry's
                            // target category so relevant items are highlighted.
                            // Pass the concrete setting label so the settings
                            // search lands on a visible row instead of an empty
                            // category-only filter.
                            Services.IslandService.settingsInitialFilter = sEntry.label
                            Services.IslandService.showSettingsCenter()
                        }
                    }
                }
            }

            // Empty-state prompt shown when the search query matches no apps
            // or settings. Keeps the results area from reading as a blank
            // surface — user sees a clear "no results" cue instead.
            Item {
                anchors.centerIn: parent
                visible: !compactListView.hasVisibleEntries()
                width: parent.width
                height: noMatchLabel.height

                Services.FluidText {
                    id: noMatchLabel
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "No matching apps or settings found"
                    color: Services.Color.mOnSurfaceVariant
                    basePixelSize: 13
                    opacity: 0.5
                }
            }
            }
        }
    }

    // --- Clipboard list component ---
    Component {
        id: islandClipboard

        ListView {
            id: clipListView
            anchors.fill: parent
            anchors.margins: 4
            clip: true
            spacing: 0
            property int openStaggerStep: 28
            property int openStaggerCount: 8
            property int openRevealToken: 0
            property bool openRevealArmed: false

            function triggerOpenReveal() {
                openRevealToken = root._openRevealToken
                openRevealArmed = true
                openRevealResetTimer.restart()
            }

            Connections {
                target: root

                function on_OpenRevealTokenChanged() {
                    clipListView.triggerOpenReveal()
                }
            }

            property string query: {
                var q = Services.IslandService.query.toLowerCase()
                if (q.startsWith(">clip")) return q.slice(5).trim()
                return q.startsWith(">") ? "" : q
            }

            property var allItems: {
                const all = Services.ClipboardService.items
                if (!all || all.length === 0) return []
                return all
            }

            onQueryChanged: {
                var items = allItems
                for (var i = 0; i < items.length; i++) {
                    if (clipMatches(items[i], query)) {
                        clipListView.currentIndex = i
                        clipListView.positionViewAtBeginning()
                        return
                    }
                }
                clipListView.currentIndex = 0
            }
            function clipMatches(item, q) {
                if (!q) return true
                const preview = (item.preview || "").toLowerCase()
                const kind = item.isImage ? "image" : "text"
                return preview.includes(q) || kind.includes(q)
            }
            function nextVisibleIndex(from, direction) {
                var step = direction === "down" ? 1 : -1
                var i = from + step
                while (i >= 0 && i < allItems.length) {
                    if (clipMatches(allItems[i], query))
                        return i
                    i += step
                }
                return from
            }

            model: allItems

            Component.onCompleted: Services.ClipboardService.list()

            add: Transition {
                ParallelAnimation {
                    NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 180; easing.type: Easing.OutCubic }
                    NumberAnimation { property: "x"; from: 26; to: 0; duration: 220; easing.type: Easing.OutCubic }
                }
            }

            remove: Transition {
                ParallelAnimation {
                    NumberAnimation { property: "opacity"; to: 0; duration: 150; easing.type: Easing.InCubic }
                    NumberAnimation { property: "x"; to: 30; duration: 180; easing.type: Easing.InCubic }
                }
            }

            displaced: Transition {
                NumberAnimation { properties: "x,y"; duration: 220; easing.type: Easing.OutCubic }
            }

            delegate: Rectangle {
                id: clipDelegate

                required property var modelData
                required property int index

                width: ListView.view ? ListView.view.width : 200
                readonly property bool matchesFilter: clipListView.clipMatches(modelData, clipListView.query)
                property bool _contentRevealVisible: true
                property int _seenOpenRevealToken: 0
                height: matchesFilter ? 52 : 0
                opacity: matchesFilter ? 1 : 0
                x: matchesFilter ? 0 : 30
                visible: height > 1 || opacity > 0.01
                radius: MenuVisuals.rowRadius
                color: clipMouse.containsMouse || clipListView.currentIndex === index
                    ? Qt.rgba(Services.Color.mOnSurface.r, Services.Color.mOnSurface.g, Services.Color.mOnSurface.b, MenuVisuals.hoverOpacity)
                    : "transparent"

                Behavior on height { NumberAnimation { duration: 220; easing.type: Easing.InOutCubic } }
                Behavior on x { NumberAnimation { duration: 190; easing.type: clipDelegate.matchesFilter ? Easing.OutCubic : Easing.InCubic } }
                Behavior on opacity { NumberAnimation { duration: 190; easing.type: clipDelegate.matchesFilter ? Easing.OutCubic : Easing.InCubic } }

                Component.onCompleted: maybeQueueOpenReveal()

                function maybeQueueOpenReveal() {
                    if (!ListView.view || !ListView.view.openRevealArmed || !matchesFilter)
                        return
                    if (_seenOpenRevealToken === ListView.view.openRevealToken)
                        return

                    _seenOpenRevealToken = ListView.view.openRevealToken
                    _contentRevealVisible = false
                    openRevealTimer.restart()
                }

                Connections {
                    target: ListView.view

                    function onOpenRevealTokenChanged() {
                        clipDelegate.maybeQueueOpenReveal()
                    }
                }

                Timer {
                    id: openRevealTimer
                    interval: Math.min(clipDelegate.index, clipListView.openStaggerCount) * clipListView.openStaggerStep
                    repeat: false
                    onTriggered: clipDelegate._contentRevealVisible = true
                }

                Item {
                    id: clipContent
                    anchors.fill: parent
                    opacity: clipDelegate._contentRevealVisible ? 1 : 0
                    x: clipDelegate._contentRevealVisible ? 0 : 18

                    Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    Behavior on x { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

                    Services.FluidText {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        height: 48
                        anchors.leftMargin: MenuVisuals.listContentInset
                        anchors.rightMargin: MenuVisuals.listContentInset
                        verticalAlignment: Text.AlignVCenter
                        text: modelData.isImage ? "[Image]" : (modelData.preview || "")
                        color: Services.Color.mOnSurface
                        basePixelSize: 13
                        elide: Text.ElideRight
                    }
                }

                MouseArea {
                    id: clipMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        clipListView.currentIndex = index
                        Services.ClipboardService.copyItem(modelData.id)
                        Services.IslandService.close()
                    }
                }
            }

            Timer {
                id: openRevealResetTimer
                interval: clipListView.openStaggerCount * clipListView.openStaggerStep + 260
                repeat: false
                onTriggered: clipListView.openRevealArmed = false
            }
        }
    }
}
