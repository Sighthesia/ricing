import QtQuick
import ".."
import "../../lazerbar"
import "../../../services" as Services

// Compact now-playing pill; lyrics take priority over raw titles. The pill
// grows with its content up to a cap, the translucent album cover sits in a
// square region centered on the music glyph, and an over-long primary line
// marquee-scrolls instead of being cut short.
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

    visible: hasMedia
    implicitWidth: visible ? contentRow.implicitWidth + 12 : 0
    hoverable: hasMedia

    onClicked: Services.MediaService.playPause()

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

        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            // Primary line grows with content; once past the cap it clips
            // and marquee-scrolls (static elide under reduced motion).
            Item {
                id: titleSlot
                width: Math.min(titleLabel.implicitWidth, root.maxTextWidth)
                height: titleLabel.implicitHeight
                clip: true

                Text {
                    id: titleLabel
                    text: root.primaryText
                    color: LazerTheme.textPrimary
                    font.pixelSize: 12
                    font.bold: true
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
}
