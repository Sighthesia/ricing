import QtQuick
import QtQuick.Layouts
import qs.config
import "." as SuperIslandParts

// Expanded launcher page shown inside the larger SuperIsland overlay.
Item {
    id: root

    property bool _pageActive: false
    property string _pendingQueryText: ""

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
        if (_launcherCoreLoader.item.openPanel)
            _launcherCoreLoader.item.openPanel()

        if (_pendingQueryText !== "" && _launcherCoreLoader.item.setQueryText) {
            _launcherCoreLoader.item.setQueryText(_pendingQueryText)
            _pendingQueryText = ""
        }

        if (_launcherCoreLoader.item.runStructuralEnter)
            _launcherCoreLoader.item.runStructuralEnter()
    }

    function _focusLauncherSearch() {
        if (!_launcherCoreLoader.item || !_pageActive)
            return

        if (_launcherCoreLoader.item.focusSearch)
            _launcherCoreLoader.item.focusSearch()
    }

    function pageActivated() {
        root._pageActive = true
        root._applyLauncherActivation()
    }

    function pageDeactivated() {
        root._pageActive = false
        root._syncLauncherCoreState()

        if (_launcherCoreLoader.item && _launcherCoreLoader.item.runStructuralExit)
            _launcherCoreLoader.item.runStructuralExit()

        if (_launcherCoreLoader.item && _launcherCoreLoader.item.closePanel)
            _launcherCoreLoader.item.closePanel()
    }

    function _activatePresetQuery(queryText) {
        root._pendingQueryText = queryText

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
            spacing: 0

            Item { Layout.fillWidth: true }

            Rectangle {
                implicitWidth: 264
                implicitHeight: 30
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
                        label: "应用"
                        iconGlyph: "\uf002"
                        selected: !_launcherCoreLoader.item || !_launcherCoreLoader.item._searchHeader
                            ? true
                            : !_launcherCoreLoader.item._searchHeader.text.startsWith(">clip")
                        firstSegment: true
                        onPressed: root._switchToAppSearch()
                    }

                    SuperIslandParts.SuperIslandOverlayNavButton {
                        Layout.fillWidth: true
                        label: "剪贴板"
                        iconGlyph: "\uf0ea"
                        selected: _launcherCoreLoader.item && _launcherCoreLoader.item._searchHeader
                            ? _launcherCoreLoader.item._searchHeader.text.startsWith(">clip")
                            : false
                        lastSegment: true
                        onPressed: root._switchToClipboardSearch()
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
                    root._syncLauncherCoreState()

                    if (!root._pageActive)
                        return

                    root._applyLauncherActivation()
                }
            }
        }
    }

    Connections {
        target: IslandOverlayService

        function onStateChanged() {
            if (IslandOverlayService.mode !== "launcher" || IslandOverlayService.state !== "open")
                return

            Qt.callLater(function() {
                root._focusLauncherSearch()
            })
            Qt.callLater(function() {
                root._focusLauncherSearch()
            })
        }
    }
}
