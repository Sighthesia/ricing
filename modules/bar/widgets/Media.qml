import QtQuick
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
    readonly property bool hasCoverArt: Services.MediaControlService.artUrl !== ""

    // Ghost exit reuses OsuTextField's FallingDownContainer contract.
    readonly property int lyricGhostFallTime: 200
    readonly property real lyricGhostFallDistanceScale: 1.5

    // Spectrum registration — mirrors the old bar spectrum integration.
    readonly property string spectrumComponentId: "media:" + (root.instanceKey !== "" ? root.instanceKey : (root.widgetId !== "" ? root.widgetId : root.screenName))
    readonly property var mediaSettings: Services.SettingsService.widgetSettingsObject("media", root.instanceKey)
    readonly property bool needsSpectrum: root.hasMedia && root.playing && !MotionTokens.reducedMotion
        && (root.mediaSettings ? root.mediaSettings.showAudioSpectrum !== false : true)

    property string trackedPrimaryText: ""

    visible: hasMedia
    implicitWidth: visible ? contentRow.implicitWidth + 12 : 0
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
    Component.onDestruction: Services.SpectrumService.unregisterComponent(root.spectrumComponentId)
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
        spawnLyricGhost(oldText)
        titleLabel.opacity = 0
        lyricFadeIn.restart()
    }

    function spawnLyricGhost(oldText) {
        if (oldText === "")
            return
        lyricGhostComponent.createObject(ghostLayer, {
            text: oldText,
            color: LazerTheme.textPrimary,
            font: titleLabel.font,
            x: 0,
            y: 0,
            opacity: 1,
            // Travel one-and-a-half line heights, like the field's delete ghosts.
            fallDistance: Math.max(1, titleLabel.height) * root.lyricGhostFallDistanceScale
        })
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

        // Cover region: translucent artwork behind the always-present music
        // glyph; failed or missing art falls back to the bare glyph.
        Item {
            anchors.verticalCenter: parent.verticalCenter
            width: root.coverSize
            height: root.coverSize

            Image {
                anchors.fill: parent
                source: Services.MediaControlService.artUrl
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: root.hasCoverArt && status !== Image.Error
                opacity: visible ? 0.55 : 0

                Behavior on opacity { NumberAnimation { duration: MotionTokens.fast } }
            }

            Image {
                anchors.centerIn: parent
                width: LazerTheme.barGlyphSize - 6
                height: LazerTheme.barGlyphSize - 6
                source: "../../lazerbar/icons/music.svg"
                opacity: root.playing ? 0.95 : 0.5

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

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: parent.height * Services.MediaControlService.progress
                radius: 1.5
                color: LazerTheme.accentColor

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
                text: Services.MediaControlService.artist
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

        // Left aligns exactly with textColumn to avoid exceeding text X range.
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

        DockzoneSpectrum {
            anchors.fill: parent
            values: Services.SpectrumService.values
            barColor: Qt.rgba(LazerTheme.accentColor.r, LazerTheme.accentColor.g, LazerTheme.accentColor.b, 0.58)
        }
    }

    // Incoming lyric fades in transparently; outgoing lyric is handled by
    // the ghost layer above reusing the text-field fall contract.
    NumberAnimation {
        id: lyricFadeIn
        target: titleLabel
        property: "opacity"
        from: 0
        to: 1
        duration: root.lyricGhostFallTime
        easing.type: Easing.OutQuad
    }

    Component {
        id: lyricGhostComponent

        Text {
            id: ghost

            property real fallDistance: 10

            font.bold: true
            font.pixelSize: 12
            elide: Text.ElideNone

            Behavior on y { NumberAnimation { duration: root.lyricGhostFallTime; easing.type: Easing.InQuad } }
            Behavior on opacity { NumberAnimation { duration: root.lyricGhostFallTime; easing.type: Easing.InQuad } }

            Timer {
                id: fallTimer
                interval: 1
                onTriggered: {
                    ghost.y += ghost.fallDistance
                    ghost.opacity = 0
                }
            }
            Timer {
                id: retireTimer
                interval: root.lyricGhostFallTime + 1
                onTriggered: ghost.destroy()
            }
            Component.onCompleted: {
                fallTimer.restart()
                retireTimer.restart()
            }
        }
    }
}
