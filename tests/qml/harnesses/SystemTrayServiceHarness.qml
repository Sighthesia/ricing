import Quickshell
import Quickshell.Services.SystemTray
import QtQuick
import "../../../services" as RepoServices

// Minimal service harness for system tray preflight and settings checks.
Item {
    id: root

    readonly property string _mode: Quickshell.env("HARNESS_MODE") || "preflight"
    property bool _settingsCheckDone: false

    function _fail(message) {
        console.log("FAIL:", message)
        Qt.quit()
    }

    function _pass(message) {
        console.log("PASS:", message)
        Qt.quit()
    }

    function _hasFunction(target, name) {
        try {
            return target && typeof target[name] === "function"
        } catch (_) {
            return false
        }
    }

    function _runPreflight() {
        if (SystemTray === undefined) {
            _fail("missing SystemTray singleton")
            return
        }

        if (SystemTray.items === undefined) {
            _fail("missing SystemTray.items")
            return
        }

        let details = ["singleton-ok"]
        if (SystemTray.items.count > 0) {
            const item = SystemTray.items.get(0)
            details.push("has-item")
            details.push("id=" + (item && item.id !== undefined))
            details.push("activate=" + _hasFunction(item, "activate"))
            details.push("display=" + _hasFunction(item, "display"))
            details.push("secondaryActivate=" + _hasFunction(item, "secondaryActivate"))
            details.push("scroll=" + _hasFunction(item, "scroll"))
        } else {
            details.push("no-live-item-runtime-check-deferred")
        }

        _pass(details.join(","))
    }

    function _runSettings() {
        if (root._settingsCheckDone)
            return

        root._settingsCheckDone = true

        const settingsData = RepoServices.SettingsService && RepoServices.SettingsService.data
            ? RepoServices.SettingsService.data
            : undefined
        const traySettings = settingsData ? settingsData.systemTray : undefined

        if (traySettings === undefined) {
            _fail("missing systemTray settings")
            return
        }

        if (typeof traySettings.enabled !== "boolean") {
            _fail("missing systemTray.enabled")
            return
        }

        if (typeof traySettings.hoverReveal !== "boolean") {
            _fail("missing systemTray.hoverReveal")
            return
        }

        if (typeof traySettings.flashEnabled !== "boolean") {
            _fail("missing systemTray.flashEnabled")
            return
        }

        if (traySettings.pinnedItems === undefined) {
            _fail("missing systemTray.pinnedItems")
            return
        }

        if (RepoServices.BarLayoutService.systemTrayFlashExtension === undefined) {
            _fail("missing BarLayoutService.systemTrayFlashExtension")
            return
        }

        _pass("settings-ok")
    }

    Component.onCompleted: {
        if (root._mode === "settings") {
            return
        }

        _runPreflight()
    }

    Connections {
        target: RepoServices.SettingsService

        function onSettingsLoaded() {
            if (root._mode === "settings")
                root._runSettings()
        }

        function onSettingsReloaded() {
            if (root._mode === "settings")
                root._runSettings()
        }
    }
}
