import QtQuick
import QtTest
import "../../modules/lazerbar" as Lazer
import "../../modules/lazerbar/WallpaperMotionLogic.js" as Motion

// The boot reveal and a live switch are two different timing contracts, and the
// decision lives in a shared JS module so this test reads the same rule the
// component runs instead of restating it.
Item {
    id: root

    // Stand-ins for the token values; the identity of a number is all this needs.
    readonly property int bootDuration: 3000
    readonly property int swapDuration: 480
    readonly property int bootEasing: 42
    readonly property int swapEasing: 43

    TestCase {
        name: "WallpaperMotionLogic"
        when: windowShown

        function test_theBootRevealTakesTheBootContract() {
            verify(Motion.isBootReveal(true))
            compare(Motion.revealDuration(true, root.bootDuration, root.swapDuration),
                    root.bootDuration)
            compare(Motion.revealEasing(true, root.bootEasing, root.swapEasing),
                    root.bootEasing)
        }

        function test_aLiveSwitchTakesTheSwapContract() {
            verify(!Motion.isBootReveal(false))
            compare(Motion.revealDuration(false, root.bootDuration, root.swapDuration),
                    root.swapDuration)
            compare(Motion.revealEasing(false, root.bootEasing, root.swapEasing),
                    root.swapEasing)
        }

        // The handover between the two is read from a live property, so an
        // undefined or stale read must resolve to the fast path rather than
        // stranding the user behind a three-second open.
        function test_onlyALiteralTrueIsABootReveal() {
            compare(Motion.isBootReveal(undefined), false)
            compare(Motion.isBootReveal(null), false)
            compare(Motion.isBootReveal(1), false)
            compare(Motion.isBootReveal("true"), false)
            compare(Motion.isBootReveal(1), false)
            compare(Motion.revealDuration(undefined, root.bootDuration,
                                          root.swapDuration), root.swapDuration)
        }

        function test_theBootContractIsActuallyDistinctAndSlower() {
            // Guards against the two contracts silently collapsing into one,
            // which would make every assertion above pass for the wrong reason.
            verify(root.bootDuration > root.swapDuration,
                   "the boot reveal must be the slower of the two")
            verify(root.bootEasing !== root.swapEasing,
                   "the boot reveal must not reuse the swap curve")
        }

        // The real tokens, not the stand-ins above: the boot contract is
        // DymicShell's background window, so 3000ms at its default speedFactor
        // of 1.0 with InOutSine. Pinned so a future retune is a deliberate edit
        // rather than a drift nobody notices.
        function test_theBootTokensAreDymicShellsNumbers() {
            compare(Lazer.MotionTokens.wallpaperBootReveal, 3000,
                    "DymicShell's reveal is Math.round(3000 / speedFactor) at 1.0")
            compare(Lazer.MotionTokens.wallpaperBootRevealEasing, Easing.InOutSine)
            // And the live switch is untouched by that change.
            compare(Lazer.MotionTokens.wallpaperSwap, 480)
            verify(Lazer.MotionTokens.wallpaperBootReveal
                   > Lazer.MotionTokens.wallpaperSwap,
                   "the boot reveal must be the slower of the two")
        }
    }
}
