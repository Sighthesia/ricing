import Quickshell
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import ".." as BarComponents
import "." as SuperIslandParts

// Paged content deck rendered inside the expanded SuperIsland surface.
Item {
    id: root

    property bool drawSurface: true
    property bool measurementMode: false
    property bool activatePages: !measurementMode

    readonly property string currentPage: IslandOverlayService.mode || "launcher"
    readonly property bool _showChrome:
        root._presentedPage !== "break-reminder"
        && root._presentedPage !== "session-control"
    readonly property bool _fullScreenPage:
        root._presentedPage === "break-reminder"
        || root._presentedPage === "session-control"
    readonly property real _deckMargins: root._fullScreenPage ? 0 : ThemeSuperIsland.expandedDeckMargin
    readonly property real _deckSpacing: root._fullScreenPage ? 0 : ThemeSuperIsland.expandedDeckSpacing
    readonly property real _headerHeight:
        root._showChrome
            ? Math.max(
                _clockItem.implicitHeight,
                _navItem.implicitHeight,
                _sessionItem.implicitHeight,
                _closeItem.height
            )
            : 0
    readonly property real _contentHeight: {
        return root.measurementMode
            ? root._measurePageHeight(root._presentedPage)
            : root._targetContentHeight
    }
    property string _presentedPage: root.currentPage
    property string _pendingPage: ""
    property real _targetContentHeight: root._measurePageHeight(root._presentedPage)

    implicitHeight:
        root._deckMargins * 2
        + root._contentHeight
        + (root._showChrome
            ? (root._headerHeight + root._deckSpacing + 1 + root._deckSpacing)
            : 0)

    Behavior on _targetContentHeight {
        NumberAnimation {
            duration: Math.max(1, SettingsService.effectiveAnimation.staggerExitDuration)
            easing.type: Theme.anim.moveType
        }
    }

    function _showHeaderForPage(pageName) {
        return pageName !== "break-reminder" && pageName !== "session-control"
    }

    function _pageItem(pageName) {
        if (!root.measurementMode && !root.activatePages)
            return null

        if (pageName === "launcher")
            return launcherPageLoader.item
        if (pageName === "settings")
            return settingsPageLoader.item
        if (pageName === "control-center")
            return controlCenterPageLoader.item
        if (pageName === "session-control")
            return sessionControlPageLoader.item
        if (pageName === "notifications")
            return notificationsPageLoader.item
        if (pageName === "break-reminder")
            return breakReminderPageLoader.item
        return null
    }

    function _measurePageHeight(pageName) {
        let pageItem = root._pageItem(pageName)
        return pageItem ? pageItem.implicitHeight : 0
    }

    function _pageExitDuration(pageName) {
        let pageItem = root._pageItem(pageName)
        if (pageItem && typeof pageItem.pageExitDuration === "function")
            return Math.max(0, pageItem.pageExitDuration())

        return SettingsService.effectiveAnimation.staggerExitDuration
    }

    function _runDeckEnter(includeHeader) {
        if (root.measurementMode)
            return

        _deckStagger.clear()
        if (includeHeader) {
            _deckStagger.registerItem(_clockItem, 0, 1)
            _deckStagger.registerItem(_navItem, 1, 1)
            _deckStagger.registerItem(_sessionItem, 2, 1)
            _deckStagger.registerItem(_closeItem, 3, 1)
            _deckStagger.registerItem(_dividerItem, 4, 1)
        }
        _deckStagger.registerItem(_contentItem, 0, 2)
        _deckStagger.runEnter()
    }

    function _activatePage(pageName, includeHeader) {
        if (!root.activatePages)
            return

        root._runDeckEnter(includeHeader)

        if (root.measurementMode)
            return

        if (pageName === "launcher" && launcherPageLoader.item) {
            launcherPageLoader.item.pageActivated()
            return
        }

        if (pageName === "settings" && settingsPageLoader.item) {
            settingsPageLoader.item.pageActivated()
            return
        }

        if (pageName === "control-center" && controlCenterPageLoader.item) {
            controlCenterPageLoader.item.pageActivated()
            return
        }

        if (pageName === "session-control" && sessionControlPageLoader.item) {
            sessionControlPageLoader.item.pageActivated()
            return
        }

        if (pageName === "notifications" && notificationsPageLoader.item) {
            notificationsPageLoader.item.pageActivated()
            return
        }

        if (pageName === "break-reminder" && breakReminderPageLoader.item)
            breakReminderPageLoader.item.pageActivated()
    }

    function _deactivatePage(pageName, includeHeader) {
        if (!root.activatePages)
            return

        if (includeHeader)
            _deckStagger.runExit()

        if (root.measurementMode)
            return

        if (pageName === "launcher" && launcherPageLoader.item) {
            launcherPageLoader.item.pageDeactivated()
            return
        }

        if (pageName === "settings" && settingsPageLoader.item) {
            settingsPageLoader.item.pageDeactivated()
            return
        }

        if (pageName === "control-center" && controlCenterPageLoader.item) {
            controlCenterPageLoader.item.pageDeactivated()
            return
        }

        if (pageName === "session-control" && sessionControlPageLoader.item) {
            sessionControlPageLoader.item.pageDeactivated()
            return
        }

        if (pageName === "notifications" && notificationsPageLoader.item) {
            notificationsPageLoader.item.pageDeactivated()
            return
        }

        if (pageName === "break-reminder" && breakReminderPageLoader.item)
            breakReminderPageLoader.item.pageDeactivated()
    }

    function _retargetPage(pageName) {
        if (!pageName || pageName === root.currentPage)
            return

        IslandOverlayService.retargetOverlay(pageName, IslandOverlayService.modePayload)
    }

    Component.onCompleted: {
        root._presentedPage = root.currentPage
        if (root.measurementMode || !root.activatePages)
            return

        Qt.callLater(function() {
            root._activatePage(root._presentedPage, root._showHeaderForPage(root._presentedPage))
        })
    }

    Component.onDestruction: {
        if (root.measurementMode || !root.activatePages)
            return

        root._deactivatePage(
            root._presentedPage,
            root._showHeaderForPage(root._presentedPage)
        )
    }

    Connections {
        target: IslandOverlayService

        function onModeChanged() {
            if (root.measurementMode) {
                root._presentedPage = IslandOverlayService.mode || "launcher"
                root._pendingPage = ""
                root._targetContentHeight = root._measurePageHeight(root._presentedPage)
                return
            }

            if (!root.activatePages) {
                root._presentedPage = IslandOverlayService.mode || "launcher"
                root._pendingPage = ""
                root._targetContentHeight = root._measurePageHeight(root._presentedPage)
                return
            }

            let nextPage = IslandOverlayService.mode || "launcher"
            let previousPage = root._presentedPage

            if (nextPage === previousPage)
                return

            root._pendingPage = nextPage
            root._targetContentHeight = root._measurePageHeight(nextPage)
            root._deactivatePage(previousPage, false)
            _pageSwitchDelay.interval = root._pageExitDuration(previousPage)
            _pageSwitchDelay.restart()
        }

    }

    Timer {
        id: _pageSwitchDelay
        repeat: false
        interval: SettingsService.effectiveAnimation.staggerExitDuration

        onTriggered: {
            if (!root._pendingPage)
                return

            root._presentedPage = root._pendingPage
            root._pendingPage = ""

            Qt.callLater(function() {
                root._activatePage(root._presentedPage, root._showHeaderForPage(root._presentedPage))
            })
        }
    }

    BarComponents.StaggerOrchestrator {
        id: _deckStagger
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.cornerRadius
        color: Qt.rgba(Colors.background.r, Colors.background.g, Colors.background.b, 0.22)
        border.color: Qt.rgba(Colors.border.r, Colors.border.g, Colors.border.b, 0.5)
        border.width: 1
        visible: root.drawSurface
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: root._deckMargins
        spacing: root._deckSpacing

        RowLayout {
            visible: root._showChrome
            Layout.fillWidth: true
            Layout.preferredHeight: visible ? implicitHeight : 0
            spacing: ThemeSuperIsland.expandedDeckSpacing

            BarComponents.StaggerItem {
                id: _clockItem
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: _clockLabel.implicitWidth
                implicitHeight: _clockLabel.implicitHeight

                Text {
                    id: _clockLabel
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeBody
                    font.bold: true
                    color: Colors.text
                }
            }

            Item { Layout.fillWidth: true }

            BarComponents.StaggerItem {
                id: _navItem
                Layout.preferredWidth: ThemeSuperIsland.expandedDeckNavWidth
                Layout.preferredHeight: ThemeSuperIsland.expandedDeckNavHeight
                implicitWidth: _navRow.implicitWidth
                implicitHeight: _navRow.implicitHeight

                RowLayout {
                    id: _navRow
                    anchors.fill: parent
                    spacing: 0

                    SuperIslandParts.SuperIslandOverlayNavButton {
                        Layout.fillWidth: true
                        label: "启动器"
                        iconGlyph: "\uf002"
                        selected: root.currentPage === "launcher"
                        firstSegment: true
                        onPressed: root._retargetPage("launcher")
                    }

                    SuperIslandParts.SuperIslandOverlayNavButton {
                        Layout.fillWidth: true
                        label: "控制中心"
                        iconGlyph: "\uf013"
                        selected: root.currentPage === "control-center"
                        onPressed: root._retargetPage("control-center")
                    }

                    SuperIslandParts.SuperIslandOverlayNavButton {
                        Layout.fillWidth: true
                        label: "设置"
                        iconGlyph: "\uf085"
                        selected: root.currentPage === "settings"
                        onPressed: root._retargetPage("settings")
                    }

                    SuperIslandParts.SuperIslandOverlayNavButton {
                        Layout.fillWidth: true
                        label: "通知"
                        iconGlyph: "\uf0f3"
                        selected: root.currentPage === "notifications"
                        lastSegment: true
                        onPressed: root._retargetPage("notifications")
                    }
                }
            }

            BarComponents.StaggerItem {
                id: _sessionItem
                Layout.preferredWidth: ThemeSuperIsland.expandedDeckSessionWidth
                Layout.preferredHeight: ThemeSuperIsland.expandedDeckNavHeight
                implicitWidth: _sessionButton.implicitWidth
                implicitHeight: _sessionButton.implicitHeight

                SuperIslandParts.SuperIslandOverlayNavButton {
                    id: _sessionButton
                    anchors.fill: parent
                    label: "电源"
                    iconGlyph: "\uf011"
                    firstSegment: true
                    lastSegment: true
                    onPressed: {
                        SessionControlService.openSessionControl("super-island")
                    }
                }
            }

            BarComponents.StaggerItem {
                id: _closeItem
                width: ThemeSuperIsland.expandedDeckCloseSize
                height: ThemeSuperIsland.expandedDeckCloseSize

                Text {
                    anchors.centerIn: parent
                    text: "✕"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    color: Colors.text
                }

                MouseArea {
                    id: _closeArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: IslandOverlayService.closeOverlay("deck-close")
                }
            }
        }

        BarComponents.StaggerItem {
            id: _dividerItem
            visible: root._showChrome
            Layout.fillWidth: true
            Layout.preferredHeight: visible ? 1 : 0

            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: Qt.rgba(Colors.border.r, Colors.border.g, Colors.border.b, 0.65)
            }
        }

        BarComponents.StaggerItem {
            id: _contentItem
            Layout.fillWidth: true
            Layout.fillHeight: true

            Item {
                anchors.fill: parent

                Loader {
                    id: launcherPageLoader
                    active: root.measurementMode || (root.activatePages && root._presentedPage === "launcher")
                    anchors.fill: parent
                    visible: root._presentedPage === "launcher"
                    source: "ExpandedLauncherPage.qml"
                }

                Loader {
                    id: settingsPageLoader
                    active: root.measurementMode || (root.activatePages && root._presentedPage === "settings")
                    anchors.fill: parent
                    visible: root._presentedPage === "settings"
                    source: "ExpandedSettingsPage.qml"
                }

                Loader {
                    id: controlCenterPageLoader
                    active: root.measurementMode || (root.activatePages && root._presentedPage === "control-center")
                    anchors.fill: parent
                    visible: root._presentedPage === "control-center"
                    source: "ExpandedControlCenterPage.qml"
                }

                Loader {
                    id: notificationsPageLoader
                    active: root.measurementMode || (root.activatePages && root._presentedPage === "notifications")
                    anchors.fill: parent
                    visible: root._presentedPage === "notifications"
                    source: "ExpandedNotificationsPage.qml"
                }

                Loader {
                    id: sessionControlPageLoader
                    active: root.measurementMode || (root.activatePages && root._presentedPage === "session-control")
                    anchors.fill: parent
                    visible: root._presentedPage === "session-control"
                    source: "ExpandedSessionControlPage.qml"
                }

                Loader {
                    id: breakReminderPageLoader
                    active: root.measurementMode || (root.activatePages && root._presentedPage === "break-reminder")
                    anchors.fill: parent
                    visible: root._presentedPage === "break-reminder"
                    source: "ExpandedBreakReminderPage.qml"
                }
            }
        }
    }
}
