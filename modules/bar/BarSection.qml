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
    readonly property string centerSurfaceState: root.sectionName === "center" && root.sectionModel.length > 0 ? (root.floatingValidationIntent ? "floating" : "attached") : "hidden"

    implicitHeight: Services.BarLayoutService.barHeight
    implicitWidth: surfaceLoader.item ? surfaceLoader.item.implicitWidth : 0
    width: implicitWidth
    height: implicitHeight

    // Route center through the new surface owner; left/right keep the legacy path.
    Loader {
        id: surfaceLoader

        active: true
        sourceComponent: root.sectionName === "center" ? centerSurface : legacySurface
    }

    // Center path: owner-managed surface with model-driven rendering.
    Component {
        id: centerSurface

        Item {
            id: centerSurfaceRoot

            implicitWidth: dockzone.implicitWidth
            implicitHeight: dockzone.implicitHeight
            width: implicitWidth
            height: implicitHeight

            function syncCenterFloatingValidationIntent() {
                var hasLocalPointerIntent = false;

                for (var i = 0; i < centerRow.children.length; ++i) {
                    var child = centerRow.children[i];
                    if (child && child.localPointerIntent) {
                        hasLocalPointerIntent = true;
                        break;
                    }
                }

                root.floatingValidationIntent = hasLocalPointerIntent;
            }

            Component.onCompleted: syncCenterFloatingValidationIntent()

            DockzoneSurfaceRoot {
                id: dockzone

                section: root.sectionName
                screenName: root.screenName
                surfaceHeight: root.implicitHeight
                contentWidth: centerRow.implicitWidth
                contentHeight: centerRow.implicitHeight
                surfaceState: root.centerSurfaceState
                anchors.fill: parent

                // Lay out widgets for this section in order.
                Row {
                    id: centerRow

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

                            onLocalPointerIntentChanged: centerSurfaceRoot.syncCenterFloatingValidationIntent()
                        }

                    }

                }

            }

        }

    }

    // Left/right path: legacy background kept until full migration.
    Component {
        id: legacySurface

        BarDockZoneBackground {
            screenName: root.screenName
            sectionType: root.sectionName
            surfaceHeight: root.implicitHeight
            contentWidth: legacyRow.implicitWidth
            contentHeight: legacyRow.implicitHeight

            // Lay out widgets for this section in order.
            Row {
                id: legacyRow

                z: 1
                x: parent.bodyX + (parent.bodyWidth - width) / 2
                y: parent.bodyY + (parent.bodyHeight - height) / 2
                spacing: BarLayoutSections.widgetSpacing

                // Instantiate each managed widget in sequence.
                Repeater {
                    id: legacyRepeater

                    model: root.sectionModel.length

                    // Keep each widget wrapper as the delegate so its implicit size drives the row.
                    BarWidgetWrapper {
                        required property int index

                        screenName: root.screenName
                        widgetEntry: root.sectionModel[index]
                        widgetSource: Qt.resolvedUrl(widgetEntry.source)
                    }

                }

            }

        }

    }

}
