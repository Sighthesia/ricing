import QtQuick
import QtQuick.Controls
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
    readonly property int _filterOrder: {
        if (!parent || !parent.children)
            return 0

        for (let index = 0; index < parent.children.length; index++) {
            if (parent.children[index] === root)
                return index
        }

        return 0
    }
    readonly property int _filterDelay: _filterOrder * SettingsService.effectiveAnimation.staggerExitStep
    visible: height > 0.5 || opacity > 0.01
    opacity: _matchesFilter ? 1 : 0
    height: _matchesFilter ? implicitHeight : 0

    property bool _open: false   // dropdown expanded state

    // Height collapses to a single row when closed; expands to include the
    // search bar + font list when open.
    implicitWidth: ThemeSettings.rowWidth
    implicitHeight: _open
        ? ThemeSettings.rowHeight + dropdownCol.implicitHeight + ThemeSettings.pickerDropdownGap
        : ThemeSettings.rowHeight

    Behavior on implicitHeight {
        NumberAnimation { duration: Theme.anim.moveDuration; easing.type: Theme.anim.moveType }
    }

    Behavior on height {
        SequentialAnimation {
            PauseAnimation { duration: root._filterDelay }
            NumberAnimation { duration: Theme.anim.moveDuration; easing.type: Theme.anim.moveType }
        }
    }

    Behavior on opacity {
        SequentialAnimation {
            PauseAnimation { duration: root._filterDelay }
            NumberAnimation { duration: Theme.anim.highlightDuration }
        }
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

    // ── Main row ──────────────────────────────────────────────────────
    Item {
        id: headerRow
        width: parent.width
        height: ThemeSettings.rowHeight

        Row {
            anchors.fill: parent
            anchors.leftMargin: ThemeSettings.panelPadding
            anchors.rightMargin: ThemeSettings.panelPadding
            spacing: ThemeSettings.rowGap

            // Label
            Text {
                width: ThemeSettings.labelWidth
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
                width: parent.width - ThemeSettings.labelWidth - parent.spacing
                height: parent.height - ThemeSettings.fieldVerticalInset
                radius: ThemeSettings.fieldRadius
                color: root._open
                    ? Qt.rgba(Colors.highlight.r, Colors.highlight.g, Colors.highlight.b, 0.08)
                    : Colors.surface
                border.color: root._open ? Colors.highlight : Colors.border
                border.width: 1

                Behavior on color { ColorAnimation { duration: Theme.anim.highlightDuration } }
                Behavior on border.color { ColorAnimation { duration: Theme.anim.highlightDuration } }

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: ThemeSettings.pickerPreviewPaddingStart
                    anchors.rightMargin: ThemeSettings.pickerPreviewPaddingEnd

                    // Font name preview — renders text using the selected font
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - chevron.width - ThemeSettings.pickerLabelGap
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
                            NumberAnimation { duration: Theme.anim.moveDuration; easing.type: Theme.anim.moveType }
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
        y: ThemeSettings.rowHeight + ThemeSettings.pickerDropdownGap
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: ThemeSettings.panelPadding
        anchors.rightMargin: ThemeSettings.panelPadding
        spacing: ThemeSettings.pickerDropdownGap
        visible: root._open

        // Search bar
        Rectangle {
            id: searchBar
            width: parent.width
            height: ThemeSettings.pickerSearchHeight
            radius: ThemeSettings.fieldRadius
            color: Colors.surface
            border.color: searchInput.activeFocus ? Colors.highlight : Colors.border
            border.width: 1
            Behavior on border.color { ColorAnimation { duration: Theme.anim.highlightDuration } }

            Text {
                visible: searchInput.text === "" && !searchInput.activeFocus
                anchors { left: parent.left; leftMargin: ThemeSettings.pickerPreviewPaddingStart; verticalCenter: parent.verticalCenter }
                text: FontService.fontsReady ? "搜索字体..." : "加载字体列表中…"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                color: Colors.textMuted
            }

            TextInput {
                id: searchInput
                anchors.fill: parent
                anchors.margins: ThemeSettings.fieldPaddingH
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
            height: Math.min(root._filteredFonts.length * ThemeSettings.groupHeaderHeight,
                             ThemeSettings.groupHeaderHeight * ThemeSettings.pickerMaxVisibleRows)
            radius: ThemeSettings.fieldRadius
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
                    height: ThemeSettings.groupHeaderHeight

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
