import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import "../bar/MenuVisuals.js" as MenuVisuals
import "../../services" as Services

// Expanded island content: search input + app list or clipboard list.
Item {
    id: root

    property bool compact: false
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
            } else {
                root.clearSearchFocus()
            }
        }

        function onPanelPageChanged() {
            if (root.focusAllowed) {
                root.focusSearchWhenReady()
            } else {
                root.clearSearchFocus()
            }
        }

        function onQueryChanged() {
            if (root.focusAllowed && Services.IslandService.query.startsWith(">clip ")) {
                root.focusSearchWhenReady()
            }
        }
    }

    onFocusAllowedChanged: {
        if (focusAllowed)
            focusSearchWhenReady()
        else
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
            color: Qt.rgba(Services.Color.mOnSurface.r, Services.Color.mOnSurface.g, Services.Color.mOnSurface.b, MenuVisuals.hoverOpacity)

            TextInput {
                id: searchInput
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                verticalAlignment: TextInput.AlignVCenter
                color: Services.Color.mOnSurface
                font.family: Services.SettingsService.appearance.fontDefault || Qt.application.font.family
                font.pixelSize: Math.round(14 * (Services.SettingsService.appearance.fontDefaultScale || 1.0))
                text: Services.IslandService.query
                onTextChanged: {
                    Services.IslandService.query = text
                    if (text.trim().length > 0)
                        Services.IslandService.openPage("launcher")
                }
                focus: root.focusAllowed
                Keys.onEscapePressed: Services.IslandService.close()

                // Navigate list with Up/Down keys.
                Keys.onUpPressed: {
                    var loader = Services.IslandService.mode === "clipboard" ? clipLoader : appLoader
                    if (loader.item && loader.item.count > 0) {
                        loader.item.currentIndex = loader.item.nextVisibleIndex(loader.item.currentIndex, "up")
                    }
                }
                Keys.onDownPressed: {
                    var loader = Services.IslandService.mode === "clipboard" ? clipLoader : appLoader
                    if (loader.item && loader.item.count > 0) {
                        loader.item.currentIndex = loader.item.nextVisibleIndex(loader.item.currentIndex, "down")
                    }
                }
                Keys.onReturnPressed: {
                    var loader = Services.IslandService.mode === "clipboard" ? clipLoader : appLoader
                    var listView = loader.item
                    if (listView) {
                        var idx = listView.currentIndex
                        if (Services.IslandService.mode === "clipboard") {
                            var items = listView.allItems
                            if (idx >= 0 && idx < items.length) {
                                Services.ClipboardService.copyItem(items[idx].id)
                                Services.IslandService.close()
                            }
                        } else {
                            var apps = listView.sortedApps
                            if (idx >= 0 && idx < apps.length) {
                                Services.LaunchCountService.recordLaunch(apps[idx].id || "")
                                apps[idx].execute()
                                Services.IslandService.close()
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

        // Results area.
        Item {
            anchors.left: parent.left
            anchors.right: parent.right
            height: root.height - searchBar.height - 8
            clip: true

            // App list mode.
            Loader {
                id: appLoader
                anchors.fill: parent
                active: Services.IslandService.mode === "apps"
                sourceComponent: islandAppList

                onLoaded: {
                    if (item && Services.IslandService.query.trim().length === 0) {
                        item.currentIndex = 0
                    }
                }
            }

            // Clipboard mode.
            Loader {
                id: clipLoader
                anchors.fill: parent
                active: Services.IslandService.mode === "clipboard"
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
                var q = Services.IslandService.query.toLowerCase()
                if (q.startsWith(">")) return ""
                return q
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

            property var sortedApps: {
                const all = DesktopEntries.applications.values
                if (!all || all.length === 0) return []
                return all.slice().sort((a, b) => {
                    const ca = Services.LaunchCountService.getLaunchCount(a.id || "")
                    const cb = Services.LaunchCountService.getLaunchCount(b.id || "")
                    return cb - ca
                })
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
                    NumberAnimation { property: "_filterSoftness"; from: 1; to: 0; duration: 220; easing.type: Easing.OutCubic }
                }
            }

            remove: Transition {
                ParallelAnimation {
                    NumberAnimation { property: "opacity"; to: 0; duration: 150; easing.type: Easing.InCubic }
                    NumberAnimation { property: "x"; to: 30; duration: 180; easing.type: Easing.InCubic }
                    NumberAnimation { property: "_filterSoftness"; to: 1; duration: 180; easing.type: Easing.InCubic }
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
                property real _filterSoftness: matchesFilter ? 0 : 1

                width: ListView.view ? ListView.view.width : 200
                height: matchesFilter ? 52 : 0
                opacity: matchesFilter ? 1 : 0
                x: matchesFilter ? 0 : 30
                visible: height > 1 || opacity > 0.01
                radius: MenuVisuals.rowRadius
                layer.enabled: _filterSoftness > 0.01
                layer.effect: MultiEffect {
                    blurEnabled: true
                    blurMax: 14
                    blur: appDelegate._filterSoftness * 0.42
                }
                color: delegateMouse.containsMouse || ListView.view.currentIndex === index
                    ? Qt.rgba(Services.Color.mOnSurface.r, Services.Color.mOnSurface.g, Services.Color.mOnSurface.b, MenuVisuals.hoverOpacity)
                    : "transparent"

                Behavior on height { NumberAnimation { duration: 220; easing.type: Easing.InOutCubic } }
                Behavior on x { NumberAnimation { duration: 190; easing.type: appDelegate.matchesFilter ? Easing.OutCubic : Easing.InCubic } }
                Behavior on opacity { NumberAnimation { duration: 190; easing.type: appDelegate.matchesFilter ? Easing.OutCubic : Easing.InCubic } }
                Behavior on _filterSoftness { NumberAnimation { duration: 190; easing.type: appDelegate.matchesFilter ? Easing.OutCubic : Easing.InCubic } }

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
                    NumberAnimation { property: "_filterSoftness"; from: 1; to: 0; duration: 220; easing.type: Easing.OutCubic }
                }
            }

            remove: Transition {
                ParallelAnimation {
                    NumberAnimation { property: "opacity"; to: 0; duration: 150; easing.type: Easing.InCubic }
                    NumberAnimation { property: "x"; to: 30; duration: 180; easing.type: Easing.InCubic }
                    NumberAnimation { property: "_filterSoftness"; to: 1; duration: 180; easing.type: Easing.InCubic }
                }
            }

            displaced: Transition {
                NumberAnimation { properties: "x,y"; duration: 220; easing.type: Easing.OutCubic }
            }

            delegate: Rectangle {
                id: clipDelegate

                required property var modelData
                required property int index
                readonly property bool matchesFilter: clipListView.clipMatches(modelData, clipListView.query)
                property real _filterSoftness: matchesFilter ? 0 : 1

                width: ListView.view ? ListView.view.width : 200
                height: matchesFilter ? 52 : 0
                opacity: matchesFilter ? 1 : 0
                x: matchesFilter ? 0 : 30
                visible: height > 1 || opacity > 0.01
                radius: MenuVisuals.rowRadius
                layer.enabled: _filterSoftness > 0.01
                layer.effect: MultiEffect {
                    blurEnabled: true
                    blurMax: 14
                    blur: clipDelegate._filterSoftness * 0.42
                }
                color: clipMouse.containsMouse || clipListView.currentIndex === index
                    ? Qt.rgba(Services.Color.mOnSurface.r, Services.Color.mOnSurface.g, Services.Color.mOnSurface.b, MenuVisuals.hoverOpacity)
                    : "transparent"

                Behavior on height { NumberAnimation { duration: 220; easing.type: Easing.InOutCubic } }
                Behavior on x { NumberAnimation { duration: 190; easing.type: clipDelegate.matchesFilter ? Easing.OutCubic : Easing.InCubic } }
                Behavior on opacity { NumberAnimation { duration: 190; easing.type: clipDelegate.matchesFilter ? Easing.OutCubic : Easing.InCubic } }
                Behavior on _filterSoftness { NumberAnimation { duration: 190; easing.type: clipDelegate.matchesFilter ? Easing.OutCubic : Easing.InCubic } }

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
        }
    }
}
