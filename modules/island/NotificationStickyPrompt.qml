import QtQuick
import Quickshell
import "../../services" as Services

// Hint capsule for toggling persistent notification state.
Item {
    id: root

    property bool sticky: false
    property string appName: ""
    property string summary: ""
    property string body: ""
    property string rawIcon: ""
    property color promptColor: Qt.rgba(Services.Color.mPrimary.r, Services.Color.mPrimary.g, Services.Color.mPrimary.b, root.sticky ? 0.18 : 0.1)
    property color promptOutlineColor: Qt.rgba(Services.Color.mPrimary.r, Services.Color.mPrimary.g, Services.Color.mPrimary.b, root.sticky ? 0.62 : 0.38)
    readonly property string iconSource: {
        if (root.rawIcon === "") return ""
        if (root.rawIcon.indexOf("/") !== -1 || root.rawIcon.indexOf(":") !== -1)
            return root.rawIcon
        return Quickshell.iconPath(root.rawIcon, true)
    }
    readonly property string previewTitle: root.appName !== "" ? root.appName : "通知"
    readonly property string previewText: root.summary !== "" ? root.summary : (root.body !== "" ? root.body : "无正文")

    implicitWidth: promptCapsule.implicitWidth
    implicitHeight: promptCapsule.implicitHeight

    Behavior on promptColor {
        ColorAnimation { duration: Services.Motion.color.transitionDuration; easing.type: Services.Motion.color.transitionEasing }
    }

    Behavior on promptOutlineColor {
        ColorAnimation { duration: Services.Motion.color.transitionDuration; easing.type: Services.Motion.color.transitionEasing }
    }

    // Keep the hint readable as a standalone layout unit.
    Rectangle {
        id: promptCapsule

        width: root.width > 0 ? root.width : implicitWidth
        height: implicitHeight
        radius: 10
        color: root.promptColor
        border.color: root.promptOutlineColor
        border.width: 1
        clip: true

        implicitWidth: Math.max(actionRow.implicitWidth + 20, previewRow.implicitWidth + 20)
        implicitHeight: previewRow.implicitHeight + actionRow.implicitHeight + 18

        // Stack the latest notification preview above the sticky action hint.
        Column {
            id: promptColumn

            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            // Show the latest notification source and content.
            Row {
                id: previewRow

                width: parent.width
                spacing: 8

                // App icon or fallback source monogram.
                Item {
                    width: 22
                    height: 22
                    anchors.verticalCenter: parent.verticalCenter

                    Image {
                        anchors.fill: parent
                        visible: root.iconSource !== ""
                        source: root.iconSource
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        sourceSize.width: 22
                        sourceSize.height: 22
                    }

                    Services.FluidText {
                        anchors.centerIn: parent
                        visible: root.iconSource === ""
                        text: root.previewTitle.charAt(0).toUpperCase()
                        color: Services.Color.mOnSurface
                        basePixelSize: 10
                        font.bold: true
                    }
                }

                // Latest message text.
                Column {
                    width: Math.max(0, parent.width - 30)
                    spacing: 1

                    Services.FluidText {
                        width: parent.width
                        text: root.previewTitle
                        color: Services.Color.mOnSurface
                        basePixelSize: 11
                        font.bold: true
                        elide: Text.ElideRight
                    }

                    Services.FluidText {
                        width: parent.width
                        text: root.previewText
                        color: Services.Color.mOnSurfaceVariant
                        basePixelSize: 10
                        elide: Text.ElideRight
                    }
                }
            }

            // Pair the prompt glyph and copy inside the capsule.
            Row {
                id: actionRow

                spacing: 6

                // Sticky state glyph.
                Services.FluidText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.sticky ? "★" : "+"
                    color: Services.Color.mPrimary
                    basePixelSize: root.sticky ? 11 : 12
                    font.bold: true
                }

                // Persistent-state action copy.
                Services.FluidText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.sticky ? "左键可取消常驻" : "左键可设为常驻"
                    color: Services.Color.mOnSurfaceVariant
                    basePixelSize: 10
                }
            }
        }
    }
}
