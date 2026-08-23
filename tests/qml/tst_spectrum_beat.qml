import QtQuick
import QtTest
import "../../services/spectrum/BeatDetect.js" as BeatDetect

Item {
    // Build one 24-bar cava frame with the given bass level and near-zero rest.
    function frame(bass) {
        var values = []
        for (var i = 0; i < 24; i++)
            values.push(i < BeatDetect.defaultOptions.bassBars ? bass : 0.01)
        return values
    }

    // Simulate kick pulses at the given period (frames) for a while, then
    // report the tracker's settled BPM.
    function runAt(tracker, periodFrames, frames) {
        var fired = false
        for (var t = 0; t < frames; t++) {
            var phase = t % periodFrames
            var bass = phase === 0 ? 0.9 : (phase === 1 ? 0.5 : 0.05 + Math.random() * 0.02)
            if (BeatDetect.feedFrame(tracker, frame(bass)))
                fired = true
        }
        return fired
    }

    TestCase {
        name: "BeatDetect"

        function test_bassEnergy_weights_low_bars() {
            var tracker = BeatDetect.createTracker({})
            var energy = BeatDetect.bassEnergy(tracker, [1.0, 0.0, 0.0, 0.0, 0.0])
            verify(energy > 0 && energy <= 1.0)
            compare(energy, 5 / 15)
        }

        function test_silence_never_fires_or_estimates() {
            var tracker = BeatDetect.createTracker({})
            for (var t = 0; t < 300; t++)
                verify(!BeatDetect.feedFrame(tracker, frame(0.01)))
            compare(tracker.bpm, 0)
            compare(tracker.pulse, 0)
        }

        function test_pulse_spikes_and_decays_on_onset() {
            var tracker = BeatDetect.createTracker({})
            runAt(tracker, 15, 90)
            verify(tracker.pulse > 0)
            verify(tracker.pulse <= 1.0)
        }

        function test_steady_120bpm_converges_near_target() {
            var tracker = BeatDetect.createTracker({ minGapFrames: 4 })
            runAt(tracker, 15, 240)  // 120 BPM at 30fps -> every 15 frames
            verify(tracker.bpm > 100 && tracker.bpm < 145,
                   "bpm=" + tracker.bpm)
        }

        function test_fast_tempo_folds_into_musical_range() {
            var tracker = BeatDetect.createTracker({ minGapFrames: 4 })
            runAt(tracker, 6, 300)   // ~300 raw BPM -> folds to ~150
            verify(tracker.bpm >= BeatDetect.defaultOptions.minBpm
                   && tracker.bpm <= BeatDetect.defaultOptions.maxBpm,
                   "bpm=" + tracker.bpm)
        }

        function test_reset_clears_state() {
            var tracker = BeatDetect.createTracker({ minGapFrames: 4 })
            runAt(tracker, 15, 180)
            BeatDetect.resetTracker(tracker)
            compare(tracker.bpm, 0)
            compare(tracker.intervals.length, 0)
            compare(tracker.average, 0)
        }
    }
}
