import QtQuick
import Qt5Compat.GraphicalEffects
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
    readonly property bool titleOverflows: titleLabel.implicitWidth > maxTextWidth
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

    // Ghost exit reuses OsuTextField's FallingDownContainer contract,
    // applied per character with a left-to-right stagger.
    readonly property int lyricGhostFallTime: 200
    readonly property real lyricGhostFallDistanceScale: 1.5
    readonly property int lyricCharStaggerExit: 16
    readonly property int lyricCharStaggerEnter: 22
    readonly property int lyricCharFadeTime: 140
    readonly property int lyricMaxChars: 48
    property var _enterRow: null

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

    property string trackedPrimaryText: ""

    visible: hasMedia
    implicitWidth: visible ? Math.max(root.minPillWidth, contentRow.implicitWidth + 12) : 0
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
        if (root._enterRow)
            root._enterRow.destroy()
    }
    onNeedsSpectrumChanged: syncSpectrumRegistration()

    onPrimaryTextChanged: {
        if (root.trackedPrimaryText === "" || root.trackedPrimaryText === root.primaryText) {
            root.trackedPrimaryText = root.primaryText
            return
        }
        const oldText = root.trackedPrimaryText
        root.trackedPrimaryText = root.primaryText
        if (MotionTokens.reducedMotion) {
            titleScroll.stop()
            titleLabel.x = 0
            titleLabel.opacity = 1
            return
        }
        // Reset marquee before spawning so ghosts start at the same origin
        // the new line fades in from.
        titleScroll.stop()
        titleLabel.x = 0
        spawnLyricGhosts(oldText)
        startCharEnter(root.primaryText)
    }

    function spawnLyricGhosts(oldText) {
        if (oldText === "")
            return
        var count = Math.min(oldText.length, root.lyricMaxChars)
        for (var i = 0; i < count; i++) {
            ghostMetrics.font = titleLabel.font
            ghostMetrics.text = oldText.slice(0, i)
            lyricGhostComponent.createObject(ghostLayer, {
                text: oldText[i],
                color: LazerTheme.textPrimary,
                font: titleLabel.font,
                x: ghostMetrics.advanceWidth,
                y: 0,
                opacity: 1,
                delay: i * root.lyricCharStaggerExit,
                // Travel one-and-a-half line heights, like the field's delete ghosts.
                fallDistance: Math.max(1, titleLabel.height) * root.lyricGhostFallDistanceScale
            })
        }
    }

    // Entrance renders per-character fade-ins on a temporary row while the
    // real label stays hidden; once the last char lands the row is retired
    // and the (elide/marquee-capable) label takes over again.
    function startCharEnter(text) {
        if (root._enterRow) {
            root._enterRow.destroy()
            root._enterRow = null
        }
        if (text === "" || MotionTokens.reducedMotion) {
            titleLabel.opacity = 1
            return
        }
        titleLabel.opacity = 0
        root._enterRow = enterRowComponent.createObject(titleSlot, { chars: text })
        // Safety net: no matter what happens inside the row, the real
        // label always comes back.
        enterGuard.restart()
    }

    // Fallback restores the label if the enter row's own timers ever fail.
    Timer {
        id: enterGuard
        interval: 2400
        onTriggered: {
            if (root._enterRow) {
                root._enterRow.destroy()
                root._enterRow = null
            }
            titleLabel.opacity = 1
        }
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
            // overlay this slot without clipping so they can fall past the pill.
            Item {
                id: titleContainer
                width: Math.min(titleLabel.implicitWidth, root.maxTextWidth)
                height: titleLabel.implicitHeight
                clip: false

                Item {
                    id: titleSlot
                    anchors.fill: parent
                    clip: true

                    Text {
                        id: titleLabel
                        text: root.primaryText
                        color: LazerTheme.textPrimary
                        font.pixelSize: 12
                        font.bold: true
                        opacity: 1
                        width: titleScroll.running ? implicitWidth : Math.min(implicitWidth, root.maxTextWidth)
                        elide: titleScroll.running ? Text.ElideNone : Text.ElideRight
                    }

                    SequentialAnimation {
                        id: titleScroll
                        running: root.titleOverflows && !MotionTokens.reducedMotion
                        loops: Animation.Infinite

                        onRunningChanged: if (!running) titleLabel.x = 0

                        PauseAnimation { duration: 1400 }
                        NumberAnimation {
                            target: titleLabel
                            property: "x"
                            to: -(titleLabel.implicitWidth - titleSlot.width)
                            duration: Math.max(2000, (titleLabel.implicitWidth - titleSlot.width) * 18)
                            easing.type: Easing.Linear
                        }
                        PauseAnimation { duration: 1400 }
                        NumberAnimation {
                            target: titleLabel
                            property: "x"
                            to: 0
                            duration: Math.max(2000, (titleLabel.implicitWidth - titleSlot.width) * 18)
                            easing.type: Easing.Linear
                        }
                    }
                }

                // Ghosts share the slot's origin but live outside the clip so
                // the fall remains visible as it exits the pill.
                Item {
                    id: ghostLayer
                    anchors.fill: parent
                    clip: false
                    z: 10
                }
            }

            Text {
                width: Math.min(implicitWidth, root.maxTextWidth)
                // While lyrics lead the primary line the sub-line carries
                // "artist - song"; otherwise it stays the artist alone.
                text: Services.MediaControlService.showCompactLyric
                    ? Services.MediaControlService.artist
                        + (Services.MediaControlService.title !== ""
                            ? " - " + Services.MediaControlService.title : "")
                    : Services.MediaControlService.artist
                visible: text.length > 0
                color: LazerTheme.textMuted
                elide: Text.ElideRight
                font.pixelSize: 10
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

    // Incoming lyric fades in per character via enterRowComponent; the
    // outgoing line is handled by the per-char ghost layer above reusing
    // the text-field fall contract.
    // Shared per-character advance measuring for ghost placement.
    TextMetrics {
        id: ghostMetrics
    }

    Component {
        id: lyricGhostComponent

        Text {
            id: ghost

            property real fallDistance: 10
            property int delay: 0

            font.bold: true
            font.pixelSize: 12
            elide: Text.ElideNone

            Behavior on y { NumberAnimation { duration: root.lyricGhostFallTime; easing.type: Easing.InQuad } }
            Behavior on opacity { NumberAnimation { duration: root.lyricGhostFallTime; easing.type: Easing.InQuad } }

            Timer {
                id: fallTimer
                interval: ghost.delay > 0 ? ghost.delay + 1 : 1
                onTriggered: {
                    ghost.y += ghost.fallDistance
                    ghost.opacity = 0
                }
            }
            Timer {
                id: retireTimer
                interval: (ghost.delay > 0 ? ghost.delay : 0) + root.lyricGhostFallTime + 2
                onTriggered: ghost.destroy()
            }
            Component.onCompleted: {
                fallTimer.restart()
                retireTimer.restart()
            }
        }
    }

    Component {
        id: enterRowComponent

        Row {
            id: enterRow

            property string chars: ""

            spacing: 0

            Repeater {
                model: Math.min(enterRow.chars.length, root.lyricMaxChars)

                Text {
                    id: charItem

                    required property int index

                    text: enterRow.chars[index]
                    color: LazerTheme.textPrimary
                    font.bold: true
                    font.pixelSize: 12
                    opacity: 0

                    Behavior on opacity { NumberAnimation { duration: root.lyricCharFadeTime; easing.type: Easing.OutQuad } }

                    Timer {
                        interval: charItem.index * root.lyricCharStaggerEnter + 1
                        onTriggered: charItem.opacity = 1
                    }
                }
            }

            Timer {
                id: retireTimer
                interval: Math.min(enterRow.chars.length, root.lyricMaxChars) * root.lyricCharStaggerEnter
                    + root.lyricCharFadeTime + MotionTokens.fast
                onTriggered: {
                    titleLabel.opacity = 1
                    if (root._enterRow === enterRow)
                        root._enterRow = null
                    enterRow.destroy()
                }
            }
        }
    }

    // Hover opens this widget's popup in the shared overlay host.
    WidgetHoverPopup {
        kind: "media"
    }
}
