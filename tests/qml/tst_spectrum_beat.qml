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

        function test_instrumentation_fill_does_not_shift_bpm() {
            // Locked at 142; a drum fill injects three offbeat intervals at
            // ~1.5x before the steady beat resumes. The readout must hold.
            const clock = BeatClock.createClock({})
            let t = 0.5
            for (let i = 0; i < 15; i++) { BeatClock.feedBeat(clock, t); t += 60 / 142 }
            for (let f = 0; f < 3; f++) { BeatClock.feedBeat(clock, t); t += 60 / 213 }
            for (let k = 0; k < 6; k++) { BeatClock.feedBeat(clock, t); t += 60 / 142 }
            verify(Math.abs(clock.bpm - 142) < 5, "bpm=" + clock.bpm)
        }

        function test_sustained_tempo_change_relocks() {
            const clock = BeatClock.createClock({})
            let t = 0.5
            for (let i = 0; i < 12; i++) { BeatClock.feedBeat(clock, t); t += 60 / 120 }
            // Genuine half-time section: all following beats at 85 BPM.
            for (let j = 0; j < 20; j++) { BeatClock.feedBeat(clock, t); t += 60 / 85 }
            verify(Math.abs(clock.bpm - 85) < 6, "bpm=" + clock.bpm)
        }

        function test_low_confidence_beats_do_not_touch_history() {
            const clock = BeatClock.createClock({})
            let t = 0.5
            for (let i = 0; i < 10; i++) { BeatClock.feedBeat(clock, t); t += 60 / 120 }
            const lockedBpm = clock.bpm
            // Quiet bridge: beats keep coming but with near-zero confidence.
            for (let j = 0; j < 8; j++) {
                BeatClock.feedBeat(clock, t, 0.05)
                t += 60 / 160
            }
            compare(clock.bpm, lockedBpm)
            compare(clock.intervals.length, BeatClock.defaultOptions.intervalHistory)
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
