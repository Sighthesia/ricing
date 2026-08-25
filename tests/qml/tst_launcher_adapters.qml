import QtQuick
import QtTest
import "../../services/launcher/LauncherAdapters.js" as LauncherAdapters

// Exercise the production launcher adapter factory exactly as wired by
// LauncherService: adapter installation shape, application / clipboard /
// shortcut listing and execution against fixture backends, explicit errors
// for unavailable sources, command building for niri actions, and the full
// production LauncherSession driven through these adapters (including the
// interactive-state execution gate). A final structural assertion pins the
// singleton wiring itself; it skips when local XHR reads are disabled.
Item {
    id: root

    // Production session under test, loaded by file path so the suite stays
    // independent of the Quickshell-only services directory module.
    Loader {
        id: sessionLoader
        source: "../../services/launcher/LauncherSession.qml"
    }

    // Fixture clipboard backend mirroring ClipboardService's public surface:
    // availability, item snapshots, revision counter, list request, and a
    // real connectable completion signal.
    QtObject {
        id: clipBackend
        property bool available: true
        property var items: []
        property int revision: 1
        property bool listRequested: false
        property var copies: []
        signal listCompleted()

        function list() { listRequested = true }

        function copyItem(id) { copies.push(id) }

        function complete(nextItems) {
            items = nextItems
            revision++
            listCompleted()
        }

        function reset() {
            available = true
            items = []
            revision = 0
            listRequested = false
            copies = []
        }
    }

    // Backend that starts unavailable mid-probe and flips available later,
    // mirroring ClipboardService's boot sequence (availableChanged +
    // probeFinished contract).
    Component {
        id: probeBackendComponent
        QtObject {
            property bool available: false
            property bool probeFinished: false
            property var items: [{ id: "7", preview: "later", mime: "text/plain", isImage: false, firstSeenMs: 1 }]
            property int revision: 1
            function list() {}
            function becomeAvailable() { available = true }
        }
    }

    // Fixture shortcut backend mirroring NiriShortcutService's public
    // surface: load state, surfaced error text, binds model, reload signal.
    QtObject {
        id: keyBackend
        property bool isLoaded: false
        property string errorText: ""
        property var shortcutsModel: null
        signal shortcutsReloaded()

        function publish(rows) {
            shortcutsModel = { count: rows.length, get: function(index) { return rows[index] } }
            isLoaded = true
            shortcutsReloaded()
        }

        function fail(message) {
            errorText = message
            isLoaded = true
        }

        function reset() {
            isLoaded = false
            errorText = ""
            shortcutsModel = null
        }
    }

    TestCase {
        name: "LauncherAdapters"

        // --- fixture helpers ---

        function makeAppEntry(id, name, comment, options) {
            var entry = {
                id: id,
                name: name,
                comment: comment || "",
                icon: options && options.icon ? options.icon : "",
                noDisplay: !!(options && options.noDisplay),
                execCalls: 0
            }
            entry.execute = function() { entry.execCalls++ }
            return entry
        }

        function makeLaunchCounts(initial) {
            var counts = { map: initial || {}, recorded: [] }
            counts.getLaunchCount = function(id) { return this.map[id] || 0 }
            counts.recordLaunch = function(id) { this.recorded.push(id) }
            return counts
        }

        // Mirrors DesktopEntries.applications.values: an indexable QML list
        // object rather than a JavaScript array.
        function makeAppsSource(entries) {
            var values = { length: entries.length }
            for (var index = 0; index < entries.length; index++)
                values[index] = entries[index]
            return { values: values }
        }

        function makeRunner(outcome) {
            var runner = { calls: [], outcome: outcome }
            runner.run = function(argv, done) {
                runner.calls.push(argv)
                done(outcome)
            }
            return runner
        }

        function makeManualAdapter() {
            var adapter = {
                queries: [],
                executions: [],
                pendingRefreshes: [],
                pendingExecutions: []
            }
            adapter.refresh = function(query, mode, done) {
                adapter.queries.push({ query: query, mode: mode })
                adapter.pendingRefreshes.push(done)
            }
            adapter.execute = function(item, done) {
                adapter.executions.push(item)
                adapter.pendingExecutions.push(done)
            }
            return adapter
        }

        function readSourceFile(relativePath) {
            try {
                var xhr = new XMLHttpRequest()
                xhr.open("GET", Qt.resolvedUrl(relativePath), false)
                xhr.send(null)
                if (xhr.status !== 0 && xhr.status !== 200)
                    return null
                return String(xhr.responseText || "")
            } catch (e) {
                return null
            }
        }

        function svc() {
            return sessionLoader.item
        }

        function resetSession() {
            var s = svc()
            s._refreshToken++
            s.visible = false
            s.query = ""
            s.results = []
            s.loading = false
            s.error = ""
            s.selectedIndex = -1
            s._pooledMode = ""
            s.displayPool = []
            s._adapters = ({})
        }

        function init() {
            verify(sessionLoader.status === Loader.Ready,
                   "LauncherSession failed to load: " + sessionLoader.source)
            clipBackend.reset()
            keyBackend.reset()
            clipBackend.revision = 1
            resetSession()
        }

        // --- installation shape ---

        function test_factoryInstallsAllThreeModes() {
            var adapters = LauncherAdapters.createAdapters({})

            verify(adapters.apps && typeof adapters.apps.refresh === "function"
                   && typeof adapters.apps.execute === "function")
            verify(adapters.clipboard && typeof adapters.clipboard.refresh === "function"
                   && typeof adapters.clipboard.execute === "function")
            verify(adapters.shortcuts && typeof adapters.shortcuts.refresh === "function"
                   && typeof adapters.shortcuts.execute === "function")
        }

        // --- applications ---

        function test_appsAdapterListsApplicationsForEmptyQuery() {
            var counts = makeLaunchCounts({ alpha: 3 })
            var adapters = LauncherAdapters.createAdapters({
                appsSource: makeAppsSource([
                    makeAppEntry("alpha", "Alpha Editor", "writes text", { icon: "alpha-icon" }),
                    makeAppEntry("hidden", "Hidden App", "", { noDisplay: true })
                ]),
                launchCounts: counts,
                iconResolver: function(name) { return name ? "theme:" + name : "" }
            })

            var outcome = "pending"
            adapters.apps.refresh("", "apps", function(result) { outcome = result })

            verify(Array.isArray(outcome))
            compare(outcome.length, 1)
            compare(outcome[0].id, "alpha")
            compare(outcome[0].displayName, "Alpha Editor")
            compare(outcome[0].description, "writes text")
            compare(outcome[0].icon, "theme:alpha-icon")
            compare(outcome[0].favoriteWeight, 3)
        }

        function test_appsAdapterFiltersQueriesAcrossNameCommentAndId() {
            var adapters = LauncherAdapters.createAdapters({
                appsSource: makeAppsSource([
                    makeAppEntry("firefox", "Firefox", "web browser"),
                    makeAppEntry("editor", "Emacs", "text editing"),
                    makeAppEntry("web-thing", "Chromium", "")
                ])
            })

            var byName = null
            adapters.apps.refresh("fire", "apps", function(result) { byName = result })
            compare(byName.length, 1)
            compare(byName[0].id, "firefox")

            var byComment = null
            adapters.apps.refresh("editing", "apps", function(result) { byComment = result })
            compare(byComment.length, 1)
            compare(byComment[0].id, "editor")

            var byId = null
            adapters.apps.refresh("web-", "apps", function(result) { byId = result })
            compare(byId.length, 1)
            compare(byId[0].id, "web-thing")
        }

        function test_appsAdapterSurfacesUnavailableSource() {
            var adapters = LauncherAdapters.createAdapters({})

            var refreshOutcome = null
            adapters.apps.refresh("", "apps", function(result) { refreshOutcome = result })
            verify(refreshOutcome && refreshOutcome.error === "application source unavailable")

            var executeOutcome = null
            adapters.apps.execute({ id: "x" }, function(result) { executeOutcome = result })
            verify(executeOutcome && executeOutcome.ok === false)
            verify(String(executeOutcome.error).length > 0)
        }

        function test_appsAdapterExecuteLaunchesEntryAndRecordsUse() {
            var counts = makeLaunchCounts({})
            var alpha = makeAppEntry("alpha", "Alpha", "")
            var adapters = LauncherAdapters.createAdapters({
                appsSource: makeAppsSource([alpha]),
                launchCounts: counts
            })

            var outcome = null
            adapters.apps.execute({ id: "alpha", displayName: "Alpha" }, function(result) { outcome = result })
            compare(alpha.execCalls, 1)
            compare(counts.recorded.length, 1)
            compare(counts.recorded[0], "alpha")
            verify(outcome && outcome.ok === true)

            var missing = null
            adapters.apps.execute({ id: "ghost" }, function(result) { missing = result })
            verify(missing && missing.ok === false)
            verify(String(missing.error).indexOf("ghost") >= 0)
        }

        function test_appsAdapterExecuteReportsFailedLaunch() {
            // entry.execute() returning false (launch refused) must surface
            // as a failed outcome, not a silent ok that closes the panel.
            var refusing = makeAppEntry("refuser", "Refuser", "")
            refusing.execute = function() { return false }
            var adapters = LauncherAdapters.createAdapters({
                appsSource: makeAppsSource([refusing]),
                launchCounts: makeLaunchCounts({})
            })

            var outcome = null
            adapters.apps.execute({ id: "refuser", displayName: "Refuser" }, function(result) { outcome = result })
            verify(outcome && outcome.ok === false)
            verify(String(outcome.error).length > 0)
        }

        function test_appsAdapterExecuteSurvivesThrowingEntry() {
            // A desktop entry whose execute() throws must still complete the
            // callback or the activated row strands hidden mid-fling.
            var bomb = makeAppEntry("bomb", "Bomb", "")
            bomb.execute = function() { throw new Error("broken Exec") }
            var counts = makeLaunchCounts({})
            var adapters = LauncherAdapters.createAdapters({
                appsSource: makeAppsSource([bomb]),
                launchCounts: counts
            })

            var outcome = null
            adapters.apps.execute({ id: "bomb", displayName: "Bomb" }, function(result) { outcome = result })
            verify(outcome && outcome.ok === false)
            verify(String(outcome.error).length > 0)
            compare(counts.recorded.length, 0)
        }

        // --- built-in shell commands ---

        function test_appsAdapterSurfacesBuiltinCommands() {
            var adapters = LauncherAdapters.createAdapters({
                appsSource: makeAppsSource([makeAppEntry("alpha", "Alpha", "")]),
                commands: LauncherAdapters.builtinCommands()
            })

            var outcome = "pending"
            adapters.apps.refresh("", "apps", function(result) { outcome = result })

            compare(outcome.length, 2)
            var lock = outcome[1]
            compare(lock.id, "builtin-lock")
            compare(lock.kind, "command")
            compare(lock.displayName, "锁定屏幕")
            compare(lock.actionId, "shell.lock.activate")
            verify(lock.managedByShell === true)
        }

        function test_appsAdapterFiltersCommandsByQuery() {
            var adapters = LauncherAdapters.createAdapters({
                appsSource: makeAppsSource([]),
                commands: LauncherAdapters.builtinCommands()
            })

            var hit = "pending"
            adapters.apps.refresh("锁屏", "apps", function(result) { hit = result })
            compare(hit.length, 1)
            compare(hit[0].id, "builtin-lock")

            var english = "pending"
            adapters.apps.refresh("lock", "apps", function(result) { english = result })
            compare(english.length, 1)

            var miss = "pending"
            adapters.apps.refresh("firefox", "apps", function(result) { miss = result })
            compare(miss.length, 0)
        }

        function test_appsAdapterExecutesCommandsThroughIpcHelper() {
            var ran = []
            var adapters = LauncherAdapters.createAdapters({
                appsSource: makeAppsSource([]),
                commands: LauncherAdapters.builtinCommands(),
                ipcHelperPath: "/opt/afloat-ipc",
                actionRunner: function(argv, done) { ran.push(argv); done({ ok: true }) }
            })

            var outcome = null
            adapters.apps.execute({
                id: "builtin-lock",
                kind: "command",
                actionId: "shell.lock.activate",
                managedByShell: true
            }, function(result) { outcome = result })

            verify(outcome && outcome.ok === true)
            compare(ran.length, 1)
            compare(ran[0].join(" "), "/opt/afloat-ipc lock activate")
        }

        function test_appsAdapterCommandWithoutRunnerErrors() {
            var adapters = LauncherAdapters.createAdapters({
                appsSource: makeAppsSource([]),
                commands: LauncherAdapters.builtinCommands()
            })

            var outcome = null
            adapters.apps.execute({
                id: "builtin-lock",
                kind: "command",
                actionId: "shell.lock.activate",
                managedByShell: true
            }, function(result) { outcome = result })

            verify(outcome && outcome.ok === false)
            verify(String(outcome.error).length > 0)
        }

        // --- clipboard ---

        function test_clipboardAdapterMapsEntriesWithWriteBackExecution() {
            clipBackend.items = [
                { id: "42", preview: "hello token", mime: "text/plain", isImage: false, firstSeenMs: 1700000100000 },
                { id: "43", preview: "[image] png binary data", mime: "image/png", isImage: true, firstSeenMs: 1700000200000 }
            ]
            var adapters = LauncherAdapters.createAdapters({ clipboardBackend: clipBackend })

            var outcome = "pending"
            adapters.clipboard.refresh("token", "clipboard", function(result) { outcome = result })

            verify(Array.isArray(outcome))
            compare(outcome.length, 1)
            compare(outcome[0].id, "42")
            compare(outcome[0].displayName, "hello token")
            verify(outcome[0].description.indexOf("copied") >= 0)

            var executed = null
            adapters.clipboard.execute({ id: "42" }, function(result) { executed = result })
            compare(clipBackend.copies.length, 1)
            compare(clipBackend.copies[0], "42")
            verify(executed && executed.ok === true)
        }

        function test_clipboardAdapterWaitsForProbeBeforeErroring() {
            clipBackend.reset()
            clipBackend.available = false
            var probingBackend = probeBackendComponent.createObject(clipBackend)
            var adapters = LauncherAdapters.createAdapters({ clipboardBackend: probingBackend })

            var outcome = "pending"
            adapters.clipboard.refresh("", "clipboard", function(result) { outcome = result })
            compare(outcome, "pending")

            probingBackend.becomeAvailable()
            verify(Array.isArray(outcome))
            compare(outcome.length, 1)
            compare(outcome[0].id, "7")
            probingBackend.destroy()
        }

        function test_clipboardAdapterErrorsOnceProbeFinishedUnavailable() {
            var deadBackend = probeBackendComponent.createObject(clipBackend)
            deadBackend.probeFinished = true
            var adapters = LauncherAdapters.createAdapters({ clipboardBackend: deadBackend })

            var outcome = "pending"
            adapters.clipboard.refresh("", "clipboard", function(result) { outcome = result })
            verify(outcome && outcome.error === "clipboard history unavailable")
            deadBackend.destroy()
        }

        function test_clipboardAdapterWaitsForFirstHistoryFetch() {
            clipBackend.revision = 0
            var adapters = LauncherAdapters.createAdapters({ clipboardBackend: clipBackend })

            var calls = []
            adapters.clipboard.refresh("", "clipboard", function(result) { calls.push(result) })

            verify(clipBackend.listRequested)
            compare(calls.length, 0)

            clipBackend.complete([{ id: "7", preview: "first clip", firstSeenMs: 5 }])

            compare(calls.length, 1)
            verify(Array.isArray(calls[0]))
            compare(calls[0].length, 1)
            compare(calls[0][0].id, "7")

            // Once history is loaded later refreshes answer synchronously.
            var second = null
            adapters.clipboard.refresh("first", "clipboard", function(result) { second = result })
            compare(second.length, 1)
        }

        function test_clipboardAdapterSurfacesUnavailableSource() {
            clipBackend.available = false
            var adapters = LauncherAdapters.createAdapters({ clipboardBackend: clipBackend })

            var refreshOutcome = null
            adapters.clipboard.refresh("", "clipboard", function(result) { refreshOutcome = result })
            verify(refreshOutcome && refreshOutcome.error === "clipboard history unavailable")

            var executeOutcome = null
            adapters.clipboard.execute({ id: "42" }, function(result) { executeOutcome = result })
            verify(executeOutcome && executeOutcome.ok === false)

            var missingBackend = LauncherAdapters.createAdapters({})
            var noService = null
            missingBackend.clipboard.refresh("", "clipboard", function(result) { noService = result })
            verify(noService && noService.error === "clipboard service unavailable")
        }

        // --- shortcuts ---

        function makeShortcutRow(entryId, label, sequence, detail, actionId, managedByShell) {
            return {
                entryId: entryId,
                label: label,
                sequence: sequence,
                detail: detail,
                actionId: actionId || "",
                category: "",
                managedByShell: !!managedByShell
            }
        }

        function keyAdapters(runner) {
            return LauncherAdapters.createAdapters({
                shortcutsBackend: keyBackend,
                actionRunner: runner ? runner.run : null,
                ipcHelperPath: "/usr/bin/afloat-ipc"
            })
        }

        function test_shortcutsAdapterWaitsForLoadThenListsBinds() {
            var runner = makeRunner({ ok: true })
            var adapters = keyAdapters(runner)

            var calls = []
            adapters.shortcuts.refresh("", "shortcuts", function(result) { calls.push(result) })
            compare(calls.length, 0)

            keyBackend.publish([
                makeShortcutRow("s1", "Open terminal", "Super+Return", 'spawn "foot"', ""),
                makeShortcutRow("s2", "Launcher: afloat", "Super+Shift+Space",
                                'spawn "sh" "/x/afloat-ipc" "launcher" "toggle"',
                                "shell.launcher.toggle", true)
            ])

            compare(calls.length, 1)
            verify(Array.isArray(calls[0]))
            compare(calls[0].length, 2)
            compare(calls[0][0].id, "s1")
            compare(calls[0][0].displayName, "Open terminal")
            compare(calls[0][0].keySequence, "Super+Return")
            compare(calls[0][1].managedByShell, true)
        }

        function test_shortcutsAdapterFiltersByLabelSequenceAndDetail() {
            keyBackend.publish([
                makeShortcutRow("s1", "Open terminal", "Super+Return", 'spawn "foot"'),
                makeShortcutRow("s2", "Close window", "Super+Q", "close-window"),
                makeShortcutRow("s3", "Screenshot", "Print", "screenshot")
            ])
            var adapters = keyAdapters(null)

            var byLabel = null
            adapters.shortcuts.refresh("term", "shortcuts", function(result) { byLabel = result })
            compare(byLabel.length, 1)
            compare(byLabel[0].id, "s1")

            var bySequence = null
            adapters.shortcuts.refresh("super+q", "shortcuts", function(result) { bySequence = result })
            compare(bySequence.length, 1)
            compare(bySequence[0].id, "s2")

            var byDetail = null
            adapters.shortcuts.refresh("screen", "shortcuts", function(result) { byDetail = result })
            compare(byDetail.length, 1)
            compare(byDetail[0].id, "s3")
        }

        function test_shortcutsAdapterSurfacesBindFileErrors() {
            keyBackend.fail("未找到 ~/.config/niri/binds.kdl，当前无法接管 niri 快捷键。")
            var adapters = keyAdapters(null)

            var outcome = null
            adapters.shortcuts.refresh("", "shortcuts", function(result) { outcome = result })

            verify(outcome && !Array.isArray(outcome))
            verify(String(outcome.error).indexOf("binds.kdl") >= 0)
        }

        function test_shortcutsAdapterSurfacesUnavailableSource() {
            var adapters = LauncherAdapters.createAdapters({})

            var refreshOutcome = null
            adapters.shortcuts.refresh("", "shortcuts", function(result) { refreshOutcome = result })
            verify(refreshOutcome && refreshOutcome.error === "shortcut service unavailable")

            var executeOutcome = null
            adapters.shortcuts.execute({ detail: "close-window" }, function(result) { executeOutcome = result })
            verify(executeOutcome && executeOutcome.ok === false)
        }

        function test_shortcutsAdapterExecutesNiriActionsThroughRunner() {
            var runner = makeRunner({ ok: true })
            var adapters = keyAdapters(runner)

            var outcome = null
            adapters.shortcuts.execute(
                { id: "s1", displayName: "Terminal", detail: 'spawn "foot" --server' },
                function(result) { outcome = result })

            compare(runner.calls.length, 1)
            compare(runner.calls[0].join(" "), "niri msg action spawn -- foot --server")
            verify(outcome && outcome.ok === true)
        }

        function test_shortcutsAdapterRoutesManagedShellBindsThroughIpcHelper() {
            var runner = makeRunner({ ok: true })
            var adapters = keyAdapters(runner)

            var outcome = null
            adapters.shortcuts.execute(
                { id: "s2", managedByShell: true, actionId: "shell.launcher.toggle",
                  detail: 'spawn "sh" "/x/afloat-ipc" "launcher" "toggle"' },
                function(result) { outcome = result })

            compare(runner.calls.length, 1)
            compare(runner.calls[0][0], "/usr/bin/afloat-ipc")
            compare(runner.calls[0][1], "launcher")
            compare(runner.calls[0][2], "toggle")
            verify(outcome && outcome.ok === true)
        }

        function test_shortcutsAdapterPropagatesActionFailures() {
            var runner = makeRunner({ ok: false, error: "niri rejected the action" })
            var adapters = keyAdapters(runner)

            var outcome = null
            adapters.shortcuts.execute({ id: "s9", detail: "close-window" }, function(result) { outcome = result })

            verify(outcome && outcome.ok === false)
            compare(outcome.error, "niri rejected the action")
        }

        function test_actionArgvBuildsNiriCommandsFromActionBodies() {
            compare(LauncherAdapters.actionArgv(
                { detail: "close-window" }, "").join(" "), "niri msg action close-window")
            compare(LauncherAdapters.actionArgv(
                { detail: 'spawn-sh "swaylock -f"' }, "").join(" "), "niri msg action spawn-sh -- swaylock -f")
            compare(LauncherAdapters.actionArgv(null, "").length, 0)
            compare(LauncherAdapters.actionArgv({ detail: "" }, "").length, 0)
        }

        // --- production session integration ---

        function test_sessionWithProductionFactorySurfacesUnavailableSources() {
            clipBackend.available = false
            svc()._adapters = LauncherAdapters.createAdapters({
                clipboardBackend: clipBackend
            })

            svc().open()

            compare(svc().visible, true)
            compare(svc().mode, "apps")
            compare(svc().loading, false)
            verify(String(svc().error).indexOf("application source unavailable") >= 0)
            compare(svc().results.length, 0)

            svc().query = ">clip x"
            compare(svc().error, "clipboard history unavailable")

            svc().query = ">key y"
            compare(svc().error, "shortcut service unavailable")
        }

        function test_sessionWithProductionFactoryListsAndExecutesApplications() {
            var counts = makeLaunchCounts({ alpha: 2, beta: 7 })
            var beta = makeAppEntry("beta", "Beta", "")
            var alpha = makeAppEntry("alpha", "Alpha", "")
            svc()._adapters = LauncherAdapters.createAdapters({
                appsSource: makeAppsSource([alpha, beta]),
                launchCounts: counts
            })

            svc().open()

            compare(svc().loading, false)
            compare(svc().error, "")
            compare(svc().results.length, 2)
            compare(svc().results[0].id, "beta")
            compare(svc().results[1].id, "alpha")
            compare(svc().selectedIndex, 0)

            svc().executeSelected()
            compare(beta.execCalls, 1)
            compare(counts.recorded.length, 1)
            compare(counts.recorded[0], "beta")
            compare(svc().visible, false)
        }

        function test_sessionExecuteIsGatedWhileLoading() {
            var apps = makeManualAdapter()
            svc()._adapters = ({ apps: apps })

            svc().open()
            compare(svc().loading, true)

            // Stale results from a previous view must not execute mid-load.
            svc().results = [{ id: "stale", displayName: "Stale" }]
            svc().selectedIndex = 0
            svc().executeSelected()
            svc().execute({ id: "stale", displayName: "Stale" })
            compare(apps.executions.length, 0)

            apps.pendingRefreshes[0]([makeItem("fresh", "Fresh", 0, 0)])
            compare(svc().loading, false)
            compare(svc().interactive, true)

            svc().executeSelected()
            compare(apps.executions.length, 1)
            compare(apps.executions[0].id, "fresh")
        }

        function test_sessionExecuteIsGatedWhileErrorShown() {
            var apps = makeManualAdapter()
            svc()._adapters = ({ apps: apps })

            svc().open()
            apps.pendingRefreshes[0]({ error: "source failed" })
            compare(svc().interactive, false)

            svc().execute({ id: "anything" })
            compare(apps.executions.length, 0)
        }

        function makeItem(id, name, weight, usedAt) {
            return { id: id, displayName: name, favoriteWeight: weight, lastUsedAt: usedAt }
        }

        // --- production singleton wiring (structural guard) ---

        function test_productionServiceInstallsFactoryAdapters() {
            var source = readSourceFile("../../services/LauncherService.qml")
            if (source === null)
                skip("local XHR file reads disabled; set QML_XHR_ALLOW_FILE_READ=1 to enable")

            verify(source.indexOf("_adapters") >= 0,
                   "production service must assign the session adapter seam")
            verify(source.indexOf("LauncherAdapters.createAdapters") >= 0,
                   "production service must install adapters via the production factory")
            verify(source.indexOf("DesktopEntries.applications") >= 0,
                   "apps mode must be wired to desktop entries")
            verify(source.indexOf("Services.ClipboardService") >= 0,
                   "clipboard mode must be wired to ClipboardService")
            verify(source.indexOf("Services.NiriShortcutService") >= 0,
                   "shortcuts mode must be wired to NiriShortcutService")
            verify(source.indexOf("_adapters: root._adapters") >= 0,
                   "embedded session must receive the production adapters")
        }
    }
}
