import QtQuick
import Quickshell
import "./modules/lazerbar" as LazerBar
import "./services" as Services

// Regression guard for the startup deferral of the never-shown chrome.
//
// The cost probes (tst_invisible_subtree_cost.qml, tst_bar_widget_load_cost.qml)
// measure what a subtree costs, not when it is built - they load the component
// files directly, so they cannot tell whether the shell built them at startup.
// This file covers the other half: that the shell does NOT build them until
// something asks for them.
//
// Both hosts used to construct their content behind `visible: false`, which does
// not gate construction in QML. Measured headlessly, per screen per start:
// BarPopupActions 238ms cold, LazerSettingsPanel 181ms cold / 154ms warm,
// BarPopupIdentity 100ms cold. The settings panel's warm cost means it is paid
// on every start, not just the first.
//
// The settings overlay is a plain Item, so it can be mounted headlessly and the
// gate observed directly. The popup host is a PanelWindow and cannot be loaded
// without a compositor, so it is covered by a source-level contract below - the
// same approach tst_startup_cold_paths.qml takes, and stated here as such rather
// than passed off as a behavioural check.
//
// Run from the repo root:
//   qs -p tst_startup_deferral.qml
Item {
    id: root
    width: 1280
    height: 720

    property int failures: 0
    property int checks: 0
    property bool finished: false

    function check(label, condition, detail) {
        root.checks++
        if (condition) {
            console.log("PASS:", label)
            return
        }
        root.failures++
        console.log("FAIL:", label, detail !== undefined ? "| " + detail : "")
    }

    function readText(path) {
        const xhr = new XMLHttpRequest()
        xhr.open("GET", Qt.resolvedUrl(path), false)
        xhr.send(null)
        return xhr.status === 200 ? xhr.responseText : ""
    }

    readonly property string overlaySource: root.readText("./modules/lazerbar/LazerSettingsOverlay.qml")
    readonly property string popupSource: root.readText("./modules/bar/BarPopupHost.qml")

    // The production overlay, mounted headlessly. `visible`/`enabled` follow
    // `phase`, which starts closed, so this is the same state the bar puts it in
    // on every shell start.
    LazerBar.LazerSettingsOverlay {
        id: overlay
        width: 1280
        height: 720
        // The host inputs are assigned in the same construction-time pattern
        // modules/bar/TopBar.qml uses. That is the point of this instance: the
        // panel does not exist while these run, so assigning them to `panel.*`
        // instead of to the overlay fails the whole config to load - which is
        // exactly the regression that shipped. Keep in step with TopBar's list.
        appearanceSettings: Services.SettingsService.appearance
        barSettings: Services.SettingsService.bar
        notificationSettings: Services.SettingsService.notifications
        saveCallback: Services.SettingsService.save
        appearanceDefaults: Services.SettingsService.appearanceDefaults
        barDefaults: Services.SettingsService.barDefaults
        notificationDefaults: Services.SettingsService.notificationDefaults
        settingsReset: Services.SettingsService.resetCategorySetting
        wallpaperService: Services.WallpaperService
        locationService: Services.LocationService
        effectiveSunrise: Services.SettingsService.effectiveSunrise
        effectiveSunset: Services.SettingsService.effectiveSunset
        coordsValid: Services.SettingsService.locationCoordsValid
        locationError: Services.LocationService.lastError
        locationDisplayName: Services.LocationService.displayName
    }

    function verifyClosedState() {
        root.check("overlay starts closed", overlay.phase === "closed",
                   "phase=" + overlay.phase)
        root.check("overlay does not block the desktop while closed",
                   overlay.blocksDesktop === false)
        // The whole point: the panel subtree must not exist yet. `panel` is the
        // handle TopBar.qml writes through, so it has to be defined - but it has
        // to be null, not a built panel.
        root.check("panel is not built before the first open",
                   overlay.panelLoaded === false && overlay.panel === null,
                   "panelLoaded=" + overlay.panelLoaded + " panel=" + overlay.panel)
        // Layer handles must resolve to a defined null rather than undefined: a
        // caller binding to a missing property throws, and an undefined Binding
        // target logs an error every re-evaluation.
        root.check("sidebarLayer is a defined null while unloaded",
                   overlay.sidebarLayer === null, "got " + overlay.sidebarLayer)
        root.check("contentLayer is a defined null while unloaded",
                   overlay.contentLayer === null, "got " + overlay.contentLayer)
        root.check("panelHost exists while unloaded", overlay.panelHost !== null)

        // A close or a reset arriving before the first open must be inert, not
        // fatal: both run on the QML thread and a null-property read throws.
        let threw = null
        try {
            overlay.closeAndRestoreFocus()
            overlay.resetImmediately()
        } catch (e) {
            threw = String(e)
        }
        root.check("close and reset before the first open do not throw",
                   threw === null, threw)
        root.check("overlay is still coherent after an early close",
                   overlay.phase === "closed" && overlay.panelLoaded === false,
                   "phase=" + overlay.phase + " loaded=" + overlay.panelLoaded)
        root.check("debugSnapshot survives an unloaded panel",
                   typeof overlay.debugSnapshot() === "object")

        Qt.callLater(root.verifyAfterOpen)
    }

    function verifyAfterOpen() {
        overlay.openFrom(null, true)
        // Synchronous by contract: the Loader declares asynchronous: false
        // precisely so callers may use `panel` in the same call stack.
        root.check("opening builds the panel synchronously",
                   overlay.panelLoaded === true,
                   "panelLoaded=" + overlay.panelLoaded)
        root.check("panel handle resolves once built", overlay.panel !== null)
        root.check("sidebarLayer resolves once built", overlay.sidebarLayer !== null)
        root.check("contentLayer resolves once built", overlay.contentLayer !== null)
        root.check("the open did not get stranded", overlay.phase === "opening",
                   "phase=" + overlay.phase)

        // Every host-facing input must have reached the panel. The host assigns
        // these at construction time, while the panel does not exist yet, so
        // this is the only place the hand-off can be proven end to end - and
        // getting it wrong is what broke the config load.
        const forwarded = ["appearanceSettings", "barSettings", "notificationSettings",
            "saveCallback", "appearanceDefaults", "barDefaults", "notificationDefaults",
            "settingsReset", "wallpaperService", "locationService", "effectiveSunrise",
            "effectiveSunset", "coordsValid", "locationError", "locationDisplayName"]
        const missing = []
        for (let i = 0; i < forwarded.length; i++) {
            const value = overlay.panel[forwarded[i]]
            if (value === undefined || value === null)
                missing.push(forwarded[i])
        }
        root.check("every host input reached the panel", missing.length === 0,
                   "null/undefined: " + missing.join(", "))
        root.check("a host override survives the hand-off",
                   overlay.panel.appearanceSettings === overlay.appearanceSettings
                   && overlay.panel.locationDisplayName === overlay.locationDisplayName,
                   "appearanceSettings/locationDisplayName did not round-trip")

        // The latch is one-way: a second open must not rebuild the panel, or the
        // saving would only move from the first start to the first reopen.
        const first = overlay.panel
        overlay.resetImmediately()
        overlay.openFrom(null, true)
        root.check("the panel instance is reused across sessions",
                   overlay.panel === first, "panel was rebuilt")

        Qt.callLater(root.verifySourceContracts)
    }

    function verifySourceContracts() {
        // The popup host cannot be mounted headlessly (PanelWindow), so its gate
        // is asserted against the source. Read, not reimplemented.
        root.check("popup bodies load through an inactive-by-default Loader",
                   root.popupSource.indexOf("_popupBodiesArmed") >= 0
                   && root.popupSource.indexOf("active: root._popupBodiesArmed") >= 0)
        root.check("the popup latch is armed from the intent path, not a clear path",
                   root.popupSource.indexOf("function updateIntent(") >= 0)
        root.check("the popup host still resolves its contentData alias",
                   root.popupSource.indexOf("readonly property alias contentData") >= 0)
        root.check("the settings overlay gates its panel on the armed latch",
                   root.overlaySource.indexOf("active: root._panelArmed") >= 0)
        root.check("the settings loader is synchronous so callers can use panel immediately",
                   root.overlaySource.indexOf("asynchronous: false") >= 0)
        root.finish()
    }

    function finish() {
        if (root.finished)
            return
        root.finished = true
        giveUp.stop()
        console.log("Totals: " + (root.failures === 0
            ? root.checks + " passed, 0 failed"
            : root.failures + " failed"))
        Qt.quit()
    }

    Timer {
        id: giveUp
        interval: 60000
        repeat: false
        onTriggered: {
            console.log("FAIL: deferral harness did not finish")
            root.failures++
            root.finish()
        }
    }

    Component.onCompleted: {
        giveUp.restart()
        Qt.callLater(root.verifyClosedState)
    }
}