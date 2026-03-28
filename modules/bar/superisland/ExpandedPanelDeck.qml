import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import "." as SuperIslandParts

// Paged content deck rendered inside the expanded SuperIsland surface.
Item {
    id: root

    readonly property string currentPage: IslandOverlayService.mode || "launcher"
    readonly property string _title: root._pageMeta(root.currentPage).title
    readonly property string _subtitle: root._pageMeta(root.currentPage).subtitle

    property string _presentedPage: root.currentPage

    function _pageMeta(pageName) {
        switch (pageName) {
        case "settings":
            return {
                title: "设置面板",
                subtitle: "让扩展后的 SuperIsland 直接承载配置入口，而不是再弹一个独立窗。"
            }
        case "notifications":
            return {
                title: "通知中心",
                subtitle: "消息历史、勿扰切换和通知状态都留在岛内完成。"
            }
        case "launcher":
        default:
            return {
                title: "启动器",
                subtitle: "更大的岛面直接容纳搜索、结果和快捷入口。"
            }
        }
    }

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
        anchors.margins: 14
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                Text {
                    text: root._title
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeBody + 3
                    font.weight: Font.DemiBold
                    color: Colors.text
                }

                Text {
                    Layout.fillWidth: true
                    text: root._subtitle
                    wrapMode: Text.WordWrap
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    color: Colors.textMuted
                }
            }

            Rectangle {
                width: 30
                height: 30
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
                    font.pixelSize: Theme.fontSizeBody
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

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 12

            Rectangle {
                Layout.preferredWidth: 176
                Layout.fillHeight: true
                radius: Theme.cornerRadius
                color: Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 0.44)
                border.color: Colors.border
                border.width: 1

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 8

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
                        onPressed: root._retargetPage("notifications")
                    }

                    Item { Layout.fillHeight: true }
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
                    sourceComponent: _launcherPageComponent
                }

                Loader {
                    id: settingsPageLoader
                    active: true
                    anchors.fill: parent
                    visible: root._presentedPage === "settings"
                    sourceComponent: _settingsPageComponent
                }

                Loader {
                    id: notificationsPageLoader
                    active: true
                    anchors.fill: parent
                    visible: root._presentedPage === "notifications"
                    sourceComponent: _notificationsPageComponent
                }
            }
        }
    }

    Component {
        id: _launcherPageComponent

        SuperIslandParts.ExpandedLauncherPage {}
    }

    Component {
        id: _settingsPageComponent

        SuperIslandParts.ExpandedSettingsPage {}
    }

    Component {
        id: _notificationsPageComponent

        SuperIslandParts.ExpandedNotificationsPage {}
    }
}
