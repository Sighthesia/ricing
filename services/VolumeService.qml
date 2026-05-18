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

    // IPC surface for niri keybind integration.
    property IpcHandler ipc: IpcHandler {
        target: "VolumeService"
        function setSinkVolume(volume: real) { root.setSinkVolume(root.sinkVolume + volume) }
        function toggleSinkMute() { root.toggleSinkMute() }
        function toggleSourceMute() { root.toggleSourceMute() }
    }
}
