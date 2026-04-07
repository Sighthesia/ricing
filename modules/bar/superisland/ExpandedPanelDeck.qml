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

    readonly property string currentPage: IslandOverlayService.mode || "launcher"
    readonly property bool _showChrome: root._presentedPage !== "break-reminder"
    readonly property bool _fullScreenPage: root._presentedPage === "break-reminder"
    readonly property real _deckMargins: root._fullScreenPage ? 0 : 12
    readonly property real _deckSpacing: root._fullScreenPage ? 0 : 10
    property string _presentedPage: root.currentPage
    property string _pendingPage: ""

    function _showHeaderForPage(pageName) {
        return pageName !== "break-reminder"
    }

    function _pageItem(pageName) {
        if (pageName === "control-center")
            return controlCenterPageLoader.item
        if (pageName === "launcher")
            return launcherPageLoader.item
        if (pageName === "settings")
            return settingsPageLoader.item
        if (pageName === "notifications")
            return notificationsPageLoader.item
        if (pageName === "break-reminder")
            return breakReminderPageLoader.item
        return null
    }

    function _pageExitDuration(pageName) {
        let pageItem = root._pageItem(pageName)
        if (pageItem && typeof pageItem.pageExitDuration === "function")
            return Math.max(0, pageItem.pageExitDuration())

        return SettingsService.data.animation.staggerExitDuration
    }

    function _runDeckEnter(includeHeader) {
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
        root._runDeckEnter(includeHeader)

        if (pageName === "control-center" && controlCenterPageLoader.item) {
            controlCenterPageLoader.item.pageActivated()
            return
        }

        if (pageName === "launcher" && launcherPageLoader.item) {
            launcherPageLoader.item.pageActivated()
            return
        }

        if (pageName === "settings" && settingsPageLoader.item) {
            settingsPageLoader.item.pageActivated()
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
        if (includeHeader)
            _deckStagger.runExit()

        if (pageName === "control-center" && controlCenterPageLoader.item) {
            controlCenterPageLoader.item.pageDeactivated()
            return
        }

        if (pageName === "launcher" && launcherPageLoader.item) {
            launcherPageLoader.item.pageDeactivated()
            return
        }

        if (pageName === "settings" && settingsPageLoader.item) {
            settingsPageLoader.item.pageDeactivated()
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
        Qt.callLater(function() {
            root._activatePage(root._presentedPage, root._showHeaderForPage(root._presentedPage))
        })
    }

    Component.onDestruction: root._deactivatePage(
        root._presentedPage,
        root._showHeaderForPage(root._presentedPage)
    )

    Connections {
        target: IslandOverlayService

        function onModeChanged() {
            let nextPage = IslandOverlayService.mode || "launcher"
            let previousPage = root._presentedPage

            if (nextPage === previousPage)
                return

            root._pendingPage = nextPage
            root._deactivatePage(previousPage, false)
            _pageSwitchDelay.interval = root._pageExitDuration(previousPage)
            _pageSwitchDelay.restart()
        }

    }

    Timer {
        id: _pageSwitchDelay
        repeat: false
        interval: SettingsService.data.animation.staggerExitDuration

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
            spacing: 10

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
                Layout.preferredWidth: Math.round(420 * Theme.uiScale)
                Layout.preferredHeight: 30
                implicitWidth: _navRow.implicitWidth
                implicitHeight: _navRow.implicitHeight

                RowLayout {
                    id: _navRow
                    anchors.fill: parent
                    spacing: 0

                    SuperIslandParts.SuperIslandOverlayNavButton {
                        Layout.fillWidth: true
                        label: "中控"
                        iconGlyph: "\uf085"
                        selected: root.currentPage === "control-center"
                        firstSegment: true
                        onPressed: root._retargetPage("control-center")
                    }

                    SuperIslandParts.SuperIslandOverlayNavButton {
                        Layout.fillWidth: true
                        label: "启动器"
                        iconGlyph: "\uf002"
                        selected: root.currentPage === "launcher"
                        onPressed: root._retargetPage("launcher")
                    }

                    SuperIslandParts.SuperIslandOverlayNavButton {
                        Layout.fillWidth: true
                        label: "设置"
                        iconGlyph: "\uf013"
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
                Layout.preferredWidth: Math.round(102 * Theme.uiScale)
                Layout.preferredHeight: 30
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
                        IslandOverlayService.closeOverlay("session-control")
                    }
                }
            }

            BarComponents.StaggerItem {
                id: _closeItem
                width: 28
                height: 28

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
                    id: controlCenterPageLoader
                    active: true
                    anchors.fill: parent
                    visible: root._presentedPage === "control-center"
                    source: "ExpandedControlCenterPage.qml"
                }

                Loader {
                    id: launcherPageLoader
                    active: true
                    anchors.fill: parent
                    visible: root._presentedPage === "launcher"
                    source: "ExpandedLauncherPage.qml"
                }

                Loader {
                    id: settingsPageLoader
                    active: true
                    anchors.fill: parent
                    visible: root._presentedPage === "settings"
                    source: "ExpandedSettingsPage.qml"
                }

                Loader {
                    id: notificationsPageLoader
                    active: true
                    anchors.fill: parent
                    visible: root._presentedPage === "notifications"
                    source: "ExpandedNotificationsPage.qml"
                }

                Loader {
                    id: breakReminderPageLoader
                    active: true
                    anchors.fill: parent
                    visible: root._presentedPage === "break-reminder"
                    source: "ExpandedBreakReminderPage.qml"
                }
            }
        }
    }
}
