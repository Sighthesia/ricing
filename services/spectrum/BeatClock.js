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
    minGapSeconds: 0.12
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

        lastBeatSeconds: -1,
        intervals: [],
        bpm: 0
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

    clock.intervals.push(elapsed)
    if (clock.intervals.length > clock.intervalHistory)
        clock.intervals.shift()

    if (clock.intervals.length < 2)
        return clock.bpm

    var estimated = 60 / median(clock.intervals)
    if (estimated < clock.minBpm * 0.95 || estimated > clock.maxBpm * 1.05)
        return clock.bpm
    estimated = Math.min(Math.max(estimated, clock.minBpm), clock.maxBpm)

    // Light smoothing keeps the readout stable between beats.
    clock.bpm = clock.bpm > 0 ? clock.bpm * 0.7 + estimated * 0.3 : estimated
    return clock.bpm
}

// Reset all state (track change / stream idle).
function resetClock(clock) {
    clock.lastBeatSeconds = -1
    clock.intervals = []
    clock.bpm = 0
}
