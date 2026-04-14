import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import ".." as BarComponents
import "." as SuperIslandParts

// Expanded launcher page shown inside the larger SuperIsland overlay.
Item {
    id: root

    property bool _pageActive: false
    property string _pendingQueryText: ""

    function _runPageEnter() {
        _pageStagger.clear()
        _pageStagger.registerItem(_modeSwitcherItem, 0, 1)
        _pageStagger.registerItem(_launcherBodyItem, 0, 2)
        _pageStagger.runEnter()
    }

    function pageExitDuration() {
        return SettingsService.effectiveAnimation.staggerExitDuration
            + SettingsService.effectiveAnimation.staggerExitStep
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

        root._runPageEnter()
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
        _pageStagger.runExit()
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

    BarComponents.StaggerOrchestrator {
        id: _pageStagger
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: ThemeCards.shellGap

        RowLayout {
            Layout.fillWidth: true
            spacing: 0

            Item { Layout.fillWidth: true }

            BarComponents.StaggerItem {
                id: _modeSwitcherItem
                implicitWidth: ThemeCards.overlayNavWidth
                implicitHeight: ThemeCards.overlayNavHeight
                BarComponents.FloatingShellSurface {
                    anchors.fill: parent
                    contentMargin: 0
                    shellRadius: ThemeCards.overlayNavRadius

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
        }

        BarComponents.StaggerItem {
            id: _launcherBodyItem
            Layout.fillWidth: true
            Layout.fillHeight: true
            BarComponents.FloatingShellSurface {
                anchors.fill: parent
                contentMargin: ThemeCards.panelInset

                Loader {
                    id: _launcherCoreLoader
                    anchors.fill: parent
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
