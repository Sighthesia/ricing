import QtQuick
import "LazerSettingsLogic.js" as Logic
import "../../services" as Services

// Own the fixed left settings surface; its sidebar and content layers move apart.
Item {
    id: root
    property string phase: "closed"
    readonly property bool interactive: phase === "opening" || phase === "open"
    readonly property bool blocksDesktop: phase !== "closed"
    property real progress: 0
    property Item opener: null
    readonly property real requiredWidth: Logic.sidePanelWidth(width)
    readonly property int panelEnterDuration: MotionTokens.settingsSlide
    readonly property int panelExitDuration: MotionTokens.settingsSlide
    // ---- Host-facing panel inputs ---------------------------------------
    //
    // Hosts configure THIS overlay, never the panel directly. The panel is
    // loaded on first use, so during construction - which is exactly when a
    // host's `panel.appearanceSettings: ...` assignments run - the handle is
    // null and writing to it fails the whole config to load with "Cannot assign
    // to non-existent property". Accepting the inputs here keeps that contract
    // working whether or not the panel happens to exist yet.
    //
    // The defaults are the live shell's own wiring, so a host that overrides
    // nothing still gets exactly what it got before the panel was gated.
    property var appearanceSettings: Services.SettingsService.appearance
    property var barSettings: Services.SettingsService.bar
    property var notificationSettings: Services.SettingsService.notifications
    property var saveCallback: Services.SettingsService.save
    property var appearanceDefaults: Services.SettingsService.appearanceDefaults
    property var barDefaults: Services.SettingsService.barDefaults
    property var notificationDefaults: Services.SettingsService.notificationDefaults
    property var settingsReset: Services.SettingsService.resetCategorySetting
    // Persisted panel chrome (rail collapse state). Passed as an object rather
    // than a boolean so the panel can write back through the same seam the
    // other categories use.
    property var uiSettings: Services.SettingsService.ui
    property var wallpaperService: Services.WallpaperService
    property var locationService: Services.LocationService
    property string effectiveSunrise: Services.SettingsService.effectiveSunrise
    property string effectiveSunset: Services.SettingsService.effectiveSunset
    property bool coordsValid: Services.SettingsService.locationCoordsValid
    property string locationError: Services.LocationService.lastError
    property string locationDisplayName: Services.LocationService.displayName
    // Lock-clock placement: whether the Python/OpenCV runtime behind it exists.
    property bool clockPlacementAvailable: Services.ClockPlacementService.available
    property string clockPlacementHint: Services.ClockPlacementService.hint
    // The panel handle. Read-only in practice: the panel is built on first use,
    // so this is null until then, and every internal use goes through
    // panelOrNull(). Writes are only valid after an open has armed the loader.
    property alias panel: panelLoader.item
    property alias panelHost: panelHost
    // An alias cannot be null-checked, so these resolve to null — never
    // undefined — while the panel is unloaded. A caller binding to a missing
    // property would throw; null is a defined value it can ignore.
    readonly property var sidebarLayer: panelLoader.item ? panelLoader.item.sidebar : null
    readonly property var contentLayer: panelLoader.item ? panelLoader.item.content : null
    readonly property bool panelLoaded: panelLoader.item !== null
    signal closed()
    signal closeRequested()
    property bool _restoreFocus: true
    property int _contentToken: 0
    property int readyToken: 0
    // One-way latch for the panel loader. Constructing LazerSettingsPanel costs
    // 181 ms cold and still 154 ms warm per screen (35 rows, each carrying an
    // Image and a MultiEffect), and `visible: false` does not gate construction
    // in QML — only `active` does. So the panel is not built until settings is
    // first opened, and is then kept for the rest of the session.
    property bool _panelArmed: false
    // Set when an open path ran before the panel existed; Loader.onLoaded
    // finishes it so the first-ever open still gets the whole choreography.
    property bool _openPending: false
    property bool debugHoverEnabled: false
    property int debugHoverToken: 0
    property string debugScreenName: "unknown"
    property string debugMaskOverride: "auto"
    property bool debugMaskActive: false
    property string _lastDebugSignature: ""

    visible: blocksDesktop
    enabled: blocksDesktop
    Keys.onEscapePressed: event => { root.requestClose(); event.accepted = true }

    // Single null-safe accessor for every internal panel touch: a close, a
    // reset, or a debug snapshot can arrive before the first open has armed
    // the loader, and a null-property read would throw.
    function panelOrNull() {
        return panelLoader.item || null
    }

    // Build the panel on demand. Loading is synchronous (see the Loader), so
    // callers may use `panel` in the same call stack that armed it.
    function armPanel() {
        if (_panelArmed)
            return
        _panelArmed = true
    }

    function openFrom(source, resetOpener) {
        opener = resetOpener === true ? (source || null) : (source || opener)
        armPanel()
        beginOpen()
    }

    // The open choreography, split out because the first open has to survive
    // arming the loader. If the panel is not resident yet the rest is handed
    // to Loader.onLoaded rather than silently skipped.
    function beginOpen() {
        if (!panelOrNull()) {
            _openPending = true
            return
        }
        _openPending = false
        panel.beginSession()
        panelMotion.stop()
        phase = "opening"
        // Kick off (or reuse) the wallpaper palette previews for the theme cards.
        Services.ColorService.previewSchemes()
        panelMotion.duration = MotionTokens.reducedMotion ? MotionTokens.fast : panelEnterDuration
        panelMotion.easing.type = Easing.OutQuint
        panelMotion.to = 1
        panelMotion.restart()
        scheduleContentReady()
    }
    function prepareDebugOpen() {
        opener = null
        _restoreFocus = false
        // The debug hosts write `panel.selectedCategory` in the statement right
        // after this call, so the panel has to exist by the time it returns.
        armPanel()
    }
    function closeAndRestoreFocus() { close(true) }
    function closeWithoutFocusRestore() { close(false) }
    function requestClose() { if (interactive) { closeRequested(); closeAndRestoreFocus() } }
    function close(restoreFocus) {
        if (phase === "closed" || phase === "closing") return
        _contentToken += 1
        var panelItem = panelOrNull()
        if (panelItem) panelItem.contentReady = false
        panelMotion.stop(); phase = "closing"; _restoreFocus = restoreFocus
        panelMotion.duration = MotionTokens.reducedMotion ? MotionTokens.fast : panelExitDuration
        panelMotion.easing.type = Easing.InQuad; panelMotion.to = 0; panelMotion.restart()
    }
    function resetImmediately() {
        _contentToken += 1
        panelMotion.stop(); phase = "closed"; progress = 0; opener = null; _restoreFocus = false
        var panelItem = panelOrNull()
        if (!panelItem) return
        panelItem.endSession()
        panelItem.contentReady = false
    }

    function _debugRect(item) {
        if (!item)
            return { "x": 0, "y": 0, "width": 0, "height": 0 }
        var pos = item.mapToItem(root, 0, 0)
        return {
            "x": Number(pos.x), "y": Number(pos.y),
            "width": Math.max(0, Number(item.width)),
            "height": Math.max(0, Number(item.height)),
        }
    }

    function debugSnapshot() {
        var panelItem = panelOrNull()
        return {
            "event": "snapshot",
            "screen": root.debugScreenName,
            "overlay": {
                "rect": root._debugRect(root), "phase": root.phase,
                "progress": Number(root.progress), "visible": root.visible,
                "enabled": root.enabled, "opacity": Number(root.opacity),
                "z": Number(root.z), "blocksDesktop": root.blocksDesktop,
                "requiredWidth": Number(root.requiredWidth),
                "panelLoaded": root.panelLoaded,
            },
            "panel": panelItem ? panelItem.debugSnapshot() : null,
            "mask": {
                "active": root.debugMaskActive,
                "overlayBlocksDesktop": root.blocksDesktop,
                "override": root.debugMaskOverride,
                "owner": "settingsOverlay",
            },
        }
    }

    function debugLog(eventName, payload) {
        if (!root.debugHoverEnabled)
            return
        var entry = Object.assign({ "event": eventName, "screen": root.debugScreenName }, payload || ({}))
        var signature = JSON.stringify(entry)
        if (signature === root._lastDebugSignature)
            return
        root._lastDebugSignature = signature
        console.log("[afloat:SettingsHoverDebug]", signature)
    }

    function emitDebugSnapshot() {
        root.debugLog("snapshot", root.debugSnapshot())
    }

    onDebugHoverEnabledChanged: {
        if (!debugHoverEnabled)
            _lastDebugSignature = ""
    }

    onDebugHoverTokenChanged: {
        if (debugHoverEnabled)
            emitDebugSnapshot()
    }

    // Poll only while diagnostics are enabled so hover and scroll transitions
    // are captured without installing another pointer or focus owner.
    Timer {
        interval: 120
        repeat: true
        running: root.debugHoverEnabled
        onTriggered: root.emitDebugSnapshot()
    }

    // Sample state changes without adding an input or visual layer.
    Connections {
        target: root
        function onPhaseChanged() { root.debugLog("overlay", { "phase": root.phase, "progress": Number(root.progress) }) }
        function onProgressChanged() { root.debugLog("overlay", { "phase": root.phase, "progress": Number(root.progress) }) }
    }

    // Defer content activation so the initial slide never competes for the first frames.
    function scheduleContentReady() {
        _contentToken += 1
        var panelItem = panelOrNull()
        if (panelItem) panelItem.contentReady = false
        readyToken = _contentToken
        readyTimer.restart()
    }

    // Keep the panel host at fixed owner size; the two layers translate inside it.
    Item {
        id: panelHost
        width: root.requiredWidth
        height: root.height

        // The construction gate for the panel subtree. `visible: false` on the
        // overlay does not stop QML from building it, so the 181 ms/154 ms
        // panel was paid on every shell start per screen; this is armed by the
        // first open and latched afterwards.
        Loader {
            id: panelLoader
            anchors.fill: parent
            active: root._panelArmed
            // Stay synchronous: the debug hosts read and write `panel` in the
            // same call stack as armPanel(), and the open continues in the same
            // turn. An asynchronous load would show an empty panel for a frame
            // and would push beginSession() onto a later one.
            asynchronous: false
            // A Loader is a focus scope, so key events from inside the panel
            // stop here instead of reaching the overlay root. Accept the event
            // so escape-to-close fires exactly once, from either end.
            Keys.onEscapePressed: event => { root.requestClose(); event.accepted = true }
            // A first-ever open may have arrived before the panel existed.
            onLoaded: if (root._openPending) root.beginOpen()

            sourceComponent: Component {
                LazerSettingsPanel {
                    anchors.fill: parent
                    availableWidth: root.width
                    availableHeight: root.height
                    sidePanel: true
                    interactive: root.interactive
                    progress: root.progress
                    // Everything the host configures reaches the panel through
                    // the overlay, so a host's construction-time assignments
                    // land here whether or not this component existed when they
                    // ran. Tests inject fakes the same way.
                    appearanceSettings: root.appearanceSettings
                    barSettings: root.barSettings
                    notificationSettings: root.notificationSettings
                    saveCallback: root.saveCallback
                    appearanceDefaults: root.appearanceDefaults
                    barDefaults: root.barDefaults
                    notificationDefaults: root.notificationDefaults
                    settingsReset: root.settingsReset
                    uiSettings: root.uiSettings
                    wallpaperService: root.wallpaperService
                    locationService: root.locationService
                    effectiveSunrise: root.effectiveSunrise
                    effectiveSunset: root.effectiveSunset
                    coordsValid: root.coordsValid
                    locationError: root.locationError
                    locationDisplayName: root.locationDisplayName
                    clockPlacementAvailable: root.clockPlacementAvailable
                    clockPlacementHint: root.clockPlacementHint
                    onCloseRequested: root.requestClose()
                }
            }
        }
    }

    Timer {
        id: readyTimer
        interval: MotionTokens.settingsContentDelay
        repeat: false
        onTriggered: {
            if (!root.interactive || root.readyToken !== root._contentToken)
                return
            var panelItem = root.panelOrNull()
            if (!panelItem)
                return
            panelItem.contentReady = true
            panelItem.focusSearch()
        }
    }

    NumberAnimation {
        id: panelMotion; target: root; property: "progress"
        onFinished: {
            if (root.phase === "opening" && root.progress >= 1) root.phase = "open"
            else if (root.phase === "closing" && root.progress <= 0) {
                root.phase = "closed"
                var panelItem = root.panelOrNull()
                if (panelItem) panelItem.endSession()
                if (root._restoreFocus && root.opener) root.opener.forceActiveFocus()
                root.closed()
            }
        }
    }
}
