import Quickshell
import QtQuick
import qs.modules.bar as BarParts
import qs.services

// Smoke harness for super system monitor availability in widget registries.
ShellRoot {
    id: root

    function _assert(condition, message) {
        if (!condition)
            throw new Error(message)
    }

    function _layoutWidgetCount(widgetId) {
        let count = 0

        for (let i = 0; i < BarLayoutService.layoutModel.count; i++) {
            if (BarLayoutService.layoutModel.get(i).id === widgetId)
                count += 1
        }

        return count
    }

    BarParts.BarContent {
        id: barContent
        width: 360
        height: 48
        visible: false
    }

    BarParts.WidgetPickerWindow {
        id: widgetPickerWindow
    }

    Component.onCompleted: {
        BarLayoutService.resetLayout()
        BarLayoutService.addWidget("superSystemMonitor", "right")

        root._assert(barContent.widgetRegistry.superSystemMonitor,
            "BarContent should register superSystemMonitor")
        root._assert(widgetPickerWindow.widgetRegistry.superSystemMonitor,
            "WidgetPickerWindow should register superSystemMonitor")
        root._assert(widgetPickerWindow.widgetNames.superSystemMonitor,
            "WidgetPickerWindow should expose a display name for superSystemMonitor")
        root._assert(root._layoutWidgetCount("superSystemMonitor") === 1,
            "BarLayoutService should insert exactly one superSystemMonitor into the layout model")

        console.log("SuperSystemMonitorAvailability smoke test passed")
        Qt.callLater(Qt.quit)
    }
}
