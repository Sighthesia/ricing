import "."
import "./tray" as Tray
import "../../services" as Services
import "../../services/barlayout/BarLayoutSections.js" as BarLayoutSections
import QtQuick

// Render a single ordered section inside a shared attached-island surface.
Item {
    id: root

    required property string sectionName
    required property string screenName
    property bool floatingValidationIntent: false
    readonly property var sectionModel: Services.BarLayoutService.sectionWidgets(sectionName)
    readonly property bool hasSectionContent: root.sectionModel.length > 0
    readonly property bool canOpenWidgetPicker: Services.BarLayoutService.layoutReady
    readonly property var blurParts: surfaceLoader.item ? surfaceLoader.item.blurParts : []
    readonly property string surfaceState: root.sectionName === "center"
        ? (root.hasSectionContent ? (root.floatingValidationIntent ? "floating" : "attached") : "hidden")
        : (root.hasSectionContent ? "attached" : "hidden")

    implicitHeight: surfaceLoader.item ? surfaceLoader.item.implicitHeight : Services.BarLayoutService.barHeight
    implicitWidth: root.hasSectionContent
        ? (surfaceLoader.item ? surfaceLoader.item.implicitWidth : 0)
        : (root.canOpenWidgetPicker ? 72 : 0)
    width: implicitWidth
    height: implicitHeight

    // Preserve a small hit target so an empty dockzone can still reopen the widget picker.
    MouseArea {
        anchors.fill: parent
        enabled: !root.hasSectionContent && root.canOpenWidgetPicker
        acceptedButtons: Qt.RightButton
        hoverEnabled: enabled
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: (mouse) => {
            var barPos = root.mapToItem(root.parent, mouse.x, mouse.y)
            var barContent = root.parent

            while (barContent && !barContent.openWidgetContextMenu) {
                barContent = barContent.parent
            }

            if (barContent && barContent.openWidgetContextMenu) {
                barContent.openWidgetContextMenu("", "", barPos.x)
            }
        }
    }

    // Route every section through the unified surface owner.
    Loader {
        id: surfaceLoader

        active: true
        sourceComponent: surfaceShell
    }

    // Unified path: owner-managed surface with section-aware model-driven rendering.
    Component {
        id: surfaceShell

        Item {
            id: surfaceRoot

            readonly property var blurParts: dockzone.blurParts

            implicitWidth: dockzone.implicitWidth
            implicitHeight: dockzone.implicitHeight
            width: implicitWidth
            height: implicitHeight

            function syncCenterFloatingValidationIntent() {
                if (root.sectionName !== "center")
                    return;

                var hasLocalPointerIntent = false;

                for (var i = 0; i < sectionRow.children.length; ++i) {
                    var child = sectionRow.children[i];
                    if (child && child.localPointerIntent) {
                        hasLocalPointerIntent = true;
                        break;
                    }
                }

                root.floatingValidationIntent = hasLocalPointerIntent;
            }

            Component.onCompleted: syncCenterFloatingValidationIntent()

            // Track section hover passively so child mouse areas do not retrigger it.
            HoverHandler {
                id: sectionHoverHandler

                enabled: root.hasSectionContent
            }

            DockzoneSurfaceRoot {
                id: dockzone

                section: root.sectionName
                screenName: root.screenName
                surfaceHeight: Services.BarLayoutService.barHeight
                contentWidth: sectionRow.implicitWidth
                contentHeight: sectionRow.implicitHeight
                surfaceState: root.surfaceState
                hoverIntent: sectionHoverHandler.hovered
                anchors.fill: parent

                // Host the tray DBus menu by expanding this dockzone downward
                // (island-style) when the menu is open and its anchor icon lives
                // in this section. The body grows by the menu height and widens
                // to the menu width; the menu renders in the body below the icon
                // row. expandHeight/expandWidth are zero for every other section
                // and when closed, so normal dockzones are unaffected.
                readonly property real rowScreenLeft: sectionRow.mapToItem(null, 0, 0).x
                readonly property real rowScreenRight: sectionRow.mapToItem(null, sectionRow.width, 0).x
                readonly property bool hostsTrayMenu: root.hasSectionContent
                    && Services.TrayMenuService.visible
                    && Services.TrayMenuService.anchorX >= rowScreenLeft - 24
                    && Services.TrayMenuService.anchorX <= rowScreenRight + 24
                readonly property real menuW: trayMenuLoader.item ? trayMenuLoader.item.implicitWidth : 0
                readonly property real menuH: trayMenuLoader.item ? trayMenuLoader.item.implicitHeight : 0

                expandHeight: hostsTrayMenu ? (menuH + 8) : 0
                expandWidth: hostsTrayMenu ? menuW : 0

                Behavior on expandHeight {
                    SpringAnimation {
                        spring: Services.Motion.islandExpand.spring
                        mass: Services.Motion.islandExpand.mass
                        damping: Services.Motion.islandExpand.dampingExpand
                        epsilon: Services.Motion.islandExpand.epsilon
                    }
                }
                Behavior on expandWidth {
                    SpringAnimation {
                        spring: Services.Motion.islandExpand.spring
                        mass: Services.Motion.islandExpand.mass
                        damping: Services.Motion.islandExpand.dampingExpand
                        epsilon: Services.Motion.islandExpand.epsilon
                    }
                }

                // Tray DBus menu rendered inside the expanded body, beneath the
                // icon row. Kept loaded while the body is still collapsing so the
                // shrink animation has content to clip.
                Loader {
                    id: trayMenuLoader

                    active: dockzone.hostsTrayMenu || dockzone.bodyHeight > dockzone.topBandHeight + 1
                    z: 2
                    x: parent.bodyX + (parent.bodyWidth - width) / 2
                    y: parent.bodyY + parent.topBandHeight
                    width: dockzone.menuW
                    clip: true
                    height: Math.max(0, dockzone.bodyHeight - parent.topBandHeight)

                    sourceComponent: Tray.TrayMenuView {
                        rootHandle: Services.TrayMenuService.menuHandle
                    }

                    // Keep the menu open while the pointer rests on it.
                    HoverHandler {
                        id: trayMenuHover
                        onHoveredChanged: Services.TrayMenuService.pointerInMenu = hovered
                    }
                }

                // Lay out widgets for this section in order.
                Row {
                    id: sectionRow

                    z: 1
                    // Center horizontally in the body; vertically in the resting
                    // top band so it stays put when the body expands downward.
                    x: parent.bodyX + (parent.bodyWidth - width) / 2
                    y: parent.bodyY + (parent.topBandHeight - height) / 2
                    spacing: BarLayoutSections.widgetSpacing

                    // Instantiate each managed widget in sequence.
                    Repeater {
                        model: root.sectionModel.length

                        // Keep each widget wrapper as the delegate so its implicit size drives the row.
                        BarWidgetWrapper {
                            required property int index

                            screenName: root.screenName
                            widgetEntry: root.sectionModel[index]
                            widgetSource: Qt.resolvedUrl(widgetEntry.source)

                            onLocalPointerIntentChanged: surfaceRoot.syncCenterFloatingValidationIntent()
                        }

                    }

                }

            }

        }

    }

}
