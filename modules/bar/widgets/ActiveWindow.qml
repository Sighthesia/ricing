import QtQuick
import Quickshell.Widgets
import "../../../services" as Services

// Display the focused window icon and title.
Item {
    id: root

    property string currentTitle: Services.NiriService.activeTitle || "Desktop"
    property string currentAppId: Services.NiriService.activeAppId || ""
    property string pendingTitle: currentTitle
    property string pendingAppId: currentAppId
    property bool transitioning: false

    implicitWidth: Math.min(Math.max(currentLayer.implicitWidth, nextLayer.implicitWidth) + 16, 220)
    implicitHeight: 26

    Behavior on implicitWidth {
        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
    }

    function syncFocusedWindow() {
        var nextTitle = Services.NiriService.activeTitle || "Desktop"
        var nextAppId = Services.NiriService.activeAppId || ""

        if (nextTitle === root.currentTitle && nextAppId === root.currentAppId && !root.transitioning)
            return

        root.pendingTitle = nextTitle
        root.pendingAppId = nextAppId

        if (root.transitioning)
            return

        root.transitioning = true
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

        ParallelAnimation {
            NumberAnimation {
                target: currentLayer
                property: "opacity"
                from: 1
                to: 0
                duration: 100
                easing.type: Easing.OutCubic
            }

            NumberAnimation {
                target: nextLayer
                property: "opacity"
                from: 0
                to: 1
                duration: 140
                easing.type: Easing.OutCubic
            }
        }

        ScriptAction {
            script: {
                root.currentTitle = root.pendingTitle
                root.currentAppId = root.pendingAppId
            }
        }

        ScriptAction {
            script: {
                currentLayer.opacity = 1
                nextLayer.opacity = 0
                root.transitioning = false
            }
        }
    }

    // Keep the current content visible while the next one fades in.
    Item {
        id: currentLayer

        anchors.centerIn: parent
        opacity: 1
        visible: opacity > 0

        implicitWidth: currentContent.implicitWidth
        implicitHeight: currentContent.implicitHeight

        // Render the currently focused icon and title.
        Row {
            id: currentContent

            anchors.centerIn: parent
            spacing: 6

            // Current app icon.
            Item {
                id: currentIconSlot

                anchors.verticalCenter: parent.verticalCenter
                width: root.currentAppId !== "" ? 16 : 0
                height: 16
                opacity: root.currentAppId !== "" ? 1 : 0

                Behavior on width {
                    NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                }

                Behavior on opacity {
                    NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                }

                IconImage {
                    anchors.fill: parent
                    source: "image://icon/" + (root.currentAppId || "application-x-executable")
                    implicitSize: 16
                    visible: currentIconSlot.width > 0
                }
            }

            // Current window title.
            Item {
                id: currentTitleSlot

                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(currentTitleText.implicitWidth, 184)
                height: currentTitleText.implicitHeight

                Behavior on width {
                    NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                }

                Text {
                    id: currentTitleText
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    text: root.currentTitle
                    color: Services.Color.mOnSurface
                    font.pixelSize: 12
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }
            }
        }
    }

    // Fade in the next content on top of the outgoing content.
    Item {
        id: nextLayer

        anchors.centerIn: parent
        opacity: 0
        visible: opacity > 0
        z: 1

        implicitWidth: nextContent.implicitWidth
        implicitHeight: nextContent.implicitHeight

        // Render the next focused icon and title.
        Row {
            id: nextContent

            anchors.centerIn: parent
            spacing: 6

            // Next app icon.
            Item {
                id: nextIconSlot

                anchors.verticalCenter: parent.verticalCenter
                width: root.pendingAppId !== "" ? 16 : 0
                height: 16
                opacity: root.pendingAppId !== "" ? 1 : 0

                Behavior on width {
                    NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                }

                Behavior on opacity {
                    NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                }

                IconImage {
                    anchors.fill: parent
                    source: "image://icon/" + (root.pendingAppId || "application-x-executable")
                    implicitSize: 16
                    visible: nextIconSlot.width > 0
                }
            }

            // Next window title.
            Item {
                id: nextTitleSlot

                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(nextTitleText.implicitWidth, 184)
                height: nextTitleText.implicitHeight

                Behavior on width {
                    NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                }

                Text {
                    id: nextTitleText
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    text: root.pendingTitle
                    color: Services.Color.mOnSurface
                    font.pixelSize: 12
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }
            }
        }
    }
}
