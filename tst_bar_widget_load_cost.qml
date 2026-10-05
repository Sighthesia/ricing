import QtQuick
import Quickshell
import "./modules/bar" as Bar
import "./modules/bar/ShippedWidgets.js" as ShippedWidgets
import "./services" as Services

// Startup cost probe for the bar's widget tree.
//
// Why this exists: the bar mounts while the wallpaper is still decoding, and its
// content fills in over three batches, one per 16ms tick. Whether that pacing
// buys anything is an empirical question. If a batch costs a fraction of a
// millisecond the timer is pure latency; if it costs 100ms the pacing is the
// thing keeping the bar smooth. Guessing either way wastes a cycle, so this
// measures it - offscreen, with the real widget files and the session's real
// persisted layout.
//
// Phase order matters, because the dominant cost is one-time QML type
// compilation, which the first phase pays and the rest do not:
//
//   A. the staged timeline the shell ships, cold. This is the number that
//      answers the question: how long from bar mount to a filled bar on a real
//      reload, and how big each batch's frame is.
//   B. the same tree with staging off (everything in one turn), warm. The gap to
//      A is what the pacing costs in latency and what it saves in spike.
//   C. per-widget attribution, warm. Relative ranking only - the types are
//      already compiled by then - which is what tells us what to defer.
//
// Nothing here asserts a timing budget; wall-clock thresholds would be flaky
// across machines. It asserts only structural facts (every registry widget
// constructs, staging stays one-way) and prints the numbers for a human.
//
// Offscreen-safe: the widgets are plain Items and no widget opens a layer-shell
// surface. Run from the repo root so ./modules resolves inside the config root:
//   qs -p tst_bar_widget_load_cost.qml
Item {
    id: root
    width: 1280
    height: 48

    property int failures: 0
    property int checks: 0
    property bool finished: false
    property string phase: "idle"

    function check(label, condition, detail) {
        root.checks++
        if (condition) {
            console.log("PASS:", label)
            return
        }
        root.failures++
        console.log("FAIL:", label, detail !== undefined ? "| " + detail : "")
    }

    function ms(value) {
        return Math.round(Number(value) * 100) / 100
    }

    // -----------------------------------------------------------------
    // Phase A - the staged timeline, cold.
    // -----------------------------------------------------------------
    property bool stagedReady: false
    property double stagedConstructAt: 0
    property double stagedWidgetsReadyAt: 0
    property double stagedFinishAt: 0
    property var batchTimes: []
    property real stagedTotal: 0
    property int stagedLatchedLimit: -1

    Loader {
        id: stagedLoader
        active: false
        sourceComponent: Component {
            Bar.BarContent {
                width: root.width
                height: root.height
                startupStaging: true
            }
        }
        onLoaded: {
            root.stagedConstructAt = Date.now()
            root.watchStaged(stagedLoader.item)
        }
    }

    function watchStaged(bar) {
        if (!bar)
            return
        bar.widgetsReadyChanged.connect(function() {
            if (bar.widgetsReady && root.stagedWidgetsReadyAt === 0)
                root.stagedWidgetsReadyAt = Date.now()
        })
        bar.startupBatchLimitChanged.connect(function() {
            root.batchTimes.push(Date.now())
        })
        bar.startupReadyChanged.connect(function() {
            if (!bar.startupReady || root.stagedReady)
                return
            root.stagedFinishAt = Date.now()
            root.stagedReady = true
        })
    }

    function startPhaseA() {
        root.phase = "A"
        stagedLoader.active = true
        stagedWait.restart()
    }

    function reportStaged() {
        var span = root.batchTimes.length > 1
            ? root.batchTimes[root.batchTimes.length - 1] - root.batchTimes[0] : 0
        var gaps = []
        for (var i = 1; i < root.batchTimes.length; i++)
            gaps.push(root.ms(root.batchTimes[i] - root.batchTimes[i - 1]))
        console.log("[cost] A staged COLD: construct -> widgetsReady "
            + root.ms(root.stagedWidgetsReadyAt - root.stagedConstructAt) + " ms")
        console.log("[cost] A staged COLD: widgetsReady -> startupReady "
            + root.ms(root.stagedFinishAt - root.stagedWidgetsReadyAt) + " ms")
        console.log("[cost] A staged COLD: bar mount -> filled bar "
            + root.ms(root.stagedFinishAt - root.stagedConstructAt) + " ms")
        console.log("[cost] A staged COLD: batch gaps " + JSON.stringify(gaps)
            + " ms (16ms of each is the timer floor)")
        root.stagedTotal = root.stagedFinishAt - root.stagedConstructAt
        root.check("staged path released every batch", root.batchTimes.length >= 3,
                   "batches=" + root.batchTimes.length)
        root.stagedLatchedLimit = stagedLoader.item ? stagedLoader.item.startupBatchLimit : -1
        if (stagedLoader.item)
            stagedLoader.item.startupStaging = false
        stagedWait.stop()
        // Let the staged tree drain its own deferred work before phase B, so B
        // does not measure A's tail.
        Qt.callLater(function() { Qt.callLater(root.startPhaseB) })
    }

    Timer {
        id: stagedWait
        interval: 30
        repeat: true
        running: false
        onTriggered: {
            if (!root.stagedReady)
                return
            stagedWait.stop()
            root.reportStaged()
        }
    }

    // -----------------------------------------------------------------
    // Phase B - the same tree in one turn, warm.
    // -----------------------------------------------------------------
    property bool oneShotReady: false
    property double oneShotStart: 0
    property double oneShotFinishAt: 0

    Loader {
        id: oneShotLoader
        active: false
        sourceComponent: Component {
            Bar.BarContent {
                width: root.width
                height: root.height
                startupStaging: false
            }
        }
        onLoaded: root.watchOneShot(oneShotLoader.item)
    }

    function watchOneShot(bar) {
        if (!bar)
            return
        bar.widgetsReadyChanged.connect(function() {
            if (bar.widgetsReady && root.oneShotStart === 0)
                root.oneShotStart = Date.now()
        })
        bar.startupReadyChanged.connect(function() {
            if (!bar.startupReady || root.oneShotReady)
                return
            root.oneShotFinishAt = Date.now()
            root.oneShotReady = true
        })
    }

    function startPhaseB() {
        root.phase = "B"
        // Tear phase A down first: two copies of every widget would measure each
        // other rather than the pacing.
        stagedLoader.active = false
        stagedLoader.sourceComponent = null
        oneShotLoader.active = true
        oneShotWait.restart()
    }

    Timer {
        id: oneShotWait
        interval: 30
        repeat: true
        running: false
        onTriggered: {
            if (!root.oneShotReady)
                return
            oneShotWait.stop()
            var total = root.oneShotFinishAt - root.oneShotStart
            console.log("[cost] B one-shot warm: widgetsReady -> startupReady "
                + root.ms(total) + " ms in a single turn")
            console.log("[cost] pacing adds " + root.ms(root.stagedTotal - total)
                + " ms of latency and splits a " + root.ms(total) + " ms frame")
            root.check("one-shot path reached readiness", total >= 0)
            root.check("staging stayed one-way when switched off",
                       root.stagedLatchedLimit === ShippedWidgets.startupBatchCount,
                       "latched=" + root.stagedLatchedLimit
                       + " expected=" + ShippedWidgets.startupBatchCount)
            stagedLoader.sourceComponent = null
            Qt.callLater(root.startPhaseC)
        }
    }

    // -----------------------------------------------------------------
    // Phase C - per-widget attribution, warm. Ranking only.
    // -----------------------------------------------------------------
    property var queue: []
    property var perWidget: []
    property int widgetIndex: 0
    property double probeStart: 0
    // Whether this pass is paying the one-time cost or reading a warm tree.
    property bool coldAttribution: false

    function collectEntries() {
        var entries = []
        var sections = ["left", "center", "right"]
        for (var s = 0; s < sections.length; s++) {
            var found = Services.BarLayoutService.sectionWidgets(sections[s]) || []
            for (var e = 0; e < found.length; e++) {
                if (!found[e] || !ShippedWidgets.ships(found[e].id))
                    continue
                entries.push({
                    id: found[e].id,
                    instanceKey: found[e].instanceKey || "",
                    section: sections[s],
                    source: found[e].source
                })
            }
        }
        return entries
    }

    function startPhaseC() {
        root.phase = "C"
        oneShotLoader.active = false
        oneShotLoader.sourceComponent = null
        root.queue = root.collectEntries()
        root.coldAttribution = root.attributeFirst
        console.log("[cost] layout resolved: " + root.queue.length + " widget entries")
        if (root.queue.length === 0) {
            root.check("layout resolved at least one widget", false, "empty layout")
            root.finish()
            return
        }
        root.probeNextWidget()
    }

    function probeNextWidget() {
        if (root.widgetIndex >= root.queue.length) {
            console.log("[cost] C per-widget construction, "
                + (root.coldAttribution ? "COLD" : "warm") + " (ms):")
            var sorted = root.perWidget.slice().sort(function(a, b) { return b.ms - a.ms })
            var sum = 0
            for (var i = 0; i < sorted.length; i++) {
                sum += sorted[i].ms
                console.log("[cost]   " + sorted[i].id + " batch " + sorted[i].batch
                    + " " + root.ms(sorted[i].ms))
            }
            console.log("[cost] C sum: " + root.ms(sum) + " ms")
            root.check("every registry widget constructed",
                       root.perWidget.length === root.queue.length,
                       root.perWidget.length + "/" + root.queue.length)
            // No teardown here on purpose. Tearing the last real widget down
            // runs its destruction handlers, and several of them assign to
            // properties that no longer resolve - which throws inside this
            // function and strands the run before finish() is reached. The
            // process is about to quit, so there is nothing to clean up.
            //
            // Cold attribution runs first when asked, and the staged run still
            // has to follow it, so this hands over instead of finishing.
            if (root.attributeFirst)
                Qt.callLater(root.startPhaseA)
            else
                root.finish()
            return
        }
        var entry = root.queue[root.widgetIndex]
        root.probeNextEntry = entry
        // The clock is taken before the source, because a Loader can finish
        // synchronously inside the assignment and would otherwise measure
        // against the previous entry's timestamp.
        root.probeStart = Date.now()
        probeLoader.widgetId_ = entry.id
        probeLoader.instanceKey_ = entry.instanceKey
        probeLoader.section_ = entry.section
        probeLoader.batch_ = ShippedWidgets.startupBatch(entry.id)
        probeLoader.source = Qt.resolvedUrl("modules/bar/" + entry.source)
    }

    property var probeNextEntry: null

    Loader {
        id: probeLoader
        property string widgetId_: ""
        property string instanceKey_: ""
        property string section_: ""
        property int batch_: -1
        // Parked off-screen and never shown: the probe measures construction,
        // not painting.
        x: -100000
        source: ""
        onLoaded: {
            var cost = Date.now() - root.probeStart
            if (item) {
                item.widgetId = widgetId_
                item.instanceKey = instanceKey_
                item.section = section_
                item.screenName = "eDP-1"
            }
            root.perWidget.push({ id: widgetId_, ms: cost, batch: batch_ })
            root.widgetIndex++
            // One turn between widgets so a widget's own deferred timers never
            // land inside the next widget's construction window.
            Qt.callLater(root.probeNextWidget)
        }
    }

    function finish() {
        if (root.finished)
            return
        root.finished = true
        stagedWait.stop()
        oneShotWait.stop()
        settingsWait.stop()
        giveUp.stop()
        console.log("Totals: " + (root.failures === 0
            ? root.checks + " passed, 0 failed"
            : root.failures + " failed"))
        Qt.quit()
    }

    Timer {
        id: giveUp
        interval: 90000
        repeat: false
        onTriggered: {
            console.log("FAIL: probe did not finish | phase=" + root.phase
                + " stagedReady=" + root.stagedReady
                + " oneShotReady=" + root.oneShotReady
                + " widgets=" + root.perWidget.length)
            root.failures++
            root.finish()
        }
    }

    Timer {
        id: settingsWait
        interval: 30
        repeat: true
        running: false
        onTriggered: {
            if (!Services.SettingsService.settingsReady)
                return
            settingsWait.stop()
            Qt.callLater(root.firstPhase)
        }
    }

    // Which phase pays the one-time cost. The default runs the staged timeline
    // first, because that is the number the question is about. Setting
    // AFLOAT_COST_FIRST=widgets runs per-widget attribution first instead, so a
    // second invocation attributes the *cold* cost (QML compilation plus each
    // widget's own service cold-start) to individual files instead of only
    // showing the warm total.
    readonly property bool attributeFirst:
        String(Quickshell.env("AFLOAT_COST_FIRST") || "") === "widgets"

    // Warm the service singletons before the staged run, to separate the two
    // one-time costs. A widget's construction cost is Qt compiling its type plus
    // whatever the services its bindings reference do on first instantiation -
    // and several of those fork a process. Touching the services first and
    // re-running the staged fill attributes the difference: what disappears is
    // service construction and process spawn, what remains is QML compile plus
    // per-instance construction.
    readonly property bool warmServicesFirst:
        String(Quickshell.env("AFLOAT_COST_FIRST") || "") === "services"

    // Every service the production bar constructs at startup: the ones the
    // shipped widgets bind to, plus the ones the bar injects into its wave
    // surface for the control-center route. The second group is here because the
    // owner edge binds them at bar construction whether or not the route is ever
    // opened - WeatherService most of all, since a cached read plus a first-refresh
    // timer is real work the probe would otherwise charge to the bar fill.
    //
    // Named rather than held as objects, so the coverage check below can compare
    // this list against the bindings in modules/bar/TopBar.qml instead of against
    // a copy of itself. Media is the expensive one: MediaControlService pulls in
    // the netease python3 bridge, MediaService reads a JSON cache with
    // blockLoading, and Media's own completion registers with SpectrumService,
    // which starts cava and the beat tracker.
    readonly property var startupServiceNames: [
        "NiriService", "SettingsService", "LauncherService",
        "ClipboardService", "WindowHintService", "MediaService",
        "MediaControlService", "NeteaseWebLyricsService",
        "NetworkService", "VolumeService", "BrightnessService",
        "BatteryService", "BluetoothService", "WeatherService",
        "NotificationService", "BarLayoutService",
    ]

    // Name to singleton, spelled out. A lookup through the module namespace by
    // string must NOT be used here: it answers an object for a name that does not
    // exist, so a typo would count as covered and the probe would report a warm
    // number for a service it never warmed. `default: null` is what keeps a typo
    // visible: warmAllServices stops counting it, and the warm run asserts the
    // count.
    function serviceFor(name) {
        switch (name) {
        case "NiriService": return Services.NiriService
        case "SettingsService": return Services.SettingsService
        case "LauncherService": return Services.LauncherService
        case "ClipboardService": return Services.ClipboardService
        case "WindowHintService": return Services.WindowHintService
        case "MediaService": return Services.MediaService
        case "MediaControlService": return Services.MediaControlService
        case "NeteaseWebLyricsService": return Services.NeteaseWebLyricsService
        case "NetworkService": return Services.NetworkService
        case "VolumeService": return Services.VolumeService
        case "BrightnessService": return Services.BrightnessService
        case "BatteryService": return Services.BatteryService
        case "BluetoothService": return Services.BluetoothService
        case "WeatherService": return Services.WeatherService
        case "NotificationService": return Services.NotificationService
        case "BarLayoutService": return Services.BarLayoutService
        default: return null
        }
    }

    // Returns how many of the names above resolved to a singleton, so a typo shows
    // up as a run that did not warm what it claims to have warmed. A null from
    // serviceFor is otherwise silent in two places at once: the coverage check
    // only compares strings, and the warm numbers would just be that much
    // warmer.
    function warmAllServices() {
        // Reading a property is what forces a lazy singleton to instantiate, so this is
        // the only place in the probe that touches one - except for the coverage
        // check, which must stay name-only or it would pay the cost being measured.
        let resolved = 0
        for (let i = 0; i < root.startupServiceNames.length; i++) {
            if (root.serviceFor(root.startupServiceNames[i]))
                resolved++
        }
        // MediaControlService.hasMedia is the binding Media.qml itself reads, and
        // it is what constructs the lyrics bridge chain.
        let bridgeWarm = 0
        if (Services.MediaControlService)
            bridgeWarm = Number(Services.MediaControlService.hasMedia === true ? 1 : 0)
        return { resolved: resolved, bridgeWarm: bridgeWarm }
    }

    // The services the production bar injects into its wave surface, read from the
    // bar's own source rather than retyped here: a hand-typed copy of that list
    // would only prove the copy agrees with itself, and the list is exactly the
    // thing that drifts when a new service is bound at the owner edge.
    function injectedWaveServiceNames(source) {
        const start = source.indexOf("LauncherSurface {")
        if (start < 0)
            return []
        const next = source.indexOf("PanelWindow {", start)
        const block = source.slice(start, next < 0 ? start + 4000 : next)
        const found = []
        const pattern = /([A-Za-z]+Service):[ \t]*Services\.([A-Za-z]+)/g
        let match = pattern.exec(block)
        while (match !== null) {
            found.push(match[2])
            match = pattern.exec(block)
        }
        return found
    }

    // Coverage, asserted before anything is warmed: a service injected at the
    // owner edge and missing from the list above would silently move its cold
    // cost into the bar fill this probe exists to attribute.
    function checkWarmCoverage() {
        const source = root.readText("./modules/bar/TopBar.qml")
        root.check("the production bar source is readable", source !== "")
        const injected = root.injectedWaveServiceNames(source)
        root.check("the production bar injects services into its wave surface",
                   injected.length > 0, "found " + injected.length)
        // Compared by name, never by resolving: reading a singleton is what
        // instantiates it, and only the warm run is allowed to pay that before it
        // starts measuring. That each name is real is proved there instead, by the
        // resolved count.
        const missing = injected.filter(function(name) {
            return root.startupServiceNames.indexOf(name) < 0
        })
        root.check("every service the bar injects into the wave surface is warmed",
                   missing.length === 0, "not warmed: " + missing.join(", "))
    }

    function readText(path) {
        const xhr = new XMLHttpRequest()
        xhr.open("GET", Qt.resolvedUrl(path), false)
        xhr.send(null)
        return xhr.status === 200 ? xhr.responseText : ""
    }

    function firstPhase() {
        if (root.attributeFirst)
            root.startPhaseC()
        else if (root.warmServicesFirst)
            warmThenStaged()
        else
            root.startPhaseA()
    }

    function warmThenStaged() {
        root.phase = "warm-services"
        const started = Date.now()
        const warmed = root.warmAllServices()
        console.log("[cost] warmed " + warmed.resolved + " services before the staged run")
        // Every name has to have resolved, or the warm run is not warm: a name
        // `serviceFor` does not know returns null and is silently not counted,
        // which hands this run back the very cold cost it exists to separate out.
        root.check("every named warm-up service resolved to a singleton",
                   warmed.resolved === root.startupServiceNames.length,
                   "resolved " + warmed.resolved + " of " + root.startupServiceNames.length)
        // One turn, so the spawns the services just started are forked and the
        // staged fill is not measured against their fork cost.
        Qt.callLater(function() {
            console.log("[cost] lyrics bridge constructed: " + (warmed.bridgeWarm ? "yes" : "no"))
        console.log("[cost] service warm took " + root.ms(Date.now() - started) + " ms")
            Qt.callLater(root.startPhaseA)
        })
    }

    Component.onCompleted: {
        giveUp.restart()
        // Before anything is measured or warmed: is the list complete?
        checkWarmCoverage()
        // Settings decide the layout, so the probe waits for the real load
        // rather than measuring an empty tree.
        if (Services.SettingsService.settingsReady)
            Qt.callLater(root.firstPhase)
        else
            settingsWait.restart()
    }
}