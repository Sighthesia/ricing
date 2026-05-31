import QtQuick
import "../bar" as Bar
import "../../services" as Services

// Animated island body: expands from collapsed clock to full launcher panel.
// Delegates the spring-morphing attached-island silhouette (ears, blur strips,
// blur lead, body clip) to AttachedIslandSurface and only owns the collapsed
// vs expanded content and its interaction handlers.
Item {
    id: root

    required property string screenName

    // Geometry constants.
    readonly property int collapsedW: 220
    readonly property int collapsedH: Services.BarLayoutService.barHeight
    readonly property int expandedW: 480
    readonly property int expandedH: 420
    readonly property int earRadius: 24
    readonly property int collapsedHorizontalPadding: 16
    readonly property int hoverWLift: 12
    readonly property int hoverHLift: 4
    readonly property int hoverRadiusLift: 2
    readonly property color surfaceColor: Qt.alpha(Services.Color.mSurface, Services.SettingsService.panelSurfaceOpacity)
    readonly property var centerWidgets: Services.BarLayoutService.sectionWidgets("center")
    readonly property bool showManagedCenterWidgets: !Services.IslandService.expanded
        && root.centerWidgets.length > 0
    readonly property real collapsedContentWidth: collapsedContentLoader.item
        ? collapsedContentLoader.item.implicitWidth + collapsedHorizontalPadding
        : collapsedW

    // Target dimensions driven by island state and passive hover intent;
    // fed into the surface which owns the spring deformation.
    property int targetW: Services.IslandService.expanded
        ? expandedW
        : collapsedContentWidth + (hoverHandler.hovered ? hoverWLift : 0)
    property int targetH: Services.IslandService.expanded
        ? expandedH
        : collapsedH + (hoverHandler.hovered ? hoverHLift : 0)
    property int targetR: Services.IslandService.expanded
        ? 24
        : 14 + (hoverHandler.hovered ? hoverRadiusLift : 0)

    // Size mirrors the surface's animated geometry so external consumers
    // (IslandWindow hit region) keep tracking the live island bounds.
    width: surface.width
    height: surface.height
    implicitWidth: width
    implicitHeight: height

    // Forward the surface blur parts for IslandWindow's blur region tracking.
    readonly property var blurParts: surface.blurParts

    // Forward widget-aware context menu requests from center widget wrappers.
    function openWidgetContextMenu(instanceKey, widgetId, clickX) {
        Services.BarLayoutService.openContextMenu(clickX, instanceKey, widgetId)
    }

    // Passive hover tracking for the collapsed island geometry.
    HoverHandler {
        id: hoverHandler
    }

    // Shared attached-island silhouette shell; hosts island content in its body.
    AttachedIslandSurface {
        id: surface
        anchors.top: parent.top
        anchors.left: parent.left

        targetBodyWidth: root.targetW
        targetBodyHeight: root.targetH
        targetRadius: root.targetR
        earRadius: root.earRadius
        surfaceColor: root.surfaceColor

        // --- Collapsed content: center widgets or fallback clock ---
        Item {
            id: collapsedContent
            anchors.fill: parent
            opacity: Services.IslandService.expanded ? 0 : 1
            visible: opacity > 0.01

            Behavior on opacity {
                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
            }

            // Switch collapsed content between the real center widgets and the fallback clock.
            Loader {
                id: collapsedContentLoader

                anchors.centerIn: parent
                sourceComponent: root.showManagedCenterWidgets ? managedCenterWidgets : fallbackClock
            }

            // Render the actual managed center widgets in collapsed mode.
            Component {
                id: managedCenterWidgets

                Row {
                    id: centerWidgetsRow

                    spacing: 8

                    Repeater {
                        model: root.centerWidgets.length

                        Bar.BarWidgetWrapper {
                            required property int index

                            screenName: root.screenName
                            widgetEntry: root.centerWidgets[index]
                            widgetSource: Qt.resolvedUrl(widgetEntry.source)
                        }
                    }
                }
            }

            // Keep the clock as the fallback when no center widgets exist.
            Component {
                id: fallbackClock

                IslandClock {
                }
            }
        }

        // --- Expanded content: search + results ---
        Item {
            id: expandedContent
            anchors.fill: parent
            anchors.margins: 16
            anchors.topMargin: 12
            opacity: Services.IslandService.expanded ? 1 : 0
            visible: opacity > 0.01

            Behavior on opacity {
                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
            }

            IslandLauncher {
                anchors.fill: parent
                visible: parent.visible
            }
        }

        // Keep left-click expansion on the whole collapsed island surface.
        MouseArea {
            anchors.fill: parent
            enabled: !Services.IslandService.expanded
                && !Services.BarLayoutService.settingsMode
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton
            onClicked: Services.IslandService.toggle()
        }

        // Right-click opens the center layout menu across the collapsed island.
        MouseArea {
            anchors.fill: parent
            enabled: !Services.IslandService.expanded && !root.showManagedCenterWidgets
            acceptedButtons: Qt.RightButton
            onClicked: (mouse) => {
                var scenePos = root.mapToItem(null, mouse.x, mouse.y)
                Services.BarLayoutService.openContextMenu(scenePos.x, "", "")
            }
        }
    }
}
