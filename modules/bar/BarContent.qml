import QtQuick
import QtQuick.Layouts
import qs.config

Item {
    id: barContent

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.barPadding
        anchors.rightMargin: Theme.barPadding
        spacing: 0

        BarSection {
            role: "left"
            Layout.fillHeight: true
        }

        Item { Layout.fillWidth: true; Layout.fillHeight: true }

        BarSection {
            role: "center"
            Layout.fillHeight: true
        }

        Item { Layout.fillWidth: true; Layout.fillHeight: true }

        BarSection {
            role: "right"
            Layout.fillHeight: true
        }
    }
}
