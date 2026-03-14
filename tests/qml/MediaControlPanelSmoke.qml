import Quickshell
import QtQuick
import qs.services
import qs.modules.bar

// Smoke harness for MediaControlPanel open and close lifecycle behavior.
ShellRoot {
    id: root

    function _assert(condition, message) {
        if (!condition)
            throw new Error(message)
    }

    MediaControlPanel {
        id: panel
    }

    Component.onCompleted: {
        MediaControlService._setMediaOverride({
            hasPlayer: true,
            title: "Panel Track",
            artist: "Panel Artist",
            artUrl: "",
            playerName: "Panel Player",
            playbackState: "playing",
            positionMs: 90000,
            lengthMs: 240000,
            canGoPrevious: true,
            canTogglePlayback: true,
            canGoNext: true
        })
        MediaControlService._setVisualizerOverride({
            bars: [0.3, 0.4, 0.6],
            healthy: true
        })

        MediaControlService.openPanel()

        let openTimer = Qt.createQmlObject('import QtQuick; Timer { interval: 80; repeat: false }', root)
        openTimer.triggered.connect(function() {
            root._assert(panel.active === true,
                "MediaControlPanel should become active when the service opens the panel")
            root._assert(panel.visible === true,
                "MediaControlPanel should remain visible during the open state")

            MediaControlService.closePanel()

            let closeTimer = Qt.createQmlObject('import QtQuick; Timer { interval: 260; repeat: false }', root)
            closeTimer.triggered.connect(function() {
                root._assert(panel.active === false,
                    "MediaControlPanel should deactivate when the service closes the panel")
                console.log("MediaControlPanel smoke test passed")
                Qt.callLater(Qt.quit)
            })
            closeTimer.start()
        })
        openTimer.start()
    }
}
