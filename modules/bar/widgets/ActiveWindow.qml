import QtQuick
import Quickshell
import Quickshell.Widgets
import ".."
import "../../lazerbar"
import "../../../services" as Services

// Focused window icon with a two-line readout: window title on top,
// application name underneath, mirroring the Media pill's text column.
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
    // Friendly app label: collapse reverse-DNS ids ("org.mozilla.firefox")
    // down to their final segment so the sub-line reads like Media's artist.
    readonly property string displayAppName: {
        if (!root.hasWindow)
            return ""
        var id = root.activeAppId
        var dot = id.lastIndexOf(".")
        return dot >= 0 && dot < id.length - 1 ? id.substring(dot + 1) : id
    }
    readonly property string iconSource: root.activeAppId.length > 0 ? Quickshell.iconPath(root.activeAppId, true) : ""
    readonly property bool hasIcon: root.showIcon && root.hasWindow && root.iconSource !== ""

    // Tracks the last choreographed title so the first render never plays
    // the exit/enter transition for content that was never visible.
    property string trackedTitle: ""

    implicitWidth: Math.min(contentRow.implicitWidth + 8, root.maxWidth)
    implicitHeight: LazerTheme.barWidgetHeight

    Component.onCompleted: root.trackedTitle = root.displayTitle

    onDisplayTitleChanged: {
        var previous = root.trackedTitle
        if (previous === "" || root.displayTitle === previous) {
            root.trackedTitle = root.displayTitle
            return
        }
        root.trackedTitle = root.displayTitle
        // Per-char fade-in entrance plus staggered falling ghost exit,
        // reusing the media pill's main-line contract via MarqueeLabel.
        titleText.transitionFrom(previous)
    }

    // Smooth width morph: title changes ease instead of snapping, so the
    // Row layout smoothly pushes neighboring widgets aside.
    Behavior on implicitWidth {
        enabled: !MotionTokens.reducedMotion
        NumberAnimation { duration: MotionTokens.medium; easing.type: Easing.OutQuad }
    }

    Row {
        id: contentRow

        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        spacing: root.hasIcon ? 6 : 0

        // Tray-sized app icon so both identity glyphs share one visual weight.
        IconImage {
            id: appIcon

            anchors.verticalCenter: parent.verticalCenter
            width: root.hasIcon ? LazerTheme.barGlyphSize : 0
            height: LazerTheme.barGlyphSize
            visible: root.hasIcon
            source: root.iconSource
            asynchronous: true
            backer.fillMode: Image.PreserveAspectFit
            opacity: visible && status === Image.Ready ? 1 : 0

            Behavior on opacity { NumberAnimation { duration: MotionTokens.fast } }
        }

        Column {
            id: textColumn

            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            // Primary line grows with content; once past the cap it clips
            // and marquee-scrolls instead of being elided short.
            MarqueeLabel {
                id: titleText

                text: root.displayTitle
                textColor: LazerTheme.textPrimary
                maxWidth: root.maxTitleWidth
                pixelSize: 12
                bold: true
            }

            // Sub-line shows the application name like Media's artist line.
            MarqueeLabel {
                text: root.displayAppName
                visible: text.length > 0
                maxWidth: root.maxTitleWidth
                textColor: LazerTheme.textMuted
                pixelSize: 10
            }
        }
    }
}
