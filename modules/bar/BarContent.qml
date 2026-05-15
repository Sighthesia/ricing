import "."
import "../../services" as Services
import QtQuick

// Compose the left, center, and right bar zones.
Item {
    id: root

    required property string screenName

    // Keep the transparent container tall enough for unified side bottom ears.
    implicitHeight: Math.max(
        Services.BarLayoutService.barHeight,
        leftSection.implicitHeight,
        centerSection.implicitHeight,
        rightSection.implicitHeight
    )

    // Keep the left zone anchored to the screen edge.
    BarSection {
        id: leftSection

        sectionName: "left"
        screenName: root.screenName
        anchors.left: parent.left
        anchors.top: parent.top
    }

    // Keep the center zone aligned to the screen midpoint.
    BarSection {
        id: centerSection

        sectionName: "center"
        screenName: root.screenName
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
    }

    // Keep the right zone anchored to the screen edge.
    BarSection {
        id: rightSection

        sectionName: "right"
        screenName: root.screenName
        anchors.right: parent.right
        anchors.top: parent.top
    }

}
