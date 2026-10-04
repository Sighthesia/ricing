pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import "volume/VolumeLogic.js" as VolumeLogic
import "." as Services

// Pipewire audio state: device lists (output + input), the default
// sink/source volume and mute control, and the per-application mixer.
//
// Volume and mute for every node here are pure PipeWire bindings, so they stay
// live with no polling. The ONE thing PipeWire cannot express through
// Quickshell is where a playback stream is routed - `PwNode` exposes no target,
// and playback nodes carry no `target.*` property at all - so the mixer shells
// out to pactl for that alone. See volume/VolumeLogic.js for the join.
Singleton {
    id: root

    property PwObjectTracker _tracker: PwObjectTracker {
        objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource]
    }

    // --- Sink (speaker) ---
    readonly property bool sinkMuted: Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.audio.muted : false
    readonly property real sinkVolume: Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.audio.volume : 0
    // The nodes the device lists highlight as "current". Named once so the UI
    // compares identity against a live node rather than re-deriving it.
    readonly property var defaultSinkNode: Pipewire.defaultAudioSink
    readonly property var defaultSourceNode: Pipewire.defaultAudioSource

    function setSinkVolume(volume: real) {
        if (!Pipewire.defaultAudioSink) return
        Pipewire.defaultAudioSink.audio.volume = Math.max(0.0, Math.min(1.0, volume))
        if (Pipewire.defaultAudioSink.audio.muted)
            Pipewire.defaultAudioSink.audio.muted = false
    }

    function toggleSinkMute() {
        if (Pipewire.defaultAudioSink)
            Pipewire.defaultAudioSink.audio.muted = !Pipewire.defaultAudioSink.audio.muted
    }

    // --- Source (mic) ---
    readonly property bool sourceMuted: Pipewire.defaultAudioSource ? Pipewire.defaultAudioSource.audio.muted : false
    readonly property real sourceVolume: Pipewire.defaultAudioSource ? Pipewire.defaultAudioSource.audio.volume : 0

    function setSourceVolume(volume: real) {
        if (!Pipewire.defaultAudioSource) return
        Pipewire.defaultAudioSource.audio.volume = Math.max(0.0, Math.min(1.0, volume))
        if (Pipewire.defaultAudioSource.audio.muted)
            Pipewire.defaultAudioSource.audio.muted = false
    }

    function toggleSourceMute() {
        if (Pipewire.defaultAudioSource)
            Pipewire.defaultAudioSource.audio.muted = !Pipewire.defaultAudioSource.audio.muted
    }

    // --- Device enumeration (hardware sinks/sources, excluding streams) ---
    readonly property var sinks: Pipewire.ready ? _filterDevices(true) : []
    readonly property var sources: Pipewire.ready ? _filterDevices(false) : []

    function _filterDevices(wantSinks) {
        if (!Pipewire.nodes || !Pipewire.nodes.values) return []
        return Pipewire.nodes.values.filter(function (node) {
            if (!node || node.isStream) return false
            var name = node.name || ""
            var mediaName = (node.properties && node.properties["media.name"]) || ""
            if (name === "quickshell" || mediaName === "quickshell") return false
            if (wantSinks) return node.isSink === true
            // Source: not a sink, has audio
            return node.audio != null && !node.isSink
        })
    }

    // Track all device nodes so their audio properties stay bound.
    property PwObjectTracker _deviceTracker: PwObjectTracker {
        objects: root.sinks.concat(root.sources)
    }

    // --- Application mixer (playback streams / sink inputs) ---

    // Only playback streams belong in an output mixer: a capture stream
    // (`isStream && !isSink`) belongs with the input device, and the hardware
    // nodes are already in `sinks`.
    readonly property var streams: Pipewire.ready ? _filterStreams() : []

    function _filterStreams() {
        if (!Pipewire.nodes || !Pipewire.nodes.values) return []
        var filtered = []
        for (var index = 0; index < Pipewire.nodes.values.length; index += 1) {
            var node = Pipewire.nodes.values[index]
            if (!VolumeLogic.isPlaybackStream(node)) continue
            if (VolumeLogic.isShellStream(node)) continue
            filtered.push(node)
        }
        return filtered
    }

    // Stream volume/mute are only valid on a bound node, and the nodes arrive
    // before they are bound - so the list must be bound here or every row would
    // read a permanently absent `audio`.
    property PwObjectTracker _streamTracker: PwObjectTracker {
        objects: root.streams
    }

    function streamAppName(stream) { return VolumeLogic.streamAppName(stream) }
    function streamMediaName(stream) { return VolumeLogic.streamMediaName(stream) }
    function streamIconName(stream) { return VolumeLogic.streamIconName(stream) }
    function streamLevel(stream) { return VolumeLogic.streamLevel(stream) }
    function streamMuted(stream) { return VolumeLogic.streamMuted(stream) }

    function setStreamVolume(stream, volume) {
        if (!stream || !stream.audio) return
        var next = Math.max(0, Math.min(1, Number(volume)))
        if (!isFinite(next)) return
        stream.audio.volume = next
        if (stream.audio.muted)
            stream.audio.muted = false
    }

    function toggleStreamMute(stream) {
        if (!stream || !stream.audio) return
        stream.audio.muted = !stream.audio.muted
    }

    // --- Stream routing (pactl; PipeWire exposes no target on a stream) ---

    // pipewire node id -> { pulseIndex, sinkIndex, sinkName }. Null until the
    // first read succeeds, and deliberately NEVER cleared to {} on a failed
    // read: an empty table would read as "every app follows the default
    // device", which is a wrong claim rather than a stale one.
    readonly property var streamRoutes: _streamRoutes
    property var _streamRoutes: null

    // True once a read has landed, so the UI can tell "not read yet" from
    // "read, and this app genuinely has no route entry".
    readonly property bool streamRoutesReady: _streamRoutes !== null

    readonly property var cEnvironment: ({ "LC_ALL": "C", "LANG": "C" })

    // Read both documents in one invocation so a sink index read and a
    // sink-input read can never come from different points in time.
    Process {
        id: routeScanProcess
        running: false
        environment: root.cEnvironment
        command: ["sh", "-c",
            "pactl -f json list sink-inputs 2>/dev/null; "
            + "printf '\\n" + VolumeLogic.ROUTE_SECTION_MARKER + "\\n'; "
            + "pactl -f json list sinks 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: root._applyRouteScan(text)
        }
        stderr: StdioCollector {
            // stderr finishes on stream CLOSE, so it also fires for a clean run
            // and would otherwise overwrite the good stdout result. pactl emits
            // a locale warning for non-ASCII media names; the shell already
            // drops it, and this guard is the second line of defence.
            onStreamFinished: {
                if (!text.trim())
                    return
                console.warn("[Volume] route scan stderr:", text.trim().slice(0, 200))
            }
        }
    }

    function _applyRouteScan(stdout) {
        var sections = VolumeLogic.splitSections(stdout)
        var routes = sections ? VolumeLogic.parseStreamRoutes(sections.sinkInputs, sections.sinks) : null
        if (!routes) {
            // Keep the previous table; see the note on `streamRoutes`.
            console.warn("[Volume] route scan unparsable, keeping previous table")
            return
        }
        root._streamRoutes = routes
    }

    function refreshStreamRoutes() {
        if (!Pipewire.ready) return
        if (routeScanProcess.running) return
        routeScanProcess.running = true
    }

    // Immutable per-run snapshot. Reading `routeMoveProcess.jobSink` from
    // `onExited` would report run 1's arguments for run 2 when a second move
    // starts before the first settles.
    property var _moveJob: null

    function moveStreamToSink(stream, sinkNode) {
        if (!stream || !sinkNode || !Pipewire.ready) return
        var entry = VolumeLogic.routeFor(root._streamRoutes, stream.id)
        // No route entry means the read has not landed (or this stream appeared
        // after it). Refusing is the honest answer: a pulse index guessed from
        // anything else would move some other application's audio.
        if (!entry) return
        var sinkName = sinkNode.name == null ? "" : String(sinkNode.name)
        if (sinkName === "" || sinkName === entry.sinkName) return
        root._moveJob = { pulseIndex: entry.pulseIndex, sinkName: sinkName }
        Qt.callLater(root._startRouteMove)
    }

    function _startRouteMove() {
        if (routeMoveProcess.running || !root._moveJob) return
        routeMoveProcess.jobPulse = String(root._moveJob.pulseIndex)
        routeMoveProcess.jobSink = root._moveJob.sinkName
        Qt.callLater(function () {
            if (!routeMoveProcess.running)
                routeMoveProcess.running = true
        })
    }

    Process {
        id: routeMoveProcess
        property string jobPulse: ""
        property string jobSink: ""
        running: false
        environment: root.cEnvironment
        command: ["pactl", "move-sink-input", jobPulse, jobSink]
        onExited: function (code) {
            if (code === 0) {
                // Re-read rather than assume: the new sink is the claim to verify.
                Qt.callLater(root.refreshStreamRoutes)
            } else {
                console.warn("[Volume] move-sink-input failed", code, jobPulse, jobSink)
            }
        }
    }

    // Route reads are only worth their process spawn while the mixer is on
    // screen, and the singleton outlives every popup - so polling is opt-in and
    // owned by the panel that asked for it.
    property Timer routePollTimer: Timer {
        interval: 1500
        repeat: true
        running: false
        onTriggered: root.refreshStreamRoutes()
    }

    function setRoutePolling(enabled) {
        if (enabled) {
            root.refreshStreamRoutes()
            if (!routePollTimer.running)
                routePollTimer.restart()
            return
        }
        if (routePollTimer.running)
            routePollTimer.stop()
    }

    // Display label for the sink a stream is routed to, resolved against the
    // same device list the panel shows so the two never disagree on a name.
    function streamRouteLabel(stream) {
        var entry = VolumeLogic.routeFor(root._streamRoutes, stream ? stream.id : null)
        if (!entry) return ""
        return VolumeLogic.sinkLabel(entry.sinkName, root.sinks)
    }

    function isDefaultSink(node) {
        return !!node && !!Pipewire.defaultAudioSink && node.id === Pipewire.defaultAudioSink.id
    }

    function isDefaultSource(node) {
        return !!node && !!Pipewire.defaultAudioSource && node.id === Pipewire.defaultAudioSource.id
    }

    // Switch the default output device.
    function setAudioSink(node) {
        if (!Pipewire.ready || !node) return
        Pipewire.preferredDefaultAudioSink = node
        console.info("[Volume] setAudioSink", node.name || node.description)
    }

    // Switch the default input device.
    function setAudioSource(node) {
        if (!Pipewire.ready || !node) return
        Pipewire.preferredDefaultAudioSource = node
        console.info("[Volume] setAudioSource", node.name || node.description)
    }

    // Human-readable label for a device node.
    function deviceLabel(node) {
        if (!node) return ""
        var desc = node.description
        if (desc && String(desc).trim() !== "") return desc
        return node.name || "Device"
    }

    // IPC surface for niri keybind integration.
    property IpcHandler ipc: IpcHandler {
        target: "VolumeService"
        function setSinkVolume(volume: real) { root.setSinkVolume(root.sinkVolume + volume) }
        function stepVolumeUp() { root.setSinkVolume(root.sinkVolume + Services.SettingsService.controls.volumeStep) }
        function stepVolumeDown() { root.setSinkVolume(root.sinkVolume - Services.SettingsService.controls.volumeStep) }
        function toggleSinkMute() { root.toggleSinkMute() }
        function toggleSourceMute() { root.toggleSourceMute() }
    }
}
