import Quickshell
import QtQuick
import qs.services

// Smoke harness for AudioDeviceService API exposure, override hooks, and command-safe actions.
ShellRoot {
    id: root

    function _assert(condition, message) {
        if (!condition)
            throw new Error(message)
    }

    Component.onCompleted: {
        root._assert(typeof AudioDeviceService.volumeLevel === "number",
            "AudioDeviceService should expose volumeLevel as a numeric property")
        root._assert(typeof AudioDeviceService.volumeMuted === "boolean",
            "AudioDeviceService should expose volumeMuted as a boolean property")
        root._assert(typeof AudioDeviceService.microphoneMuted === "boolean",
            "AudioDeviceService should expose microphoneMuted as a boolean property")
        root._assert(typeof AudioDeviceService.sinkAvailable === "boolean",
            "AudioDeviceService should expose sinkAvailable as a boolean property")
        root._assert(typeof AudioDeviceService.sourceAvailable === "boolean",
            "AudioDeviceService should expose sourceAvailable as a boolean property")
        root._assert(typeof AudioDeviceService.setVolumeLevel === "function",
            "AudioDeviceService should expose setVolumeLevel()")
        root._assert(typeof AudioDeviceService.toggleMicrophoneMute === "function",
            "AudioDeviceService should expose toggleMicrophoneMute()")
        root._assert(typeof AudioDeviceService._setStateOverride === "function",
            "AudioDeviceService should expose _setStateOverride() for smoke coverage")

        AudioDeviceService._setStateOverride({
            volumeLevel: 1.7,
            volumeMuted: true,
            microphoneMuted: false,
            sinkAvailable: true,
            sourceAvailable: true
        })

        root._assert(Math.abs(AudioDeviceService.volumeLevel - 1) < 0.001,
            "AudioDeviceService should clamp override volumeLevel into the 0..1 range")
        root._assert(AudioDeviceService.volumeMuted === true,
            "AudioDeviceService should surface override volumeMuted")
        root._assert(AudioDeviceService.microphoneMuted === false,
            "AudioDeviceService should surface override microphoneMuted")
        root._assert(AudioDeviceService.sinkAvailable === true,
            "AudioDeviceService should surface override sinkAvailable")
        root._assert(AudioDeviceService.sourceAvailable === true,
            "AudioDeviceService should surface override sourceAvailable")

        AudioDeviceService.setVolumeLevel(-0.4)
        root._assert(Math.abs(AudioDeviceService.volumeLevel - 0) < 0.001,
            "AudioDeviceService should clamp setVolumeLevel() requests below zero")

        AudioDeviceService.toggleMicrophoneMute()
        root._assert(AudioDeviceService.microphoneMuted === true,
            "AudioDeviceService should flip microphoneMuted when toggleMicrophoneMute() runs under override")

        AudioDeviceService._setStateOverride({
            volumeLevel: 0.42,
            volumeMuted: false,
            microphoneMuted: true,
            sinkAvailable: false,
            sourceAvailable: true
        })

        root._assert(Math.abs(AudioDeviceService.volumeLevel - 0.42) < 0.001,
            "AudioDeviceService should accept an in-range override volumeLevel")
        root._assert(AudioDeviceService.volumeMuted === false,
            "AudioDeviceService should replace override volumeMuted on later overrides")
        root._assert(AudioDeviceService.microphoneMuted === true,
            "AudioDeviceService should replace override microphoneMuted on later overrides")
        root._assert(AudioDeviceService.sinkAvailable === false,
            "AudioDeviceService should replace override sinkAvailable on later overrides")
        root._assert(AudioDeviceService.sourceAvailable === true,
            "AudioDeviceService should preserve source availability from the override")

        console.log("AudioDeviceService smoke test passed")
        Qt.callLater(Qt.quit)
    }
}
