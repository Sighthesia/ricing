import QtQuick
import QtTest
import "../../modules/lazerbar" as Lazer
import "../../services/launcher/LauncherAdapters.js" as LauncherAdapters

// Two launcher rows can end up with an empty icon slot while their text is
// perfectly intact, and both failures share a shape: something hands the row
// an `Image.source` that cannot load, and nothing ever lets it try again.
//
//  1. A clipboard thumbnail whose file could not be loaded. The page caches
//     one decoded path per entry id and never invalidates it, so the row's
//     `thumbFailed` latch - cleared only by a CHANGE of thumbPath - can never
//     be re-armed. One failed load blanks that row for the rest of the
//     session, across any number of open/close cycles, and it stays blank
//     after the file becomes loadable again.
//
//  2. A built-in shell command. `commandItem` put its bare icon NAME straight
//     into `icon`, so `Image.source` resolved it as a relative file path
//     against the component's own directory and errored for good, while the
//     app rows beside it went through the icon resolver and were fine.
//
// Every test here drives the real page or the real adapter against an
// injected session, and the thumbnail ones cycle open/close on the SAME page
// instance - which is what WaveSurfaceHost.routeRetained makes possible and
// what a single-open test cannot reach.
Item {
    id: testRoot
    width: 900
    height: 700

    // A real, loadable image, and a path nothing has ever written - the shape a
    // failed `cliphist decode` leaves behind, because ClipboardService reports
    // its path whether or not the redirect produced anything.
    readonly property string loadableImage: Qt.resolvedUrl("../../modules/lazerbar/icons/apps.svg")
    readonly property string brokenPath: "/tmp/opencode/afloat-no-such-thumbnail.svg"

    // Stand-in for ClipboardService's thumbnail decode seam. Records how many
    // decodes were asked for, so the retry budget is observable rather than
    // assumed, and hands back whatever path it was pointed at.
    QtObject {
        id: decodeStub
        property string path: ""
        property int calls: 0
        function decodeThumbnail(id, mime, callback) {
            decodeStub.calls++
            if (callback)
                callback(decodeStub.path)
        }
    }

    // Standalone result-row probe, the shape tst_launcher_page.qml uses: a
    // relative import inside inline QML is blackholed, so the component is
    // declared here rather than built from a string.
    Component {
        id: rowComponent
        Lazer.LauncherResultRow {}
    }

    Lazer.LauncherPage {
        id: page
        anchors.fill: parent
    }

    TestCase {
        name: "LauncherIcons"
        when: windowShown

        property var clipboardAdapter: null
        property var appsAdapter: null

        // --- fixture helpers ------------------------------------------------

        function makeManualAdapter() {
            var adapter = { pendingRefreshes: [], executions: [], pendingExecutions: [] }
            adapter.refresh = function(query, mode, done) { adapter.pendingRefreshes.push(done) }
            adapter.execute = function(item, done) { adapter.pendingExecutions.push(done) }
            return adapter
        }

        // cliphist ids are numeric, and clipThumbPath only resolves those.
        function clipboardPull(imageId) {
            return [
                { id: "1", displayName: "a pasted line", description: "text/plain",
                  searchText: "pasted", icon: "", previewText: "a pasted line",
                  mime: "text/plain", isImage: false, time: 20,
                  category: "text", favoriteWeight: 0, lastUsedAt: 20 },
                { id: String(imageId), displayName: "[Image] 8x8",
                  description: "image/png", searchText: "image", icon: "",
                  previewText: "", mime: "image/png", isImage: true, time: 10,
                  category: "image", favoriteWeight: 0, lastUsedAt: 10 }
            ]
        }

        function resetSession() {
            var s = page.session
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
            s.category = ""
            s.loadingMore = false
        }

        // Open the clipboard route the way production does: the query prefix
        // is rewritten and the pool is re-pulled, so the reopen resolves onto
        // the same retained delegates.
        function openClipboardRoute(imageId) {
            page.session.openClipboard()
            wait(0)
            while (clipboardAdapter.pendingRefreshes.length > 0) {
                clipboardAdapter.pendingRefreshes.shift()(clipboardPull(imageId), true)
                wait(20)
            }
            page._releaseAllRowsInstantly()
            wait(80)
        }

        function rowThumbPath(index) {
            var row = page.resultAt(index)
            return row ? row.thumbPath : ""
        }

        function init() {
            Lazer.MotionTokens.reducedMotionOverride = false
            resetSession()
            clipboardAdapter = makeManualAdapter()
            appsAdapter = makeManualAdapter()
            page.session._adapters = ({ apps: appsAdapter, clipboard: clipboardAdapter })
            // Stand-in for ClipboardService's decode seam: the real one shells
            // out to `cliphist decode` and reports the path it wrote, whether or
            // not the redirect produced anything. Reporting the path is the
            // point - it is what puts an unloadable path into the page's cache.
            page.session.clipboardService = decodeStub
            testRoot.forceActiveFocus()
        }

        function cleanup() {
            Lazer.MotionTokens.reducedMotionOverride = false
            page.session.close()
            resetSession()
        }

        // --- a failed thumbnail must be retried, not latched ----------------

        function test_aThumbnailThatFailedToLoadIsRetriedOnTheNextOpen() {
            ignoreWarning(/QML Image: Cannot open: .*afloat-no-such-thumbnail\.svg/)
            // A decode that lands on a file nothing can load: exactly what a
            // failed `cliphist decode` leaves behind, because the service
            // reports its path whether or not the redirect produced anything.
            decodeStub.path = testRoot.brokenPath
            openClipboardRoute(4711)
            tryVerify(function() { return rowThumbPath(1).length > 0 }, 3000)
            var row = page.resultAt(1)
            compare(row.displayName, "[Image] 8x8")
            tryVerify(function() { return row.thumbFailed === true }, 3000)
            verify(!row.thumbnailItem.visible, "a failed thumbnail must hide the slot")
            compare(row.displayName, "[Image] 8x8", "the row keeps its text while the icon slot is empty")
            verify(row.thumbPath.length > 0, "the bound thumbnail path must survive the failure")
            verify(decodeStub.calls >= 1, "the row must have gone through the decode seam")

            // The load failed, so the page's decoded-path cache must stop being
            // treated as the answer: the cached path is permanent, derived from
            // the entry id, and a row whose latch clears only on a CHANGE of
            // thumbPath could otherwise never look again.
            page.session.close()
            wait(80)
            verify(rowThumbPath(1) === "",
                "closing must drop the failed entry's cached path, but the row still holds '"
                + rowThumbPath(1) + "' - a cached path is what latches the row blank for good")
            verify(row.thumbFailed === false,
                "the row's failure latch must be re-armed once the cached path is gone")

            // The file is readable now, the way it is after a decode that was
            // merely unreadable for a moment. The reopen must serve the entry
            // again instead of serving the cached dead path.
            decodeStub.calls = 0
            decodeStub.path = testRoot.loadableImage
            for (var attempt = 1; attempt <= 3; attempt++) {
                openClipboardRoute(4711)
                tryVerify(function() { return rowThumbPath(1).length > 0 }, 3000)
                var live = page.resultAt(1)
                verify(live, "attempt " + attempt + ": the row must survive the reopen")
                verify(!live.thumbFailed,
                    "attempt " + attempt + ": the row is still latched blank from the failed load"
                    + " (thumbPath='" + live.thumbPath + "', status=" + live.thumbnailItem.status + ")")
                tryVerify(function() { return live.thumbnailItem.status === Image.Ready }, 3000)
                verify(live.thumbnailItem.visible,
                    "attempt " + attempt + ": the thumbnail must be shown again")
                verify(live.displayName === "[Image] 8x8")
                verify(decodeStub.calls >= 1,
                    "attempt " + attempt + ": the entry was never re-decoded, so a dead"
                    + " cached path is all the row will ever be given")
                page.session.close()
                wait(60)
            }
        }

        // The retry is bounded by OPENS, not by failures: a file that is
        // genuinely missing must not spawn a decode every tick forever.
        function test_aPermanentlyBrokenThumbnailIsRetriedOncePerOpen() {
            ignoreWarning(/QML Image: Cannot open: .*afloat-no-such-thumbnail\.svg/)
            decodeStub.path = testRoot.brokenPath
            openClipboardRoute(4713)
            tryVerify(function() { return rowThumbPath(1).length > 0 }, 3000)
            tryVerify(function() { return page.resultAt(1).thumbFailed === true }, 3000)

            decodeStub.calls = 0
            for (var open = 1; open <= 4; open++) {
                page.session.close()
                wait(80)
                openClipboardRoute(4713)
                tryVerify(function() { return rowThumbPath(1).length > 0 }, 3000)
                tryVerify(function() { return page.resultAt(1).thumbFailed === true }, 3000)
            }
            compare(decodeStub.calls, 4,
                "a permanently broken thumbnail must cost exactly one re-decode per open,"
                + " not one per tick")
            page.session.close()
        }

        // The contract the latch was introduced for must keep holding: a
        // failure never severs the binding, and a different path still flows.
        function test_aFailedThumbnailNeverSeversItsBinding() {
            ignoreWarning(/QML Image: Cannot open: .*afloat-no-such-thumbnail\.svg/)
            openClipboardRoute(4712)
            var row = page.resultAt(1)
            verify(row)
            page._thumbDecoded("4712", testRoot.brokenPath)
            tryVerify(function() { return row.thumbFailed === true }, 3000)
            verify(row.thumbPath.length > 0, "the bound path must survive the failure")

            page._thumbDecoded("4712", testRoot.loadableImage)
            tryVerify(function() { return row.thumbnailItem.status === Image.Ready }, 3000)
            verify(row.thumbnailItem.visible, "a fresh path must load and show")
            verify(!row.thumbFailed)
            page.session.close()
        }

        // --- a built-in command's icon name must be resolved, not inlined ----

        function test_builtinCommandIconsGoThroughTheResolver() {
            var commands = LauncherAdapters.builtinCommands()
            var lookups = []
            var adapters = LauncherAdapters.createAdapters({
                appsSource: { values: [] },
                commands: commands,
                iconResolver: function(name) {
                    lookups.push(name)
                    return name ? "image://icon/" + name : ""
                }
            })
            var pulled = null
            adapters.apps.refresh("", "apps", function(outcome) { pulled = outcome })

            verify(pulled && pulled.length > 0, "the built-in commands must stream a result")
            verify(lookups.length > 0,
                "the built-in commands never asked the icon resolver for anything")
            for (var i = 0; i < pulled.length; i++) {
                verify(pulled[i].icon.length > 0,
                    "built-in command " + pulled[i].id + " carries no icon at all")
                verify(pulled[i].icon.indexOf("image://") === 0,
                    "built-in command " + pulled[i].id + " carries the bare icon name '"
                    + pulled[i].icon + "', which Image.source resolves as a relative file path")
            }
        }

        // The consequence, at the row: a bare name resolves against the
        // component's own directory and errors for good, so the card keeps its
        // text and shows an empty icon slot. A URL does not.
        function test_aBareIconNameLeavesTheRowWithAnEmptyIconSlot() {
            ignoreWarning(/QML Image: Cannot open: .*\/modules\/lazerbar\/lock$/)
            var bare = rowComponent.createObject(testRoot, {
                result: { id: "cmd", displayName: "锁屏", description: "Lock the session",
                          icon: "lock" }
            })
            verify(bare)
            tryVerify(function() { return bare.iconItem.status === Image.Error }, 3000)
            compare(bare.displayName, "锁屏", "the row keeps its text")
            verify(bare.iconItem.paintedWidth <= 0, "the icon slot is empty")

            bare.result = { id: "cmd2", displayName: "锁屏", description: "Lock the session",
                            icon: testRoot.loadableImage }
            tryVerify(function() { return bare.iconItem.status === Image.Ready }, 3000)
            verify(bare.iconItem.paintedWidth > 0, "a real source paints the icon")
            bare.destroy()
        }
    }
}