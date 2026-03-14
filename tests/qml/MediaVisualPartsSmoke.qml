import Quickshell
import QtQuick
import qs.config
import qs.services
import "modules/bar/media" as MediaParts

// Smoke harness for media visual components and expanded-panel layout contracts.
ShellRoot {
    id: root

    function _assert(condition, message) {
        if (!condition)
            throw new Error(message)
    }

    function _findFirstByPredicate(node, predicate) {
        if (!node || !node.children)
            return null

        for (let i = 0; i < node.children.length; ++i) {
            const child = node.children[i]
            if (predicate(child))
                return child

            const nestedMatch = root._findFirstByPredicate(child, predicate)
            if (nestedMatch)
                return nestedMatch
        }

        return null
    }

    MediaParts.MediaArtwork {
        id: artwork
        visible: false
    }

    MediaParts.MediaArtwork {
        id: panelArtwork
        visible: false
        roundedRect: true
    }

    MediaParts.MediaVisualizerBackground {
        id: visualizer
        width: 120
        height: 36
        visible: false
        bars: [0.1, 0.4, 0.8]
    }

    MediaParts.MediaProgressStrip {
        id: progressStrip
        visible: false
        progress: 0.5
        expanded: true
    }

    MediaParts.MediaFlashControls {
        id: controls
        width: 220
        visible: false
        progress: 0.5
        durationLabel: "03:20"
        playbackState: "playing"
        canGoPrevious: true
        canTogglePlayback: true
        canGoNext: true
    }

    MediaParts.MediaPanelContent {
        id: panelContent
        width: Theme.barWidget.mediaPanelWidth
        visible: false
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
            canGoNext: true,
            canSeek: true
        })
        MediaControlService._setVisualizerOverride({
            bars: [0.3, 0.5, 0.7],
            healthy: true
        })

        const panelLayout = panelContent.children[0]
        const panelTransport = root._findFirstByPredicate(panelLayout, child => child && child.showProgress !== undefined)
        const panelProgressRow = root._findFirstByPredicate(panelLayout, child => child && child.progress !== undefined && child.expanded !== undefined)

        root._assert(artwork.implicitWidth > 0,
            "MediaArtwork should report a positive implicit width")
        root._assert(artwork.fallbackIcon === "audio-x-generic-symbolic",
            "MediaArtwork should use a note-style fallback icon when no artwork is available")
        root._assert(panelArtwork.cornerRadius === Theme.cornerRadius,
            "MediaArtwork should support rounded-rectangle artwork for expanded panel layouts")
        root._assert(visualizer.bars.length === 3,
            "MediaVisualizerBackground should retain the provided bars")
        root._assert(progressStrip.implicitHeight > 0,
            "MediaProgressStrip should report a positive thickness")
        root._assert(progressStrip.implicitHeight > Theme.barWidget.mediaProgressThickness,
            "MediaProgressStrip should grow taller when expanded")
        root._assert(controls.implicitWidth > progressStrip.implicitWidth,
            "MediaFlashControls should occupy more width than the progress strip alone")
        root._assert(Math.abs(controls.childrenRect.width - controls.width) <= 2,
            "MediaFlashControls should stretch its internal layout to the assigned width")
        root._assert(panelTransport !== null,
            "MediaPanelContent should expose a transport row below the hero surface")
        root._assert(panelTransport.showProgress === false,
            "MediaPanelContent should keep playback buttons on their own row once progress and time move above them")
        root._assert(panelProgressRow !== null,
            "MediaPanelContent should expose a dedicated progress row above the playback buttons")

        console.log("MediaVisualParts smoke test passed")
        Qt.callLater(Qt.quit)
    }
}
