import QtQuick
import QtTest
import "../../modules/lazerbar/StartupRevealLogic.js" as Logic

// Contract for the staged startup reveal: one monotonic stage ladder shared by
// the root coordinator, the lock wave gate, and the per-screen chrome
// aggregation. Pure JS so the ordering can be asserted without a shell.
Item {
    TestCase {
        name: "StartupRevealLogic"
        when: windowShown
        visible: true

        // Every declared stage, in the order the ladder climbs.
        readonly property var stageNames: [
            "lockedFloor", "wallpaperReveal", "chromeStaging", "quietReady",
        ]
        readonly property var events: [
            "wallpaper-ready", "chrome-mounted", "chrome-ready", "wave-started",
        ]

        function test_everyDeclaredStageIsADistinctOrderedInteger() {
            var previous = -1
            for (var index = 0; index < stageNames.length; index++) {
                var name = stageNames[index]
                var value = Logic.Stages[name]
                verify(typeof value === "number", name + " must be a number")
                compare(Math.floor(value), value, name + " must be an integer")
                verify(value > previous, name + " must sort after the stage below it")
                previous = value
            }
        }

        function test_stageOrderIsMonotonic() {
            compare(Logic.advance(Logic.Stages.lockedFloor, "wallpaper-ready"),
                    Logic.Stages.wallpaperReveal)
            compare(Logic.advance(Logic.Stages.wallpaperReveal, "chrome-mounted"),
                    Logic.Stages.chromeStaging)
            compare(Logic.advance(Logic.Stages.chromeStaging, "chrome-ready"),
                    Logic.Stages.chromeStaging)
            compare(Logic.advance(Logic.Stages.chromeStaging, "wave-started"),
                    Logic.Stages.quietReady)
            compare(Logic.advance(Logic.Stages.quietReady, "wallpaper-ready"),
                    Logic.Stages.quietReady)
            compare(Logic.advance(Logic.Stages.lockedFloor, "unknown"),
                    Logic.Stages.lockedFloor)
            compare(Logic.advance(Logic.Stages.lockedFloor, "chrome-mounted"),
                    Logic.Stages.chromeStaging)
        }

        // chrome-ready only records the gate: the stage stays on chromeStaging
        // until the lock wave itself starts, because quiet-ready is the wave.
        function test_chromeReadyRecordsWithoutAdvancingTheStage() {
            var staged = Logic.advance(Logic.Stages.wallpaperReveal, "chrome-mounted")
            compare(staged, Logic.Stages.chromeStaging)
            compare(Logic.advance(staged, "chrome-ready"), Logic.Stages.chromeStaging)
            compare(Logic.advance(staged, "wave-started"), Logic.Stages.quietReady)
        }

        function test_duplicateEventsAreIdempotent() {
            var stage = Logic.Stages.lockedFloor
            for (var index = 0; index < 3; index++) {
                stage = Logic.advance(stage, events[index])
            }
            compare(stage, Logic.Stages.chromeStaging)
            for (var repeat = 0; repeat < 3; repeat++) {
                compare(Logic.advance(stage, events[repeat]), stage,
                        "a repeated " + events[repeat] + " must not move the stage")
            }
            compare(Logic.advance(stage, events[3]), Logic.Stages.quietReady)
            // Everything after quiet-ready is a no-op: a late signal must never
            // send the ladder back down.
            for (var late = 0; late < events.length; late++) {
                compare(Logic.advance(Logic.Stages.quietReady, events[late]),
                        Logic.Stages.quietReady)
            }
        }

        // Exhaustive invariant: no event from no stage may move the ladder
        // backward, and the result is always one of the declared stages.
        function test_noEventFromAnyStageMovesBackward() {
            var hostile = events.concat([
                "", "unknown", "WALLPAPER-READY", "chrome_ready", null, undefined, 1, true,
            ])
            for (var stageIndex = 0; stageIndex < stageNames.length; stageIndex++) {
                var stage = Logic.Stages[stageNames[stageIndex]]
                for (var eventIndex = 0; eventIndex < hostile.length; eventIndex++) {
                    var next = Logic.advance(stage, hostile[eventIndex])
                    verify(next >= stage,
                           hostile[eventIndex] + " moved " + stageNames[stageIndex]
                           + " backward")
                    verify(stageNames.indexOf(stageNameOf(next)) >= 0,
                           "advance() returned the undeclared stage " + next)
                }
            }
        }

        // A known event arriving before its stage is dropped rather than
        // skipping the ladder, so a mis-wired caller cannot jump to quiet-ready.
        function test_outOfOrderEventsDoNotSkipAStage() {
            compare(Logic.advance(Logic.Stages.lockedFloor, "chrome-ready"),
                    Logic.Stages.lockedFloor)
            compare(Logic.advance(Logic.Stages.lockedFloor, "wave-started"),
                    Logic.Stages.lockedFloor)
            compare(Logic.advance(Logic.Stages.wallpaperReveal, "chrome-ready"),
                    Logic.Stages.wallpaperReveal)
            compare(Logic.advance(Logic.Stages.wallpaperReveal, "wave-started"),
                    Logic.Stages.wallpaperReveal)
            compare(Logic.advance(Logic.Stages.chromeStaging, "wallpaper-ready"),
                    Logic.Stages.chromeStaging)
        }

        // A stage the caller cannot read is read as the floor, so the next real
        // event still climbs the ladder instead of being dropped forever.
        function test_unknownStageStartsFromTheFloor() {
            compare(Logic.advance(undefined, "wallpaper-ready"), Logic.Stages.wallpaperReveal)
            compare(Logic.advance(99, "chrome-mounted"), Logic.Stages.chromeStaging)
            compare(Logic.advance(99, "unknown"), Logic.Stages.lockedFloor)
            compare(Logic.advance("chromeStaging", "wave-started"), Logic.Stages.lockedFloor)
        }

        function test_startupWaveNeedsBothGates() {
            verify(!Logic.waveAllowed(true, false, false))
            verify(!Logic.waveAllowed(true, true, false))
            verify(!Logic.waveAllowed(true, false, true))
            verify(Logic.waveAllowed(true, true, true))
            verify(Logic.waveAllowed(false, false, false))
        }

        // A manual request never consults the startup gates, so the configured
        // reveal behaviour cannot be delayed by a boot that is still settling.
        function test_manualRequestsIgnoreTheStartupGates() {
            verify(Logic.waveAllowed(false, false, false))
            verify(Logic.waveAllowed(false, true, true))
            verify(Logic.waveAllowed(false, false, true))
            verify(Logic.waveAllowed(false, true, false))
            verify(Logic.waveAllowed(undefined, false, false))
            verify(Logic.waveAllowed(null, false, false))
        }

        // Missing gates are not true: a startup surface must wait rather than
        // wave on an undefined readiness.
        function test_startupGatesAreFailClosed() {
            verify(!Logic.waveAllowed(true, undefined, true))
            verify(!Logic.waveAllowed(true, true, undefined))
            verify(!Logic.waveAllowed(true, undefined, undefined))
            // A truthy startup marker is still a startup marker: it must not slip
            // past the gates the way a falsy manual request does.
            verify(!Logic.waveAllowed(1, true, false))
            verify(!Logic.waveAllowed(1, false, true))
            verify(Logic.waveAllowed(1, true, true))
        }

        function test_everyCurrentScreenMustBeRecorded() {
            verify(!Logic.allScreensReady([], ["DP-1", "HDMI-1"]))
            verify(!Logic.allScreensReady(["DP-1"], ["DP-1", "HDMI-1"]))
            verify(!Logic.allScreensReady(["DP-1", "HDMI-1"], ["DP-1", "HDMI-1", "DP-2"]))
            verify(Logic.allScreensReady(["DP-1", "HDMI-1"], ["DP-1", "HDMI-1"]))
        }

        function test_noScreensIsNeverReady() {
            verify(!Logic.allScreensReady([], []))
            verify(!Logic.allScreensReady(["DP-1"], []))
            verify(!Logic.allScreensReady(["DP-1"], undefined))
            verify(!Logic.allScreensReady(undefined, undefined))
        }

        function test_aScreenThatLeftDoesNotBlockAndCannotResurrect() {
            verify(Logic.allScreensReady(["DP-1", "HDMI-1"], ["DP-1"]))
            // The completion recorded for a gone screen must never satisfy a
            // later screen of the same name appearing again.
            verify(!Logic.allScreensReady(["DP-1"], ["DP-1", "HDMI-1"]))
        }

        function test_screensAreMatchedByName() {
            verify(!Logic.allScreensReady(["DP-1"], ["DP-2"]))
            verify(!Logic.allScreensReady(["DP-1"], ["DP-1", "DP-2"]))
            verify(Logic.allScreensReady(["DP-1", "DP-2"], ["DP-2", "DP-1"]))
        }

        // A missing screen entry carries no identity to record, so it cannot
        // count as ready — and it does not make a finished screen unreadiness.
        function test_absentScreenEntriesAreSkipped() {
            verify(!Logic.allScreensReady([], [null, "DP-1"]))
            verify(Logic.allScreensReady(["DP-1"], [undefined, "DP-1"]))
            verify(!Logic.allScreensReady([], [null, undefined]))
        }

        function test_recordFinishedIgnoresDuplicatesAndKeepsOrder() {
            var once = Logic.recordFinished([], "DP-1")
            compare(once, ["DP-1"])
            compare(Logic.recordFinished(once, "DP-1"), ["DP-1"])
            compare(Logic.recordFinished(once, "HDMI-1"), ["DP-1", "HDMI-1"])
            var twice = Logic.recordFinished(Logic.recordFinished(once, "HDMI-1"), "HDMI-1")
            compare(twice, ["DP-1", "HDMI-1"])
        }

        function test_recordFinishedNeverMutatesTheCallerList() {
            var recorded = ["DP-1"]
            var added = Logic.recordFinished(recorded, "HDMI-1")
            compare(recorded, ["DP-1"])
            verify(added !== recorded)
        }

        function test_aRepeatedReportDoesNotChangeReadiness() {
            var recorded = Logic.recordFinished([], "DP-1")
            verify(!Logic.allScreensReady(recorded, ["DP-1", "HDMI-1"]))
            var reported = Logic.recordFinished(recorded, "DP-1")
            verify(!Logic.allScreensReady(reported, ["DP-1", "HDMI-1"]))
            verify(Logic.allScreensReady(
                Logic.recordFinished(reported, "HDMI-1"), ["DP-1", "HDMI-1"]))
        }

        // Read the booleans for gating, not the ladder: a surface that waits on
        // the stage alone would never learn that its own gate opened.
        function test_stageAndGatesAreIndependentReadinessChannels() {
            var stage = Logic.Stages.wallpaperReveal
            compare(Logic.advance(stage, "chrome-mounted"), Logic.Stages.chromeStaging)
            // Chrome is still working, so the wave gate stays shut even though
            // the ladder already climbed past the wallpaper.
            verify(!Logic.waveAllowed(true, true, false))
            verify(Logic.waveAllowed(true, true, true))
        }

        function stageNameOf(stage) {
            for (var index = 0; index < stageNames.length; index++) {
                if (Logic.Stages[stageNames[index]] === stage)
                    return stageNames[index]
            }
            return ""
        }
    }
}
