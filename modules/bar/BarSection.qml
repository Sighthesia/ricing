import QtQuick
import QtQuick.Layouts

Item {
    id: section

    required property string role  // "left", "center", "right"

    implicitWidth: sectionRow.implicitWidth
    implicitHeight: parent ? parent.height : 0

    RowLayout {
        id: sectionRow
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8

        // Align-left sub-row
        Row {
            id: alignLeft
            spacing: 6
            // Widgets with alignment="left" go here
        }

        // Align-center sub-row
        Row {
            id: alignCenter
            spacing: 6
            // Widgets with alignment="center" go here
        }

        // Align-right sub-row
        Row {
            id: alignRight
            spacing: 6
            // Widgets with alignment="right" go here
        }
    }
}
