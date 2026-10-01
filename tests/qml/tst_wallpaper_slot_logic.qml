import QtQuick
import QtTest
import "../../modules/lazerbar/WallpaperSlotLogic.js" as Slots

// Contract for the two reusable wallpaper slots: which role the other slot is,
// how the roles swap once a reveal settles, and how large a decode may be asked
// for. Pure JS so promotion stays testable without a window.
Item {
    TestCase {
        name: "WallpaperSlotLogic"
        when: windowShown
        visible: true

        function test_otherSlotFlipsTheTwoRoles() {
            compare(Slots.otherSlot(0), 1)
            compare(Slots.otherSlot(1), 0)
        }

        function test_otherSlotIsFailClosedForInvalidInput() {
            compare(Slots.otherSlot(-1), 0)
            compare(Slots.otherSlot(2), 0)
            compare(Slots.otherSlot(1.5), 0)
            compare(Slots.otherSlot(""), 0)
            compare(Slots.otherSlot("1"), 0)
            compare(Slots.otherSlot(null), 0)
            compare(Slots.otherSlot(undefined), 0)
        }

        function test_promotionKeepsTheDecodedIncomingSlot() {
            compare(Slots.promote(0, 1), { settledSlot: 1, incomingSlot: 0 })
            compare(Slots.promote(1, 0), { settledSlot: 0, incomingSlot: 1 })
        }

        function test_promotionDoesNotSwapAnEqualPair() {
            compare(Slots.promote(0, 0), { settledSlot: 0, incomingSlot: 0 })
            compare(Slots.promote(1, 1), { settledSlot: 1, incomingSlot: 1 })
        }

        function test_promotionIsFailClosedForInvalidSlots() {
            // Roles never change for an input the classifier cannot read, and the
            // pair that comes back is always two real slots.
            compare(Slots.promote(0, 7), { settledSlot: 0, incomingSlot: 1 })
            compare(Slots.promote(-1, 1), { settledSlot: 0, incomingSlot: 1 })
            compare(Slots.promote(1, "0"), { settledSlot: 1, incomingSlot: 0 })
            compare(Slots.promote(undefined, undefined), { settledSlot: 0, incomingSlot: 1 })
            compare(Slots.promote(null, null), { settledSlot: 0, incomingSlot: 1 })
        }

        function test_promotionIsPure() {
            var result = Slots.promote(0, 1)
            compare(result, { settledSlot: 1, incomingSlot: 0 })
            // A second call on the promoted roles swaps them straight back, which
            // is only true if the first call mutated nothing it was handed.
            compare(Slots.promote(0, 1), { settledSlot: 1, incomingSlot: 0 })
            compare(Slots.promote(1, 0), { settledSlot: 0, incomingSlot: 1 })
        }

        function test_sourceSizeIsBoundedByScreenAndTextureBudget() {
            var size = Slots.sourceSize(3840, 2160, 2, 16 * 1024 * 1024)
            verify(size.width <= 7680)
            verify(size.height <= 4320)
            verify(size.width * size.height <= 16 * 1024 * 1024)
            verify(size.width > 0 && size.height > 0)
        }

        function test_sourceSizeUsesTheScreenWhenItFitsTheBudget() {
            compare(Slots.sourceSize(1920, 1080, 1, 16 * 1024 * 1024),
                    { width: 1920, height: 1080 })
        }

        function test_sourceSizeScalesWithTheDevicePixelRatio() {
            compare(Slots.sourceSize(1920, 1080, 2, 16 * 1024 * 1024),
                    { width: 3840, height: 2160 })
            compare(Slots.sourceSize(1280, 720, 1.5, 16 * 1024 * 1024),
                    { width: 1920, height: 1080 })
        }

        // A DPR below one would ask for fewer pixels than the screen has, which
        // is a blurry wallpaper rather than a cheaper one.
        function test_sourceSizeClampsTheDevicePixelRatioToAtLeastOne() {
            compare(Slots.sourceSize(1920, 1080, 0.5, 16 * 1024 * 1024),
                    { width: 1920, height: 1080 })
            compare(Slots.sourceSize(1920, 1080, 0, 16 * 1024 * 1024),
                    { width: 1920, height: 1080 })
            compare(Slots.sourceSize(1920, 1080, -3, 16 * 1024 * 1024),
                    { width: 1920, height: 1080 })
            compare(Slots.sourceSize(1920, 1080, undefined, 16 * 1024 * 1024),
                    { width: 1920, height: 1080 })
        }

        function test_sourceSizePreservesAspectRatioWhenClamped() {
            var size = Slots.sourceSize(3840, 2160, 2, 4 * 1024 * 1024)
            verify(size.width * size.height <= 4 * 1024 * 1024)
            verify(Math.abs(size.width / size.height - 16 / 9) < 0.01,
                   "clamping kept " + size.width + "x" + size.height + ", not 16:9")
            // The longer side is what gives way, so the pair stays inside the
            // untruncated screen size rather than growing past it.
            verify(size.width < 7680)
            verify(size.height < 4320)
        }

        function test_sourceSizeReturnsWholePixels() {
            var size = Slots.sourceSize(1366, 768, 1.25, 3 * 1024 * 1024)
            compare(Math.floor(size.width), size.width)
            compare(Math.floor(size.height), size.height)
            verify(size.width > 0 && size.height > 0)
        }

        function test_sourceSizeStaysPositiveForDegenerateGeometry() {
            compare(Slots.sourceSize(0, 0, 1, 1024), { width: 1, height: 1 })
            compare(Slots.sourceSize(undefined, undefined, 1, 1024), { width: 1, height: 1 })
            var missing = Slots.sourceSize(NaN, "nonsense", 1, 1024)
            verify(missing.width > 0 && missing.height > 0)
        }

        // An unusable cap falls back to the default texture budget instead of
        // collapsing the wallpaper to a single pixel.
        function test_sourceSizeIgnoresAnUnusableTextureCap() {
            compare(Slots.sourceSize(1920, 1080, 1, 0), { width: 1920, height: 1080 })
            compare(Slots.sourceSize(1920, 1080, 1, -1), { width: 1920, height: 1080 })
            compare(Slots.sourceSize(1920, 1080, 1, undefined), { width: 1920, height: 1080 })
            compare(Slots.sourceSize(1920, 1080, 1, "big"), { width: 1920, height: 1080 })
        }

        // A cap smaller than one pixel still has to produce a drawable image.
        function test_sourceSizeHonoursATinyTextureCap() {
            var size = Slots.sourceSize(3840, 2160, 2, 1)
            verify(size.width > 0 && size.height > 0)
            verify(size.width * size.height <= 1)
        }

        function test_sourceSizeIsPure() {
            var first = Slots.sourceSize(3840, 2160, 2, 4 * 1024 * 1024)
            var second = Slots.sourceSize(3840, 2160, 2, 4 * 1024 * 1024)
            compare(first, second)
        }
    }
}
