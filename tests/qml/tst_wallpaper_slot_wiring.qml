import QtQuick
import QtTest

// Contract for the wallpaper slot handover *as written*. The behaviour lives in
// WallpaperBackground's PanelWindow, which cannot be instantiated headlessly —
// offscreen has no layer-shell backend — so this reads the production file and
// pins the seams that the two-slot change introduced and the old
// baseImage/reveal.nextWallpaper handoff removed. The complementary root harness
// (`tst_wallpaper_startup_slots.qml`) asserts the same contract at runtime where
// a window exists.
//
// Requires file reads: run with QML_XHR_ALLOW_FILE_READ=1.
Item {
    id: harness

    function readText(url) {
        var xhr = new XMLHttpRequest()
        xhr.open("GET", url, false)
        xhr.send(null)
        return { status: xhr.status, text: xhr.responseText }
    }

    readonly property var source: readText(
        Qt.resolvedUrl("../../modules/lazerbar/WallpaperBackground.qml"))

    // The body of a member, found by its id, so a name mentioned in a comment
    // or in a caller never counts as a declaration.
    function bodyOf(needle) {
        var start = harness.source.text.indexOf(needle)
        if (start < 0)
            return ""
        return harness.source.text.slice(start, harness.source.text.length)
    }

    TestCase {
        name: "WallpaperSlotWiring"
        when: windowShown
        visible: true

        function test_sourceIsReadable() {
            verify(harness.source.status === 200, "WallpaperBackground.qml must be readable")
            verify(harness.source.text.length > 2000,
                   "WallpaperBackground.qml looks truncated")
        }

        // Two fixed slots, not one base image plus a private reveal image: a slot
        // that is re-declared per switch would defeat the whole promotion.
        function test_twoFixedSlotsAreDeclared() {
            var text = harness.source.text
            verify(text.indexOf("id: wallpaperSlot0") >= 0, "slot 0 must be declared")
            verify(text.indexOf("id: wallpaperSlot1") >= 0, "slot 1 must be declared")
            verify(text.indexOf("id: baseImage") < 0, "the single baseImage layer is gone")
        }

        // Both slots fill the surface the same way, and neither caches: a
        // full-screen wallpaper never fits QPixmapCache, so caching it only holds
        // a second copy.
        function test_bothSlotsShareTheDecodeContract() {
            for (var slot = 0; slot < 2; slot++) {
                var body = harness.bodyOf("id: wallpaperSlot" + slot).slice(0, 700)
                verify(body.indexOf("fillMode: Image.PreserveAspectCrop") >= 0,
                       "slot " + slot + " must crop to fill")
                verify(body.indexOf("cache: false") >= 0, "slot " + slot + " must not cache")
                verify(body.indexOf("sourceSize: wallpaperWindow.wallpaperDecodeSize") >= 0,
                       "slot " + slot + " must use the capped decode size")
                verify(body.indexOf("visible: wallpaperWindow.settledSlot === " + slot) >= 0,
                       "slot " + slot + " visibility must follow its role")
            }
        }

        // A role is data, not a source: a binding that copied one slot's source
        // into the other would re-decode the wallpaper this task removes.
        function test_noSlotBorrowsTheOtherSlotsSource() {
            for (var slot = 0; slot < 2; slot++) {
                var body = harness.bodyOf("id: wallpaperSlot" + slot).slice(0, 700)
                verify(body.indexOf("source: wallpaperSlot") < 0,
                       "slot " + slot + " must not take its source from a slot")
                verify(body.indexOf("source: wallpaperWindow.settledImage.source") < 0,
                       "slot " + slot + " must not be bound to the settled source")
            }
            verify(harness.source.text.indexOf("settledImage.source = ") < 0,
                   "promotion must never assign a source to the settled slot")
            verify(harness.source.text.indexOf("baseImage.source = ") < 0,
                   "the old settled-layer handover is gone")
        }

        // The reveal borrows the incoming slot, so the wallpaper being revealed
        // is the wallpaper that gets promoted.
        function test_revealBorrowsTheIncomingSlot() {
            var body = harness.bodyOf("id: reveal")
            verify(body.indexOf("sourceItem: wallpaperWindow.incomingImage") >= 0,
                   "the reveal must mask the incoming slot")
        }

        // Promotion is a role swap plus a release, and the release happens after
        // the swap — the outgoing slot's decode is only pointless once it stops
        // being painted.
        function test_promotionSwapsRolesThenReleasesTheOldSlot() {
            var body = harness.bodyOf("function promoteIncoming()")
            var promoted = body.indexOf("SlotLogic.promote(")
            var settledAt = body.indexOf("settledSlot = roles.settledSlot")
            var incomingAt = body.indexOf("incomingSlot = roles.incomingSlot")
            var releasedAt = body.indexOf("released.source = \"\"")
            verify(promoted >= 0, "promotion must go through the pure slot helper")
            verify(settledAt >= 0 && incomingAt >= 0, "both roles must be reassigned")
            verify(releasedAt > settledAt && releasedAt > incomingAt,
                   "the old slot is released only after the roles swap")
            // The release targets the slot read *before* the swap, which is the
            // one that stops being settled; reading `settledImage` afterwards
            // would clear the wallpaper that was just promoted.
            verify(body.indexOf("var released = wallpaperWindow.settledImage") >= 0,
                   "the released slot must be captured before the swap")
        }

        // A collapsed role pair is the one promotion that cannot do: `released` is
        // then the very image being promoted, so releasing it would wipe the
        // wallpaper that is on screen. The pure helper deliberately returns an
        // equal pair as it is — tst_wallpaper_slot_logic pins that — so the
        // refusal has to live where the release happens. Fail closed: keep the
        // pixels, and hand the pair back distinct so the next switch still has a
        // spare slot.
        function test_promotionRefusesToReleaseThePromotedSlot() {
            var body = harness.bodyOf("function promoteIncoming()")
            var guard = body.indexOf("roles.settledSlot === roles.incomingSlot")
            var released = body.indexOf("released.source = \"\"")
            verify(guard >= 0, "promotion must refuse a collapsed slot pair")
            verify(released >= 0 && guard < released,
                   "the collapsed-pair guard must come before the release")
            verify(body.indexOf("SlotLogic.otherSlot(") > guard,
                   "a refused promotion must hand the pair back distinct")
            var warned = body.indexOf("console.warn", guard)
            verify(warned > guard && warned < released,
                   "a refused promotion must say so in the log")
        }

        // Promotion is only meaningful for a slot that decoded. A direct settle
        // of a broken path fails inside its own source assignment, and the
        // failure handler releases the slot — promoting it anyway would put an
        // empty slot on screen and wipe the wallpaper.
        function test_promotionRefusesToPromoteAnUndecodedSlot() {
            var body = harness.bodyOf("function promoteIncoming()")
            var guard = body.indexOf("incomingImage.status !== Image.Ready")
            var swap = body.indexOf("SlotLogic.promote(")
            var discard = body.indexOf("discardIncoming()")
            verify(guard >= 0, "promotion must check that the incoming slot decoded")
            verify(guard < swap, "the check must come before the role swap")
            verify(discard > guard && discard < swap,
                   "an undecoded incoming slot must be released, not promoted")
        }

        // The decode bound is explicit and justified rather than inherited: two
        // live slots at 4 bytes per pixel is the whole reason for a cap.
        function test_productionDecodeCapIsExplicit() {
            var body = harness.bodyOf("maxDecodePixels")
            verify(/maxDecodePixels:\s*\d+\s*\*\s*\d+\s*\*\s*\d+/.test(body),
                   "the production decode cap must be an explicit pixel budget")
            verify(body.length > 200, "the decode cap must carry its rationale")
            var decode = harness.bodyOf("readonly property size wallpaperDecodeSize")
            verify(decode.indexOf("SlotLogic.sourceSize(") >= 0,
                   "the decode size must come from the shared helper")
            verify(decode.indexOf("devicePixelRatio") >= 0,
                   "the decode size must account for the device pixel ratio")
        }

        // The root publishes its windows: a Variants scope cannot be walked from QML
        // at all, so tst_wallpaper_startup_slots reaches the slots through this
        // registry and would silently stop running if it went away.
        function test_theRootPublishesItsScreenWindows() {
            var text = harness.source.text
            verify(text.indexOf("function registerScreenWindow(window)") >= 0,
                   "the root must expose a way to register a screen window")
            verify(text.indexOf("function unregisterScreenWindow(window)") >= 0,
                   "an unplugged screen must not leave a destroyed window behind")
            // Reassigned, never mutated in place: a binding cannot see an in-place
            // JS array mutation, so every reader would freeze on the first value.
            verify(text.indexOf("root.screenWindows = root.screenWindows.concat(") >= 0,
                   "the registry must be replaced, not mutated")
            verify(text.indexOf("root.registerScreenWindow(wallpaperWindow)") >= 0,
                   "each screen window must register itself")
            verify(text.indexOf("root.unregisterScreenWindow(wallpaperWindow)") >= 0,
                   "each screen window must deregister itself")
        }

        // The boot classifier must compare against the settled slot, or every
        // boot wallpaper would look unchanged.
        function test_bootOutcomeComparesAgainstTheSettledSlot() {
            var body = harness.bodyOf("function bootOutcomeFor(path)")
            verify(body.indexOf("wallpaperWindow.settledImage.source") >= 0,
                   "bootOutcomeFor must compare against the settled slot's source")
            verify(body.indexOf("incomingImage.source") >= 0,
                   "a failure must be attributed to the incoming slot")
        }

        function test_bootReadinessWaitsForPersistedSettings() {
            var text = harness.source.text
            verify(text.indexOf("&& Services.SettingsService.settingsReady") >= 0,
                   "bootReady must not accept the adapter's empty default path")
            verify(text.indexOf("property bool bootWaitingForSettings") >= 0,
                   "a screen must remember that it is waiting for settings")
            verify(text.indexOf("onSettingsReadyChanged") >= 0,
                   "the boot wallpaper must resume after settings load")
        }
    }
}
