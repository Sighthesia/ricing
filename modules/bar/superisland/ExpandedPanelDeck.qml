import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import "." as SuperIslandParts

// Paged content deck rendered inside the expanded SuperIsland surface.
Item {
    id: root

    readonly property string currentPage: IslandOverlayService.mode || "launcher"
    property string _presentedPage: root.currentPage

    function _activatePage(pageName) {
        if (pageName === "launcher" && launcherPageLoader.item) {
            launcherPageLoader.item.pageActivated()
            return
        }

        if (pageName === "settings" && settingsPageLoader.item) {
            settingsPageLoader.item.pageActivated()
            return
        }

        if (pageName === "notifications" && notificationsPageLoader.item)
            notificationsPageLoader.item.pageActivated()
    }

    function _deactivatePage(pageName) {
        if (pageName === "launcher" && launcherPageLoader.item) {
            launcherPageLoader.item.pageDeactivated()
            return
        }

        if (pageName === "settings" && settingsPageLoader.item) {
            settingsPageLoader.item.pageDeactivated()
            return
        }

        if (pageName === "notifications" && notificationsPageLoader.item)
            notificationsPageLoader.item.pageDeactivated()
    }

    function _retargetPage(pageName) {
        if (!pageName || pageName === root.currentPage)
            return

        IslandOverlayService.retargetOverlay(pageName, IslandOverlayService.modePayload)
    }

    Component.onCompleted: {
        root._presentedPage = root.currentPage
        Qt.callLater(function() {
            root._activatePage(root._presentedPage)
        })
    }

    Component.onDestruction: root._deactivatePage(root._presentedPage)

    Connections {
        target: IslandOverlayService

        function onModeChanged() {
            let nextPage = IslandOverlayService.mode || "launcher"
            let previousPage = root._presentedPage

            if (nextPage === previousPage)
                return

            root._deactivatePage(previousPage)
            root._presentedPage = nextPage

            Qt.callLater(function() {
                root._activatePage(nextPage)
            })
        }

    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.cornerRadius
        color: Qt.rgba(Colors.background.r, Colors.background.g, Colors.background.b, 0.22)
        border.color: Qt.rgba(Colors.border.r, Colors.border.g, Colors.border.b, 0.5)
        border.width: 1
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 0

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 30
                radius: 11
                color: Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 0.38)
                border.color: Colors.border
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 0
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

            Item { Layout.fillWidth: true }

            Rectangle {
                width: 28
                height: 28
                radius: Theme.cornerRadius - 2
                color: _closeArea.containsMouse ? Colors.surface : "transparent"
                border.color: _closeArea.containsMouse ? Colors.border : "transparent"
                border.width: 1

                Behavior on color {
                    ColorAnimation { duration: Theme.anim.highlightDuration }
                }

                Behavior on border.color {
                    ColorAnimation { duration: Theme.anim.highlightDuration }
                }

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

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

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
        }
    }
}
