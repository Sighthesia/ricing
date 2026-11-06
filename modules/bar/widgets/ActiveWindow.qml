import QtQuick
import QtQuick.Effects
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
    readonly property string desktopLabel: widgetSettings && widgetSettings.desktopLabel && String(widgetSettings.desktopLabel).length > 0 ? String(widgetSettings.desktopLabel) : Services.Tr.q("widget.activeWindow.desktop")
    readonly property string displayTitle:
        Services.NiriService.activeTitle.length > 0 ? Services.NiriService.activeTitle : root.desktopLabel
    readonly property string activeAppId: Services.NiriService.activeAppId
    readonly property bool hasWindow: Services.NiriService.activeTitle.length > 0 && root.activeAppId.length > 0
    // Friendly app label: collapse reverse-DNS ids ("org.mozilla.firefox")
    // down to their final segment so the sub-line reads like Media's artist.
    //
    // An empty workspace is not an empty sub-line: the two lines are always
    // both present, so the desk state says what is on screen (the compositor)
    // instead of leaving a hole. That is also what makes the pair hold a fixed
    // height - see the Column below.
    readonly property string displayAppName: {
        if (!root.hasWindow)
            return Services.Tr.q("widget.activeWindow.compositor")
        var id = root.activeAppId
        var dot = id.lastIndexOf(".")
        return dot >= 0 && dot < id.length - 1 ? id.substring(dot + 1) : id
    }
    // Keep the icon input on the same complete-window snapshot used by the
    // legacy ActiveWindow implementation; workspace activation can otherwise
    // expose a transient empty activeAppId before windows are reloaded.
    property string currentAppId: ""
    readonly property string iconSource: root.currentAppId.length > 0 ? Quickshell.iconPath(root.currentAppId, true) : ""
    // The icon SLOT is permanent (like the two text lines): an empty workspace
    // shows a compositor glyph instead of collapsing the slot and sliding the
    // title left. `hasIcon` therefore answers "is the slot shown", and
    // `hasAppIcon` answers "is there a real window icon to draw in it".
    readonly property bool hasIcon: root.showIcon
    readonly property bool hasAppIcon: root.hasWindow
        && root.currentAppId.length > 0 && root.iconSource !== ""
    property string trackedIconSource: ""
    property string outgoingIconSource: ""
    property int iconTransitionRevision: 0

    // The title the label actually RENDERS. It is deliberately NOT bound to
    // `displayTitle`: niri reports "no window" for a frame or two in the middle
    // of a workspace switch, so a direct binding painted the desktop label,
    // then repainted the previous window's title when the window snapshot came
    // back, and then painted the desktop label again when the hold expired -
    // three visible states where the user should see one transition. The
    // transition code below is the only writer, and it decides when the text
    // moves.
    property string shownTitle: ""
    // The sub-line's counterpart of `shownTitle`, for the same reason.
    property string shownAppName: ""
    // Tracks the last choreographed title so the first render never plays
    // the exit/enter transition for content that was never visible.
    property string trackedTitle: ""
    property string trackedAppName: ""
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
            root.shownTitle = root.displayTitle
            root.outgoingHoldWidth = root._cappedAdvance(prev)
            root.outgoingHoldHadIcon = root.hasIcon
            titleHoldTimer.restart()
            titleText.transitionFrom(prev, root.displayTitle)
        }
    }

    property string _pendingDesktopAppPrev: ""
    Timer {
        id: desktopAppHold
        interval: 120
        onTriggered: {
            // The desk state is a label now ("Niri"), not an empty string, so
            // the guard asks whether a window is still absent rather than
            // whether the text is empty.
            if (root.hasWindow || root._pendingDesktopAppPrev === "")
                return
            var prev = root._pendingDesktopAppPrev
            root._pendingDesktopAppPrev = ""
            root.trackedAppName = root.displayAppName
            root.shownAppName = root.displayAppName
            appNameText.transitionFrom(prev, root.displayAppName)
        }
    }

    // Width floor held by the outgoing title while its scan transition
    // retires, the same contract Media's pill uses: the widget grows to fit
    // the wider of old/new first and settles to the incoming width only after
    // the ghosts have landed. Without it `implicitWidth` collapsed to the new
    // short title on the same frame the scan started, and `clip: true` below
    // then sliced the falling ghosts at the new edge - the old title was cut
    // off mid-fall rather than finishing its drop.
    property real outgoingHoldWidth: 0
    // Icon state at the moment the hold began. The hold has to describe the
    // frame the scan started in, not the frame it is running in: `hasIcon`
    // flips on its own clock (it follows `currentAppId`, which arrives one
    // turn later), and reading it live here let the held width change under
    // the falling ghosts.
    property bool outgoingHoldHadIcon: false
    // The text span only; the caller's own 8px padding is added once, below.
    readonly property int outgoingHoldWidgetWidth: root.outgoingHoldWidth > 0
        ? root.outgoingHoldWidth + (root.outgoingHoldHadIcon ? LazerTheme.barGlyphSize + 6 : 0)
        : 0
    implicitWidth: Math.min(Math.max(contentRow.implicitWidth, root.outgoingHoldWidgetWidth) + 8, root.maxWidth)
    implicitHeight: LazerTheme.barWidgetHeight
    // Clip so long-window ghosts do not spill into neighboring gaps when the
    // title shortens - EXCEPT while a line is retiring its old text, where the
    // clip would cut the drop short. Same reasoning as Media's pill; the
    // exemption ends with the sweep.
    clip: !titleText.sweeping && !appNameText.sweeping

    Component.onCompleted: {
        root.shownTitle = root.displayTitle
        root.shownAppName = root.displayAppName
        root.trackedTitle = root.displayTitle
        root.trackedAppName = root.displayAppName
        root.syncFocusedWindow()
        root.trackedIconSource = root.iconSource
        incomingIcon.source = root.iconSource
    }

    // Measure a title with the title label's own font, capped the way the
    // label itself is capped, so the hold width matches what was on screen.
    function _cappedAdvance(text) {
        holdProbe.text = String(text || "")
        return Math.min(holdProbe.advanceWidth, root.maxTitleWidth)
    }

    // Independent measuring context: reading the live label's metrics would
    // feed the hold back into its own layout.
    TextMetrics {
        id: holdProbe
        font: titleText.label.font
    }

    // One full scan transition: sweep across, gap, reveal, plus the ghost fall
    // tail. Releasing exactly after this keeps the hold invisible.
    // Release the width when the LAST ghost lands, not when the reveal
    // finishes. `sweepExitMs` is measured from the ghosts actually spawned
    // (delay + drop), so a short title frees its space in ~200ms instead of
    // holding it for the full scan budget.
    Timer {
        id: titleHoldTimer
        interval: Math.max(MotionTokens.fast, titleText.sweepExitMs + MotionTokens.fast)
        onTriggered: root.outgoingHoldWidth = 0
    }

    function syncFocusedWindow() {
        root.currentAppId = root.activeAppId
    }

    Connections {
        target: Services.NiriService

        function onWindowsUpdated() {
            Qt.callLater(root.syncFocusedWindow)
        }
    }

    function syncIcon() {
        const oldSource = root.trackedIconSource
        const newSource = root.iconSource
        if (oldSource === newSource)
            return
        root.trackedIconSource = newSource
        const transitionRevision = ++root.iconTransitionRevision

        if (MotionTokens.reducedMotion || oldSource === "" || newSource === "") {
            iconCrossfade.stop()
            root.outgoingIconSource = ""
            outgoingIcon.opacity = 0
            incomingIcon.source = newSource
            incomingIcon.opacity = newSource === "" ? 0 : 1
            return
        }

        // Match Media's cover transition: retain the old layer while the new
        // layer is prepared, then crossfade both layers on the next turn.
        root.outgoingIconSource = oldSource
        outgoingIcon.opacity = 1
        incomingIcon.source = newSource
        incomingIcon.opacity = 0
        Qt.callLater(() => {
            if (root.trackedIconSource !== newSource
                    || root.iconTransitionRevision !== transitionRevision)
                return
            iconCrossfade.restart()
        })
    }

    onIconSourceChanged: syncIcon()
    onHasIconChanged: syncIcon()

    onDisplayTitleChanged: {
        var previous = root.trackedTitle
        if (previous === "" || root.displayTitle === previous) {
            // A pending desktop hold would now be stale.
            if (desktopHold.running) {
                desktopHold.stop()
                root._pendingDesktopPrev = ""
            }
            root.trackedTitle = root.displayTitle
            root.shownTitle = root.displayTitle
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
            root.shownTitle = root.displayTitle
            root.outgoingHoldWidth = root._cappedAdvance(coalescedPrev)
            root.outgoingHoldHadIcon = root.hasIcon
            titleHoldTimer.restart()
            titleText.transitionFrom(coalescedPrev, root.displayTitle)
            return
        }
        root._pendingDesktopPrev = ""
        root.trackedTitle = root.displayTitle
        root.shownTitle = root.displayTitle
        // Hold the outgoing title's width until the scan has retired, so the
        // widget does not shrink under the falling ghosts.
        root.outgoingHoldWidth = root._cappedAdvance(previous)
        root.outgoingHoldHadIcon = root.hasIcon
        titleHoldTimer.restart()
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
            root.shownAppName = root.displayAppName
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
        if (!root.hasWindow) {
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
            root.shownAppName = root.displayAppName
            appNameText.transitionFrom(coalescedPrev, root.displayAppName)
            return
        }
        root.trackedAppName = root.displayAppName
        root.shownAppName = root.displayAppName
        appNameText.transitionFrom(prevApp, root.displayAppName)
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
        // The icon follows `hasIcon` on the frame it changes, so the title
        // slides left into place as the switch starts rather than after the
        // scan retires. Deferring it here (an earlier attempt) left the row
        // misaligned for the whole transition and then snapped.
        //
        // The falling ghosts do not suffer from this reflow: the widget's own
        // width is held by `outgoingHoldWidth` below, and that hold drops the
        // icon term in the same frame the icon does, so the text region keeps
        // its width while the column moves left under it.
        spacing: root.hasIcon ? 6 : 0

        move: Transition { NumberAnimation { properties: "x"; duration: MotionTokens.medium; easing.type: Easing.OutQuad } }
        Behavior on spacing { NumberAnimation { duration: MotionTokens.medium; easing.type: Easing.OutQuad } }
        Behavior on y { NumberAnimation { duration: MotionTokens.medium; easing.type: Easing.OutQuad } }

        // Tray-sized app icon using the legacy directional switch animation.
        Item {
            id: iconContainer

            anchors.verticalCenter: parent.verticalCenter
            width: root.hasIcon ? LazerTheme.barGlyphSize : 0
            height: LazerTheme.barGlyphSize
            opacity: root.hasIcon ? 1 : 0

            Behavior on width { NumberAnimation { duration: MotionTokens.medium; easing.type: Easing.OutQuad } }
            Behavior on opacity { NumberAnimation { duration: MotionTokens.medium; easing.type: Easing.OutQuad } }

            // Desk state: no window, so the slot carries the compositor glyph
            // instead of an application icon. Same white source + MultiEffect
            // tint recipe the identity rail uses.
            Item {
                id: deskGlyphSlot

                anchors.fill: parent
                opacity: root.hasAppIcon ? 0 : 1
                Behavior on opacity { NumberAnimation { duration: MotionTokens.medium; easing.type: Easing.OutQuad } }

                Image {
                    id: deskGlyphSource

                    anchors.fill: parent
                    // niri's own mark (docs/wiki/logo/niri-icon-smol.svg,
                    // CC BY-SA, filtered shadow layers stripped, fills
                    // flattened to white for the tint below).
                    source: Qt.resolvedUrl("../../lazerbar/icons/niri.svg")
                    fillMode: Image.PreserveAspectFit
                    visible: false
                }

                MultiEffect {
                    anchors.fill: deskGlyphSource
                    source: deskGlyphSource
                    colorization: 1
                    colorizationColor: LazerTheme.barIcon
                }
            }

            IconImage {
                id: outgoingIcon

                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width
                height: parent.height
                source: root.outgoingIconSource
                // Keep the short-lived transition layer off the long-lived
                // async pixmap reader, which can lose icons after churn.
                asynchronous: false
                visible: root.hasAppIcon && root.outgoingIconSource !== "" && opacity > 0.01
                opacity: 0
            }

            IconImage {
                id: incomingIcon

                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width
                height: parent.height
                source: ""
                // Synchronous loading keeps both crossfade layers stable
                // during long-running window churn.
                asynchronous: false
                visible: root.hasAppIcon
                opacity: 1
            }

            // Explicitly run the same two-layer opacity crossfade as Media.
            ParallelAnimation {
                id: iconCrossfade

                NumberAnimation {
                    target: outgoingIcon
                    property: "opacity"
                    from: 1
                    to: 0
                    duration: MotionTokens.medium
                    easing.type: Easing.OutQuad
                }
                NumberAnimation {
                    target: incomingIcon
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: MotionTokens.medium
                    easing.type: Easing.OutQuad
                }
                onFinished: root.outgoingIconSource = ""
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

                text: root.shownTitle
                textColor: LazerTheme.textPrimary
                maxWidth: root.maxTitleWidth
                pixelSize: 12
                bold: true
            }

            // Sub-line shows the application name like Media's artist line.
            //
            // The two lines are PERMANENT: this one always occupies its height
            // and only its text changes. It used to collapse to zero when the
            // app name emptied (an empty workspace), which had two costs - the
            // Column re-centred, so the title jumped half a line, and the
            // collapse itself was a hard cut because the height only released
            // after the whole scan retired. Holding the slot means the title
            // never moves and the sub-line never has to animate away: its ink
            // is replaced by the next sub-line text, which is the same
            // transition the title already runs.
            //
            // The slot height is FIXED, derived from the line's own font, not
            // measured: `implicitHeight` is 0 for empty text, and a measured
            // value would dip through 0 for a frame during a text swap, which
            // is exactly the reflow this is here to prevent.
            MarqueeLabel {
                id: appNameText

                text: root.shownAppName
                height: appNameText.lineHeight
                maxWidth: root.maxTitleWidth
                textColor: LazerTheme.barSubtitle
                pixelSize: 10
                // Same persistent secondary-line outline as Media's artist
                // line, so every 10px bar subtitle reads with one edge
                // contract instead of per-widget improvisation.
                textStyle: Text.Outline
                textStyleColor: LazerTheme.barSubtitleOutline
            }
        }
    }
}
