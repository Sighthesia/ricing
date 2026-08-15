import QtQuick

// Present one transient notification as a compact glass island.
Item {
    id: root
    property string appName: ""
    property string summary: ""
    property string body: ""
    property string iconSource: ""
    property bool openState: false
    readonly property bool reducedMotion: MotionTokens.reducedMotion
    signal dismissRequested

    implicitWidth: 360
    implicitHeight: card.implicitHeight
    height: implicitHeight
    opacity: openState ? 1 : 0
    scale: reducedMotion ? 1 : (openState ? 1 : 0.96)

    Component.onCompleted: Qt.callLater(function() { root.openState = true })

    Behavior on opacity { NumberAnimation { duration: root.reducedMotion ? 0 : MotionTokens.fast; easing.type: Easing.OutCubic } }
    Behavior on scale { NumberAnimation { duration: root.reducedMotion ? 0 : MotionTokens.medium; easing.type: Easing.OutBack } }

    // Draw the notification surface and its readable content column.
    Rectangle {
        id: card
        implicitWidth: 360
        implicitHeight: contentColumn.implicitHeight + 24
        width: parent.width
        height: parent.height
        radius: 14
        color: "#E61D1C22"
        border.width: 1
        border.color: "#24FFFFFF"

        Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
        Behavior on border.color { ColorAnimation { duration: MotionTokens.fast } }

        // Keep notification text clear of the rounded glass corners.
        Column {
            id: contentColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 12
            spacing: 4

            // Identify the source without competing with the notification summary.
            Text {
                width: parent.width
                text: root.appName || "Notification"
                color: "#B8B4BC"
                font.pixelSize: 11
                elide: Text.ElideRight
            }

            // Keep the summary visually dominant in the compact popup.
            Text {
                width: parent.width
                text: root.summary
                color: "#FFFFFF"
                font.pixelSize: 15
                font.bold: true
                wrapMode: Text.Wrap
            }

            // Allow longer notification bodies to determine the card height.
            Text {
                width: parent.width
                text: root.body
                visible: text.length > 0
                color: "#B8B4BC"
                font.pixelSize: 12
                wrapMode: Text.Wrap
                maximumLineCount: 5
                elide: Text.ElideRight
            }

            // Offer an explicit, keyboard- and pointer-friendly dismissal action.
            Rectangle {
                width: 70
                height: 26
                radius: 13
                color: dismissArea.containsMouse ? "#18FFFFFF" : "transparent"
                border.width: 1
                border.color: "#24FFFFFF"

                Text {
                    anchors.centerIn: parent
                    text: "关闭"
                    color: "#FFFFFF"
                    font.pixelSize: 11
                }

                MouseArea {
                    id: dismissArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: root.dismissRequested()
                }
            }
        }
    }

}
