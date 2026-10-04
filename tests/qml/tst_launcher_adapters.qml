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

    // Backend whose startup caches have not landed yet: list() is a no-op
    // and no completion will ever fire for the wait.
    Component {
        id: cachePendingBackendComponent
        QtObject {
            property bool available: true
            property bool probeFinished: true
            property var items: []
            property int revision: 0
            property bool _firstSeenCacheReady: false
            property bool listRequested: false
            signal listCompleted()
            function list() { listRequested = true }
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
                categories: options && options.categories ? options.categories : [],
                noDisplay: !!(options && options.noDisplay),
                execCalls: 0
            }
            entry.execute = function() { entry.execCalls++ }
            return entry
        }

        // Adapters deliver rows in ranked order, so a formatting test must not read
        // them by position: look them up by id instead.
        function byId(items) {
            var map = ({})
            for (var index = 0; index < items.length; index++)
                map[String(items[index].id)] = items[index]
            return map
        }

        function ids(items) {
            var out = []
            for (var index = 0; index < items.length; index++)
                out.push(String(items[index].id))
            return out
        }

        // Collects every batch a refresh streams out. `schedule` is
        // synchronous here, so one refresh() call still delivers all of them.
        function collectingRefresh(adapter, mode, query) {
            var batches = []
            adapter.refresh(query || "", mode || "apps", function(items, complete) {
                batches.push({ items: items, complete: complete })
            })
            return batches
        }

        // Drains a scheduler queue after refresh() returns, the way the
        // production frame stepper would. Draining inside the completion
        // callback cannot work: the step is only queued after the callback
        // returns.
        function drain(queue, limit) {
            var guard = 0
            while (queue.length && guard++ < (limit || 40))
                queue.shift()()
            return guard
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

        // Command fixture taken from the shipped builtin list, so merge/filter
        // /execute coverage pins the real entry rather than a stand-in.
        function makeLockCommand() {
            var commands = LauncherAdapters.builtinCommands()
            verify(commands.length > 0, "a lock command must ship")
            return commands[0]
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
            // In-flight guards must return to fresh-session state as well: a
            // test that starts an execution without completing it (a manual
            // adapter swallowing done) would otherwise silently disarm
            // execute() for every later test in the case.
            s._executionInFlight = false
            s._appsPrimeInFlight = false
            s._metadataRefreshPending = false
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

        function test_appsAdapterIconCacheRetriesMissesInsteadOfPinningBlanks() {
            // A lookup that misses while the desktop-entry scan or icon
            // theme is still settling must not pin "" forever: later pulls
            // retry and pick the icon up once resolution succeeds, while
            // hits stay cached and never re-hit the theme.
            var lookups = []
            var adapters = LauncherAdapters.createAdapters({
                appsSource: makeAppsSource([
                    makeAppEntry("alpha", "Alpha", "", { icon: "alpha-icon" })
                ]),
                iconResolver: function(name) {
                    lookups.push(name)
                    return lookups.length > 1 ? "theme:" + name : ""
                }
            })

            var first = null
            adapters.apps.refresh("", "apps", function(result) { first = result })
            compare(first[0].icon, "")

            var second = null
            adapters.apps.refresh("", "apps", function(result) { second = result })
            compare(second[0].icon, "theme:alpha-icon")

            var third = null
            adapters.apps.refresh("", "apps", function(result) { third = result })
            compare(third[0].icon, "theme:alpha-icon")
            compare(lookups.length, 2)
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

        function test_clipboardTimeLabelShowsMonthDayAndSeconds() {
            // Copy timestamps read "MM-dd HH:mm:ss" in local time.
            var stamp = new Date(2026, 0, 5, 7, 8, 9).getTime()
            compare(LauncherAdapters.timeLabel(stamp), "01-05 07:08:09")
        }

        function test_appsAdapterNamelessEntriesFallBackToId() {
            // A broken .desktop with no Name previously rendered as a blank
            // card or vanished entirely; falling back to the id keeps the
            // app listed, searchable by its id, and presentable.
            var nameless = makeAppEntry("searchterm", "", "")
            var adapters = LauncherAdapters.createAdapters({
                appsSource: makeAppsSource([nameless]),
                launchCounts: makeLaunchCounts({})
            })

            var outcome = null
            adapters.apps.refresh("searchterm", "apps", function(result) { outcome = result })
            verify(outcome && !outcome.error)
            compare(outcome.length, 1)
            compare(outcome[0].displayName, "searchterm")
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
                commands: [makeLockCommand()]
            })

            var outcome = "pending"
            adapters.apps.refresh("", "apps", function(result) { outcome = result })

            compare(outcome.length, 2)
            var lock = outcome[1]
            compare(lock.id, "cmd-lock")
            compare(lock.kind, "command")
            compare(lock.displayName, "锁屏")
            compare(lock.actionId, "shell.lock.lock")
            verify(lock.managedByShell === true)
        }

        function test_appsAdapterFiltersCommandsByQuery() {
            var adapters = LauncherAdapters.createAdapters({
                appsSource: makeAppsSource([]),
                commands: [makeLockCommand()]
            })

            var hit = "pending"
            adapters.apps.refresh("锁屏", "apps", function(result) { hit = result })
            compare(hit.length, 1)
            compare(hit[0].id, "cmd-lock")

            var english = "pending"
            adapters.apps.refresh("lock", "apps", function(result) { english = result })
            compare(english.length, 1)

            var miss = "pending"
            adapters.apps.refresh("firefox", "apps", function(result) { miss = result })
            compare(miss.length, 0)
        }

        // The launcher's lock item must reach the real session lock, not the
        // 5s self-test probe: `lock test` was the only thing that ever spawned
        // lock-test.qml, and it is gone.
        function test_builtinLockCommandLocksTheRealSession() {
            var commands = LauncherAdapters.builtinCommands()
            compare(commands.length, 1)
            var lock = commands[0]
            compare(lock.id, "cmd-lock")
            compare(lock.label, "锁屏")
            compare(lock.icon, "lock")
            compare(lock.actionId, "shell.lock.lock")
            for (var i = 0; i < commands.length; ++i)
                verify(String(commands[i].actionId) !== "shell.lock.test",
                       "the self-test probe must not stay reachable from the launcher")
        }

        function test_appsAdapterExecutesCommandsThroughIpcHelper() {
            var ran = []
            var adapters = LauncherAdapters.createAdapters({
                appsSource: makeAppsSource([]),
                commands: [makeLockCommand()],
                ipcHelperPath: "/opt/afloat-ipc",
                actionRunner: function(argv, done) { ran.push(argv); done({ ok: true }) }
            })

            var outcome = null
            adapters.apps.execute({
                id: "cmd-lock",
                kind: "command",
                actionId: "shell.lock.lock",
                managedByShell: true
            }, function(result) { outcome = result })

            verify(outcome && outcome.ok === true)
            compare(ran.length, 1)
            compare(ran[0].join(" "), "/opt/afloat-ipc lock lock")
        }

        function test_appsAdapterCommandWithoutRunnerErrors() {
            var adapters = LauncherAdapters.createAdapters({
                appsSource: makeAppsSource([]),
                commands: [makeLockCommand()]
            })

            var outcome = null
            adapters.apps.execute({
                id: "cmd-lock",
                kind: "command",
                actionId: "shell.lock.lock",
                managedByShell: true
            }, function(result) { outcome = result })

            verify(outcome && outcome.ok === false)
            verify(String(outcome.error).length > 0)
        }

        // --- categories ---

        function test_appsAdapterTagsEntriesThroughTheInjectedClassifier() {
            var adapters = LauncherAdapters.createAdapters({
                appsSource: makeAppsSource([
                    makeAppEntry("steam", "Steam", "games", { categories: ["Game"] }),
                    makeAppEntry("editor", "Editor", "", {})
                ]),
                // A stub resolver keeps the adapter contract under test; the
                // production wiring is LauncherCategories.appCategoryOf.
                appCategoryResolver: function(entry) {
                    return entry.categories.length ? "games" : "other"
                }
            })

            var outcome = "pending"
            adapters.apps.refresh("", "apps", function(result) { outcome = result })

            compare(outcome.length, 2)
            var byId = ({})
            for (var i = 0; i < outcome.length; i++)
                byId[outcome[i].id] = outcome[i]
            compare(byId["steam"].category, "games")
            compare(byId["editor"].category, "other")
            // The id rides searchText, so typing a category name finds it.
            verify(byId["steam"].searchText.indexOf("games") >= 0)
        }

        function test_appsAdapterDefaultsToOtherWithoutAClassifier() {
            var adapters = LauncherAdapters.createAdapters({
                appsSource: makeAppsSource([makeAppEntry("alpha", "Alpha", "",
                                                        { categories: ["Game"] })])
            })

            var outcome = "pending"
            adapters.apps.refresh("", "apps", function(result) { outcome = result })
            compare(outcome[0].category, "other")
        }

        function test_builtinCommandsDeclareTheirChipBucket() {
            var adapters = LauncherAdapters.createAdapters({
                appsSource: makeAppsSource([makeAppEntry("alpha", "Alpha", "")]),
                commands: LauncherAdapters.builtinCommands()
            })

            var outcome = "pending"
            adapters.apps.refresh("", "apps", function(result) { outcome = result })

            var lock = outcome[1]
            compare(lock.id, "cmd-lock")
            // Locking the session is a system action, not an unclassified one.
            compare(lock.category, "system")
        }

        function test_clipboardAdapterTagsEntriesThroughTheInjectedClassifier() {
            clipBackend.items = [
                { id: "1", preview: "plain sentence", mime: "text/plain", isImage: false, firstSeenMs: 1700000100000 },
                { id: "2", preview: "shot", mime: "image/png", isImage: true, firstSeenMs: 1700000200000 }
            ]
            var adapters = LauncherAdapters.createAdapters({
                clipboardBackend: clipBackend,
                clipCategoryResolver: function(raw) { return raw.isImage ? "image" : "text" }
            })

            var batches = collectingRefresh(adapters.clipboard, "clipboard")
            verify(batches.length === 1)
            var rows = byId(batches[0].items)
            compare(Object.keys(rows).length, 2)
            compare(rows["1"].category, "text")
            compare(rows["2"].category, "image")
        }

        function test_clipboardAdapterDefaultsToTextWithoutAClassifier() {
            clipBackend.items = [
                { id: "1", preview: "plain", mime: "text/plain", isImage: false, firstSeenMs: 1700000100000 },
                { id: "2", preview: "shot", mime: "image/png", isImage: true, firstSeenMs: 1700000200000 }
            ]
            var adapters = LauncherAdapters.createAdapters({ clipboardBackend: clipBackend })

            var batches = collectingRefresh(adapters.clipboard, "clipboard")
            var rows = byId(batches[0].items)
            compare(rows["1"].category, "text")
            // An image row keeps its own bucket even with no classifier: it is
            // the one kind the raw entry already states.
            compare(rows["2"].category, "image")
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

        function test_clipboardAdapterFormatsTextMetadata() {
            var adapters = LauncherAdapters.createAdapters({ clipboardBackend: clipBackend })
            clipBackend.complete([
                { id: "short", preview: "hello", textCharCount: 1234, metadataReady: true, mime: "text/plain", isImage: false, firstSeenMs: 1700000100000 },
                { id: "long", preview: "1234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890", textCharCount: 2500, metadataReady: true, mime: "text/plain", isImage: false, firstSeenMs: 1700000200000 }
            ])

            var batches = collectingRefresh(adapters.clipboard, "clipboard")
            var rows = byId(batches[0].items)
            compare(Object.keys(rows).length, 2)
            verify(rows["short"].description.indexOf("1234 characters") >= 0)
            verify(rows["long"].description.indexOf("2500 characters") >= 0)
            verify(rows["long"].description.indexOf("Long text") < 0)
            verify(rows["short"].description.indexOf("copied") >= 0)
        }

        function test_clipboardAdapterFormatsImageMetadataAndFallsBackToMime() {
            var parsed = LauncherAdapters.parseClipboardImageMeta(
                "[[ binary data 12345 png 1920x1080 ]]")
            compare(parsed.size, "12345")
            compare(parsed.format, "png")
            compare(parsed.width, 1920)
            compare(parsed.height, 1080)

            var spaced = LauncherAdapters.parseClipboardImageMeta(
                "[[ binary data 471 KiB png 1705x905 ]]")
            compare(spaced.size, "471 KiB")
            compare(spaced.format, "png")
            compare(spaced.width, 1705)
            compare(spaced.height, 905)
            compare(LauncherAdapters.formatClipboardByteSize(482304), "482.3 KB")
            compare(LauncherAdapters.formatClipboardByteSize(
                LauncherAdapters.clipboardByteCount("471 KiB")), "482.3 KB")
            compare(LauncherAdapters.formatClipboardByteSize(
                LauncherAdapters.clipboardByteCount("2 MiB")), "2.1 MB")

            var adapters = LauncherAdapters.createAdapters({ clipboardBackend: clipBackend })
            clipBackend.complete([
                { id: "image", preview: "[[ binary data 12345 png 1920x1080 ]]", imageFormat: "PNG", imageBytes: 482304, imageWidth: 1705, imageHeight: 905, metadataReady: true, mime: "image/png", isImage: true, firstSeenMs: 1700000100000 },
                { id: "bad-image", preview: "[[ binary data unavailable ]]", mime: "image/jpeg", isImage: true, firstSeenMs: 1700000200000 },
                { id: "preview-image", preview: "[[ binary data 37 KiB png 712x522 ]]", mime: "image/png", isImage: true, firstSeenMs: 1700000300000 }
            ])
            var batches = collectingRefresh(adapters.clipboard, "clipboard")
            var rows = byId(batches[0].items)
            compare(rows["image"].displayName, "[Image] 1705x905")
            verify(rows["image"].description.indexOf("png") >= 0)
            verify(rows["image"].description.indexOf("482.3 KB") >= 0)
            verify(rows["image"].description.indexOf("copied") >= 0)
            verify(rows["bad-image"].description.indexOf("image/jpeg") >= 0)
            verify(rows["bad-image"].description.indexOf("unavailable") < 0)
            compare(rows["preview-image"].displayName, "[Image] 712x522")
            verify(rows["preview-image"].description.indexOf("37.9 KB") >= 0)
        }

        function test_clipboardAdapterAppliesPersistentMetadataWithoutRecounting() {
            var items = [
                { id: "known-text", preview: "hello world", isImage: false },
                { id: "changed-text", preview: "new text", isImage: false },
                { id: "known-image", preview: "[[ binary data 471 KiB png 1705x905 ]]", isImage: true },
                { id: "type-changed", preview: "hello world", isImage: true }
            ]
            var cache = {
                "known-text": { preview: "hello world", isImage: false, textCharCount: 1500 },
                "changed-text": { preview: "old text", isImage: false, textCharCount: 42 },
                "known-image": { preview: "[[ binary data 471 KiB png 1705x905 ]]", isImage: true, format: "PNG", width: 1705, height: 905, bytes: 482304 },
                "type-changed": { preview: "hello world", isImage: false, textCharCount: 1500 }
            }

            compare(LauncherAdapters.applyClipboardMetadataCache(items, cache), 2)
            verify(items[0].metadataReady)
            compare(items[0].textCharCount, 1500)
            verify(!items[1].metadataReady)
            verify(items[2].metadataReady)
            compare(items[2].imageWidth, 1705)
            compare(items[2].imageHeight, 905)
            compare(items[2].imageBytes, 482304)
            verify(!items[3].metadataReady)
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

        function test_clipboardAdapterAnswersImmediatelyWhenCachesNotReady() {
            // list() is a no-op until the backend's startup caches land; the
            // adapter must answer with what it has instead of waiting for a
            // completion that will never arrive (stuck "Searching...").
            var backend = cachePendingBackendComponent.createObject(clipBackend)
            var adapters = LauncherAdapters.createAdapters({ clipboardBackend: backend })

            var outcome = "pending"
            adapters.clipboard.refresh("", "clipboard", function(result) { outcome = result })

            verify(Array.isArray(outcome), "waited for a completion that never comes")
            compare(outcome.length, 0)
            backend.destroy()
        }

        function test_clipboardListRowParseSplitsTabAndFallsBackToSpace() {
            // The history fetch loop runs these helpers inline; a scope slip
            // there used to abort the whole fetch (stuck "Searching..."), so
            // the parse itself is pinned here.
            var tabbed = LauncherAdapters.splitClipboardListLine("42\thello token")
            verify(tabbed !== null)
            compare(tabbed.id, "42")
            compare(tabbed.preview, "hello token")

            var spaced = LauncherAdapters.splitClipboardListLine("43 hello token")
            verify(spaced !== null)
            compare(spaced.id, "43")
            compare(spaced.preview, "hello token")

            verify(LauncherAdapters.splitClipboardListLine("") === null)
            verify(LauncherAdapters.splitClipboardListLine(null) === null)
        }

        function test_clipboardListRowParseClassifiesImagesByPrefixOnly() {
            verify(LauncherAdapters.isClipboardImagePreview("[[ binary data 12345 png 1920x1080 ]]"))
            verify(!LauncherAdapters.isClipboardImagePreview("hello <img world"))
            verify(!LauncherAdapters.isClipboardImagePreview(""))
            verify(!LauncherAdapters.isClipboardImagePreview(null))

            compare(LauncherAdapters.clipboardMimeForPreview("hello", false), "text/plain")
            compare(LauncherAdapters.clipboardMimeForPreview("[[ binary data 1 png 2x2 ]]", true), "image/png")
            compare(LauncherAdapters.clipboardMimeForPreview("[[ binary data 1 JPG 2x2 ]]", true), "image/jpeg")
            compare(LauncherAdapters.clipboardMimeForPreview("[[ binary data 1 webp 2x2 ]]", true), "image/webp")
            compare(LauncherAdapters.clipboardMimeForPreview("[[ binary data 1 gif 2x2 ]]", true), "image/gif")
            compare(LauncherAdapters.clipboardMimeForPreview("[[ binary data 1 bmp 2x2 ]]", true), "image/*")
        }

        function test_previewDecodeQueueCoalescesAndServesNewestFirst() {
            // Overlapping preview requests used to overwrite the running id
            // and misattribute content; queued requests keep their identity
            // and drain newest-first so the current selection previews next.
            var queue = LauncherAdapters.queuePreviewDecode(null, "a", false)
            queue = LauncherAdapters.queuePreviewDecode(queue, "b", false)
            queue = LauncherAdapters.queuePreviewDecode(queue, "a", false)
            compare(queue.length, 2)
            compare(queue[0].id, "a")
            compare(queue[1].id, "b")
            verify(LauncherAdapters.queuePreviewDecode(queue, "", false) === queue)

            compare(LauncherAdapters.takeNewestPreviewDecode(queue).id, "b")
            compare(LauncherAdapters.takeNewestPreviewDecode(queue).id, "a")
            verify(LauncherAdapters.takeNewestPreviewDecode(queue) === null)
            verify(LauncherAdapters.takeNewestPreviewDecode(null) === null)
        }

        function test_firstSeenCacheSplitAcceptsNewShapeAndLegacyMap() {
            // Cold boots must restore exact row timestamps; the stored shape
            // is { signatures, ids } while older files are bare signature maps.
            var shaped = LauncherAdapters.splitFirstSeenCache({
                signatures: { "aa": 100 },
                ids: { "7": 200 }
            })
            compare(shaped.signatures["aa"], 100)
            compare(shaped.ids["7"], 200)

            var legacy = LauncherAdapters.splitFirstSeenCache({ "aa": 100 })
            compare(legacy.signatures["aa"], 100)
            verify(Object.keys(legacy.ids).length === 0)

            var empty = LauncherAdapters.splitFirstSeenCache(null)
            verify(Object.keys(empty.signatures).length === 0)
            verify(Object.keys(empty.ids).length === 0)
        }

        function test_firstSeenCachePackPrunesDeadIds() {
            var packed = LauncherAdapters.packFirstSeenCache(
                { "aa": 100 },
                { "7": 200, "gone": 300, "zero": 0 },
                [{ id: "7", preview: "kept" }, { id: 9, preview: "numeric" }])
            compare(packed.signatures["aa"], 100)
            compare(packed.ids["7"], 200)
            verify(!("gone" in packed.ids))
            verify(!("zero" in packed.ids))

            var unlisted = LauncherAdapters.packFirstSeenCache({ "aa": 100 }, { "7": 200 }, null)
            verify(Object.keys(unlisted.ids).length === 0)
            compare(unlisted.signatures["aa"], 100)
        }

        function test_clipboardCopySeedRoundTripInheritsTimestamp() {
            // The shell copying an entry back recreates it under a fresh id;
            // matching the seed must hand back the original timestamp so the
            // row keeps its position instead of jumping to the top.
            var seeds = LauncherAdapters.rememberClipboardCopySeed(
                null, "hello token", false, 1700000100000, 1700000200000)
            compare(seeds.length, 1)
            compare(LauncherAdapters.matchClipboardCopySeed(
                seeds, "hello token", false, 1700000201000), 1700000100000)
        }

        function test_clipboardCopySeedRejectsMismatchesAndExpiry() {
            var now = 1700000200000
            var seeds = LauncherAdapters.rememberClipboardCopySeed(
                null, "hello token", false, 1700000100000, now)
            // Different preview, different type, and expired seeds miss.
            compare(LauncherAdapters.matchClipboardCopySeed(seeds, "other text", false, now + 1000), 0)
            compare(LauncherAdapters.matchClipboardCopySeed(seeds, "hello token", true, now + 1000), 0)
            compare(LauncherAdapters.matchClipboardCopySeed(
                seeds, "hello token", false,
                now + LauncherAdapters.clipboardCopySeedMaxAgeMs + 1), 0)
            // Newest matching seed wins.
            seeds = LauncherAdapters.rememberClipboardCopySeed(
                seeds, "hello token", false, 1700000150000, now + 2000)
            compare(LauncherAdapters.matchClipboardCopySeed(seeds, "hello token", false, now + 3000),
                    1700000150000)
        }

        function test_clipboardCopySeedPrunesExpiredAndCapsLength() {
            var now = 1700000200000
            var seeds = LauncherAdapters.rememberClipboardCopySeed(
                null, "stale", false, 1, now - LauncherAdapters.clipboardCopySeedMaxAgeMs - 1)
            seeds = LauncherAdapters.rememberClipboardCopySeed(seeds, "fresh", false, 2, now)
            compare(seeds.length, 1)
            compare(seeds[0].preview, "fresh")

            var many = []
            for (var i = 0; i < LauncherAdapters.clipboardCopySeedLimit + 4; i++)
                many = LauncherAdapters.rememberClipboardCopySeed(many, "item-" + i, false, i + 1, now + i)
            compare(many.length, LauncherAdapters.clipboardCopySeedLimit)
            compare(many[many.length - 1].preview,
                    "item-" + (LauncherAdapters.clipboardCopySeedLimit + 3))
        }

        // --- progressive delivery ---

        function test_appsAdapterStreamsBatchesInRankedOrder() {
            // 120 entries with descending launch counts, delivered through a
            // synchronous stepper: one refresh() call still emits every batch,
            // and the batch boundaries follow the chunk size, not the set.
            var entries = []
            for (var index = 0; index < 120; index++)
                entries.push(makeAppEntry("app" + index, "App " + index, ""))
            var counts = { map: ({}) }
            for (var c = 0; c < 120; c++)
                counts.map["app" + c] = 120 - c
            counts.getLaunchCount = function(id) { return this.map[id] || 0 }
            counts.recordLaunch = function() {}
            var adapters = LauncherAdapters.createAdapters({
                appsSource: makeAppsSource(entries),
                launchCounts: counts,
                // Collect every scheduled step instead of running it at once,
                // which is what the production frame stepper does.
                schedule: function(step) { pending.push(step) }
            })

            var batches = []
            var pending = []
            adapters.apps.refresh("", "apps", function(items, complete) {
                batches.push({ items: items, complete: complete })
            })

            // The first batch is handed over synchronously; the rest wait for
            // the scheduler, so the caller paints before the set is mapped. It
            // is deliberately small: it is what builds the opening frame's
            // rows, and the throughput batches follow behind it.
            verify(batches.length === 1)
            compare(batches[0].complete, false)
            compare(batches[0].items.length, 24)
            compare(batches[0].items[0].id, "app0")

            var guard = 0
            while (pending.length && guard++ < 20) {
                var step = pending.shift()
                step()
            }
            verify(batches.length >= 3)
            // Only the last batch reports completion.
            compare(batches[batches.length - 1].complete, true)
            for (var b = 0; b < batches.length - 1; b++)
                compare(batches[b].complete, false)

            // Concatenated batches are the ranked whole: launch-count
            // descending, and never re-sorted after the fact.
            var joined = []
            for (var j = 0; j < batches.length; j++)
                joined = joined.concat(batches[j].items)
            compare(joined.length, 120)
            var sortedOk = true
            for (var k = 1; k < joined.length; k++) {
                if (joined[k - 1].favoriteWeight < joined[k].favoriteWeight)
                    sortedOk = false
            }
            verify(sortedOk, "batches must arrive in ranked order")
        }

        function test_batchesDoubleSoALongSetArrivesInAFewCommits() {
            // What a commit costs is a pool pass and a stretch of the row list,
            // not the batch's own mapping, so a dozen fixed-size batches read
            // as the list twitching as it fills. Each batch after the first
            // doubles up to four times the base: a 750-entry set commits seven
            // times instead of sixteen, and the opening frame still gets its
            // small first batch. The ceiling is what keeps the largest frame
            // inside a budget - past the window size a batch only feeds the
            // pool, so mapping it is pure per-frame cost.
            var entries = []
            for (var index = 0; index < 750; index++)
                entries.push(makeAppEntry("app" + index, "App " + index, ""))
            var adapters = LauncherAdapters.createAdapters({
                appsSource: makeAppsSource(entries),
                launchCounts: { map: ({}), getLaunchCount: function() { return 0 },
                                recordLaunch: function() {} },
                schedule: function(step) { pending.push(step) }
            })

            var sizes = []
            var pending = []
            var complete = false
            adapters.apps.refresh("", "apps", function(items, isComplete) {
                // The last batch is the remainder and can be any size; only the
                // ones before it are the growth curve.
                sizes.push(isComplete ? -items.length : items.length)
                complete = isComplete
            })
            while (pending.length > 0)
                pending.shift()()

            verify(complete, "the stream must finish once the scheduler drains")
            var grew = sizes.slice(0, sizes.length - 1)
            compare(grew[0], 24, "the opening batch stays small")
            verify(sizes.length <= 7,
                   "750 entries should arrive in a handful of commits, got "
                   + sizes.length + ": " + sizes.join(","))
            for (var s = 1; s < grew.length; s++)
                verify(grew[s] >= grew[s - 1],
                       "batches must not shrink: " + sizes.join(","))
            verify(grew[grew.length - 1] >= 192,
                   "the growth must reach its ceiling: " + sizes.join(","))
            var total = 0
            for (var t = 0; t < sizes.length; t++)
                total += Math.abs(sizes[t])
            compare(total, 750, "every entry must arrive exactly once")
        }

        function test_appsAdapterStreamedResultMatchesTheOneShotResult() {
            var entries = []
            for (var index = 0; index < 30; index++)
                entries.push(makeAppEntry("app" + index, "App " + index, "",
                                          { categories: index % 2 ? ["Game"] : ["Network"] }))
            var streamed = []
            var pending = []
            var adapters = LauncherAdapters.createAdapters({
                appsSource: makeAppsSource(entries),
                schedule: function(step) { pending.push(step) }
            })
            adapters.apps.refresh("", "apps", function(items) {
                streamed = streamed.concat(items)
            })
            drain(pending)
            // Without a scheduler the batches still arrive one call at a
            // time, just all within the refresh: collect them the same way.
            var oneShot = []
            var plain = LauncherAdapters.createAdapters({ appsSource: makeAppsSource(entries) })
            plain.apps.refresh("", "apps", function(items) { oneShot = oneShot.concat(items) })

            compare(ids(streamed), ids(oneShot))
            compare(oneShot.length, 30)
        }

        function test_streamedQueryFiltersEveryBatch() {
            // The needle applies to the whole stream, not just its first
            // batch: a match in the tail still has to arrive.
            var entries = []
            for (var index = 0; index < 100; index++)
                entries.push(makeAppEntry("app" + index,
                                           index === 90 ? "Needle app" : "App " + index, ""))
            var pending = []
            var adapters = LauncherAdapters.createAdapters({
                appsSource: makeAppsSource(entries),
                schedule: function(step) { pending.push(step) }
            })
            var found = []
            adapters.apps.refresh("needle", "apps", function(items) {
                found = found.concat(items)
            })
            drain(pending)
            compare(ids(found), ["app90"])
        }

        function test_concurrentStreamsBothFinishInsteadOfStarving() {
            // A background read (the clipboard metadata merge) streams while
            // the visible list is still streaming. Neither may be cancelled
            // or dropped: each keeps its own cursor and its own needle.
            var rows = []
            for (var index = 0; index < 200; index++) {
                rows.push({
                    id: String(index),
                    preview: index === 150 ? "needle row" : "row " + index,
                    mime: "text/plain",
                    isImage: false,
                    firstSeenMs: 1700000000000 + index
                })
            }
            clipBackend.items = rows
            var pending = []
            var adapters = LauncherAdapters.createAdapters({
                clipboardBackend: clipBackend,
                schedule: function(step) { pending.push(step) }
            })

            var visible = []
            var needleRun = []
            adapters.clipboard.refresh("", "clipboard", function(items) {
                visible = visible.concat(items)
            })
            adapters.clipboard.refresh("needle", "clipboard", function(items) {
                needleRun = needleRun.concat(items)
            })
            drain(pending)

            // The second refresh did not retarget the first: the unfiltered
            // run still sees everything, the filtered one only its match.
            compare(visible.length, 200)
            compare(ids(needleRun), ["150"])
        }

        function test_withoutASchedulerTheWholeSetArrivesSynchronously() {
            // A caller that injects no scheduler asked for a plain refresh: it
            // must receive every row, not just the first chunk. The batches
            // still arrive one call at a time - there is simply no later turn
            // to hand the rest to.
            var entries = []
            for (var index = 0; index < 100; index++)
                entries.push(makeAppEntry("app" + index, "App " + index, ""))
            var adapters = LauncherAdapters.createAdapters({
                appsSource: makeAppsSource(entries)
            })
            var collected = []
            var completions = []
            adapters.apps.refresh("", "apps", function(items, complete) {
                collected = collected.concat(items)
                completions.push(complete)
            })
            compare(collected.length, 100)
            verify(completions.length >= 2)
            compare(completions[completions.length - 1], true)
            for (var c = 0; c < completions.length - 1; c++)
                compare(completions[c], false)
        }

        function test_emptyStreamStillReportsCompletion() {
            // An exhausted source with no matches is a real answer, not a
            // silent hang: exactly one batch, empty, complete.
            var adapters = LauncherAdapters.createAdapters({
                appsSource: makeAppsSource([makeAppEntry("alpha", "Alpha", "")])
            })
            var batches = collectingRefresh(adapters.apps, "apps", "no-such-app")
            compare(batches.length, 1)
            compare(batches[0].items.length, 0)
            compare(batches[0].complete, true)
        }

        function test_clipboardAdapterStreamsHistoryByRecency() {
            clipBackend.items = []
            for (var index = 0; index < 150; index++) {
                clipBackend.items.push({
                    id: String(index),
                    preview: "entry " + index,
                    mime: "text/plain",
                    isImage: false,
                    firstSeenMs: 1700000000000 + index
                })
            }
            var pending = []
            var adapters = LauncherAdapters.createAdapters({
                clipboardBackend: clipBackend,
                schedule: function(step) { pending.push(step) }
            })
            var joined = []
            adapters.clipboard.refresh("", "clipboard", function(items) {
                joined = joined.concat(items)
            })
            drain(pending)
            compare(joined.length, 150)
            // Newest first, which is what the pool shows while it streams.
            compare(joined[0].id, "149")
            compare(joined[149].id, "0")
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
            // Ranked delivery: binds have no usage weight, so they arrive
            // alphabetically by label ("Launcher: afloat" before "Open
            // terminal"), which is also the order the pool keeps them in.
            compare(calls[0][0].id, "s2")
            compare(calls[0][0].displayName, "Launcher: afloat")
            compare(calls[0][0].managedByShell, true)
            compare(calls[0][1].id, "s1")
            compare(calls[0][1].displayName, "Open terminal")
            compare(calls[0][1].keySequence, "Super+Return")
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
            // open() publishes visibility first and pulls the pool on the
            // next turn so the surface can claim focus synchronously.
            wait(0)

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
            // open() publishes visibility first and pulls the pool on the
            // next turn so the surface can claim focus synchronously.
            wait(0)

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
            // open() publishes visibility first and pulls the pool on the
            // next turn so the surface can claim focus synchronously.
            wait(0)
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
            // open() publishes visibility first and pulls the pool on the
            // next turn so the surface can claim focus synchronously.
            wait(0)
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
