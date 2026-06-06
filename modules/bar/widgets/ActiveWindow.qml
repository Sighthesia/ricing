import QtQuick
import Quickshell.Widgets
import "../../../services" as Services
import "../../../services/WidgetSettingsRegistry.js" as WidgetSettingsRegistry

// Display the focused window icon and title.
Item {
    id: root

    property string currentTitle: Services.NiriService.activeTitle || "Desktop"
    property string currentAppId: Services.NiriService.activeAppId || ""
    property string pendingTitle: currentTitle
    property string pendingAppId: currentAppId
    property bool transitioning: false
    property real availableWidth: -1
    readonly property var activeWindowSettings: WidgetSettingsRegistry.settingsObject(
        "active-window",
        Services.SettingsService.widgetSettings
    )
    readonly property string desktopLabel: activeWindowSettings
        ? activeWindowSettings.desktopLabel
        : "Desktop"
    readonly property bool showIcon: activeWindowSettings
        ? activeWindowSettings.showIcon
        : true
    readonly property int maxTitleWidth: activeWindowSettings
        ? activeWindowSettings.maxTitleWidth
        : 200
    readonly property real compactTitleWidth: {
        if (root.availableWidth <= 0)
            return root.maxTitleWidth

        var iconWidth = root.showIcon ? 18 : 0
        var spacing = root.showIcon ? 6 : 0
        var chrome = 20
        return Math.max(40, Math.min(root.maxTitleWidth, root.availableWidth - iconWidth - spacing - chrome))
    }
    readonly property real currentIconTargetWidth: root.showIcon && root.currentAppId !== "" ? 18 : 0
    readonly property real nextIconTargetWidth: root.showIcon && root.pendingAppId !== "" ? 18 : 0
    readonly property real currentTitleTargetWidth: Math.min(currentTitleText.implicitWidth, root.compactTitleWidth)
    readonly property real nextTitleTargetWidth: Math.min(nextTitleText.implicitWidth, root.compactTitleWidth)

    implicitWidth: Math.min(Math.max(currentLayer.implicitWidth, nextLayer.implicitWidth) + 20, 240)
    implicitHeight: 30

    function syncFocusedWindow() {
        var nextTitle = Services.NiriService.activeTitle || root.desktopLabel
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
                duration: Services.Motion.number.shortDuration
                easing.type: Services.Motion.number.shortEasing
            }

            NumberAnimation {
                target: nextLayer
                property: "opacity"
                from: 0
                to: 1
                duration: Services.Motion.number.enterDuration
                easing.type: Services.Motion.number.enterEasing
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

        implicitWidth: root.currentIconTargetWidth + root.currentTitleTargetWidth + (root.currentTitleTargetWidth > 0 && root.currentIconTargetWidth > 0 ? currentContent.spacing : 0)
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
                property real revealWidth: root.currentIconTargetWidth

                width: revealWidth
                height: 18
                opacity: root.currentIconTargetWidth > 0 ? 1 : 0

                Behavior on revealWidth {
                    NumberAnimation { duration: Services.Motion.number.contentDuration; easing.type: Services.Motion.number.contentEasing }
                }

                Behavior on opacity {
                    NumberAnimation { duration: Services.Motion.number.snugDuration; easing.type: Services.Motion.number.snugEasing }
                }

                IconImage {
                    anchors.fill: parent
                    source: root.currentAppId !== "" ? ("image://icon/" + root.currentAppId) : ""
                    implicitSize: 18
                    visible: currentIconSlot.width > 0
                }
            }

            // Current window title.
            Item {
                id: currentTitleSlot

                anchors.verticalCenter: parent.verticalCenter
                property real revealWidth: root.currentTitleTargetWidth

                width: revealWidth
                height: currentTitleText.implicitHeight

                Behavior on revealWidth {
                    NumberAnimation { duration: Services.Motion.number.contentDuration; easing.type: Services.Motion.number.contentEasing }
                }

                Text {
                    id: currentTitleText
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    text: root.currentTitle
                    color: Services.Color.mOnSurface
                    font.pixelSize: Services.TextSize.barContent
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

        implicitWidth: root.nextIconTargetWidth + root.nextTitleTargetWidth + (root.nextTitleTargetWidth > 0 && root.nextIconTargetWidth > 0 ? nextContent.spacing : 0)
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
                property real revealWidth: root.nextIconTargetWidth

                width: revealWidth
                height: 18
                opacity: root.nextIconTargetWidth > 0 ? 1 : 0

                Behavior on revealWidth {
                    NumberAnimation { duration: Services.Motion.number.contentDuration; easing.type: Services.Motion.number.contentEasing }
                }

                Behavior on opacity {
                    NumberAnimation { duration: Services.Motion.number.snugDuration; easing.type: Services.Motion.number.snugEasing }
                }

                IconImage {
                    anchors.fill: parent
                    source: root.pendingAppId !== "" ? ("image://icon/" + root.pendingAppId) : ""
                    implicitSize: 18
                    visible: nextIconSlot.width > 0
                }
            }

            // Next window title.
            Item {
                id: nextTitleSlot

                anchors.verticalCenter: parent.verticalCenter
                property real revealWidth: root.nextTitleTargetWidth

                width: revealWidth
                height: nextTitleText.implicitHeight

                Behavior on revealWidth {
                    NumberAnimation { duration: Services.Motion.number.contentDuration; easing.type: Services.Motion.number.contentEasing }
                }

                Text {
                    id: nextTitleText
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    text: root.pendingTitle
                    color: Services.Color.mOnSurface
                    font.pixelSize: Services.TextSize.barContent
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }
            }
        }
    }
}
