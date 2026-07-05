import QtQuick
import Quickshell
import Quickshell.Widgets
import "../../../services" as Services
import "../../../services/WidgetSettingsRegistry.js" as WidgetSettingsRegistry

// Display the focused window icon and title.
Item {
    id: root

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
    readonly property int maxWidth: activeWindowSettings
        ? activeWindowSettings.maxWidth
        : 240

    property real availableWidth: -1
    property string currentTitle: Services.NiriService.activeTitle || root.desktopLabel
    property string currentAppId: Services.NiriService.activeAppId || ""

    readonly property real compactTitleWidth: {
        if (root.availableWidth <= 0)
            return root.maxTitleWidth

        var iconWidth = root.showIcon ? 18 : 0
        var spacing = root.showIcon ? 6 : 0
        var chrome = 20
        return Math.max(40, Math.min(root.maxTitleWidth, root.availableWidth - iconWidth - spacing - chrome))
    }
    readonly property real iconTargetWidth: root.showIcon && root.currentAppId !== "" ? 18 : 0
    readonly property real titleTargetWidth: Math.min(titleText.contentWidth, root.compactTitleWidth)
    readonly property real rowSpacing: titleTargetWidth > 0 && iconTargetWidth > 0 ? contentRow.spacing : 0
    readonly property real targetImplicitWidth: Math.min(root.iconTargetWidth + root.titleTargetWidth + rowSpacing + 20, root.maxWidth)

    property real animImplicitWidth: targetImplicitWidth

    onTargetImplicitWidthChanged: root.animImplicitWidth = root.targetImplicitWidth

    implicitWidth: animImplicitWidth
    implicitHeight: 30

    Behavior on animImplicitWidth {
        NumberAnimation {
            duration: Services.Motion.number.contentDuration
            easing.type: Services.Motion.number.contentEasing
        }
    }

    function syncFocusedWindow() {
        root.currentTitle = Services.NiriService.activeTitle || root.desktopLabel
        root.currentAppId = Services.NiriService.activeAppId || ""
    }

    Component.onCompleted: syncFocusedWindow()

    Connections {
        target: Services.NiriService

        function onWindowsUpdated() {
            root.syncFocusedWindow()
        }
    }

    // Keep the content left-anchored so width changes only extend to the right.
    Row {
        id: contentRow

        anchors.left: parent.left
        anchors.leftMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6
    
        // Reveal the focused app icon without shifting the row anchor.
        Item {
            id: iconSlot

            anchors.verticalCenter: parent.verticalCenter
            property real revealWidth: root.iconTargetWidth

            width: revealWidth
            height: 18
            opacity: root.iconTargetWidth > 0 ? 1 : 0

            Behavior on revealWidth {
                NumberAnimation {
                    duration: Services.Motion.number.contentDuration
                    easing.type: Services.Motion.number.contentEasing
                }
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: Services.Motion.number.snugDuration
                    easing.type: Services.Motion.number.snugEasing
                }
            }

            // Switch the focused app icon with the same directional motion as the title.
            Services.AnimatedIconSwitch {
                anchors.fill: parent
                source: Quickshell.iconPath(root.currentAppId, "application-x-executable")
                visible: iconSlot.width > 0
            }
        }

        // Keep the title slot open so the text switch can drift beyond the slot bounds.
        Item {
            id: titleSlot

            anchors.verticalCenter: parent.verticalCenter
            property real revealWidth: root.titleTargetWidth

            width: revealWidth
            height: titleText.implicitHeight
            clip: false

            Behavior on revealWidth {
                NumberAnimation {
                    duration: Services.Motion.number.contentDuration
                    easing.type: Services.Motion.number.contentEasing
                }
            }

            Services.AnimatedTextSwitch {
                id: titleText

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                clipWidth: parent.width
                text: root.currentTitle
                color: Services.Color.mOnSurface
                maximumLineCount: 1
                wrapMode: Text.NoWrap
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignLeft
                verticalAlignment: Text.AlignVCenter
                offsetX: 7
                offsetY: 5
            }
        }
    }
}
