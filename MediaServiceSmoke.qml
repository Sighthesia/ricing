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
        root._assert(typeof MediaService.positionMs === "number",
            "MediaService should expose positionMs as a numeric property")
        root._assert(typeof MediaService.lengthMs === "number",
            "MediaService should expose lengthMs as a numeric property")
        root._assert(typeof MediaService.canGoPrevious === "boolean",
            "MediaService should expose canGoPrevious as a boolean property")
        root._assert(typeof MediaService.canTogglePlayback === "boolean",
            "MediaService should expose canTogglePlayback as a boolean property")
        root._assert(typeof MediaService.canGoNext === "boolean",
            "MediaService should expose canGoNext as a boolean property")
        root._assert(typeof MediaService.playPause === "function",
            "MediaService should expose playPause()")
        root._assert(typeof MediaService.previous === "function",
            "MediaService should expose previous()")
        root._assert(typeof MediaService.next === "function",
            "MediaService should expose next()")

        console.log("MediaService smoke test passed")
        Qt.callLater(Qt.quit)
    }
}