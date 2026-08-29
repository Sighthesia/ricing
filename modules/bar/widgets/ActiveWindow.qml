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
    property string trackedAppName: ""
    property string trackedIconSource: ""
    property bool trackedHasIcon: false
    // Coalesce a transient desktop fallback during workspace switches:
    // Niri briefly reports no active window while the workspace animates,
    // so displayTitle flicks window -> desktop -> next window. Holding
    // the desktop for one scan gap avoids a full desktop flash that
    // would clear the outgoing window's falling ghosts.
    property string _pendingDesktopPrev: ""
    Timer {
        id: desktopHold
        interval: 120
        onTriggered: {
            if (root.displayTitle !== root.desktopLabel || root._pendingDesktopPrev === "")
                return
            var prev = root._pendingDesktopPrev
            root._pendingDesktopPrev = ""
            root.trackedTitle = root.displayTitle
            titleText.transitionFrom(prev, root.displayTitle)
        }
    }

    property string _pendingDesktopAppPrev: ""
    Timer {
        id: desktopAppHold
        interval: 120
        onTriggered: {
            if (root.displayAppName !== "" || root._pendingDesktopAppPrev === "")
                return
            var prev = root._pendingDesktopAppPrev
            root._pendingDesktopAppPrev = ""
            root.trackedAppName = ""
            appNameText.transitionFrom(prev, "")
        }
    }

    implicitWidth: Math.min(contentRow.implicitWidth + 8, root.maxWidth)
    implicitHeight: LazerTheme.barWidgetHeight
    // Clip so long-window ghosts do not spill into neighboring gaps when
    // the title shortens; neighboring widget containers can then cover.
    clip: true

    Component.onCompleted: {
        root.trackedTitle = root.displayTitle
        root.trackedAppName = root.displayAppName
        root.trackedIconSource = root.iconSource
        root.trackedHasIcon = root.hasIcon
    }

    onDisplayTitleChanged: {
        var previous = root.trackedTitle
        if (previous === "" || root.displayTitle === previous) {
            // A pending desktop hold would now be stale.
            if (desktopHold.running) {
                desktopHold.stop()
                root._pendingDesktopPrev = ""
            }
            root.trackedTitle = root.displayTitle
            return
        }
        // Window -> desktop: hold briefly to see if a new window follows
        // within the switch animation. This prevents the desktop label
        // from stealing the outgoing ghosts mid-flight.
        if (root.displayTitle === root.desktopLabel) {
            root._pendingDesktopPrev = previous
            desktopHold.restart()
            return
        }
        // Desktop was held and a new window arrived: skip desktop entirely
        // and animate directly from the original window to the new one.
        if (desktopHold.running) {
            desktopHold.stop()
            var coalescedPrev = root._pendingDesktopPrev !== "" ? root._pendingDesktopPrev : previous
            root._pendingDesktopPrev = ""
            root.trackedTitle = root.displayTitle
            titleText.transitionFrom(coalescedPrev, root.displayTitle)
            return
        }
        root._pendingDesktopPrev = ""
        root.trackedTitle = root.displayTitle
        // Per-char fade-in entrance plus staggered falling ghost exit,
        // reusing the media pill's main-line contract via MarqueeLabel.
        titleText.transitionFrom(previous, root.displayTitle)
    }

    onDisplayAppNameChanged: {
        if (MotionTokens.reducedMotion) {
            if (desktopAppHold.running) {
                desktopAppHold.stop()
                root._pendingDesktopAppPrev = ""
            }
            root.trackedAppName = root.displayAppName
            return
        }
        var prevApp = root.trackedAppName
        if (root.displayAppName === prevApp) {
            if (desktopAppHold.running) {
                desktopAppHold.stop()
                root._pendingDesktopAppPrev = ""
            }
            return
        }
        // App -> desktop (empty): hold briefly to see if a new window follows
        // within the workspace switch animation, avoiding an intermediate
        // empty flash that would clear the outgoing app's falling ghosts.
        if (root.displayAppName === "") {
            root._pendingDesktopAppPrev = prevApp
            desktopAppHold.restart()
            return
        }
        // Desktop was held and a new app arrived: coalesce directly from
        // the original app to the new one, skipping the empty intermediate.
        if (desktopAppHold.running) {
            desktopAppHold.stop()
            var coalescedPrev = root._pendingDesktopAppPrev !== "" ? root._pendingDesktopAppPrev : prevApp
            root._pendingDesktopAppPrev = ""
            root.trackedAppName = root.displayAppName
            appNameText.transitionFrom(coalescedPrev, root.displayAppName)
            return
        }
        root.trackedAppName = root.displayAppName
        appNameText.transitionFrom(prevApp, root.displayAppName)
    }

    onHasIconChanged: handleIconTransition()
    onIconSourceChanged: handleIconTransition()

    function handleIconTransition() {
        if (MotionTokens.reducedMotion) {
            root.trackedHasIcon = root.hasIcon
            root.trackedIconSource = root.iconSource
            appIconPrev.opacity = 0
            return
        }
        const oldSrc = root.trackedIconSource
        const newSrc = root.iconSource
        const oldHas = root.trackedHasIcon
        const newHas = root.hasIcon
        if (oldHas === newHas && oldSrc === newSrc)
            return
        root.trackedHasIcon = newHas
        root.trackedIconSource = newSrc
        if (oldHas && !newHas) {
            if (oldSrc !== "") {
                appIconPrev.source = oldSrc
                appIconPrev.opacity = 1
                appIconPrev.scale = 1
            }
            appIcon.opacity = 0
            appIcon.scale = 0.85
            Qt.callLater(() => { appIconPrev.opacity = 0; appIconPrev.scale = 0.9 })
        } else if (!oldHas && newHas) {
            appIconPrev.opacity = 0
            appIcon.opacity = 0
            appIcon.scale = 0.85
            Qt.callLater(() => {
                if (root.trackedIconSource !== newSrc) return
                appIcon.opacity = 1
                appIcon.scale = 1
            })
        } else if (oldHas && newHas && oldSrc !== newSrc) {
            appIconPrev.source = oldSrc
            appIconPrev.opacity = 1
            appIconPrev.scale = 1
            appIcon.opacity = 0
            appIcon.scale = 0.9
            Qt.callLater(() => {
                if (root.trackedIconSource !== newSrc) return
                appIcon.opacity = 1
                appIcon.scale = 1
                appIconPrev.opacity = 0
                appIconPrev.scale = 0.9
            })
        }
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

        move: Transition { NumberAnimation { properties: "x"; duration: MotionTokens.medium; easing.type: Easing.OutQuad } }
        Behavior on spacing { NumberAnimation { duration: MotionTokens.medium; easing.type: Easing.OutQuad } }
        Behavior on y { NumberAnimation { duration: MotionTokens.medium; easing.type: Easing.OutQuad } }

        // Tray-sized app icon so both identity glyphs share one visual weight.
        Item {
            id: iconContainer
            anchors.verticalCenter: parent.verticalCenter
            width: root.hasIcon ? LazerTheme.barGlyphSize : 0
            height: LazerTheme.barGlyphSize
            clip: false
            visible: true
            Behavior on width { NumberAnimation { duration: MotionTokens.medium; easing.type: Easing.OutQuad } }

            IconImage {
                id: appIconPrev
                anchors.fill: parent
                visible: opacity > 0.01
                source: ""
                asynchronous: true
                backer.fillMode: Image.PreserveAspectFit
                opacity: 0
                scale: 0.9
                Behavior on opacity { NumberAnimation { duration: MotionTokens.medium; easing.type: Easing.OutQuad } }
                Behavior on scale { NumberAnimation { duration: MotionTokens.medium; easing.type: Easing.OutQuad } }
            }

            IconImage {
                id: appIcon
                anchors.fill: parent
                visible: true
                source: root.iconSource
                asynchronous: true
                backer.fillMode: Image.PreserveAspectFit
                opacity: root.hasIcon && status === Image.Ready ? 1 : 0
                scale: root.hasIcon ? 1 : 0.85
                Behavior on opacity { NumberAnimation { duration: MotionTokens.medium; easing.type: Easing.OutQuad } }
                Behavior on scale { NumberAnimation { duration: MotionTokens.medium; easing.type: Easing.OutQuad } }
            }
        }

        Column {
            id: textColumn

            anchors.verticalCenter: parent.verticalCenter
            spacing: 1
            move: Transition { NumberAnimation { properties: "x,y"; duration: MotionTokens.medium; easing.type: Easing.OutQuad } }
            Behavior on y { NumberAnimation { duration: MotionTokens.medium; easing.type: Easing.OutQuad } }

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
                id: appNameText

                text: root.displayAppName
                visible: text.length > 0 || _sweepActive
                height: visible ? implicitHeight : 0
                maxWidth: root.maxTitleWidth
                textColor: LazerTheme.barSubtitle
                pixelSize: 10

                Behavior on height { NumberAnimation { duration: MotionTokens.medium; easing.type: Easing.OutQuad } }
                Behavior on opacity { NumberAnimation { duration: MotionTokens.fast } }
            }
        }
    }
}
