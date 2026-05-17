import QtQuick
import Quickshell.Widgets
import "../../../services" as Services

// Display the focused window icon and title.
Item {
    id: root

    property string displayedTitle: Services.NiriService.activeTitle || "Desktop"
    property string displayedAppId: Services.NiriService.activeAppId || ""
    property string pendingTitle: displayedTitle
    property string pendingAppId: displayedAppId

    implicitWidth: Math.min(contentRow.implicitWidth + 16, 220)
    implicitHeight: 26

    Behavior on implicitWidth {
        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
    }

    function syncFocusedWindow() {
        var nextTitle = Services.NiriService.activeTitle || "Desktop"
        var nextAppId = Services.NiriService.activeAppId || ""

        if (nextTitle === root.displayedTitle && nextAppId === root.displayedAppId)
            return

        root.pendingTitle = nextTitle
        root.pendingAppId = nextAppId
        fadeTransition.restart()
    }

    Component.onCompleted: syncFocusedWindow()

    Connections {
        target: Services.NiriService
        function onWindowsUpdated() {
            root.syncFocusedWindow()
        }
    }

    SequentialAnimation {
        id: fadeTransition

        NumberAnimation {
            target: contentRow
            property: "opacity"
            to: 0
            duration: 90
            easing.type: Easing.OutCubic
        }

        ScriptAction {
            script: {
                root.displayedTitle = root.pendingTitle
                root.displayedAppId = root.pendingAppId
            }
        }

        NumberAnimation {
            target: contentRow
            property: "opacity"
            to: 1
            duration: 120
            easing.type: Easing.OutCubic
        }
    }

    Row {
        id: contentRow
        anchors.centerIn: parent
        spacing: 6
        opacity: 1

        // Animate the focused app icon in and out.
        Item {
            id: iconSlot

            anchors.verticalCenter: parent.verticalCenter
            width: root.displayedAppId !== "" ? 16 : 0
            height: 16
            opacity: root.displayedAppId !== "" ? 1 : 0

            Behavior on width {
                NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
            }

            Behavior on opacity {
                NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
            }

            IconImage {
                anchors.fill: parent
                source: "image://icon/" + (root.displayedAppId || "application-x-executable")
                implicitSize: 16
                visible: iconSlot.width > 0
            }
        }

        // Keep the active window title readable in the bar.
        Item {
            id: titleSlot

            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(titleText.implicitWidth, 184)
            opacity: 1

            Behavior on width {
                NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
            }

            Text {
                id: titleText
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                text: root.displayedTitle
                color: Services.Color.mOnSurface
                font.pixelSize: 12
                elide: Text.ElideRight
                maximumLineCount: 1
            }
        }
    }
}
