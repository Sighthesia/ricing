import Quickshell
import QtQuick
import qs.services

ShellRoot {
    id: root

    function _assert(condition, message) {
        if (!condition)
            throw new Error(message)
    }

    Component.onCompleted: {
        root._assert(typeof CavaService.parseFrame === "function",
            "CavaService should expose parseFrame()")
        root._assert(typeof CavaService.applyFrame === "function",
            "CavaService should expose applyFrame()")
        root._assert(typeof CavaService.degraded === "boolean",
            "CavaService should expose degraded state")

        const parsed = CavaService.parseFrame("0;500;1000")
        root._assert(parsed.length === 3,
            "CavaService should parse three bars from a three-value frame")
        root._assert(parsed[0] === 0,
            "CavaService should normalize the first bar to 0")
        root._assert(Math.abs(parsed[1] - 0.5) < 0.001,
            "CavaService should normalize the middle bar to 0.5")
        root._assert(parsed[2] === 1,
            "CavaService should normalize the last bar to 1")

        const parsedWithTrailingDelimiter = CavaService.parseFrame("10;20;30;")
        root._assert(parsedWithTrailingDelimiter.length === 3,
            "CavaService should ignore a trailing delimiter instead of creating a stuck extra bar")
        root._assert(Math.abs(parsedWithTrailingDelimiter[2] - 0.03) < 0.001,
            "CavaService should preserve the last real bar when a trailing delimiter is present")

        CavaService.applyFrame("10;20;30")
        root._assert(CavaService.bars.length === 3,
            "CavaService should retain parsed bars after applyFrame()")
        root._assert(CavaService.degraded === false,
            "CavaService should leave degraded mode after a valid frame")

        CavaService.applyFrame("")
        root._assert(CavaService.bars.length === 0,
            "CavaService should clear bars when an empty frame is applied")
        root._assert(CavaService.degraded === true,
            "CavaService should enter degraded mode after an empty frame")

        console.log("CavaService smoke test passed")
        Qt.callLater(Qt.quit)
    }
}