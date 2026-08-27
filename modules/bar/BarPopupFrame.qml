import QtQuick
import "../lazerbar"
import "BarPopupMotion.js" as PopupMotion

// Shared two-card popup frame reusing the settings sidebar's independent surfaces.
// Two brother cards (headerCard + contentCard) each own their background and motion.
Item {
    id: root

    property string title: ""
    property string iconSource: ""
    property string extraText: ""
    property int headerHeight: 48
    property real revealProgress: 1
    readonly property int revealDuration: MotionTokens.settingsSidebarFade + MotionTokens.settingsContentDelay
    readonly property real headerProgress: PopupMotion.headerProgress(
        revealProgress, revealDuration, MotionTokens.settingsSidebarFade)
    readonly property real contentProgress: PopupMotion.contentProgress(
        revealProgress, revealDuration, MotionTokens.settingsContentDelay,
        MotionTokens.settingsSidebarFade)

    default property alias contentData: contentCard.data
    readonly property alias contentItem: contentCard
    readonly property alias headerCard: headerCard

    clip: true

    implicitWidth: Math.max(headerRow.implicitWidth + 32, contentCard.implicitWidth + 24)
    implicitHeight: headerCard.height + divider.height + contentCard.implicitHeight

    // -- Header card (settingsRail) --
    Rectangle {
        id: headerCard

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: root.headerHeight
        radius: 0
        color: LazerTheme.settingsRail
        border.width: 0
        opacity: root.headerProgress
        transform: Translate { y: -PopupMotion.offset(root.headerProgress, 12) }

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
        anchors.top: headerCard.bottom
        height: 1
        color: LazerTheme.divider
    }

    // -- Content card (settingsPanel) --
    Rectangle {
        id: contentCard

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: divider.bottom
        // Height tracks children; let callers define via Column/Flickable.
        implicitHeight: childrenRect.height
        implicitWidth: childrenRect.width
        height: implicitHeight
        radius: 0
        color: LazerTheme.settingsPanel
        border.width: 0
        opacity: root.contentProgress
        transform: Translate { y: PopupMotion.offset(root.contentProgress, 14) }
    }
}
