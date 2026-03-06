import Quickshell
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.config
import qs.services
import "providers"

// Central search + results component embedded inside LauncherPanel.
// Owns all providers and routes queries to the active one.
Item {
    id: root

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
        searchField.text = "";
        _results.clear();
    }

    // --- Private state ---
    property var _providers: [appProvider]

    // Parallel stores: ListModel holds display-only scalars; _resultData holds
    // the full result objects including onActivate functions (ListModel cannot
    // store JS functions — they are stripped on append).
    ListModel { id: _results }
    property var _resultData: []

    function _activeProvider(): var {
        let text = searchField.text;
        // FIXME: route ">clip " prefix to ClipboardProvider once feat/clipboard-service is merged
        if (text.startsWith(">clip ") || text === ">clip") return null;
        return appProvider;
    }

    function _refreshResults(): void {
        _results.clear();
        root._resultData = [];
        let provider = _activeProvider();
        if (!provider) return;

        let q = searchField.text;
        let items = provider.getResults(q);
        let displayItems = [];
        for (let i = 0; i < items.length; i++) {
            displayItems.push({
                name:        items[i].name        || "",
                description: items[i].description || "",
                icon:        items[i].icon        || ""
            });
        }
        root._resultData = items;
        for (let j = 0; j < displayItems.length; j++) {
            _results.append(displayItems[j]);
        }
        _selectedIndex = items.length > 0 ? 0 : -1;
    }

    property int _selectedIndex: -1

    // --- UI ---
    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Search bar row
        Rectangle {
            Layout.fillWidth: true
            height: 52
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

        // Divider
        Rectangle { Layout.fillWidth: true; height: 1; color: Colors.border }

        // Results list
        ListView {
            id: resultList
            Layout.fillWidth: true
            Layout.fillHeight: true
            model: _results
            clip: true

            delegate: Rectangle {
                width: resultList.width
                height: 52
                color: root._selectedIndex === index
                    ? Qt.rgba(Colors.highlight.r, Colors.highlight.g, Colors.highlight.b, 0.12)
                    : "transparent"

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 10

                    Image {
                        source: "image://icon/" + (model.icon || "application-x-executable")
                        width: 24; height: 24
                        sourceSize: Qt.size(24, 24)
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            text: model.name
                            color: Colors.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeBody
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Text {
                            text: model.description
                            color: Qt.rgba(Colors.text.r, Colors.text.g, Colors.text.b, 0.55)
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                            visible: model.description !== ""
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: root._selectedIndex = index
                    onClicked: root._activateCurrent()
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
}
