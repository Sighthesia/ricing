import QtQuick
import "../lazerbar"
import "BarPopupMotion.js" as PopupMotion

// Shared two-layer popup frame reusing the settings panel language.
// Top layer (near the bar) is a darker rail showing the component/tray name;
// bottom layer is the content slot. Visual tokens mirror LazerSettings.
Rectangle {
    id: root

    property string title: ""
    property string iconSource: ""
    property string extraText: ""
    property int headerHeight: 48
    // Host-owned progress lets the header and content enter at different
    // offsets, matching the settings sidebar's layered reveal.
    property real revealProgress: 1
    readonly property int revealDuration: MotionTokens.settingsSidebarFade + MotionTokens.settingsContentDelay
    readonly property real headerProgress: PopupMotion.headerProgress(
        revealProgress, revealDuration, MotionTokens.settingsSidebarFade)
    readonly property real contentProgress: PopupMotion.contentProgress(
        revealProgress, revealDuration, MotionTokens.settingsContentDelay,
        MotionTokens.settingsSidebarFade)

    default property alias contentData: contentSlot.data
    readonly property alias contentItem: contentSlot

    radius: 0
    color: LazerTheme.settingsPanel
    // The settings panel uses color blocks for structure, not a popup outline.
    border.width: 0
    clip: true

    // Implicit size follows the content plus the two-layer chrome.
    implicitWidth: Math.max(headerRow.implicitWidth + 32, contentSlot.implicitWidth + 24)
    implicitHeight: header.height + divider.height + contentSlot.implicitHeight

    // -- Header layer (settingsRail) --
    Item {
        id: header

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: root.headerHeight
        opacity: root.headerProgress
        transform: Translate { y: -PopupMotion.offset(root.headerProgress, 12) }

        // Straight rail continues the settings sidebar's main-surface shape.
        Rectangle {
            id: headerBg

            anchors.fill: parent
            color: LazerTheme.settingsRail
        }

        Row {
            id: headerRow

            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.right: extraLabel.visible ? extraLabel.left : parent.right
            anchors.rightMargin: extraLabel.visible ? 8 : 16
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            Image {
                anchors.verticalCenter: parent.verticalCenter
                width: 16
                height: 16
                source: root.iconSource
                sourceSize: Qt.size(16, 16)
                fillMode: Image.PreserveAspectFit
                smooth: true
                asynchronous: true
                visible: root.iconSource !== ""
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - (parent.children[0].visible ? 24 : 0)
                text: root.title
                color: LazerTheme.textPrimary
                font.pixelSize: 14
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                maximumLineCount: 1
            }
        }

        Text {
            id: extraLabel

            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            text: root.extraText
            color: LazerTheme.textMuted
            font.pixelSize: 13
            visible: root.extraText !== ""
        }
    }

    Rectangle {
        id: divider

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: header.bottom
        height: 1
        color: LazerTheme.divider
    }

    // Content slot below the divider; callers fill it with Flickable/Column etc.
    Item {
        id: contentSlot

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: divider.bottom
        anchors.bottom: parent.bottom
        opacity: root.contentProgress
        transform: Translate { y: PopupMotion.offset(root.contentProgress, 14) }
        // Let children define height; the frame tracks implicitHeight.
        implicitHeight: childrenRect.height
        implicitWidth: childrenRect.width
    }
}
