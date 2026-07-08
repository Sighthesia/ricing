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
            property int prewarmCount: 12
            property bool prewarmArmed: false

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
            property var prewarmApps: {
                const apps = sortedApps
                if (!apps || apps.length === 0) return []
                return apps.slice(0, Math.min(prewarmCount, apps.length))
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

            Component.onCompleted: appPrewarmTimer.start()

            Timer {
                id: appPrewarmTimer
                interval: 0
                repeat: false
                onTriggered: appListView.prewarmArmed = true
            }

            Item {
                visible: false
                opacity: 0
                x: -10000
                y: -10000

                Repeater {
                    model: appListView.prewarmArmed ? appListView.prewarmApps : []

                    delegate: Item {
                        required property var modelData

                        width: 200
                        height: 52

                        Row {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            height: 48
                            spacing: 12

                            IconImage {
                                anchors.verticalCenter: parent.verticalCenter
                                source: "image://icon/" + (modelData.icon || "application-x-executable")
                                implicitSize: 32
                            }

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 160
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
                }
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
            property int prewarmCount: 16
            property bool prewarmArmed: false

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
            property var prewarmEntries: {
                const entries = combinedEntries
                if (!entries || entries.length === 0) return []
                return entries.slice(0, Math.min(prewarmCount, entries.length))
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

            Component.onCompleted: compactPrewarmTimer.start()

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

            Timer {
                id: compactPrewarmTimer
                interval: 0
                repeat: false
                onTriggered: compactListView.prewarmArmed = true
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

            Item {
                visible: false
                opacity: 0
                x: -10000
                y: -10000

                Repeater {
                    model: compactListView.prewarmArmed ? compactListView.prewarmEntries : []

                    delegate: Item {
                        required property var modelData

                        width: 200
                        height: 52

                        Row {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            height: 48
                            spacing: 12

                            IconImage {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: modelData.type === "app"
                                source: modelData.type === "app"
                                    ? "image://icon/" + (modelData.appData.icon || "application-x-executable")
                                    : ""
                                implicitSize: 32
                            }

                            Services.FluidText {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: modelData.type === "setting"
                                text: "⚙"
                                color: Services.Color.mPrimary
                                basePixelSize: 22
                            }

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 160
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
                    }
                }
            }
            }
        }
    }

    // --- Clipboard list component ---
    Component {
        id: islandClipboard

        // Wrapper Item: provides left-side preview alongside the clipboard list.
        // Forwards count/currentIndex/allItems/navigation to the inner ListView
        // so keyboard navigation from IslandLauncher still works through clipLoader.item.
        Item {
            id: clipRoot

            // ---- Preview state ----
            property int _hoverActiveIndex: -1
            property int _previewActiveIndex: -1
            property string _previewActiveSource: ""
            property var _pendingPreviewItem: null
            property int _pendingPreviewIndex: -1
            property real _restingListWidth: 0
            property real _previewSlotWidth: 0
            readonly property real _outerInset: 4
            // Fixed width — no longer collapses to 8px or varies by content type.
            readonly property real _previewWidth: 300
            property bool _deferPreviewContentUntilSettled: true

            // Forwarded for keyboard navigation from IslandLauncher.qml.
            readonly property alias count: clipListView.count
            property alias currentIndex: clipListView.currentIndex

            property var allItems: {
                const all = Services.ClipboardService.items
                if (!all || all.length === 0) return []
                return all
            }

            onWidthChanged: {
                _syncRestingListWidth()
            }

            Component.onCompleted: {
                _syncRestingListWidth()
                _previewSlotWidth = _previewWidth
            }

            function _syncRestingListWidth() {
                _restingListWidth = Math.max(0, width - _outerInset * 2 - _previewSlotWidth)
            }

            // All text items (short or long) and images are previewable.
            function _isPreviewable(item) {
                return item && (item.isImage || (item.preview && item.preview.length > 0))
            }

            function _previewWidthFor(item) {
                return clipRoot._previewWidth
            }

            function _formatFirstSeen(firstSeenMs) {
                if (!firstSeenMs)
                    return ""
                return Qt.formatDateTime(new Date(firstSeenMs), "MM-dd HH:mm")
            }

            function _firstSeenForId(id, fallbackMs) {
                var resolved = Services.ClipboardService.firstSeenMsForId(id)
                return resolved || fallbackMs || 0
            }

            function _dayKey(firstSeenMs) {
                if (!firstSeenMs)
                    return ""
                return Qt.formatDateTime(new Date(firstSeenMs), "yyyy-MM-dd")
            }

            function _dayLabel(firstSeenMs) {
                if (!firstSeenMs)
                    return ""
                return Qt.formatDateTime(new Date(firstSeenMs), "MM-dd")
            }

            function _updatePreviewToItem(index, item) {
                if (!item || !_isPreviewable(item)) {
                    _clearPreview()
                    return
                }
                previewClearTimer.stop()
                clipRoot._previewActiveIndex = index
                clipRoot._pendingPreviewIndex = index
                clipRoot._pendingPreviewItem = item
                var targetWidth = _previewWidthFor(item)
                clipRoot._previewSlotWidth = targetWidth
                Services.IslandService.clipboardPreviewWidth = targetWidth
                var preview = clipPreviewLoader.item
                if (!preview) return
                preview.isImage = item.isImage
                preview.clipboardId = item.id
                preview.previewText = item.preview || ""
                preview.deferHeavyContent = clipRoot._deferPreviewContentUntilSettled
                preview.active = true
                preview.targetPreviewWidth = targetWidth
                Services.IslandService.clipboardPreviewWidth = targetWidth
            }

            function _refreshPreviewFromCurrentItem() {
                if (clipRoot._hoverActiveIndex >= 0)
                    return

                var items = clipRoot.allItems
                if (clipListView.currentIndex >= 0 && clipListView.currentIndex < items.length) {
                    clipRoot._previewActiveSource = "keyboard"
                    clipRoot._updatePreviewToItem(clipListView.currentIndex, items[clipListView.currentIndex])
                } else {
                    clipRoot._clearPreview()
                }
            }

            function _clearPreview() {
                previewClearTimer.stop()
                previewAutoloadTimer.stop()
                clipRoot._previewActiveIndex = -1
                clipRoot._previewActiveSource = ""
                clipRoot._pendingPreviewIndex = -1
                clipRoot._pendingPreviewItem = null
                var preview = clipPreviewLoader.item
                if (!preview) return
                preview.active = false
                preview.isImage = false
                preview.previewText = ""
                // targetPreviewWidth and _previewSlotWidth stay at clipRoot._previewWidth
                Qt.callLater(function() {
                    if (preview && !preview.active)
                        preview.clipboardId = ""
                })
            }

            on_PreviewSlotWidthChanged: {
                Services.IslandService.clipboardPreviewWidth = _previewSlotWidth
                _syncRestingListWidth()
            }

            Behavior on _previewSlotWidth {
                NumberAnimation {
                    duration: Services.Motion.number.contentDuration
                    easing.type: Services.Motion.number.contentEasing
                }
            }

            function _onDelegateHoverChanged(itemData, index, hovered) {
                if (hovered) {
                    previewClearTimer.stop()
                    clipRoot._hoverActiveIndex = index
                    if (clipRoot._isPreviewable(itemData)) {
                        clipRoot._previewActiveSource = "hover"
                        clipRoot._updatePreviewToItem(index, itemData)
                    } else {
                        clipRoot._clearPreview()
                    }
                }
            }

            function _updatePreviewFromListPosition(mouseX, mouseY) {
                previewClearTimer.stop()
                var idx = clipListView.indexAt(mouseX, mouseY + clipListView.contentY)
                if (idx < 0 || idx >= clipRoot.allItems.length) {
                    clipRoot._hoverActiveIndex = -1
                    previewClearTimer.restart()
                    return
                }

                var item = clipRoot.allItems[idx]
                clipRoot._hoverActiveIndex = idx
                if (clipRoot._isPreviewable(item)) {
                    clipRoot._previewActiveSource = "pointer"
                    clipRoot._updatePreviewToItem(idx, item)
                } else {
                    clipRoot._clearPreview()
                }
            }

            Timer {
                id: previewClearTimer
                interval: 350
                repeat: false
                onTriggered: {
                    if (clipRoot._hoverActiveIndex >= 0)
                        return
                    // Don't clear if the pointer is still over the preview panel.
                    var preview = clipPreviewLoader.item
                    if (preview && preview.hovered)
                        return
                    clipRoot._clearPreview()
                }
            }

            // Clear preview when the underlying clipboard items change.
            onAllItemsChanged: {
                clipRoot._hoverActiveIndex = -1
                clipRoot._clearPreview()
                // Trigger prewarm when items first arrive.
                Qt.callLater(function() {
                    clipListView.prewarmArmed = true
                })
            }

            Timer {
                id: previewSettleTimer
                interval: Services.Motion.number.contentDuration
                repeat: false
                onTriggered: {
                    clipRoot._deferPreviewContentUntilSettled = false
                    previewAutoloadTimer.restart()
                }
            }

            Timer {
                id: previewAutoloadTimer
                interval: Services.Motion.number.contentDuration
                repeat: false
                onTriggered: clipRoot._refreshPreviewFromCurrentItem()
            }

            function nextVisibleIndex(from, direction) {
                return clipListView.nextVisibleIndex(from, direction)
            }

            function positionViewAtIndex(index, mode) {
                clipListView.positionViewAtIndex(index, mode)
            }

            Item {
                x: clipRoot._outerInset + clipRoot._previewSlotWidth
                y: clipRoot._outerInset
                width: clipRoot._restingListWidth
                height: parent.height - clipRoot._outerInset * 2
                clip: false

                // Surface-level hover tracking over the whole Row (preview + list).
                // When the pointer is over the preview panel the preview's hovered
                // property is set so the clear timer skips it.  When the pointer
                // leaves the entire area the timer starts the linger-then-hide.
                MouseArea {
                    id: clipRowHover
                    x: -clipRoot._previewSlotWidth
                    y: 0
                    width: clipRoot._previewSlotWidth + clipRoot._restingListWidth
                    height: parent.height
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                    onPositionChanged: (mouse) => {
                        var isOverPreview = mouse.x < clipPreviewLoader.width
                        var preview = clipPreviewLoader.item
                        if (preview) preview.hovered = isOverPreview
                    }
                    onExited: {
                        clipRoot._hoverActiveIndex = -1
                        previewClearTimer.restart()
                        var preview = clipPreviewLoader.item
                        if (preview) preview.hovered = false
                    }
                }

                // Left-side preview panel for image or long-text items.
                Loader {
                    id: clipPreviewLoader
                    x: -width
                    height: parent.height
                    source: "../launcher/ClipboardPreview.qml"
                    width: clipRoot._previewSlotWidth
                    clip: false
                    visible: width > 1
                    z: 1
                    onLoaded: {
                        item.x = 0
                        item.y = 0
                        item.viewportHeight = Qt.binding(function() { return clipPreviewLoader.height })
                        item.targetPreviewWidth = Qt.binding(function() { return clipPreviewLoader.width })
                        if (clipRoot._pendingPreviewItem)
                            clipRoot._updatePreviewToItem(clipRoot._pendingPreviewIndex, clipRoot._pendingPreviewItem)
                    }
                }

                // Clipboard entry list fills remaining space.
                ListView {
                    id: clipListView
                    x: 0
                    width: clipRoot._restingListWidth
                    height: parent.height
                    clip: true
                    spacing: 0
                    property int prewarmCount: 16
                    property bool prewarmArmed: false
                    property int openStaggerStep: 28
                    property int openStaggerCount: 8
                    property int openRevealToken: 0
                    property bool openRevealArmed: false

                    function triggerOpenReveal() {
                        openRevealToken = root._openRevealToken
                        openRevealArmed = true
                        clipRoot._deferPreviewContentUntilSettled = true
                        previewSettleTimer.restart()
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

                    property var prewarmItems: {
                        const items = clipRoot.allItems
                        if (!items || items.length === 0) return []
                        return items.slice(0, Math.min(prewarmCount, items.length))
                    }

                    onQueryChanged: {
                        var items = clipRoot.allItems
                        for (var i = 0; i < items.length; i++) {
                            if (clipMatches(items[i], query)) {
                                clipListView.currentIndex = i
                                clipListView.positionViewAtBeginning()
                                return
                            }
                        }
                        clipListView.currentIndex = 0
                    }

                    // Keyboard selection updates the preview when no delegate is hovered.
                    onCurrentIndexChanged: {
                        if (clipRoot._hoverActiveIndex >= 0)
                            return

                        var items = clipRoot.allItems
                        if (currentIndex >= 0 && currentIndex < items.length
                            && clipRoot._isPreviewable(items[currentIndex])) {
                            clipRoot._previewActiveSource = "keyboard"
                            clipRoot._updatePreviewToItem(currentIndex, items[currentIndex])
                        } else {
                            clipRoot._clearPreview()
                        }
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
                        while (i >= 0 && i < clipRoot.allItems.length) {
                            if (clipMatches(clipRoot.allItems[i], query))
                                return i
                            i += step
                        }
                        return from
                    }

                    model: clipRoot.allItems

                    Component.onCompleted: Services.ClipboardService.list()

                    // Per-pixel position tracking over the list area.
                    // Exit/surface-level hover is handled by the Row's MouseArea
                    // so the pointer can move into the preview panel without
                    // triggering the clear timer.
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.NoButton
                        z: 100
                        onPositionChanged: (mouse) => clipRoot._updatePreviewFromListPosition(mouse.x, mouse.y)
                        onEntered: (mouse) => clipRoot._updatePreviewFromListPosition(mouse.x, mouse.y)
                    }

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

                        // Expose hover state for parent preview tracking.
                        property var hoverHandler: clipRoot._onDelegateHoverChanged
                        readonly property bool hovered: clipMouse.containsMouse

                        width: ListView.view ? ListView.view.width : 200
                        readonly property bool matchesFilter: clipListView.clipMatches(modelData, clipListView.query)
                        readonly property int resolvedFirstSeenMs: clipRoot._firstSeenForId(modelData.id, modelData.firstSeenMs)
                        readonly property int previousFirstSeenMs: index > 0
                            ? clipRoot._firstSeenForId(clipRoot.allItems[index - 1].id, clipRoot.allItems[index - 1].firstSeenMs)
                            : 0
                        readonly property bool showDayHeader: index === 0
                            || clipRoot._dayKey(resolvedFirstSeenMs)
                                !== clipRoot._dayKey(previousFirstSeenMs)
                        property bool _contentRevealVisible: true
                        property int _seenOpenRevealToken: 0
                        height: matchesFilter ? (showDayHeader ? 72 : 52) : 0
                        opacity: matchesFilter ? 1 : 0
                        x: matchesFilter ? 0 : 30
                        visible: height > 1 || opacity > 0.01
                        radius: MenuVisuals.rowRadius
                        color: (clipRoot._hoverActiveIndex === index)
                            || (clipRoot._hoverActiveIndex < 0 && clipListView.currentIndex === index)
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

                            Column {
                                anchors.fill: parent
                                anchors.leftMargin: MenuVisuals.listContentInset
                                anchors.rightMargin: MenuVisuals.listContentInset
                                anchors.topMargin: 2
                                spacing: 2

                                Item {
                                    width: parent.width
                                    height: clipDelegate.showDayHeader ? 16 : 0
                                    visible: clipDelegate.showDayHeader

                                    Rectangle {
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        height: 1
                                        color: Qt.rgba(Services.Color.mOutline.r, Services.Color.mOutline.g, Services.Color.mOutline.b, 0.35)
                                    }

                                    Services.FluidText {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: clipRoot._dayLabel(clipDelegate.resolvedFirstSeenMs)
                                        color: Services.Color.mOnSurfaceVariant
                                        basePixelSize: 10
                                        opacity: 0.9
                                    }
                                }

                                Services.FluidText {
                                    width: parent.width
                                    height: 30
                                    verticalAlignment: Text.AlignVCenter
                                    text: modelData.isImage ? "[Image]" : (modelData.preview || "")
                                    textFormat: Text.PlainText
                                    color: Services.Color.mOnSurface
                                    basePixelSize: 13
                                    elide: Text.ElideRight
                                }

                                Services.FluidText {
                                    width: parent.width
                                    height: 16
                                    verticalAlignment: Text.AlignVCenter
                                    horizontalAlignment: Text.AlignRight
                                    text: clipRoot._formatFirstSeen(clipDelegate.resolvedFirstSeenMs) + " | #" + modelData.id
                                    color: Services.Color.mOnSurfaceVariant
                                    basePixelSize: 10
                                    opacity: 0.72
                                    elide: Text.ElideLeft
                                }
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
                            // Notify parent about hover state changes for preview.
                            onContainsMouseChanged: {
                                if (typeof clipDelegate.hoverHandler === "function") {
                                    clipDelegate.hoverHandler(clipDelegate.modelData, clipDelegate.index, clipDelegate.hovered)
                                }
                            }
                        }
                    }

                    Timer {
                        id: openRevealResetTimer
                        interval: clipListView.openStaggerCount * clipListView.openStaggerStep + 260
                        repeat: false
                        onTriggered: clipListView.openRevealArmed = false
                    }

                    Item {
                        visible: false
                        opacity: 0
                        x: -10000
                        y: -10000

                        Repeater {
                            model: clipListView.prewarmArmed ? clipListView.prewarmItems : []

                            delegate: Item {
                                required property var modelData

                                width: 200
                                height: 52

                                Services.FluidText {
                                    anchors.left: parent.left
                                    anchors.top: parent.top
                                    width: 180
                                    height: 48
                                    verticalAlignment: Text.AlignVCenter
                                    text: modelData.isImage ? "[Image]" : (modelData.preview || "")
                                    textFormat: Text.PlainText
                                    color: Services.Color.mOnSurface
                                    basePixelSize: 13
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
