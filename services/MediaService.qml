pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Media playback control via playerctl, with state polling.
Singleton {
    id: root

    property bool playing: false
    property string title: ""
    property string artist: ""
    property string album: ""

    function playPause() {
        Quickshell.execDetached(["playerctl", "play-pause"])
        // State will update on next poll
    }

    function previous() {
        Quickshell.execDetached(["playerctl", "previous"])
    }

    function next() {
        Quickshell.execDetached(["playerctl", "next"])
    }

    // IPC surface for niri keybind integration.
    property IpcHandler ipc: IpcHandler {
        target: "MediaService"
        function playPause() { root.playPause() }
        function previous() { root.previous() }
        function next() { root.next() }
    }

    // Poll playerctl for current playback status
    property Process _statusPoller: Process {
        id: statusPoller
        command: ["playerctl", "metadata", "--format", "{{status}}\t{{title}}\t{{artist}}\t{{album}}"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                let parts = this.text.trim().split("\t")
                if (parts.length >= 1) {
                    root.playing = parts[0] === "Playing"
                }
                if (parts.length >= 2) root.title = parts[1] || ""
                if (parts.length >= 3) root.artist = parts[2] || ""
                if (parts.length >= 4) root.album = parts[3] || ""
            }
        }

        onExited: statusPollTimer.start()
    }

    property Timer _statusPollTimer: Timer {
        id: statusPollTimer
        interval: 1000
        onTriggered: statusPoller.running = true
    }
}
