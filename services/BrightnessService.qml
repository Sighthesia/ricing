pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "." as Services

// Screen brightness state via brightnessctl, polled periodically.
Singleton {
    id: root

    property real brightness: 1.0

    function setBrightness(val: real) {
        let pct = Math.round(Math.max(0.01, Math.min(1.0, val)) * 100)
        Quickshell.execDetached(["brightnessctl", "set", pct + "%"])
        root.brightness = val
    }

    // IPC surface for niri keybind integration.
    property IpcHandler ipc: IpcHandler {
        target: "BrightnessService"
        function setBrightness(delta: real) { root.setBrightness(root.brightness + delta) }
        function stepBrightnessUp() { root.setBrightness(root.brightness + Services.SettingsService.controls.brightnessStep) }
        function stepBrightnessDown() { root.setBrightness(root.brightness - Services.SettingsService.controls.brightnessStep) }
    }

    // Poll brightnessctl -m for current value
    property Process _poller: Process {
        id: poller
        command: ["brightnessctl", "-m"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                // Format: device,class,current,percentage%,max
                let parts = this.text.trim().split(",")
                if (parts.length >= 5) {
                    let current = parseInt(parts[2])
                    let max = parseInt(parts[4])
                    if (max > 0) root.brightness = current / max
                }
            }
        }

        onExited: pollTimer.start()
    }

    property Timer _pollTimer: Timer {
        id: pollTimer
        interval: 5000
        onTriggered: poller.running = true
    }
}
