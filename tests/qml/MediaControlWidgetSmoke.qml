import Quickshell
import QtQuick
import qs.config
import qs.services
import "../../modules/bar/widgets" as BarWidgets

// Smoke harness for MediaControlWidget flash staging and collapse behavior.
ShellRoot {
    id: root

    property bool collapsePhase: false
    property bool observedCollapsePulseOpacity: false
    property bool observedCollapsePulseScale: false

    function _assert(condition, message) {
        if (!condition)
            throw new Error(message)
    }

    BarWidgets.MediaControlWidget {
        id: widget
        visible: false
        _hoverHandlerIgnored: true
    }

    Connections {
        target: widget

        function on_PulseOpacityChanged() {
            if (root.collapsePhase && widget._pulseOpacity > 0)
                root.observedCollapsePulseOpacity = true
        }

        function on_PulseScaleChanged() {
            if (root.collapsePhase && widget._pulseScale > 1)
                root.observedCollapsePulseScale = true
        }
    }

    Component.onCompleted: {
        SettingsService.data.mediaControl.enabled = true
        SettingsService.data.mediaControl.showWhenIdle = true
        SettingsService.data.mediaControl.hoverRevealControls = true
        SettingsService.data.mediaControl.announcementEnabled = false

        MediaControlService._setMediaOverride({
            hasPlayer: true,
            title: "Widget Track",
            artist: "Widget Artist",
            artUrl: "",
            playerName: "Widget Player",
            playbackState: "playing",
            positionMs: 45000,
            lengthMs: 180000,
            canGoPrevious: true,
            canTogglePlayback: true,
            canGoNext: true
        })
        MediaControlService._setVisualizerOverride({
            bars: [0.2, 0.5, 0.8, 0.4],
            healthy: true
        })
        widget._hoverFlashOverride = true

        let flashTimer = Qt.createQmlObject(
            'import QtQuick; Timer { interval: 80; repeat: false }',
            root)
        flashTimer.triggered.connect(function() {
            root._assert(widget.implicitWidth > 0,
                "MediaControlWidget should report a positive compact width while active")
            root._assert(widget.flashVisible === true,
                "MediaControlWidget should surface the flash row while hover reveal is active")
            root._assert(widget._pulseScale > 1,
                "MediaControlWidget should apply a center-based rebound scale so all four edges participate during expansion")
            root._assert(widget._flashStageProgress > 0 && widget._flashStageProgress < 1,
                "MediaControlWidget should stage the flash reveal instead of snapping transport content to fully visible")
            root._assert(BarLayoutService.mediaControlFlashExtension > 0,
                "MediaControlWidget should raise the dedicated media flash extension while flashing")

            let stageTimer = Qt.createQmlObject(
                'import QtQuick; Timer { interval: ' + Math.max(120, Theme.anim.springDuration) + '; repeat: false }',
                root)
            stageTimer.triggered.connect(function() {
                root._assert(widget._flashStageProgress > 0.98,
                    "MediaControlWidget should settle the flash reveal to a fully staged state after the entrance animation")

                MediaControlService._setMediaOverride({
                    hasPlayer: true,
                    title: "New Track",
                    artist: "New Artist",
                    artUrl: "",
                    playerName: "Widget Player",
                    playbackState: "playing",
                    positionMs: 45000,
                    lengthMs: 180000,
                    canGoPrevious: true,
                    canTogglePlayback: true,
                    canGoNext: true
                })

                let swapTimer = Qt.createQmlObject(
                    'import QtQuick; Timer { interval: ' + Math.max(80, Theme.anim.moveDuration / 2) + '; repeat: false }',
                    root)
                swapTimer.triggered.connect(function() {
                    root._assert(widget._contentSwapProgress > 0 && widget._contentSwapProgress < 1,
                        "MediaControlWidget should expose an in-progress content crossfade when media metadata changes")
                })
                swapTimer.start()

                widget._hoverFlashOverride = false

                let holdTimer = Qt.createQmlObject(
                    'import QtQuick; Timer { interval: ' + Math.max(100, SettingsService.data.mediaControl.announcementDuration - 300) + '; repeat: false }',
                    root)
                holdTimer.triggered.connect(function() {
                    root._assert(widget.flashVisible === true,
                        "MediaControlWidget should retain the flash row briefly after hover exits")

                    root.observedCollapsePulseOpacity = false
                    root.observedCollapsePulseScale = false
                    root.collapsePhase = true

                    let midCollapseTimer = Qt.createQmlObject(
                        'import QtQuick; Timer { interval: 620; repeat: false }',
                        root)
                    midCollapseTimer.triggered.connect(function() {
                        root._assert(BarLayoutService.mediaControlFlashExtension > 0,
                            "MediaControlWidget should keep the render hold briefly during the collapse animation")
                        root._assert(widget._flashStageClipHeight > widget._pillH,
                            "MediaControlWidget should keep flash content within a shrinking clip during collapse instead of snapping it directly to pill height")
                        root._assert(widget._flashStageClipHeight < (widget._pillH + Theme.barWidget.stackGap + Theme.barWidget.pillHeight),
                            "MediaControlWidget should progressively reduce the flash clip during collapse")
                    })
                    midCollapseTimer.start()

                    let settleTimer = Qt.createQmlObject(
                        'import QtQuick; Timer { interval: ' + Math.max(900, 300 + Theme.anim.springDuration + 420) + '; repeat: false }',
                        root)
                    settleTimer.triggered.connect(function() {
                        root._assert(root.observedCollapsePulseOpacity === false,
                            "MediaControlWidget should not trigger the shared pulse when the flash row collapses")
                        root._assert(root.observedCollapsePulseScale === true,
                            "MediaControlWidget should keep a center-based rebound scale during collapse so all four edges participate")
                        root._assert(widget.implicitWidth < Theme.barWidget.mediaCompactMinWidth,
                            "MediaControlWidget should shrink to fit compact content instead of staying pinned to a fixed minimum width")
                        root._assert(widget.flashVisible === false,
                            "MediaControlWidget should release the hover-retained flash row after the hold window")
                        root._assert(BarLayoutService.mediaControlFlashExtension === 0,
                            "MediaControlWidget should release the media flash extension after the hover hold ends")
                        console.log("MediaControlWidget smoke test passed")
                        Qt.callLater(Qt.quit)
                    })
                    settleTimer.start()
                })
                holdTimer.start()
            })
            stageTimer.start()
        })
        flashTimer.start()
    }
}
