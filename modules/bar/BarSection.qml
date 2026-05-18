import "."
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

                // Lay out widgets for this section in order.
                Row {
                    id: sectionRow

                    z: 1
                    x: parent.bodyX + (parent.bodyWidth - width) / 2
                    y: parent.bodyY + (parent.bodyHeight - height) / 2
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
