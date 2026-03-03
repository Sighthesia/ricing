import QtQuick
import qs.config
import qs.services

// A labeled font picker row with an inline searchable dropdown.
// Clicking the row opens a dropdown showing all installed fonts (via FontService).
// Each font entry renders its name in that font as a preview.
//
// Usage:
//   FontPickerSection {
//     label: "字体族"
//     value: SettingsService.data.appearance.fontFamily
//     onValueCommitted: SettingsService.data.appearance.fontFamily = newValue
//   }
Item {
    id: root

    property string label: ""
    property string value: ""        // current font family name
    property bool isMonospace: false  // restrict list to monospace fonts

    signal valueCommitted(string newValue)

    // When non-empty, this item shows only if its label matches the query.
    property string filterQuery: ""
    readonly property bool _matchesFilter: filterQuery === "" ||
        label.toLowerCase().indexOf(filterQuery.toLowerCase()) !== -1
    readonly property bool searchHighlight: filterQuery !== "" && _matchesFilter
    visible: _matchesFilter
    height: _matchesFilter ? implicitHeight : 0

    property bool _open: false   // dropdown expanded state

    // Height collapses to a single row when closed; expands to include the
    // search bar + font list when open.
    implicitWidth: 296
    implicitHeight: _open
        ? Theme.settingsRowHeight + dropdownCol.implicitHeight + 4
        : Theme.settingsRowHeight

    Behavior on implicitHeight {
        NumberAnimation { duration: Theme.anim.moveDuration; easing.type: Easing.InOutCubic }
    }

    clip: true

    // ── Filtered font list ─────────────────────────────────────────────
    // Reactive: re-evaluates whenever FontService finishes loading or
    // the search input changes.
    readonly property var _fontPool: root.isMonospace
        ? FontService.monospaceFonts
        : FontService.allFonts

    readonly property var _filteredFonts: {
        var pool = root._fontPool
        var q = searchInput.text.toLowerCase()
        if (q.length === 0) return pool
        return pool.filter(function(name) {
            return name.toLowerCase().indexOf(q) !== -1
        })
    }

    // ── Search match highlight background ─────────────────────────────
    Rectangle {
        anchors { fill: parent; topAnchor: parent.top; leftMargin: 4; rightMargin: 4 }
        anchors.fill: parent
        anchors.leftMargin: 4; anchors.rightMargin: 4
        height: Theme.settingsRowHeight    // only highlight the header row
        radius: 4
        color: Colors.highlight
        opacity: root.searchHighlight ? 0.1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.anim.highlightDuration } }
    }

    Rectangle {
        anchors { left: parent.left; top: parent.top; leftMargin: 4 }
        width: 3; height: Theme.settingsRowHeight
        radius: 1
        color: Colors.highlight
        opacity: root.searchHighlight ? 0.9 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.anim.highlightDuration } }
    }

    // ── Main row ──────────────────────────────────────────────────────
    Item {
        id: headerRow
        width: parent.width
        height: Theme.settingsRowHeight

        Row {
            anchors.fill: parent
            anchors.leftMargin: Theme.settingsPanelPadding
            anchors.rightMargin: Theme.settingsPanelPadding
            spacing: 8

            // Label
            Text {
                width: Theme.settingsLabelWidth
                anchors.verticalCenter: parent.verticalCenter
                text: root.label
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                color: Colors.textMuted
                elide: Text.ElideRight
            }

            // Current font display + dropdown toggle
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - Theme.settingsLabelWidth - parent.spacing
                height: parent.height - 8
                radius: 4
                color: root._open
                    ? Qt.rgba(Colors.highlight.r, Colors.highlight.g, Colors.highlight.b, 0.08)
                    : Colors.surface
                border.color: root._open ? Colors.highlight : Colors.border
                border.width: 1

                Behavior on color { ColorAnimation { duration: Theme.anim.highlightDuration } }
                Behavior on border.color { ColorAnimation { duration: Theme.anim.highlightDuration } }

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 6

                    // Font name preview — renders text using the selected font
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - chevron.width - 4
                        text: root.value !== "" ? root.value : "未设置"
                        // Preview the chosen font; fall back if the name is invalid
                        font.family: root.value !== "" ? root.value : Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        color: root.value !== "" ? Colors.text : Colors.textMuted
                        elide: Text.ElideRight
                    }

                    // Chevron indicator
                    Text {
                        id: chevron
                        anchors.verticalCenter: parent.verticalCenter
                        text: "\uf107"
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeSmall - 1
                        color: Colors.textMuted
                        rotation: root._open ? 180 : 0
                        Behavior on rotation {
                            NumberAnimation { duration: Theme.anim.moveDuration; easing.type: Easing.InOutCubic }
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root._open = !root._open
                        if (root._open) {
                            FontService.init()
                            searchInput.forceActiveFocus()
                        }
                    }
                }
            }
        }
    }

    // ── Dropdown ──────────────────────────────────────────────────────
    Column {
        id: dropdownCol
        y: Theme.settingsRowHeight + 4
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Theme.settingsPanelPadding
        anchors.rightMargin: Theme.settingsPanelPadding
        spacing: 4
        visible: root._open

        implicitHeight: searchBar.height + spacing + fontListRect.height

        // Search bar
        Rectangle {
            id: searchBar
            width: parent.width
            height: Theme.settingsRowHeight - 6
            radius: 4
            color: Colors.surface
            border.color: searchInput.activeFocus ? Colors.highlight : Colors.border
            border.width: 1
            Behavior on border.color { ColorAnimation { duration: Theme.anim.highlightDuration } }

            Text {
                visible: searchInput.text === "" && !searchInput.activeFocus
                anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
                text: FontService.fontsReady ? "搜索字体..." : "加载字体列表中…"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                color: Colors.textMuted
            }

            TextInput {
                id: searchInput
                anchors.fill: parent
                anchors.margins: 6
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                color: Colors.text
                selectByMouse: true
                HoverHandler { cursorShape: Qt.IBeamCursor }
            }
        }

        // Font list
        Rectangle {
            id: fontListRect
            width: parent.width
            // Show up to ~6 items; individual item height = settingsGroupHeaderHeight
            height: Math.min(root._filteredFonts.length * Theme.settingsGroupHeaderHeight,
                             Theme.settingsGroupHeaderHeight * 6)
            radius: 4
            color: Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 0.8)
            border.color: Colors.border
            border.width: 1
            clip: true

            // Loading indicator
            Text {
                visible: !FontService.fontsReady
                anchors.centerIn: parent
                text: "加载中..."
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                color: Colors.textMuted
            }

            // Empty indicator
            Text {
                visible: FontService.fontsReady && root._filteredFonts.length === 0
                anchors.centerIn: parent
                text: "无匹配字体"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                color: Colors.textMuted
            }

            ListView {
                id: fontList
                anchors.fill: parent
                anchors.margins: 3
                model: root._filteredFonts
                visible: FontService.fontsReady && root._filteredFonts.length > 0
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                }

                delegate: Item {
                    required property string modelData
                    required property int index

                    width: ListView.view.width
                    height: Theme.settingsGroupHeaderHeight

                    readonly property bool isSelected: modelData === root.value

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 1
                        radius: 3
                        color: isSelected
                            ? Qt.rgba(Colors.highlight.r, Colors.highlight.g, Colors.highlight.b, 0.2)
                            : (itemHover.containsMouse
                                ? Qt.rgba(Colors.highlight.r, Colors.highlight.g, Colors.highlight.b, 0.1)
                                : "transparent")
                        Behavior on color { ColorAnimation { duration: Theme.anim.highlightDuration } }
                    }

                    // Font name, rendered in that font as a live preview
                    Text {
                        anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
                        width: parent.width - 16
                        text: modelData
                        font.family: modelData
                        font.pixelSize: Theme.fontSizeSmall
                        color: isSelected ? Colors.highlight : Colors.text
                        elide: Text.ElideRight

                        Behavior on color { ColorAnimation { duration: Theme.anim.highlightDuration } }
                    }

                    MouseArea {
                        id: itemHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.valueCommitted(modelData)
                            root._open = false
                            searchInput.text = ""
                        }
                    }
                }
            }
        }
    }
}
