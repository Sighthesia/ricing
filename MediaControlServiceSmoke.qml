import Quickshell
import QtQuick
import qs.services

ShellRoot {
    id: root

    function _assert(condition, message) {
        if (!condition)
            throw new Error(message)
    }

    Component.onCompleted: {
        root._assert(typeof MediaControlService.togglePanel === "function",
            "MediaControlService should expose togglePanel()")
        root._assert(typeof MediaControlService.openPanel === "function",
            "MediaControlService should expose openPanel()")
        root._assert(typeof MediaControlService.closePanel === "function",
            "MediaControlService should expose closePanel()")
        root._assert(typeof MediaControlService.acknowledgeAnnouncement === "function",
            "MediaControlService should expose acknowledgeAnnouncement()")
        root._assert(typeof MediaControlService._setMediaOverride === "function",
            "MediaControlService should expose a media override hook for smoke coverage")
        root._assert(typeof MediaControlService._setVisualizerOverride === "function",
            "MediaControlService should expose a visualizer override hook for smoke coverage")

        MediaControlService._setMediaOverride({
            hasPlayer: true,
            title: "Song A",
            artist: "Artist A",
            artUrl: "/tmp/art.png",
            playerName: "Player A",
            playbackState: "playing",
            positionMs: 30000,
            lengthMs: 120000,
            canGoPrevious: true,
            canTogglePlayback: true,
            canGoNext: true
        })
        MediaControlService._setVisualizerOverride({
            bars: [0.2, 0.4, 0.6],
            healthy: true
        })

        root._assert(MediaControlService.hasMedia === true,
            "MediaControlService should surface hasMedia from the media snapshot")
        root._assert(MediaControlService.title === "Song A",
            "MediaControlService should surface title from the media snapshot")
        root._assert(MediaControlService.artist === "Artist A",
            "MediaControlService should surface artist from the media snapshot")
        root._assert(Math.abs(MediaControlService.progress - 0.25) < 0.001,
            "MediaControlService should normalize playback progress")
        root._assert(MediaControlService.positionLabel === "00:30",
            "MediaControlService should format elapsed time")
        root._assert(MediaControlService.durationLabel === "02:00",
            "MediaControlService should format total duration")
        root._assert(MediaControlService.visualizerBars.length === 3,
            "MediaControlService should surface visualizer bars")
        root._assert(MediaControlService.visualizerHealthy === true,
            "MediaControlService should surface visualizer health")
        root._assert(MediaControlService.announcementState !== "idle",
            "MediaControlService should raise an announcement state for a new track snapshot")

        MediaControlService.acknowledgeAnnouncement()
        root._assert(MediaControlService.announcementState === "idle",
            "MediaControlService should return to idle when the announcement is acknowledged")

        MediaControlService.togglePanel()
        root._assert(MediaControlService.panelOpen === true,
            "MediaControlService should open the panel when toggled from the closed state")
        MediaControlService.closePanel()
        root._assert(MediaControlService.panelOpen === false,
            "MediaControlService should close the panel when closePanel() is called")

        console.log("MediaControlService smoke test passed")
        Qt.callLater(Qt.quit)
    }
}