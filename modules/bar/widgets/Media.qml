import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell
import ".."
import "../../lazerbar"
import "../../../services" as Services

// Compact now-playing pill; lyrics take priority over raw titles. The pill
// grows with its content up to a cap, the translucent album cover sits in a
// square region centered on the music glyph, and an over-long primary line
// marquee-scrolls instead of being cut short. Lyric changes fade in while the
// outgoing line falls away like OsuTextField's delete ghosts. An audio
// spectrum (PipeWire via cava) renders as a sharp mirrored bar field behind
// the content when the track is playing.
BarPill {
    id: root

    // Widget identity contract filled by the layout loader.
    property string widgetId: ""
    property string instanceKey: ""
    property string section: ""
    property string screenName: ""

    readonly property bool hasMedia: Services.MediaControlService.hasMedia
    readonly property bool playing: Services.MediaControlService.playbackState === "playing"
    readonly property string primaryText:
        Services.MediaControlService.showCompactLyric
                ? Services.MediaControlService.compactPrimaryLyric
                : Services.MediaControlService.title
    readonly property string secondaryText:
        Services.MediaControlService.showCompactLyric
                ? Services.MediaControlService.artist
                    + (Services.MediaControlService.title !== "" ? " - " + Services.MediaControlService.title : "")
                : Services.MediaControlService.artist
    // Width cap where dynamic growth stops and the title starts scrolling.
    readonly property int maxTextWidth: 300
    // Square cover region centered on the music glyph, translucent over text.
    readonly property int coverSize: LazerTheme.barGlyphSize + 10
    // Avoid inheriting previous cover when current track reports empty art.
    readonly property bool hasCoverArt: {
        if (Services.MediaControlService.artUrl === "")
            return false
        // If an MPRIS player is active, require its raw trackArtUrl to be non-empty;
        // otherwise a cached fallback would keep showing previous track's art.
        if (Services.MediaService.hasPlayer) {
            var p = Services.MediaService.activePlayer
            var raw = p ? String(p.trackArtUrl || "").trim() : ""
            if (raw !== "")
                return true
            // No MPRIS art — only show Netease art when it belongs to current lyric session.
            return Services.NeteaseWebLyricsService.artUrl !== ""
                && Services.MediaControlService.artUrl === Services.NeteaseWebLyricsService.artUrl
        }
        return Services.NeteaseWebLyricsService.artUrl !== ""
    }

    property string trackedPrimaryText: ""
    property string trackedSecondaryText: ""
    property string trackedArtUrl: ""

    // Spectrum registration — mirrors the old bar spectrum integration.
    readonly property string spectrumComponentId: "media:" + (root.instanceKey !== "" ? root.instanceKey : (root.widgetId !== "" ? root.widgetId : root.screenName))
    readonly property var mediaSettings: Services.SettingsService.widgetSettingsObject("media", root.instanceKey)
    // Resident while the pill exists: the spectrum survives pause and player
    // close instead of tearing down with playback state.
    readonly property bool needsSpectrum: !MotionTokens.reducedMotion
        && (root.mediaSettings ? root.mediaSettings.showAudioSpectrum !== false : true)
    // Floors for pill so a short title cannot collapse the widget.
    readonly property int minPillWidth: 140
    // Width floor held by the outgoing primary line while its scan
    // transition retires: the island-media morph contract — the surface
    // grows to fit the wider of old/new first, and only settles to the
    // incoming width after the handback, so the pill never clips the
    // falling ghosts by shrinking under them.
    property real outgoingHoldWidth: 0
    readonly property int outgoingHoldPillWidth: root.coverSize + 8 + 3 + 8
        + Math.min(root.outgoingHoldWidth, root.maxTextWidth) + 12

    visible: hasMedia
    implicitWidth: visible ? Math.max(root.minPillWidth, contentRow.implicitWidth + 12, root.outgoingHoldPillWidth) : 0
    // Clip the pill so falling ghosts from a long title do not spill into
    // neighboring widget gaps when the pill shrinks to a short title; the
    // ghosts remain visible inside the pill during the width hold but are
    // clipped at the pill edge, allowing neighboring containers to cover.
    clip: true
    // Smooth width morph like the legacy media pill: growth/shrink eases
    // instead of snapping when lyric lengths change.
    Behavior on implicitWidth {
        enabled: !MotionTokens.reducedMotion
        NumberAnimation { duration: MotionTokens.medium; easing.type: Easing.OutQuad }
    }
    hoverable: hasMedia

    // Opt-in hover intent for BarPopupHost.
    hoverIntentEnabled: hasMedia

    onClicked: Services.MediaService.playPause()

    // Build hover intent payload for the two-layer popup.
    function buildHoverIntent() {
        var centerX = 0
        try { centerX = root.mapToGlobal(root.width / 2, root.height / 2).x } catch (e) {
            try { centerX = root.mapToItem(null, root.width / 2, 0).x } catch (e2) { centerX = 0 }
        }
        if (!isFinite(centerX)) centerX = 0
        var titleText = Services.MediaControlService.title || Services.MediaService.title || "Media"
        if (titleText === "") titleText = "Media"
        var summaryText = Services.MediaControlService.artist || Services.MediaService.artist || Services.MediaService.playerName || ""
        return {
            widgetId: root.widgetId,
            instanceKey: root.instanceKey,
            screenName: root.screenName,
            title: titleText,
            iconSource: Qt.resolvedUrl("../../lazerbar/icons/music.svg"),
            summary: summaryText,
            actionKind: "media",
            anchorX: centerX,
            payload: {
                title: titleText,
                artist: summaryText,
                mediaControlService: Services.MediaControlService,
                mediaService: Services.MediaService,
                onPrevious: function() { Services.MediaService.previous() },
                onPlayPause: function() { Services.MediaService.playPause() },
                onNext: function() { Services.MediaService.next() }
            }
        }
    }

    onHoveredChanged: {
        if (hovered) popupRequested(buildHoverIntent())
        else popupCloseRequested()
    }

    // Update anchor while the bar layout moves.
    onXChanged: if (hovered) popupAnchorUpdate(buildHoverIntent())
    onWidthChanged: if (hovered) popupAnchorUpdate(buildHoverIntent())

    function syncSpectrumRegistration() {
        if (root.needsSpectrum)
            Services.SpectrumService.registerComponent(root.spectrumComponentId)
        else
            Services.SpectrumService.unregisterComponent(root.spectrumComponentId)
    }

    Component.onCompleted: {
        root.trackedPrimaryText = root.primaryText
        root.trackedSecondaryText = root.secondaryText
        root.trackedArtUrl = Services.MediaControlService.artUrl
        // Ensure widget defaults exist so showAudioSpectrum can be toggled later.
        if (root.instanceKey !== "")
            Services.SettingsService.ensureWidgetSettings("media", root.instanceKey)
        syncSpectrumRegistration()
    }
    Component.onDestruction: {
        Services.SpectrumService.unregisterComponent(root.spectrumComponentId)
    }
    onNeedsSpectrumChanged: syncSpectrumRegistration()

    onPrimaryTextChanged: {
        if (root.trackedPrimaryText === "" || root.trackedPrimaryText === root.primaryText) {
            root.trackedPrimaryText = root.primaryText
            return
        }
        const oldText = root.trackedPrimaryText
        root.trackedPrimaryText = root.primaryText
        // Island-style width morph: hold the outgoing line's visible width
        // until the scan transition finishes retiring its ghosts, so the
        // pill grows first and settles afterwards instead of shrinking
        // under the falling characters.
        root.outgoingHoldWidth = root._cappedAdvance(oldText)
        morphHoldTimer.restart()
        // Shared per-character contract: staggered falling ghost exit plus
        // left-to-right fade-in entrance, living in MarqueeLabel.
        titleMarquee.transitionFrom(oldText, root.primaryText)
    }

    onSecondaryTextChanged: {
        if (MotionTokens.reducedMotion) {
            root.trackedSecondaryText = root.secondaryText
            return
        }
        if (root.trackedSecondaryText === root.secondaryText) {
            return
        }
        const oldSec = root.trackedSecondaryText
        root.trackedSecondaryText = root.secondaryText
        subtitleMarquee.transitionFrom(oldSec, root.secondaryText)
    }

    onHasCoverArtChanged: {
        if (MotionTokens.reducedMotion) {
            coverPrevImage.opacity = 0
            coverImage.opacity = root.hasCoverArt ? 1 : 0
            return
        }
        if (root.hasCoverArt) {
            coverImage.opacity = 0
            Qt.callLater(() => {
                if (coverImage.status !== Image.Ready) return
                coverImage.opacity = 1; coverPrevImage.opacity = 0
            })
        } else {
            if (coverImage.source !== "") {
                coverPrevImage.source = coverImage.source
                coverPrevImage.opacity = 1
                coverImage.opacity = 0
                Qt.callLater(() => { coverPrevImage.opacity = 0 })
            } else {
                coverPrevImage.opacity = 0
                coverImage.opacity = 0
            }
        }
    }

    Connections {
        target: Services.MediaControlService
        function onArtUrlChanged() {
            if (MotionTokens.reducedMotion) {
                root.trackedArtUrl = Services.MediaControlService.artUrl
                coverPrevImage.opacity = 0
                return
            }
            const oldUrl = root.trackedArtUrl
            const newUrl = Services.MediaControlService.artUrl
            if (oldUrl === "" || oldUrl === newUrl) {
                root.trackedArtUrl = newUrl
                coverPrevImage.opacity = 0
                return
            }
            root.trackedArtUrl = newUrl
            const hadCover = oldUrl !== "" && root.hasCoverArt
            const hasNewCover = newUrl !== "" && root.hasCoverArt
            if (!hadCover || !hasNewCover) {
                coverPrevImage.opacity = 0
                return
            }
            coverPrevImage.source = oldUrl
            coverPrevImage.opacity = 1
            coverImage.opacity = 0
            Qt.callLater(() => {
                if (root.trackedArtUrl !== newUrl) return
                if (coverImage.status !== Image.Ready) return
                coverImage.opacity = 1
                coverPrevImage.opacity = 0
            })
        }
    }

    // Measure text with the title label's own font in an independent
    // context — the label's internal metrics must never be fed foreign
    // text, or the live layout would briefly follow the probe.
    TextMetrics {
        id: morphProbe

        font: titleMarquee.label.font
    }

    function _cappedAdvance(text) {
        morphProbe.text = text
        return Math.min(morphProbe.advanceWidth, root.maxTextWidth)
    }

    // One full scan transition: sweep across, gap, reveal, plus the ghost
    // fall tail. Releasing exactly after this keeps the hold invisible.
    Timer {
        id: morphHoldTimer

        interval: titleMarquee.scanSweepMs + titleMarquee.scanGapMs
            + titleMarquee.scanRevealMs + MotionTokens.fast
        onTriggered: root.outgoingHoldWidth = 0
    }

    WheelHandler {
        objectName: "mediaWheelHandler"
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            if (event.angleDelta.y > 0) Services.MediaService.next()
            else if (event.angleDelta.y < 0) Services.MediaService.previous()
            event.accepted = true
        }
    }

    Row {
        id: contentRow

        anchors.left: parent.left
        anchors.leftMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8

        // Cover region: rounded via OpacityMask (Rectangle clip is rectangular,
        // not rounded), translucent artwork; the music glyph only shows when no
        // cover art is available so it can never bleed through the artwork.
        Rectangle {
            id: coverContainer

            anchors.verticalCenter: parent.verticalCenter
            width: root.coverSize
            height: root.coverSize
            radius: 4
            color: "transparent"
            layer.enabled: root.hasCoverArt && coverImage.status === Image.Ready
            layer.effect: OpacityMask {
                maskSource: Rectangle {
                    width: coverContainer.width
                    height: coverContainer.height
                    radius: coverContainer.radius
                }
            }

            // Previous cover for crossfade transition
            Image {
                id: coverPrevImage

                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: true
                opacity: 0

                Behavior on opacity { NumberAnimation { duration: MotionTokens.medium; easing.type: Easing.OutQuad } }
            }

            Image {
                id: coverImage

                anchors.fill: parent
                source: Services.MediaControlService.artUrl
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: true
                opacity: 1
                Behavior on opacity { NumberAnimation { duration: MotionTokens.medium; easing.type: Easing.OutQuad } }

                onStatusChanged: {
                    if (status === Image.Ready && root.hasCoverArt && root.trackedArtUrl === source && opacity === 0) {
                        opacity = 1
                        coverPrevImage.opacity = 0
                    }
                }
            }

            // Music glyph only appears when there is no usable cover art.
            Image {
                anchors.centerIn: parent
                width: LazerTheme.barGlyphSize - 6
                height: LazerTheme.barGlyphSize - 6
                 source: Qt.resolvedUrl("../../lazerbar/icons/music.svg")
                visible: !root.hasCoverArt || !coverImage.visible
                opacity: visible ? (root.playing ? 0.95 : 0.5) : 0

                Behavior on opacity { NumberAnimation { duration: MotionTokens.fast } }
            }
        }

        // Rounded vertical playback progress to the right of the cover glyph.
        Rectangle {
            id: mediaProgressTrack

            anchors.verticalCenter: parent.verticalCenter
            width: 3
            height: root.coverSize
            radius: 1.5
            color: Qt.rgba(1, 1, 1, 0.14)
            clip: true

            // Beat flash across the whole track (reads mostly on the
            // unplayed remainder); sits under the played fill overlay.
            Rectangle {
                anchors.fill: parent
                color: LazerTheme.textPrimary
                opacity: MotionTokens.reducedMotion
                    ? 0
                    : Services.SpectrumService.beatPulse * MotionTokens.clickFlashOpacity * 0.5
                visible: opacity > 0.01

                Behavior on opacity { NumberAnimation { duration: MotionTokens.fast } }
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: parent.height * Services.MediaControlService.progress
                radius: 1.5
                color: LazerTheme.accentColor

                // Beat flash: brightness pulse riding the shared beatPulse
                // decay, so the bar blinks once per detected beat.
                Rectangle {
                    anchors.fill: parent
                    radius: 1.5
                    color: LazerTheme.textPrimary
                    opacity: MotionTokens.reducedMotion
                        ? 0
                        : Math.min(1, Services.SpectrumService.beatPulse * MotionTokens.clickFlashOpacity * 1.8)
                    visible: opacity > 0.01

                    Behavior on opacity { NumberAnimation { duration: MotionTokens.fast } }
                }

                Behavior on height {
                    enabled: !MotionTokens.reducedMotion
                    NumberAnimation { duration: 220; easing.type: Easing.OutQuad }
                }
            }
        }

        Column {
            id: textColumn

            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            // Primary line grows with content; once past the cap it clips
            // and marquee-scrolls (static elide under reduced motion). Ghosts
            // ride the label's unclipped overlay so they can fall past the pill.
            MarqueeLabel {
                id: titleMarquee

                text: root.primaryText
                maxWidth: root.maxTextWidth
                textColor: LazerTheme.textPrimary
                pixelSize: 12
                bold: true
            }

            // Sub-line follows the same contract: scroll instead of ellipsis.
            MarqueeLabel {
                id: subtitleMarquee

                text: root.secondaryText
                visible: text.length > 0 || _sweepActive
                height: visible ? implicitHeight : 0
                maxWidth: root.maxTextWidth
                textColor: LazerTheme.barSubtitle
                pixelSize: 10

                Behavior on height { NumberAnimation { duration: MotionTokens.medium; easing.type: Easing.OutQuad } }
                Behavior on opacity { NumberAnimation { duration: MotionTokens.fast } }
            }
        }
    }

    // Spectrum backdrop — confined to the lyrics range: left edge aligns
    // exactly with the text column, width tracks it, so the bar field can
    // never reach outside the words it visualizes. Fades out when cava
    // reports idle so the resting pill stays clean.
    Item {
        id: spectrumBand

        x: contentRow.x + textColumn.x
        width: textColumn.width
        anchors.top: parent.top
        anchors.topMargin: 3
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 3
        z: -1
        visible: root.needsSpectrum && width > 0 && height > 0 && (opacity > 0.01 || !Services.SpectrumService.isIdle)
        clip: true
        opacity: Services.SpectrumService.isIdle ? 0 : 1

        Behavior on opacity { NumberAnimation { duration: MotionTokens.fast } }
        // Continuous width morph together with the pill: lyric length changes
        // animate instead of snapping, so both the overall field and each
        // bar's slot continuously interpolate rather than popping.
        Behavior on width {
            enabled: !MotionTokens.reducedMotion
            NumberAnimation { duration: MotionTokens.medium; easing.type: Easing.OutQuad }
        }

        function triggerWave() {
            spectrumBars.triggerWave()
        }

        DockzoneSpectrum {
            id: spectrumBars

            anchors.fill: parent
            values: Services.SpectrumService.values
            barColor: Qt.rgba(LazerTheme.accentColor.r, LazerTheme.accentColor.g, LazerTheme.accentColor.b, 0.58)
            // One sweep per beat interval: the front hits the far edge just
            // as the next beat fires the next wave.
            waveDuration: Services.SpectrumService.bpm > 0
                ? Math.round(Math.max(240, Math.min(1200, 60000 / Services.SpectrumService.bpm)))
                : MotionTokens.beatWave
        }
    }

    // Each detected beat launches a highlight front sweeping the spectrum
    // from its left edge, like a sound wave travelling through the bars.
    Connections {
        target: Services.SpectrumService

        function onBeat() {
            spectrumBand.triggerWave()
        }
    }

    // Incoming lyric fades in per character and the outgoing line falls
    // away per character — the shared contract lives in MarqueeLabel and
    // runs from onPrimaryTextChanged via transitionFrom.

}
