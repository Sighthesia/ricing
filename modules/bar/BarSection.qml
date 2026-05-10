import "."
import "../../services" as Services
import "../../services/barlayout/BarLayoutSections.js" as BarLayoutSections
import QtQuick

// Render a single ordered section from the shared layout model.
Item {
    id: root

    required property string sectionName
    readonly property var sectionModel: Services.BarLayoutService.sectionWidgets(sectionName)

    implicitHeight: Services.BarLayoutService.barHeight
    implicitWidth: sectionRow.implicitWidth
    width: implicitWidth
    height: implicitHeight

    // Lay out widgets for this section in order.
    Row {
        id: sectionRow

        anchors.fill: parent
        spacing: BarLayoutSections.widgetSpacing

        // Instantiate each managed widget in sequence.
        Repeater {
            model: root.sectionModel.length

            // Keep each widget wrapper as the delegate so its implicit size drives the row.
            BarWidgetWrapper {
                required property int index

                widgetEntry: root.sectionModel[index]
                widgetSource: Qt.resolvedUrl(widgetEntry.source)
            }

        }

    }

}
