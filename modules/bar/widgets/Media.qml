import QtQuick
import ".."
import "../../lazerbar"
import "../../../services" as Services

// Compact now-playing pill; lyrics take priority over raw titles.
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

        Image {
            anchors.verticalCenter: parent.verticalCenter
            width: 16
            height: 16
            source: "../../lazerbar/icons/music.svg"
            opacity: root.playing ? 0.95 : 0.5

            Behavior on opacity { NumberAnimation { duration: MotionTokens.fast } }
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            Text {
                width: Math.min(implicitWidth, 160)
                text: root.primaryText
                color: LazerTheme.textPrimary
                elide: Text.ElideRight
                font.pixelSize: 11
                font.bold: true
            }

            Text {
                width: Math.min(implicitWidth, 160)
                text: Services.MediaControlService.artist
                visible: text.length > 0
                color: LazerTheme.textMuted
                elide: Text.ElideRight
                font.pixelSize: 9
            }
        }
    }
}
