import QtQuick
import Quickshell
import "modules/bar" as Bar
import "services" as Services

// Live integration check for the volume panel's device pickers and application
// mixer, driven by the real PipeWire graph and the real VolumeService.
//
// Read-only by design: the panel's live bindings are what is under test, and a
// harness that changed the user's actual output volume to prove a slider works
// would be a worse trade than the coverage is worth. (The routing WRITE path is
// the one thing this cannot cover safely - it moves real audio between the
// user's devices - so it was verified manually against a live stream instead.)
//
// Headless-safe: every object here is a plain Item, so nothing maps a surface.
Item {
    id: root
    width: 1
    height: 1

    property int checks: 0
    property int failures: 0
    property var panel: null
    property int phase: 0
    // Bounded so a PipeWire graph that never comes up fails the run instead of
    // spinning forever.
    property int waitTries: 0

    readonly property int maxWaitTries: 40

    function check(label, condition) {
        checks += 1
        if (condition) {
            console.info("PASS:", label)
            return
        }
        failures += 1
        console.info("FAIL:", label)
    }

    function advance() {
        phase += 1
        if (phase >= 8)
            return
        advanceTimer.restart()
    }

    // One phase per event-loop turn plus a beat: PipeWire publishes its node
    // list asynchronously after startup, and a check that runs before the graph
    // lands reads an empty list and calls it a failure.
    Timer {
        id: advanceTimer
        interval: 120
        repeat: false
        onTriggered: root.runPhase()
    }

    function runPhase() {
        var svc = Services.VolumeService
        switch (phase) {
        case 0:
            if (!svc.sinks.length || !svc.sources.length) {
                root.waitTries += 1
                if (root.waitTries >= maxWaitTries) {
                    root.check("pipewire published its device lists", false)
                    root.advance()
                    return
                }
                advanceTimer.restart()
                return
            }
            root.check("pipewire published its device lists", true)
            root.advance()
            return
        case 1:
            root.check("every sink carries a usable label",
                svc.sinks.every(function (s) { return svc.deviceLabel(s) !== "" }))
            var defaultId = svc.defaultSinkNode ? svc.defaultSinkNode.id : -1
            // A current-selection bar on a row that is not in the list would be
            // a selection the user cannot see or dismiss.
            root.check("default sink appears in the device list",
                svc.sinks.some(function (s) { return s.id === defaultId }))
            var sourceId = svc.defaultSourceNode ? svc.defaultSourceNode.id : -1
            root.check("default source appears in the source list",
                svc.sources.some(function (s) { return s.id === sourceId }))
            root.advance()
            return
        case 2:
            // One route read, waited for rather than assumed: the chip shows
            // "Reading…" until this lands, so the check has to observe the
            // settled state.
            svc.setRoutePolling(true)
            root.advance()
            return
        case 3:
            if (!svc.streamRoutesReady) {
                if (root.waitTries >= maxWaitTries) {
                    root.check("route table read succeeded", false)
                    root.advance()
                    return
                }
                root.waitTries += 1
                advanceTimer.restart()
                return
            }
            root.check("route table read succeeded", true)
            root.check("every live stream has a resolved route",
                svc.streams.every(function (s) { return svc.streamRouteLabel(s) !== "" }))
            root.check("route labels name a device from the device list",
                svc.streams.every(function (s) {
                    var label = svc.streamRouteLabel(s)
                    return svc.sinks.some(function (d) { return svc.deviceLabel(d) === label })
                }))
            svc.setRoutePolling(false)
            root.advance()
            return
        case 4:
            root.panel.payload = ({ volumeService: svc })
            root.check("panel picked up the live service", root.panel.audioSinks.length > 0)
            root.advance()
            return
        case 5:
            root.check("volume panel is wide enough for a mixer row",
                root.panel.implicitWidth === 360)
            // The master level stays the settings card, so it is expected to be
            // taller than a list row - that is the panel's two families, not a
            // mismatch. What must hold is that the card is the settings card.
            root.check("master level is the settings card",
                root.panel.volumeMasterCardItem.sliderRow !== undefined
                    && root.panel.volumeMasterCardItem.muteRow !== undefined)
            root.check("volume content has a finite height",
                root.panel.volumeContentItem.height > 0
                    && root.panel.volumeContentItem.height <= root.panel.volumeViewportCap)
            root.check("scroll body is bounded by its cap",
                root.panel.volumeScrollItem.height <= root.panel.volumeViewportCap)
            // A body that fits must leave the wheel to the bar's own volume step
            // rather than trapping it on a dead list.
            root.check("scroll only takes the wheel when it overflows",
                root.panel.volumeScrollItem.interactive
                    === (root.panel.volumeScrollItem.contentHeight > root.panel.volumeScrollItem.height))
            root.advance()
            return
        default:
            // The bar widget itself, so the summary it hands the popup header is
            // covered too: it is the one place that names the current device
            // before the panel opens.
            var widget = Qt.createQmlObject(
                'import QtQuick; import "modules/bar/widgets" as W; W.Volume {}', root, "volumeWidget")
            root.check("bar volume widget mounts", widget !== null)
            root.check("bar volume widget names the current output device",
                !!widget && widget.deviceLabel !== "")
            root.check("bar volume widget summary carries the device",
                !!widget && widget.buildHoverIntent().summary.indexOf(widget.deviceLabel) === 0)
            if (widget)
                widget.destroy()

            // Destroy the panel before quitting: with it still mounted, the
            // shell tears the singletons down under it and Qt re-evaluates every
            // binding against a dead service, which floods the log with
            // "Unable to assign [undefined]" that has nothing to do with the
            // live path.
            root.panel.destroy()
            root.panel = null
            console.info("Totals: " + (root.checks - root.failures) + " passed, " + root.failures + " failed")
            Qt.callLater(Qt.quit)
        }
    }

    Component.onCompleted: {
        var item = Qt.createQmlObject(
            'import QtQuick; import "modules/bar" as Bar; Bar.BarPopupActions { actionKind: "volume";'
            + ' payload: ({ volumeService: null }) }', root, "volumePanel")
        if (!item) {
            console.info("FAIL: volume panel could not be created")
            console.info("Totals: 0 passed, 1 failed")
            Qt.callLater(Qt.quit)
            return
        }
        root.panel = item
        advanceTimer.restart()
    }
}