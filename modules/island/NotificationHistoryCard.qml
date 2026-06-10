import QtQuick
import Quickshell
import "../../services" as Services
import "../common" as Common

// Individual history row: hover reveals full text, click toggles sticky.
Item {
    id: root

    property var notificationEntry: null
    signal toggleStickyRequested()
    signal hoverEntered()

    readonly property bool hovered: hoverHandler.hovered
    readonly property bool sticky: notificationEntry ? !!notificationEntry.sticky : false
    readonly property bool read: notificationEntry ? !!notificationEntry.read : false
    readonly property string appName: notificationEntry ? (notificationEntry.appName || "") : ""
    readonly property string summary: notificationEntry ? (notificationEntry.summary || "") : ""
    readonly property string body: notificationEntry ? (notificationEntry.body || "") : ""
    readonly property string iconSource: {
        const icon = notificationEntry ? (notificationEntry.icon || "") : ""
        if (icon === "") return ""
        if (icon.indexOf("/") !== -1 || icon.indexOf(":") !== -1)
            return icon
        return Quickshell.iconPath(icon, true)
    }

    implicitWidth: card.implicitWidth
    implicitHeight: card.implicitHeight

    // Track hover so the full body can expand in place.
    HoverHandler {
        id: hoverHandler
        onHoveredChanged: {
            if (hovered)
                root.hoverEntered()
        }
    }

    // Render the notification card itself.
    Common.GlassCapsule {
        id: card

        width: ListView.view ? ListView.view.width : 200
        radius: 16
        surfaceColor: Qt.alpha(Services.Color.mSurface, Services.SettingsService.panelSurfaceOpacity)
        outlineColor: root.sticky
            ? Qt.rgba(Services.Color.mPrimary.r, Services.Color.mPrimary.g, Services.Color.mPrimary.b, 0.9)
            : Qt.rgba(Services.Color.mOutline.r, Services.Color.mOutline.g, Services.Color.mOutline.b, root.read ? 0.55 : 0.75)
        borderWidth: root.sticky ? 1.4 : 1

        implicitHeight: root.hovered ? expandedColumn.implicitHeight + 18 : compactRow.implicitHeight + 18

        Behavior on implicitHeight {
            NumberAnimation { duration: Services.Motion.number.contentDuration; easing.type: Services.Motion.number.contentEasing }
        }
        Behavior on outlineColor {
            ColorAnimation { duration: Services.Motion.color.transitionDuration; easing.type: Services.Motion.color.transitionEasing }
        }

        // Toggle sticky with a primary click.
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.toggleStickyRequested()
        }

        // Condensed row for the collapsed view.
        Row {
            id: compactRow

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            anchors.top: parent.top
            anchors.topMargin: 9
            spacing: 10

            // App icon or fallback monogram.
            Item {
                width: 24
                height: 24
                anchors.verticalCenter: parent.verticalCenter

                Image {
                    anchors.fill: parent
                    visible: root.iconSource !== ""
                    source: root.iconSource
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    sourceSize.width: 24
                    sourceSize.height: 24
                }

                Services.FluidText {
                    anchors.centerIn: parent
                    visible: root.iconSource === ""
                    text: root.appName !== "" ? root.appName.charAt(0).toUpperCase() : "N"
                    color: Services.Color.mOnSurface
                    basePixelSize: 11
                    font.bold: true
                }
            }

            // Summary text keeps the list scannable.
            Column {
                width: parent.width - 92
                spacing: 2

                Services.FluidText {
                    width: parent.width
                    text: root.appName !== "" ? root.appName : "通知"
                    color: Services.Color.mOnSurface
                    basePixelSize: 12
                    font.bold: true
                    elide: Text.ElideRight
                }

                Services.FluidText {
                    width: parent.width
                    text: root.summary !== "" ? root.summary : root.body
                    color: Services.Color.mOnSurfaceVariant
                    basePixelSize: 11
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }
            }

            // Sticky marker for persistent entries.
            Services.FluidText {
                anchors.verticalCenter: parent.verticalCenter
                text: root.sticky ? "★" : ""
                color: Services.Color.mPrimary
                basePixelSize: 13
                font.bold: true
            }
        }

        // Expanded full-text preview on hover.
        Column {
            id: expandedColumn

            visible: root.hovered
            opacity: root.hovered ? 1 : 0
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: compactRow.bottom
            anchors.topMargin: 6
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            spacing: 4

            Behavior on opacity {
                NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
            }

            Services.FluidText {
                width: parent.width
                text: root.summary
                color: Services.Color.mOnSurface
                basePixelSize: 12
                font.bold: true
                wrapMode: Text.WordWrap
            }

            Services.FluidText {
                width: parent.width
                text: root.body !== "" ? root.body : "(无正文)"
                color: Services.Color.mOnSurfaceVariant
                basePixelSize: 11
                wrapMode: Text.WordWrap
            }

            // Hint how primary click changes persistent state.
            NotificationStickyPrompt {
                width: parent.width
                sticky: root.sticky
            }
        }
    }
}
