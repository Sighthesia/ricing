import Quickshell
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.config
import qs.services
import qs.modules.bar
import "providers"

// Central search + results component embedded inside LauncherPanel.
// Owns all providers and routes queries to the active one.
Item {
    id: root

    StaggerOrchestrator {
        id: _stagger
    }

    // Called by LauncherPanel after panel becomes active
    function openPanel(): void {
        _results.clear();
        searchField.text = LauncherService.prefillText;
        searchField.forceActiveFocus();
        _refreshResults();
        for (let i = 0; i < _providers.length; i++) {
            _providers[i].onOpened();
        }
    }

    // Called by LauncherPanel when closing
    function closePanel(): void {
        _swapTimer.stop();
        _pendingDisplayItems = [];
        _pendingResultData = [];
        _suspendRefresh = true;
        searchField.text = "";
        _results.clear();
        root._resultData = [];
        _suspendRefresh = false;
    }

    function runStructuralEnter(): void {
        _stagger.clear();
        _stagger.registerItem(s_searchRow, 0, 1);
        _stagger.registerItem(s_divider, 1, 1);
        _stagger.registerItem(s_resultsViewport, 2, 1);
        _stagger.runEnter();
    }

    function runStructuralExit(): void {
        _stagger.clear();
        _stagger.registerItem(s_searchRow, 0, 1);
        _stagger.registerItem(s_divider, 1, 1);
        _stagger.registerItem(s_resultsViewport, 2, 1);
        _stagger.runExit();
    }

    // --- Private state ---
    property var _providers: [appProvider, clipProvider]

    // Parallel stores: ListModel holds display-only scalars; _resultData holds
    // the full result objects including onActivate functions (ListModel cannot
    // store JS functions — they are stripped on append).
    ListModel { id: _results }
    property var _resultData: []
    property var _pendingDisplayItems: []
    property var _pendingResultData: []
    property bool _suspendRefresh: false

    Timer {
        id: _swapTimer
        // Wait for old items to finish short exit before model swap.
        // FIXME: +20ms safety margin is empirical; expose as token if reused.
        interval: SettingsService.data.animation.staggerExitDuration + 20
        repeat: false
        onTriggered: root._applyPendingResults()
    }

    function _activeProvider(): var {
        let text = searchField.text;
        if (text.startsWith(">clip")) return clipProvider;
        return appProvider;
    }

    function _refreshResults(): void {
        if (_suspendRefresh || !LauncherService.isOpen) return;

        let provider = _activeProvider();
        if (!provider) return;

        // Strip command prefix before passing to provider
        let q = searchField.text;
        if (q.startsWith(">clip ")) q = q.substring(6);
        else if (q === ">clip") q = "";

        let items = provider.getResults(q);
        let displayItems = [];
        for (let i = 0; i < items.length; i++) {
            displayItems.push({
                name:        items[i].name        || "",
                description: items[i].description || "",
                icon:        items[i].icon        || ""
            });
        }

        // Panel opening / first render should not wait for exit animation.
        if (_results.count === 0) {
            _swapTimer.stop();
            _pendingDisplayItems = [];
            _pendingResultData = [];
            _results.clear();
            root._resultData = items;
            for (let j = 0; j < displayItems.length; j++) {
                _results.append(displayItems[j]);
            }
            _selectedIndex = items.length > 0 ? 0 : -1;
            return;
        }

        // While waiting for current exit animation, only keep the latest query result.
        _pendingDisplayItems = displayItems;
        _pendingResultData = items;
        if (!_swapTimer.running) {
            _runVisibleExit();
            _swapTimer.restart();
        }
    }

    function _runVisibleExit(): void {
        for (let i = 0; i < _results.count; i++) {
            let delegate = resultList.itemAtIndex(i);
            if (delegate && delegate.runExit) delegate.runExit();
        }
    }

    function _applyPendingResults(): void {
        _results.clear();
        root._resultData = _pendingResultData;
        for (let i = 0; i < _pendingDisplayItems.length; i++) {
            _results.append(_pendingDisplayItems[i]);
        }
        _pendingDisplayItems = [];
        _pendingResultData = [];
        _selectedIndex = root._resultData.length > 0 ? 0 : -1;
    }

    property int _selectedIndex: -1

    // --- UI ---
    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Search bar row
        StaggerItem {
            id: s_searchRow
            Layout.fillWidth: true
            height: 52
            exitDelay: 0

            Rectangle {
                anchors.fill: parent
                color: "transparent"

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8

                    // Mode badge
                    Rectangle {
                        implicitWidth: _modeBadgeText.implicitWidth + 16
                        height: 24
                        radius: Theme.cornerRadius / 2
                        color: Qt.rgba(Colors.highlight.r, Colors.highlight.g, Colors.highlight.b, 0.15)

                        Text {
                            id: _modeBadgeText
                            anchors.centerIn: parent
                            text: searchField.text.startsWith(">clip") ? "剪切板" : "应用"
                            color: Colors.highlight
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                        }
                    }

                    TextField {
                        id: searchField
                        Layout.fillWidth: true
                        placeholderText: "搜索应用… (>clip 切换剪切板)"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeBody
                        color: Colors.text
                        background: null
                        selectionColor: Qt.rgba(Colors.highlight.r, Colors.highlight.g, Colors.highlight.b, 0.3)

                        onTextChanged: Qt.callLater(root._refreshResults)

                        Keys.onUpPressed: {
                            if (root._selectedIndex > 0) root._selectedIndex--;
                            resultList.positionViewAtIndex(root._selectedIndex, ListView.Contain);
                        }
                        Keys.onDownPressed: {
                            if (root._selectedIndex < _results.count - 1) root._selectedIndex++;
                            resultList.positionViewAtIndex(root._selectedIndex, ListView.Contain);
                        }
                        Keys.onReturnPressed: root._activateCurrent()
                        Keys.onEscapePressed: LauncherService.isOpen = false
                    }
                }
            }
        }

        // Divider
        StaggerItem {
            id: s_divider
            Layout.fillWidth: true
            height: 1
            exitDelay: 0

            Rectangle {
                anchors.fill: parent
                color: Colors.border
            }
        }

        // Results list
            StaggerItem {
                id: s_resultsViewport
                Layout.fillWidth: true
                Layout.fillHeight: true
                exitDelay: 0

                ListView {
                    id: resultList
                    anchors.fill: parent
                    model: _results
                    clip: true
                    // No pre-caching: delegates are created on demand when items enter the
                    // visible viewport, so Component.onCompleted always fires on viewport
                    // entry and triggers the slide-up animation naturally.
                    cacheBuffer: 0

                    delegate: StaggerItem {
                        id: _item
                        required property int    index
                        // Qt 6 required-property delegates don't inject the implicit `model`
                        // context — each role must be declared explicitly.
                        required property string name
                        required property string description
                        required property string icon

                        // Use index % 8 so the stagger repeats in groups of 8 — high-index
                        // items scrolled into view won't wait the full max delay.
                        // FIXME: 25 ms per-item step is launcher-specific; promote to a
                        // Theme.anim token when launcher stagger tokens are added.
                        delay:  SettingsService.data.animation.staggerLevel1BaseDelay
                                + (index % 8) * 25
                        width:  resultList.width
                        height: 52

                        // Trigger slide-up + fade-in whenever this delegate is (re)created.
                        // This handles BOTH model refresh (typing) and viewport entry (scroll)
                        // because cacheBuffer: 0 ensures delegates exist only while visible.
                        Component.onCompleted: runEnter()

                        Rectangle {
                            anchors.fill: parent
                            color: root._selectedIndex === _item.index
                                ? Qt.rgba(Colors.highlight.r, Colors.highlight.g, Colors.highlight.b, 0.12)
                                : "transparent"

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 10

                                Image {
                                    source: "image://icon/" + (_item.icon || "application-x-executable")
                                    width: 24; height: 24
                                    sourceSize: Qt.size(24, 24)
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2

                                    Text {
                                        text: _item.name
                                        color: Colors.text
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeBody
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }

                                    Text {
                                        text: _item.description
                                        color: Qt.rgba(Colors.text.r, Colors.text.g, Colors.text.b, 0.55)
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeSmall
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                        visible: _item.description !== ""
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                onEntered: root._selectedIndex = _item.index
                                onClicked: root._activateCurrent()
                            }
                        }
                    }
                }
            }
    }

    function _activateCurrent(): void {
        if (root._selectedIndex < 0 || root._selectedIndex >= root._resultData.length) return;
        let item = root._resultData[root._selectedIndex];
        LauncherService.isOpen = false;
        if (item && item.onActivate) item.onActivate();
    }

    // Provider instances (children of LauncherCore)
    ApplicationsProvider { id: appProvider }
    ClipboardProvider    { id: clipProvider }

    // Re-query results whenever the desktop entry database finishes loading.
    // DesktopEntries is lazily initialized: the first access in getResults() triggers
    // async XDG scanning. Without this listener the panel stays blank on first open.
    Connections {
        target: DesktopEntries
        function onApplicationsChanged(): void {
            if (LauncherService.isOpen) _refreshResults()
        }
    }
}
