import QtQuick
import QtTest
import "../../services/spectrum/BeatClock.js" as BeatClock

Item {
    TestCase {
        name: "BeatClock"

        function test_silence_yields_no_bpm() {
            const clock = BeatClock.createClock({})
            compare(BeatClock.feedBeat(clock, 1.0), 0)
            compare(BeatClock.feedBeat(clock, 2.5), 0)
            compare(BeatClock.feedBeat(clock, 4.0), 0)
            compare(clock.bpm, 0)
        }

        function test_steady_beats_converge() {
            // 142 BPM -> interval ~0.4225s
            const clock = BeatClock.createClock({})
            let t = 0.5
            for (let i = 0; i < 20; i++) {
                BeatClock.feedBeat(clock, t)
                t += 60 / 142
            }
            verify(Math.abs(clock.bpm - 142) < 4, "bpm=" + clock.bpm)
        }

        function test_out_of_band_interval_folds() {
            // ~300 BPM (0.2s) folds to half tempo (0.4s -> 150 BPM).
            const clock = BeatClock.createClock({})
            let t = 0.5
            for (let i = 0; i < 20; i++) {
                BeatClock.feedBeat(clock, t)
                t += 0.2
            }
            verify(Math.abs(clock.bpm - 150) < 4, "bpm=" + clock.bpm)
        }

        function test_double_triggers_ignored() {
            const clock = BeatClock.createClock({})
            let t = 0.5
            for (let i = 0; i < 12; i++) {
                BeatClock.feedBeat(clock, t)
                t += 60 / 120
                BeatClock.feedBeat(clock, t)  // spurious echo right after
            }
            verify(Math.abs(clock.bpm - 120) < 6, "bpm=" + clock.bpm)
        }

        function test_tempo_change_follows() {
            const clock = BeatClock.createClock({})
            let t = 0.5
            for (let i = 0; i < 15; i++) { BeatClock.feedBeat(clock, t); t += 60 / 120 }
            for (let j = 0; j < 15; j++) { BeatClock.feedBeat(clock, t); t += 60 / 90 }
            verify(Math.abs(clock.bpm - 90) < 8, "bpm=" + clock.bpm)
        }

        function test_gap_does_not_poison_history() {
            const clock = BeatClock.createClock({})
            let t = 0.5
            for (let i = 0; i < 10; i++) { BeatClock.feedBeat(clock, t); t += 0.5 }  // 120 BPM
            BeatClock.feedBeat(clock, t + 30)  // long pause
            t += 30
            for (let j = 0; j < 8; j++) { BeatClock.feedBeat(clock, t); t += 0.5 }
            verify(Math.abs(clock.bpm - 120) < 8, "bpm=" + clock.bpm)
        }

        function test_reset_clears_state() {
            const clock = BeatClock.createClock({})
            let t = 0.5
            for (let i = 0; i < 10; i++) { BeatClock.feedBeat(clock, t); t += 0.5 }
            BeatClock.resetClock(clock)
            compare(clock.bpm, 0)
            compare(clock.intervals.length, 0)
            compare(clock.lastBeatSeconds, -1)
        }
    }
}
