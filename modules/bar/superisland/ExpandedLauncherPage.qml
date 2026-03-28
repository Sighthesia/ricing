import QtQuick
import QtQuick.Layouts
import qs.config

// Expanded launcher page shown inside the larger SuperIsland overlay.
Item {
    id: root

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

    function _switchToAppSearch() {
        root._activatePresetQuery("")
    }

    function _switchToClipboardSearch() {
        root._activatePresetQuery(">clip ")
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Item { Layout.fillWidth: true }

            Rectangle {
                implicitWidth: 92
                implicitHeight: 30
                radius: Theme.cornerRadius - 2
                color: Qt.rgba(Colors.background.r, Colors.background.g, Colors.background.b, 0.30)
                border.color: Colors.border
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: "应用"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall - 1
                    color: Colors.text
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root._switchToAppSearch()
                }
            }

            Rectangle {
                implicitWidth: 92
                implicitHeight: 30
                radius: Theme.cornerRadius - 2
                color: Qt.rgba(Colors.background.r, Colors.background.g, Colors.background.b, 0.30)
                border.color: Colors.border
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: "剪贴板"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall - 1
                    color: Colors.text
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root._switchToClipboardSearch()
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
