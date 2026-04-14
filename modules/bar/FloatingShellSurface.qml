import QtQuick
import qs.config

// Shared floating shell surface for bar panels and popups that should read as
// one SuperIsland-family card instead of a separate floating panel style.
Rectangle {
    id: root

    property real contentMargin: 0
    property color fillColor: Qt.rgba(
        Colors.background.r,
        Colors.background.g,
        Colors.background.b,
        ThemeCards.shellSurfaceAlpha
    )
    property color borderColor: Qt.rgba(
        Colors.border.r,
        Colors.border.g,
        Colors.border.b,
        ThemeCards.shellBorderAlpha
    )
    property color innerBorderColor: Qt.rgba(
        Colors.text.r,
        Colors.text.g,
        Colors.text.b,
        ThemeCards.shellInnerBorderAlpha
    )
    property real shellRadius: ThemeCards.shellRadius
    property real innerBorderInset: 1
    property real innerBorderWidth: 1
    default property alias content: contentItem.data

    color: root.fillColor
    radius: root.shellRadius
    border.color: root.borderColor
    border.width: 1

    Item {
        id: contentItem

        anchors.fill: parent
        anchors.margins: root.contentMargin
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: root.innerBorderInset
        radius: Math.max(0, root.shellRadius - root.innerBorderInset)
        color: "transparent"
        border.color: root.innerBorderColor
        border.width: root.innerBorderWidth
        visible: root.innerBorderWidth > 0
    }
}
