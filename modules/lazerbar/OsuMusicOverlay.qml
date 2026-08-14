import QtQuick

// Present fixed music metadata and controls with an interruptible reveal.
Item {
    id: root
    property string titleText: "暂无播放内容"
    property string artistText: ""
    property bool playing: false
    property real progress: 0
    readonly property real clampedProgress: Math.max(0, Math.min(1, progress))
    property bool shuffleActive: false
    property bool canGoPrevious: false
    property bool canTogglePlayback: false
    property bool canGoNext: false
    property bool openState: false
    property bool interactive: false
    property real openProgress: 0
    readonly property real effectiveYOffset: MotionTokens.reducedMotion ? 0 : -4 * (1 - openProgress)
    readonly property int openDuration: MotionTokens.medium
    readonly property int closeDuration: MotionTokens.fast
    signal shuffleRequested(bool active)
    signal previousRequested
    signal playPauseRequested
    signal nextRequested
    signal playlistRequested
    signal closeRequested

    implicitWidth: 340
    implicitHeight: 130
    opacity: openProgress
    enabled: interactive
    transform: Translate { y: root.effectiveYOffset }

    function open() { openState = true; interactive = true; reveal.duration = openDuration; reveal.to = 1; reveal.restart(); Qt.callLater(focusFirstControl) }
    function close() { interactive = false; openState = false; reveal.duration = closeDuration; reveal.to = 0; reveal.restart() }
    function focusFirstControl() { shuffleButton.forceActiveFocus() }
    Keys.onEscapePressed: event => { closeRequested(); event.accepted = true }

    NumberAnimation { id: reveal; target: root; property: "openProgress"; easing.type: Easing.BezierSpline; easing.bezierCurve: MotionTokens.outSoft }

    // Paint the fixed-size floating player card.
    Rectangle {
        anchors.fill: parent
        radius: 10
        color: LazerTheme.musicBackground
        border.width: 1
        border.color: "#24FFFFFF"

        Column {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: 14
            spacing: 2
            Text { width: parent.width - 32; anchors.horizontalCenter: parent.horizontalCenter; horizontalAlignment: Text.AlignHCenter; text: root.titleText || "暂无播放内容"; color: "white"; font.pixelSize: 16; font.bold: true; elide: Text.ElideRight }
            Text { width: parent.width - 32; anchors.horizontalCenter: parent.horizontalCenter; horizontalAlignment: Text.AlignHCenter; text: root.artistText; color: LazerTheme.musicMuted; font.pixelSize: 12; elide: Text.ElideRight }
        }

        Row {
            id: controls
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: progressTrack.top
            anchors.bottomMargin: 13
            spacing: 16
            MusicControlButton { id: shuffleButton; iconSource: "icons/shuffle.svg"; accessibleName: "Shuffle"; active: root.shuffleActive; onClicked: { root.shuffleActive = !root.shuffleActive; root.shuffleRequested(root.shuffleActive) } KeyNavigation.right: previousButton }
            MusicControlButton { id: previousButton; iconSource: "icons/previous.svg"; accessibleName: "Previous"; enabled: root.canGoPrevious; onClicked: root.previousRequested(); KeyNavigation.left: shuffleButton; KeyNavigation.right: playButton }
            MusicControlButton { id: playButton; iconSource: root.playing ? "icons/pause.svg" : "icons/play.svg"; accessibleName: root.playing ? "Pause" : "Play"; outlined: true; enabled: root.canTogglePlayback; onClicked: root.playPauseRequested(); KeyNavigation.left: previousButton; KeyNavigation.right: nextButton }
            MusicControlButton { id: nextButton; iconSource: "icons/next.svg"; accessibleName: "Next"; enabled: root.canGoNext; onClicked: root.nextRequested(); KeyNavigation.left: playButton; KeyNavigation.right: playlistButton }
            MusicControlButton { id: playlistButton; iconSource: "icons/playlist.svg"; accessibleName: "Playlist"; onClicked: root.playlistRequested(); KeyNavigation.left: nextButton }
        }

        Rectangle {
            id: progressTrack
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 4
            color: "#55000000"
            Rectangle { width: parent.width * root.clampedProgress; height: parent.height; color: LazerTheme.musicGold }
        }
    }
}
