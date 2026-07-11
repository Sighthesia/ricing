import "../../services" as Services
import "../../services/CapsuleMetrics.js" as CapsuleMetrics
import "MenuVisuals.js" as MenuVisuals
import QtQuick

// Render the widget picker inside an expanded dockzone or island host.
Item {
    id: root

    readonly property real idealContentWidth: 320
    readonly property real outerPadding: MenuVisuals.outerPadding
    readonly property real rowEdgeInset: MenuVisuals.rowEdgeInset
    readonly property real cardSpacing: 4
    property real viewportWidth: idealContentWidth
    property real viewportHeight: contentHeight
    property real hostRevealHeight: -1
    property real hostRevealProgress: 1
    property bool hostIsInteractive: true
    readonly property real contentHeight: contentColumn.implicitHeight + outerPadding * 2
    readonly property real revealHeight: hostRevealHeight >= 0
        ? Math.max(0, hostRevealHeight - 1)
        : Math.max(0, height - 1)
    readonly property real headerRevealProgress: hostRevealProgress * Math.max(0, Math.min(1, (root.revealHeight - 8) / 40))
    readonly property real listRevealProgress: hostRevealProgress * Math.max(0, Math.min(1, (root.revealHeight - 72) / 80))

    implicitWidth: idealContentWidth
    implicitHeight: contentHeight
    width: Math.max(0, viewportWidth)
    height: Math.min(viewportHeight, contentHeight)
    enabled: hostIsInteractive

    function _filteredWidgets() {
        var all = Services.BarLayoutService.availableWidgets
        var query = searchInput.text.toLowerCase().trim()

        if (!query)
            return all

        return all.filter(function (widget) {
            return widget.label.toLowerCase().indexOf(query) !== -1
                || (widget.description || "").toLowerCase().indexOf(query) !== -1
        })
    }

    // Clip the full picker content to the live expanded viewport.
    Item {
        anchors.fill: parent
        clip: true

        // Keep the picker content at natural size while the host expands.
        Column {
            id: contentColumn

            width: Math.max(0, root.width - root.rowEdgeInset * 2)
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.topMargin: root.outerPadding
            spacing: 10

            // Show which dockzone section will receive the new widget.
            Services.FluidText {
                opacity: root.headerRevealProgress
                text: "Add widget to - " + Services.BarLayoutService.widgetPickerSection
                color: Services.Color.mOnSurfaceVariant
                basePixelSize: 12
            }

            // Provide a simple inline search field for the available widgets.
            Rectangle {
                opacity: root.headerRevealProgress
                width: parent.width
                height: MenuVisuals.compactControlHeight
                radius: MenuVisuals.rowRadius
                color: Qt.rgba(Services.Color.mOnSurface.r, Services.Color.mOnSurface.g, Services.Color.mOnSurface.b, MenuVisuals.fieldRestOpacity)
                border.color: Qt.rgba(Services.Color.mOutline.r, Services.Color.mOutline.g, Services.Color.mOutline.b, 0.55)
                border.width: 1

                TextInput {
                    id: searchInput

                    anchors.fill: parent
                    anchors.margins: CapsuleMetrics.compactVerticalPadding
                    color: Services.Color.mOnSurface
                    font.family: Services.SettingsService.appearance.fontDefault || Qt.application.font.family
                    font.pixelSize: Math.round(12 * (Services.SettingsService.appearance.fontDefaultScale || 1.0))
                    clip: true
                    selectedTextColor: Services.Color.mOnSurface
                    selectionColor: Qt.rgba(Services.Color.mPrimary.r, Services.Color.mPrimary.g, Services.Color.mPrimary.b, 0.45)

                    // Keep a lightweight placeholder inside the search field.
                    Services.FluidText {
                        anchors.fill: parent
                        text: "Search widgets..."
                        color: Services.Color.mOnSurfaceVariant
                        opacity: 0.7
                        basePixelSize: 12
                        visible: !searchInput.text && !searchInput.activeFocus
                    }
                }
            }

            // List the widgets that can be inserted into the current section.
            Column {
                opacity: root.listRevealProgress
                width: parent.width
                spacing: root.cardSpacing

                Repeater {
                    model: root._filteredWidgets()

                    // Render a clickable row for each available widget.
                    Rectangle {
                        required property var modelData
                        readonly property bool fullyRevealed: y + height <= root.revealHeight

                        width: parent.width
                        height: 44
                        radius: 8
                        color: cardMouse.containsMouse
                            ? Qt.rgba(Services.Color.mOnSurface.r, Services.Color.mOnSurface.g, Services.Color.mOnSurface.b, MenuVisuals.listHoverOpacity)
                            : Qt.rgba(Services.Color.mOnSurface.r, Services.Color.mOnSurface.g, Services.Color.mOnSurface.b, MenuVisuals.listRestOpacity)
                        border.color: cardMouse.containsMouse
                            ? Qt.rgba(Services.Color.mOutline.r, Services.Color.mOutline.g, Services.Color.mOutline.b, 0.75)
                            : Qt.rgba(Services.Color.mOutline.r, Services.Color.mOutline.g, Services.Color.mOutline.b, 0.55)
                        border.width: 1
                        opacity: fullyRevealed ? 1 : 0

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: CapsuleMetrics.compactSidePadding
                            anchors.right: parent.right
                            anchors.rightMargin: CapsuleMetrics.compactSidePadding
                            spacing: 2

                            // Show the widget label prominently.
                            Services.FluidText {
                                text: modelData.label
                                color: Services.Color.mOnSurface
                                basePixelSize: 12
                                font.bold: true
                            }

                            // Show the short widget description when available.
                            Services.FluidText {
                                text: modelData.description || ""
                                color: Services.Color.mOnSurfaceVariant
                                basePixelSize: 10
                                elide: Text.ElideRight
                                width: parent.width
                                visible: text !== ""
                            }
                        }

                        MouseArea {
                            id: cardMouse

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                Services.BarLayoutService.addWidgetToSection(
                                    modelData.id,
                                    Services.BarLayoutService.widgetPickerSection
                                )
                                Services.BarLayoutService.closeWidgetPicker()
                            }
                        }
                    }
                }
            }
        }
    }
}
