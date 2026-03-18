import Quickshell
import QtQuick
import qs.services

// Smoke harness for BrightnessService API exposure, override hooks, and safe writes.
ShellRoot {
    id: root

    function _assert(condition, message) {
        if (!condition)
            throw new Error(message)
    }

    Component.onCompleted: {
        root._assert(typeof BrightnessService.available === "boolean",
            "BrightnessService should expose available as a boolean property")
        root._assert(typeof BrightnessService.level === "number",
            "BrightnessService should expose level as a numeric property")
        root._assert(typeof BrightnessService.percentLabel === "string",
            "BrightnessService should expose percentLabel as a string property")
        root._assert(typeof BrightnessService.setLevel === "function",
            "BrightnessService should expose setLevel()")
        root._assert(typeof BrightnessService._setStateOverride === "function",
            "BrightnessService should expose _setStateOverride() for smoke coverage")

        BrightnessService._setStateOverride({
            available: true,
            level: 0.42
        })

        root._assert(BrightnessService.available === true,
            "BrightnessService should surface override availability")
        root._assert(Math.abs(BrightnessService.level - 0.42) < 0.001,
            "BrightnessService should surface override level")
        root._assert(BrightnessService.percentLabel === "42%",
            "BrightnessService should derive percentLabel from the override level")

        BrightnessService.setLevel(1.4)
        root._assert(Math.abs(BrightnessService.level - 1) < 0.001,
            "BrightnessService should clamp setLevel() requests above one")
        root._assert(BrightnessService.percentLabel === "100%",
            "BrightnessService should update percentLabel after setLevel() under override")

        BrightnessService._setStateOverride({
            available: false,
            level: -0.4
        })

        root._assert(BrightnessService.available === false,
            "BrightnessService should replace override availability on later overrides")
        root._assert(Math.abs(BrightnessService.level - 0) < 0.001,
            "BrightnessService should clamp override level into the 0..1 range")
        root._assert(BrightnessService.percentLabel === "--",
            "BrightnessService should degrade percentLabel when brightness is unavailable")

        console.log("BrightnessService smoke test passed")
        Qt.callLater(Qt.quit)
    }
}
