pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

// Pipewire audio state: default sink/source volume and mute control.
Singleton {
    id: root

    property PwObjectTracker _tracker: PwObjectTracker {
        objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource]
    }

    // --- Sink (speaker) ---
    readonly property bool sinkMuted: Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.audio.muted : false
    readonly property real sinkVolume: Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.audio.volume : 0

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
        function toggleSinkMute() { root.toggleSinkMute() }
        function toggleSourceMute() { root.toggleSourceMute() }
    }
}
