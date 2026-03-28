import QtQuick
import QtQuick.Layouts
import qs.config
import ".." as BarComponents

// Expanded launcher page shown inside the larger SuperIsland overlay.
Item {
    id: root

    readonly property string _todayLabel: Qt.formatDateTime(new Date(), "M月d日 ddd")

    function pageActivated() {
        _railStagger.clear()
        _railStagger.registerItem(_heroCard, 0, 1)
        _railStagger.registerItem(_shortcutCard, 1, 1)
        if (_launcherCoreLoader.item && _launcherCoreLoader.item.openPanel)
            _launcherCoreLoader.item.openPanel()
        if (_launcherCoreLoader.item && _launcherCoreLoader.item.runStructuralEnter)
            _launcherCoreLoader.item.runStructuralEnter()
        _railStagger.runEnter()
    }

    function pageDeactivated() {
        _railStagger.clear()
        _railStagger.registerItem(_heroCard, 0, 1)
        _railStagger.registerItem(_shortcutCard, 1, 1)
        if (_launcherCoreLoader.item && _launcherCoreLoader.item.runStructuralExit)
            _launcherCoreLoader.item.runStructuralExit()
        _railStagger.runExit()
        if (_launcherCoreLoader.item && _launcherCoreLoader.item.closePanel)
            _launcherCoreLoader.item.closePanel()
    }

    function _activatePresetQuery(queryText) {
        if (_launcherCoreLoader.item && _launcherCoreLoader.item.setQueryText)
            _launcherCoreLoader.item.setQueryText(queryText)
    }

    BarComponents.StaggerOrchestrator {
        id: _railStagger
    }

    RowLayout {
        anchors.fill: parent
        spacing: 16

        ColumnLayout {
            Layout.preferredWidth: 250
            Layout.fillHeight: true
            spacing: 16

            BarComponents.StaggerItem {
                id: _heroCard
                Layout.fillWidth: true
                Layout.preferredHeight: 244
                delay: 0
                enterOffsetY: 20
                exitOffsetY: 10

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.cornerRadius
                    gradient: Gradient {
                        GradientStop {
                            position: 0.0
                            color: Qt.rgba(Colors.highlight.r, Colors.highlight.g, Colors.highlight.b, 0.20)
                        }
                        GradientStop {
                            position: 1.0
                            color: Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 0.92)
                        }
                    }
                    border.color: Qt.rgba(Colors.highlight.r, Colors.highlight.g, Colors.highlight.b, 0.25)
                    border.width: 1

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 18
                        spacing: 10

                        Text {
                            text: "启动器"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeBody + 8
                            font.weight: Font.DemiBold
                            color: Colors.text
                        }

                        Text {
                            text: root._todayLabel
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            color: Colors.highlight
                        }

                        Text {
                            Layout.fillWidth: true
                            text: "把应用搜索、命令入口和剪贴板检索都收进同一个扩展岛里。"
                            wrapMode: Text.WordWrap
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            color: Colors.textMuted
                        }

                        Item { Layout.fillHeight: true }

                        Text {
                            Layout.fillWidth: true
                            text: "回车启动，方向键切换，`>clip` 直接切到剪贴板模式。"
                            wrapMode: Text.WordWrap
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeSmall
                            color: Colors.text
                        }
                    }
                }
            }

            BarComponents.StaggerItem {
                id: _shortcutCard
                Layout.fillWidth: true
                Layout.fillHeight: true
                delay: 80
                enterOffsetY: 20
                exitOffsetY: 10

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.cornerRadius
                    color: Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 0.78)
                    border.color: Colors.border
                    border.width: 1

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 10

                        Text {
                            text: "快速入口"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeBody
                            font.weight: Font.Medium
                            color: Colors.text
                        }

                        Repeater {
                            model: [
                                {
                                    label: "应用搜索",
                                    subtitle: "从桌面条目直接启动",
                                    query: "",
                                    icon: "\uf002"
                                },
                                {
                                    label: "剪贴板",
                                    subtitle: "继续查找最近复制内容",
                                    query: ">clip ",
                                    icon: "\uf0ea"
                                }
                            ]

                            delegate: Rectangle {
                                required property var modelData

                                Layout.fillWidth: true
                                implicitHeight: 60
                                radius: Theme.cornerRadius - 2
                                color: _actionArea.containsMouse
                                    ? Qt.rgba(Colors.highlight.r, Colors.highlight.g, Colors.highlight.b, 0.12)
                                    : Qt.rgba(Colors.background.r, Colors.background.g, Colors.background.b, 0.32)
                                border.color: _actionArea.containsMouse ? Colors.highlight : Colors.border
                                border.width: 1

                                Behavior on color {
                                    ColorAnimation { duration: Theme.anim.highlightDuration }
                                }

                                Behavior on border.color {
                                    ColorAnimation { duration: Theme.anim.highlightDuration }
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    spacing: 10

                                    Text {
                                        text: modelData.icon
                                        font.family: Theme.fontMono
                                        font.pixelSize: Theme.fontSizeSmall + 2
                                        color: Colors.highlight
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 2

                                        Text {
                                            Layout.fillWidth: true
                                            text: modelData.label
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontSizeSmall
                                            font.weight: Font.Medium
                                            color: Colors.text
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: modelData.subtitle
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontSizeSmall - 1
                                            color: Colors.textMuted
                                            elide: Text.ElideRight
                                        }
                                    }
                                }

                                MouseArea {
                                    id: _actionArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root._activatePresetQuery(parent.modelData.query)
                                }
                            }
                        }

                        Item { Layout.fillHeight: true }
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Theme.cornerRadius
            color: Qt.rgba(Colors.background.r, Colors.background.g, Colors.background.b, 0.86)
            border.color: Colors.border
            border.width: 1

            Loader {
                id: _launcherCoreLoader
                anchors.fill: parent
                anchors.margins: 8
                active: true
                source: "../../launcher/LauncherCore.qml"
            }
        }
    }
}
