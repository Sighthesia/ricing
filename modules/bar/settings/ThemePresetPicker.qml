import QtQuick
import QtQuick.Controls
import qs.config
import qs.services

// Horizontal scrollable row of named color-scheme preset cards.
// Clicking a card atomically writes all 6 colors to SettingsService.
//
// Properties:
// - filterQuery: settings-panel search string (hides row when no match)
Item {
    id: root

    property string filterQuery: ""
    readonly property bool _matchesFilter: filterQuery === "" ||
        "主题预设".toLowerCase().indexOf(filterQuery.toLowerCase()) !== -1

    visible: _matchesFilter
    implicitWidth: parent ? parent.width : ThemeSettings.rowWidth
    height: cardRow.height + sectionLabel.height + ThemeSettings.presetSectionGap

    // 7 built-in palettes; values are intentionally kept as plain strings
    // so they work with QML's color-from-string codec and also as hex text
    // inputs in ColorSection.
    readonly property var presets: [
        {
            id: "tokyo-night", name: "Tokyo Night",
            bg: "#1a1b26", surface: "#24283b", accent: "#7aa2f7",
            text: "#c0caf5", textMuted: "#565f89", border: "#3b4261"
        },
        {
            id: "catppuccin-mocha", name: "Catppuccin",
            bg: "#1e1e2e", surface: "#313244", accent: "#cba6f7",
            text: "#cdd6f4", textMuted: "#6c7086", border: "#45475a"
        },
        {
            id: "nord", name: "Nord",
            bg: "#2e3440", surface: "#3b4252", accent: "#88c0d0",
            text: "#d8dee9", textMuted: "#4c566a", border: "#434c5e"
        },
        {
            id: "gruvbox-dark", name: "Gruvbox",
            bg: "#282828", surface: "#3c3836", accent: "#fabd2f",
            text: "#ebdbb2", textMuted: "#928374", border: "#504945"
        },
        {
            id: "dracula", name: "Dracula",
            bg: "#282a36", surface: "#44475a", accent: "#bd93f9",
            text: "#f8f8f2", textMuted: "#6272a4", border: "#44475a"
        },
        {
            id: "rose-pine", name: "Rosé Pine",
            bg: "#191724", surface: "#1f1d2e", accent: "#c4a7e7",
            text: "#e0def4", textMuted: "#6e6a86", border: "#26233a"
        },
        {
            id: "solarized-dark", name: "Solarized",
            bg: "#002b36", surface: "#073642", accent: "#268bd2",
            text: "#839496", textMuted: "#586e75", border: "#073642"
        }
    ]

    Text {
        id: sectionLabel
        anchors { left: parent.left; leftMargin: ThemeSettings.panelPadding; top: parent.top }
        text: "主题预设"
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
        color: Colors.textMuted
        height: ThemeSettings.groupHeaderHeight
        verticalAlignment: Text.AlignVCenter
    }

    // Horizontally scrollable row of preset cards
    ListView {
        id: cardRow
        anchors {
            left: parent.left; right: parent.right
            top: sectionLabel.bottom
            leftMargin: ThemeSettings.panelPadding
            rightMargin: ThemeSettings.panelPadding
        }
        height: ThemeSettings.presetListHeight
        orientation: ListView.Horizontal
        spacing: ThemeSettings.presetListGap
        clip: true
        model: root.presets
        boundsBehavior: Flickable.StopAtBounds

        ScrollBar.horizontal: ScrollBar {
            policy: ScrollBar.AsNeeded
        }

        delegate: Item {
            required property var modelData

            width: ThemeSettings.presetCardWidth
            height: ThemeSettings.presetCardHeight

            // Checks whether this theme is currently active (all 6 colors match).
            readonly property bool isActive:
                (SettingsService.data.appearance.backgroundColor.toString()  === modelData.bg)  &&
                (SettingsService.data.appearance.surfaceColor.toString()     === modelData.surface) &&
                (SettingsService.data.appearance.accentColor.toString()      === modelData.accent)

            // Preview card
            Rectangle {
                id: card
                width: parent.width
                height: ThemeSettings.presetPreviewHeight
                radius: ThemeSettings.presetCardRadius
                color: modelData.bg
                border.width: isActive ? 2 : 1
                border.color: isActive ? Colors.highlight
                                       : (cardHover.containsMouse ? Colors.highlight : Colors.border)

                Behavior on border.color { ColorAnimation { duration: Theme.anim.highlightDuration } }

                // Accent bar pinned to bottom of card
                Rectangle {
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                    height: ThemeSettings.presetAccentHeight
                    radius: ThemeSettings.presetAccentRadius
                    color: modelData.accent
                }

                // Three color-dot swatches in the upper area:
                //  accent · text · textMuted
                Row {
                    anchors { top: parent.top; topMargin: ThemeSettings.presetSwatchInset; left: parent.left; leftMargin: ThemeSettings.presetSwatchInset }
                    spacing: ThemeSettings.presetSwatchGap

                    Repeater {
                        model: [modelData.accent, modelData.text, modelData.textMuted]
                        delegate: Rectangle {
                            required property var modelData
                            width: ThemeSettings.presetSwatchSize; height: ThemeSettings.presetSwatchSize
                            radius: width / 2
                            color: modelData
                        }
                    }
                }

                MouseArea {
                    id: cardHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        // Apply the full palette atomically.
                        SettingsService.data.appearance.backgroundColor = modelData.bg
                        SettingsService.data.appearance.surfaceColor    = modelData.surface
                        SettingsService.data.appearance.accentColor     = modelData.accent
                        SettingsService.data.appearance.textColor       = modelData.text
                        SettingsService.data.appearance.textMutedColor  = modelData.textMuted
                        SettingsService.data.appearance.borderColor     = modelData.border
                        SettingsService.save()
                    }
                }
            }

            // Theme name label below the preview card
            Text {
                anchors { top: card.bottom; topMargin: ThemeSettings.presetLabelGap; horizontalCenter: parent.horizontalCenter }
                text: modelData.name
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall - 1
                color: Colors.textMuted
                horizontalAlignment: Text.AlignHCenter
                width: parent.width
                elide: Text.ElideRight
            }
        }
    }

    // Transparent overlay for Shift+wheel → horizontal scroll.
    // Placed outside the ListView so Flickable does not consume the event first.
    MouseArea {
        anchors {
            left: cardRow.left; right: cardRow.right
            top: cardRow.top; bottom: cardRow.bottom
        }
        acceptedButtons: Qt.NoButton   // never steal clicks
        propagateComposedEvents: true  // let all other events through

        onWheel: (wheel) => {
            // Handle Shift+vertical-wheel OR native horizontal-scroll (touchpad)
            var isHorizontalIntent =
                (wheel.modifiers & Qt.ShiftModifier) ||
                (wheel.angleDelta.x !== 0 && wheel.angleDelta.y === 0)

            if (isHorizontalIntent) {
                var delta = wheel.angleDelta.y !== 0
                    ? wheel.angleDelta.y   // Shift+vertical
                    : -wheel.angleDelta.x  // native horizontal (reversed axis)
                var maxX = Math.max(0, cardRow.contentWidth - cardRow.width)
                cardRow.contentX = Math.max(0,
                    Math.min(cardRow.contentX - delta / 120 * ThemeSettings.presetWheelStep, maxX))
                wheel.accepted = true
            } else {
                wheel.accepted = false
            }
        }
    }
}
