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

    // Spectrum registration — mirrors the old bar spectrum integration.
    readonly property string spectrumComponentId: "media:" + (root.instanceKey !== "" ? root.instanceKey : (root.widgetId !== "" ? root.widgetId : root.screenName))
    readonly property var mediaSettings: Services.SettingsService.widgetSettingsObject("media", root.instanceKey)
    // Resident while the pill exists: the spectrum survives pause and player
    // close instead of tearing down with playback state.
    readonly property bool needsSpectrum: !MotionTokens.reducedMotion
        && (root.mediaSettings ? root.mediaSettings.showAudioSpectrum !== false : true)
    // Floors for pill and spectrum so a short title cannot squeeze the
    // mirrored bar field into an unreadable sliver.
    readonly property int minPillWidth: 140
    readonly property int minSpectrumWidth: 100
    // Distance from contentRow's left edge to the text column: cover glyph,
    // row spacing, progress track, row spacing again.
    readonly property int textColumnOffset: root.coverSize + 8 + 3 + 8
    // Pill width needed so the floored spectrum field ends inside the pill:
    // with contentRow centered, its x is (W - R) / 2, and the spectrum's
    // right edge must stay within the hoverable surface (6px breathing).
    readonly property int spectrumFitWidth: !root.needsSpectrum ? 0
        : Math.max(0, 2 * (root.textColumnOffset + Math.max(root.minSpectrumWidth, textColumn.width) + 6)
            - contentRow.implicitWidth)

    visible: hasMedia
    implicitWidth: visible ? Math.max(root.minPillWidth, contentRow.implicitWidth + 12, root.spectrumFitWidth) : 0
    // Smooth width morph like the legacy media pill: growth/shrink eases
    // instead of snapping when lyric lengths change.
    Behavior on implicitWidth {
        enabled: !MotionTokens.reducedMotion
        NumberAnimation { duration: MotionTokens.medium; easing.type: Easing.OutQuad }
    }
    hoverable: hasMedia

    onClicked: Services.MediaService.playPause()

    function syncSpectrumRegistration() {
        if (root.needsSpectrum)
            Services.SpectrumService.registerComponent(root.spectrumComponentId)
        else
            Services.SpectrumService.unregisterComponent(root.spectrumComponentId)
    }

    Component.onCompleted: {
        root.trackedPrimaryText = root.primaryText
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
        // Shared per-character contract: staggered falling ghost exit plus
        // left-to-right fade-in entrance, living in MarqueeLabel.
        titleMarquee.transitionFrom(oldText, root.primaryText)
    }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            if (event.angleDelta.y > 0) Services.MediaService.next()
            else if (event.angleDelta.y < 0) Services.MediaService.previous()
            event.accepted = true
        }
    }

    Row {
        id: contentRow

        anchors.centerIn: parent
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

            Image {
                id: coverImage

                anchors.fill: parent
                source: Services.MediaControlService.artUrl
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: root.hasCoverArt && status !== Image.Error
                opacity: visible ? 1 : 0

                Behavior on opacity { NumberAnimation { duration: MotionTokens.fast } }
            }

            // Music glyph only appears when there is no usable cover art.
            Image {
                anchors.centerIn: parent
                width: LazerTheme.barGlyphSize - 6
                height: LazerTheme.barGlyphSize - 6
                source: "../../lazerbar/icons/music.svg"
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
                text: Services.MediaControlService.showCompactLyric
                    ? Services.MediaControlService.artist
                        + (Services.MediaControlService.title !== ""
                            ? " - " + Services.MediaControlService.title : "")
                    : Services.MediaControlService.artist
                visible: text.length > 0
                maxWidth: root.maxTextWidth
                textColor: LazerTheme.textMuted
                pixelSize: 10
            }
        }
    }

    // Spectrum backdrop — X strictly inside textColumn, Y fills the pill.
    // No left bleed: left edge aligns exactly with text, right bleeds slightly for breathing.
    Item {
        id: spectrumBg

        // Left aligns exactly with textColumn to avoid exceeding text X range;
        // floored so short titles cannot squeeze the field too narrow.
        x: contentRow.x + textColumn.x
        width: Math.max(root.minSpectrumWidth, textColumn.width)
        anchors.top: parent.top
        anchors.topMargin: 3
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 3
        z: -1
        visible: root.needsSpectrum && width > 0 && height > 0 && (opacity > 0.01 || !Services.SpectrumService.isIdle)
        clip: true
        opacity: Services.SpectrumService.isIdle ? 0 : 1

        Behavior on opacity { NumberAnimation { duration: MotionTokens.fast } }

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
            spectrumBg.triggerWave()
        }
    }

    // Incoming lyric fades in per character and the outgoing line falls
    // away per character — the shared contract lives in MarqueeLabel and
    // runs from onPrimaryTextChanged via transitionFrom.

    // Hover opens this widget's popup in the shared overlay host.
    WidgetHoverPopup {
        kind: "media"
    }
}
