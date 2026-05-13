import "."
import "../../services" as Services
import "../../services/barlayout/BarLayoutSections.js" as BarLayoutSections
import QtQuick

// Render a single ordered section inside a shared attached-island surface.
Item {
    id: root

    required property string sectionName
    required property string screenName
    readonly property var sectionModel: Services.BarLayoutService.sectionWidgets(sectionName)

    implicitHeight: Services.BarLayoutService.barHeight
    implicitWidth: sectionSurface.implicitWidth
    width: implicitWidth
    height: implicitHeight

    // Wrap the ordered widgets in the shared section background.
    BarDockZoneBackground {
        id: sectionSurface

        screenName: root.screenName
        sectionType: root.sectionName
        surfaceHeight: root.implicitHeight
        contentWidth: sectionRow.implicitWidth
        contentHeight: sectionRow.implicitHeight

        // Lay out widgets for this section in order.
        Row {
            id: sectionRow

            x: sectionSurface.bodyX + (sectionSurface.bodyWidth - width) / 2
            anchors.verticalCenter: parent.verticalCenter
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
                }

            }

        }

    }

}
