import QtQuick
import QtTest
import "../../modules/lazerbar/WallpaperBootLogic.js" as Boot

// Contract for the wallpaper-first boot gate: a screen is keyed by identity
// plus geometry, completion is recorded per key, and every currently present
// screen must report finished before the boot reveal is allowed to start.
Item {
    TestCase {
        name: "WallpaperBoot"
        when: windowShown
        visible: true

        function screens() {
            return [
                { name: "DP-1", x: 0, y: 0, width: 1920, height: 1080 },
                { name: "HDMI-1", x: 1920, y: 0, width: 1920, height: 1080 },
            ]
        }

        function test_keyIncludesGeometry() {
            compare(Boot.screenKey("DP-1", 0, 0, 1920, 1080),
                    "DP-1@0,0,1920x1080")
            verify(Boot.screenKey("DP-1", 0, 0, 1920, 1080)
                   !== Boot.screenKey("DP-1", 0, 0, 2560, 1440))
        }

        function test_currentKeysAreStable() {
            compare(Boot.currentKeys(screens()), [
                "DP-1@0,0,1920x1080",
                "HDMI-1@1920,0,1920x1080",
            ])
        }

        function test_duplicateCompletionIsIgnored() {
            var key = Boot.screenKey("DP-1", 0, 0, 1920, 1080)
            var once = Boot.markFinished([], key)
            var twice = Boot.markFinished(once, key)
            compare(once, [key])
            compare(twice, [key])
        }

        function test_allScreensMustFinish() {
            var keys = Boot.currentKeys(screens())
            var first = Boot.markFinished([], keys[0])
            verify(!Boot.isReady(first, keys))
            var second = Boot.markFinished(first, keys[1])
            verify(Boot.isReady(second, keys))
        }

        function test_removedScreenDoesNotBlock() {
            var keys = Boot.currentKeys(screens())
            var finished = Boot.markFinished([], keys[0])
            compare(Boot.currentKeys([screens()[0]]), [keys[0]])
            verify(Boot.isReady(finished, Boot.currentKeys([screens()[0]])))
        }

        function test_addedScreenBlocksUntilFinished() {
            var original = screens()
            var originalKeys = Boot.currentKeys(original)
            var finished = Boot.markFinished([], originalKeys[0])
            finished = Boot.markFinished(finished, originalKeys[1])
            var added = original.concat([
                { name: "DP-2", x: 0, y: 1080, width: 1920, height: 1080 },
            ])
            var addedKeys = Boot.currentKeys(added)
            verify(!Boot.isReady(finished, addedKeys))
            finished = Boot.markFinished(finished, addedKeys[2])
            verify(Boot.isReady(finished, addedKeys))
        }

        function test_emptyScreensAreNotReady() {
            verify(!Boot.isReady([], []))
        }
    }
}
