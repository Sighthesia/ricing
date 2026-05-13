import "."
import "../../services" as Services
import QtQuick

// Compose the left, center, and right bar zones.
Item {
    id: root

    required property string screenName
    implicitHeight: Services.BarLayoutService.barHeight

    // Keep the left zone anchored to the screen edge.
    BarSection {
        sectionName: "left"
        screenName: root.screenName
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
    }

    // Keep the center zone aligned to the screen midpoint.
    BarSection {
        sectionName: "center"
        screenName: root.screenName
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.bottom: parent.bottom
    }

    // Keep the right zone anchored to the screen edge.
    BarSection {
        sectionName: "right"
        screenName: root.screenName
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
    }

}
