import Quickshell
import QtQuick
import qs.services
import "modules/bar/widget-settings" as Sections

// Smoke harness for MediaControlSection settings schema and render availability.
ShellRoot {
    id: root

    function _assert(condition, message) {
        if (!condition)
            throw new Error(message)
    }

    Sections.MediaControlSection {
        id: section
        visible: false
    }

    Component.onCompleted: {
        root._assert(typeof SettingsService.data.mediaControl.enabled === "boolean",
            "mediaControl.enabled should exist in settings schema")
        root._assert(typeof SettingsService.data.mediaControl.showWhenIdle === "boolean",
            "mediaControl.showWhenIdle should exist in settings schema")
        root._assert(typeof SettingsService.data.mediaControl.announcementEnabled === "boolean",
            "mediaControl.announcementEnabled should exist in settings schema")
        root._assert(typeof SettingsService.data.mediaControl.cavaEnabled === "boolean",
            "mediaControl.cavaEnabled should exist in settings schema")
        root._assert(typeof SettingsService.data.mediaControl.hoverRevealControls === "boolean",
            "mediaControl.hoverRevealControls should exist in settings schema")
        root._assert(section.implicitHeight > 0,
            "MediaControlSection should render a positive implicit height")

        console.log("MediaControlSettings smoke test passed")
        Qt.callLater(Qt.quit)
    }
}
