// Beat-interval -> BPM estimation over timestamps from the aubio bridge.
// No QML dependencies — operates on plain arrays and numbers.

var defaultOptions = {
    // Inter-beat intervals kept for the median estimate.
    intervalHistory: 8,
    // Intervals are folded into [minInterval, maxInterval] (half/double
    // tempo) before entering the history; values outside after folding are
    // discarded as spurious double-triggers or gaps.
    minIntervalSeconds: 0.25,
    maxIntervalSeconds: 2.0,
    // Folded BPM readout is clamped into this band.
    minBpm: 80,
    maxBpm: 170,
    // Ignore beats closer than this to the previous one (double-triggers).
    minGapSeconds: 0.12,
    // --- tempo lock (instrumentation-change stability) ---
    // Once locked, intervals whose implied tempo drifts more than this
    // fraction from the current readout are held out of the history.
    lockBandFraction: 0.07,
    // After this many consecutive out-of-band beats the tempo genuinely
    // changed: drop the history and relock onto the new tempo.
    relockAfterBeats: 6
}

function createClock(options) {
    var opts = options || {}
    return {
        intervalHistory: typeof opts.intervalHistory === "number" ? opts.intervalHistory : defaultOptions.intervalHistory,
        minIntervalSeconds: typeof opts.minIntervalSeconds === "number" ? opts.minIntervalSeconds : defaultOptions.minIntervalSeconds,
        maxIntervalSeconds: typeof opts.maxIntervalSeconds === "number" ? opts.maxIntervalSeconds : defaultOptions.maxIntervalSeconds,
        minBpm: typeof opts.minBpm === "number" ? opts.minBpm : defaultOptions.minBpm,
        maxBpm: typeof opts.maxBpm === "number" ? opts.maxBpm : defaultOptions.maxBpm,
        minGapSeconds: typeof opts.minGapSeconds === "number" ? opts.minGapSeconds : defaultOptions.minGapSeconds,
        lockBandFraction: typeof opts.lockBandFraction === "number" ? opts.lockBandFraction : defaultOptions.lockBandFraction,
        relockAfterBeats: typeof opts.relockAfterBeats === "number" ? opts.relockAfterBeats : defaultOptions.relockAfterBeats,

        lastBeatSeconds: -1,
        intervals: [],
        bpm: 0,
        divergentStreak: 0
    }
}

function median(values) {
    var sorted = values.slice().sort(function (a, b) { return a - b })
    var mid = Math.floor(sorted.length / 2)
    if (sorted.length % 2 === 1)
        return sorted[mid]
    return (sorted[mid - 1] + sorted[mid]) / 2
}

// Consume one beat timestamp; returns the updated BPM readout (0 until at
// least two usable intervals have been seen).
//
// Note: aubio's beat confidence is unbounded (observed range -100..+10), so
// it must not be used as a 0..1 quality gate — stability comes from the
// tempo-lock hysteresis below alone.
function feedBeat(clock, seconds) {
    if (!(seconds >= 0))
        return clock.bpm

    var elapsed = seconds - clock.lastBeatSeconds
    clock.lastBeatSeconds = seconds

    if (!(elapsed > clock.minGapSeconds))
        return clock.bpm

    // Fold into the musical window so out-of-band multiples stay usable.
    var guard = 0
    while (elapsed < clock.minIntervalSeconds && guard < 8) {
        elapsed *= 2
        guard += 1
    }
    guard = 0
    while (elapsed > clock.maxIntervalSeconds && guard < 8) {
        elapsed /= 2
        guard += 1
    }
    if (elapsed < clock.minIntervalSeconds || elapsed > clock.maxIntervalSeconds) {
        // Keep the timestamp (phase stays valid) but skip the interval.
        return clock.bpm
    }

    // Tempo lock: once a readout exists, hold divergent intervals out of the
    // history so instrumentation changes (fills, solos, half-time sections)
    // do not drag it away. A sustained divergence clears the state and lets
    // fresh intervals rebuild the estimate (no single-interval adoption).
    if (clock.bpm > 0) {
        var implied = 60 / elapsed
        if (Math.abs(implied - clock.bpm) / clock.bpm > clock.lockBandFraction) {
            clock.divergentStreak += 1
            if (clock.divergentStreak < clock.relockAfterBeats)
                return clock.bpm
            // Genuine tempo change: start over from scratch.
            clock.divergentStreak = 0
            clock.intervals = []
            clock.bpm = 0
            return 0
        }
        clock.divergentStreak = 0
    }

    // Rebuild guard: with fewer than three intervals (fresh start or just
    // after a relock) an outlier seed must not anchor the median — replace
    // the seed instead of stacking against it.
    if (clock.intervals.length > 0 && clock.intervals.length < 3) {
        var seedMedian = median(clock.intervals)
        if (Math.abs(elapsed - seedMedian) / seedMedian > 0.3) {
            clock.intervals = [elapsed]
            return clock.bpm
        }
    }

    clock.intervals.push(elapsed)
    if (clock.intervals.length > clock.intervalHistory)
        clock.intervals.shift()

    if (clock.intervals.length < 2)
        return clock.bpm

    var estimated = 60 / median(clock.intervals)
    estimated = clampBpm(clock, estimated)
    if (estimated <= 0)
        return clock.bpm

    // Light smoothing keeps the readout stable between beats.
    clock.bpm = clock.bpm > 0 ? clock.bpm * 0.7 + estimated * 0.3 : estimated
    return clock.bpm
}

// Accept an implied tempo only inside the band (with edge tolerance).
function clampBpm(clock, bpm) {
    if (!(bpm > 0))
        return 0
    if (bpm < clock.minBpm * 0.97 || bpm > clock.maxBpm * 1.03)
        return 0
    return Math.min(Math.max(bpm, clock.minBpm), clock.maxBpm)
}

// Reset all state (track change / stream idle).
function resetClock(clock) {
    clock.lastBeatSeconds = -1
    clock.intervals = []
    clock.bpm = 0
    clock.divergentStreak = 0
}
