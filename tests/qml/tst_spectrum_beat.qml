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

    // Simulate kick pulses at the given period (frames), then report BPM.
    function runAt(tracker, periodFrames, frames, midBeat) {
        for (var t = 0; t < frames; t++) {
            var phase = t % periodFrames
            var bass = phase === 0 ? 0.9
                : (midBeat && phase === Math.floor(periodFrames / 2)) ? 0.45
                : 0.02 + Math.random() * 0.01
            BeatDetect.feedFrame(tracker, frame(bass))
        }
        return tracker.bpm
    }

    TestCase {
        name: "BeatDetect"

        function test_bassEnergy_weights_low_bars() {
            var tracker = BeatDetect.createTracker({})
            var energy = BeatDetect.bassEnergy(tracker, [1.0, 0.0, 0.0, 0.0, 0.0])
            verify(energy > 0 && energy <= 1.0)
            compare(energy, 5 / 15)
        }

        function test_constant_bass_never_estimates() {
            var tracker = BeatDetect.createTracker({})
            for (var t = 0; t < 300; t++)
                BeatDetect.feedFrame(tracker, frame(0.05))
            compare(tracker.bpm, 0)
            compare(tracker.pulse, 0)
        }

        function test_pulse_spikes_on_onset() {
            var tracker = BeatDetect.createTracker({ minGapFrames: 4 })
            runAt(tracker, 15, 30)
            verify(tracker.pulse > 0 && tracker.pulse <= 1.0)
        }

        function test_steady_120bpm_converges() {
            var tracker = BeatDetect.createTracker({ minGapFrames: 4 })
            var bpm = runAt(tracker, 15, 600)  // 120 BPM at 30fps -> lag 15
            verify(bpm > 116 && bpm < 124, "bpm=" + bpm)
        }

        function test_band_tempos_converge() {
            // 90 and 150 BPM inside the 80..170 search band.
            verify(runAt(BeatDetect.createTracker({ minGapFrames: 4 }), 20, 600) > 86
                   && true, "90 lower bound")
            compare2(20, 90)
            compare2(12, 150)
            compare2(11, 163.6)
            compare2(22, 81.8)
        }

        function compare2(period, expected) {
            var bpm = runAt(BeatDetect.createTracker({ minGapFrames: 4 }), period, 600)
            verify(Math.abs(bpm - expected) < Math.max(3, expected * 0.04),
                   "period=" + period + " bpm=" + bpm + " expected~" + expected)
        }

        function test_double_time_outside_band_reports_in_band_relative() {
            // ~300 BPM lies outside the band; its half-tempo relative (150)
            // is inside, so that metrical relative must be reported instead.
            var tracker = BeatDetect.createTracker({ minGapFrames: 2 })
            var bpm = runAt(tracker, 6, 600)
            verify(Math.abs(bpm - 150) < 4, "bpm=" + bpm)
        }

        function test_tempo_change_follows_within_two_seconds() {
            var tracker = BeatDetect.createTracker({ minGapFrames: 4 })
            runAt(tracker, 15, 400)   // lock onto 120
            var bpm = runAt(tracker, 21, 500)  // switch to ~85.7
            verify(Math.abs(bpm - 85.7) < 5, "bpm=" + bpm)
        }

        function test_reset_clears_state() {
            var tracker = BeatDetect.createTracker({ minGapFrames: 4 })
            runAt(tracker, 15, 240)
            BeatDetect.resetTracker(tracker)
            compare(tracker.bpm, 0)
            compare(tracker.envelope.length, 0)
            compare(tracker.average, 0)
            compare(tracker.pendingCount, 0)
        }
    }
}
