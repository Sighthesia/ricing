import "."
import "MenuVisuals.js" as MenuVisuals
import "../../services" as Services
import QtQuick

// Render the bar context menu inside an expanded dockzone body.
Item {
    id: root

    readonly property real idealContentWidth: MenuVisuals.idealContextContentWidth
    readonly property real outerPadding: MenuVisuals.outerPadding
    readonly property real rowEdgeInset: MenuVisuals.rowEdgeInset
    readonly property real separatorInset: MenuVisuals.separatorInset
    property real viewportWidth: menuContentWidth
    property real viewportHeight: contentHeight
    readonly property real menuContentWidth: idealContentWidth
    readonly property real contentHeight: menuColumn.implicitHeight + outerPadding * 2
    readonly property real revealHeight: Math.max(0, height - 1)

    implicitWidth: menuContentWidth
    implicitHeight: contentHeight
    width: Math.max(0, viewportWidth)
    height: Math.min(viewportHeight, contentHeight)

    // Clip the full menu content to the live expanded viewport.
    Item {
        id: viewport

        width: root.width
        height: root.height
        clip: true

        // Keep the menu content at its natural size while the host expands.
        Column {
            id: menuColumn

            width: Math.max(0, root.width - root.rowEdgeInset * 2)
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.topMargin: root.outerPadding
            spacing: MenuVisuals.compactSpacing

            // Layout mode toggle.
            ContextMenuRow {
                readonly property bool fullyRevealed: y + height <= root.revealHeight

                opacity: fullyRevealed ? 1 : 0
                label: Services.BarLayoutService.settingsMode ? "Exit Layout Mode" : "Layout Mode"
                icon: "\u2630"
                highlighted: Services.BarLayoutService.settingsMode
                onClicked: {
                    Services.BarLayoutService.toggleSettingsMode()
                    Services.BarLayoutService.closeContextMenu()
                }
            }

            // Widget picker entry for the targeted dockzone section.
            ContextMenuRow {
                readonly property bool fullyRevealed: y + height <= root.revealHeight

                opacity: fullyRevealed ? 1 : 0
                label: "Add Widget to " + Services.BarLayoutService.contextMenuSection
                icon: "+"
                onClicked: {
                    Services.BarLayoutService.openWidgetPicker(Services.BarLayoutService.contextMenuSection)
                    Services.BarLayoutService.closeContextMenu()
                }
            }

            // Divider before widget-specific actions.
            Rectangle {
                readonly property bool fullyRevealed: y + height <= root.revealHeight

                width: parent.width - root.separatorInset * 2
                anchors.horizontalCenter: parent.horizontalCenter
                height: 1
                color: Qt.alpha(Services.Color.mOutline, MenuVisuals.dividerOpacity)
                visible: Services.BarLayoutService.contextMenuWidgetKey !== ""
                opacity: fullyRevealed ? 1 : 0
            }

            // Remove widget when the menu targets a widget instance.
            ContextMenuRow {
                readonly property bool fullyRevealed: y + height <= root.revealHeight

                visible: Services.BarLayoutService.contextMenuWidgetKey !== ""
                opacity: fullyRevealed ? 1 : 0
                label: "Remove Widget"
                icon: "\u2212"
                destructive: true
                onClicked: {
                    Services.BarLayoutService.removeWidget(Services.BarLayoutService.contextMenuWidgetKey)
                    Services.BarLayoutService.closeContextMenu()
                }
            }

            // Open widget settings when the widget supports them.
            ContextMenuRow {
                readonly property bool fullyRevealed: y + height <= root.revealHeight

                visible: Services.BarLayoutService.contextMenuWidgetKey !== ""
                opacity: fullyRevealed ? 1 : 0
                label: "Widget Settings"
                icon: "\u2699"
                enabled: Services.BarLayoutService.widgetSupportsSettings(
                    Services.BarLayoutService.contextMenuWidgetId)
                onClicked: {
                    Services.BarLayoutService.openWidgetSettings(
                        Services.BarLayoutService.contextMenuWidgetKey,
                        Services.BarLayoutService.contextMenuWidgetId,
                        Services.BarLayoutService.contextMenuX,
                        Services.BarLayoutService.contextMenuScreenName
                    )
                    Services.BarLayoutService.closeContextMenu()
                }
            }

            // Divider before shell settings.
            Rectangle {
                readonly property bool fullyRevealed: y + height <= root.revealHeight

                width: parent.width - root.separatorInset * 2
                anchors.horizontalCenter: parent.horizontalCenter
                height: 1
                color: Qt.alpha(Services.Color.mOutline, MenuVisuals.dividerOpacity)
                opacity: fullyRevealed ? 1 : 0
            }

            // Open the settings surface.
            ContextMenuRow {
                readonly property bool fullyRevealed: y + height <= root.revealHeight

                opacity: fullyRevealed ? 1 : 0
                label: "Settings"
                icon: "\u2699"
                onClicked: {
                    Services.IslandService.showSettingsCenter()
                    Services.BarLayoutService.closeContextMenu()
                }
            }

            // Divider before launcher.
            Rectangle {
                readonly property bool fullyRevealed: y + height <= root.revealHeight

                width: parent.width - root.separatorInset * 2
                anchors.horizontalCenter: parent.horizontalCenter
                height: 1
                color: Qt.alpha(Services.Color.mOutline, MenuVisuals.dividerOpacity)
                opacity: fullyRevealed ? 1 : 0
            }

            // Open the launcher overlay.
            ContextMenuRow {
                readonly property bool fullyRevealed: y + height <= root.revealHeight

                opacity: fullyRevealed ? 1 : 0
                label: "Launcher"
                icon: "\u2315"
                onClicked: {
                    Services.LauncherService.toggle()
                    Services.BarLayoutService.closeContextMenu()
                }
            }
        }
    }
}
