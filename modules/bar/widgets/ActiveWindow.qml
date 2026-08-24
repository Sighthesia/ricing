import QtQuick
import Quickshell
import Quickshell.Widgets
import ".."
import "../../lazerbar"
import "../../../services" as Services

// Focused window title with app icon resolved from the compositor's active appId.
Item {
    id: root

    // Widget identity contract filled by the layout loader.
    property string widgetId: ""
    property string instanceKey: ""
    property string section: ""
    property string screenName: ""

    readonly property var widgetSettings: Services.SettingsService.widgetSettingsObject("active-window", root.instanceKey)
    readonly property bool showIcon: widgetSettings ? widgetSettings.showIcon !== false : true
    readonly property int maxTitleWidth: widgetSettings && widgetSettings.maxTitleWidth ? widgetSettings.maxTitleWidth : 200
    readonly property int maxWidth: widgetSettings && widgetSettings.maxWidth ? widgetSettings.maxWidth : 240
    readonly property string desktopLabel: widgetSettings && widgetSettings.desktopLabel && String(widgetSettings.desktopLabel).length > 0 ? String(widgetSettings.desktopLabel) : "桌面"
    readonly property string displayTitle:
        Services.NiriService.activeTitle.length > 0 ? Services.NiriService.activeTitle : root.desktopLabel
    readonly property string activeAppId: Services.NiriService.activeAppId
    readonly property bool hasWindow: Services.NiriService.activeTitle.length > 0 && root.activeAppId.length > 0
    readonly property string iconSource: root.activeAppId.length > 0 ? Quickshell.iconPath(root.activeAppId, true) : ""
    readonly property bool hasIcon: root.showIcon && root.hasWindow && root.iconSource !== ""

    implicitWidth: Math.min(contentRow.implicitWidth + 8, root.maxWidth)
    implicitHeight: LazerTheme.barWidgetHeight

    Row {
        id: contentRow

        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        spacing: root.hasIcon ? 6 : 0

        IconImage {
            id: appIcon

            anchors.verticalCenter: parent.verticalCenter
            width: root.hasIcon ? 16 : 0
            height: 16
            visible: root.hasIcon
            source: root.iconSource
            asynchronous: true
            opacity: visible && status === Image.Ready ? 1 : 0

            Behavior on opacity { NumberAnimation { duration: MotionTokens.fast } }
        }

        // Long titles marquee-scroll instead of being elided short.
        MarqueeLabel {
            id: titleText

            anchors.verticalCenter: parent.verticalCenter
            width: implicitWidth
            text: root.displayTitle
            textColor: LazerTheme.textPrimary
            maxWidth: root.maxTitleWidth
            pixelSize: 13
        }
    }
}
