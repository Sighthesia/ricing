import QtQuick
import QtQuick.Layouts
import qs.config

// Expanded launcher page shown inside the larger SuperIsland overlay.
Item {
    id: root

    readonly property string _todayLabel: Qt.formatDateTime(new Date(), "M月d日 ddd")

    property bool _pageActive: false
    property string _pendingQueryText: ""

    function _log(message) {
        console.info("[DymicShell:ExpandedLauncherPage]", message,
            "pageActive=", root._pageActive,
            "pendingQuery=", root._pendingQueryText,
            "loaderReady=", !!_launcherCoreLoader.item)
    }

    function _syncLauncherCoreState() {
        if (!_launcherCoreLoader.item)
            return

        if (_launcherCoreLoader.item.hasOwnProperty("panelActive"))
            _launcherCoreLoader.item.panelActive = root._pageActive
    }

    function _applyLauncherActivation() {
        if (!_launcherCoreLoader.item)
            return

        root._syncLauncherCoreState()
        root._log("apply activation")

        if (_launcherCoreLoader.item.openPanel)
            _launcherCoreLoader.item.openPanel()

        if (_pendingQueryText !== "" && _launcherCoreLoader.item.setQueryText) {
            _launcherCoreLoader.item.setQueryText(_pendingQueryText)
            _pendingQueryText = ""
        }

        if (_launcherCoreLoader.item.runStructuralEnter)
            _launcherCoreLoader.item.runStructuralEnter()
    }

    function pageActivated() {
        root._pageActive = true
        root._log("page activated")
        root._applyLauncherActivation()
    }

    function pageDeactivated() {
        root._pageActive = false
        root._syncLauncherCoreState()
        root._log("page deactivated")

        if (_launcherCoreLoader.item && _launcherCoreLoader.item.runStructuralExit)
            _launcherCoreLoader.item.runStructuralExit()

        if (_launcherCoreLoader.item && _launcherCoreLoader.item.closePanel)
            _launcherCoreLoader.item.closePanel()
    }

    function _activatePresetQuery(queryText) {
        root._pendingQueryText = queryText
        root._log("preset query requested")

        if (_launcherCoreLoader.item && _launcherCoreLoader.item.setQueryText)
            _launcherCoreLoader.item.setQueryText(queryText)
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 14

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 126
            radius: Theme.cornerRadius
            gradient: Gradient {
                GradientStop {
                    position: 0.0
                    color: Qt.rgba(Colors.highlight.r, Colors.highlight.g, Colors.highlight.b, 0.18)
                }
                GradientStop {
                    position: 1.0
                    color: Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 0.92)
                }
            }
            border.color: Qt.rgba(Colors.highlight.r, Colors.highlight.g, Colors.highlight.b, 0.24)
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.margins: 18
                spacing: 18

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                        text: "启动器"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeBody + 10
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
                        text: "搜索应用、切换到剪贴板历史、直接回车启动。整个页面都围绕搜索主流程展开。"
                        wrapMode: Text.WordWrap
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        color: Colors.textMuted
                    }
                }

                RowLayout {
                    spacing: 10

                    Repeater {
                        model: [
                            {
                                label: "应用",
                                subtitle: "桌面条目",
                                query: ""
                            },
                            {
                                label: "剪贴板",
                                subtitle: "最近复制",
                                query: ">clip "
                            }
                        ]

                        delegate: Rectangle {
                            required property var modelData

                            readonly property bool _active: _chipArea.containsMouse

                            implicitWidth: 118
                            implicitHeight: 64
                            radius: Theme.cornerRadius - 2
                            color: _active
                                ? Qt.rgba(Colors.highlight.r, Colors.highlight.g, Colors.highlight.b, 0.12)
                                : Qt.rgba(Colors.background.r, Colors.background.g, Colors.background.b, 0.26)
                            border.color: _active ? Colors.highlight : Colors.border
                            border.width: 1

                            Behavior on color {
                                ColorAnimation { duration: Theme.anim.highlightDuration }
                            }

                            Behavior on border.color {
                                ColorAnimation { duration: Theme.anim.highlightDuration }
                            }

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 2

                                Text {
                                    text: modelData.label
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: Font.Medium
                                    color: Colors.text
                                }

                                Text {
                                    text: modelData.subtitle
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeSmall - 1
                                    color: Colors.textMuted
                                }
                            }

                            MouseArea {
                                id: _chipArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root._activatePresetQuery(parent.modelData.query)
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Theme.cornerRadius
            color: Qt.rgba(Colors.background.r, Colors.background.g, Colors.background.b, 0.88)
            border.color: Colors.border
            border.width: 1

            Loader {
                id: _launcherCoreLoader
                anchors.fill: parent
                anchors.margins: 8
                active: true
                source: "../../launcher/LauncherCore.qml"

                onLoaded: {
                    root._log("launcher core loaded")
                    root._syncLauncherCoreState()

                    if (!root._pageActive)
                        return

                    root._applyLauncherActivation()
                }
            }
        }
    }
}
