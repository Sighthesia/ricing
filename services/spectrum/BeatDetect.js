// Pure bass-onset BPM estimation over cava spectrum frames.
// No QML dependencies — operates on plain arrays and numbers.
//
// Feed one frame per cava frame (values 0..1, lowest bar first). The tracker
// watches the low-frequency bars, fires an onset when energy spikes above an
// adaptive threshold, and derives BPM from the median of recent inter-beat
// intervals with half/double tempo folding into a musical range.

var defaultOptions = {
    // Bars counted as "bass" (cava log-spaces 50..12000Hz over 24 bars,
    // so the first few bars cover kick/bass fundamentals).
    bassBars: 5,
    // Onset fires when bass exceeds average * onsetRatio.
    onsetRatio: 1.35,
    // Bass must reach this floor so silence noise never triggers onsets.
    minEnergy: 0.08,
    // Frames between accepted onsets (~267ms at 30fps -> caps ~225 BPM).
    minGapFrames: 8,
    // Inter-beat intervals kept for median BPM estimation.
    intervalHistory: 12,
    // Intervals outside this window (seconds) are discarded as spurious.
    minIntervalSeconds: 0.25,
    maxIntervalSeconds: 2.0,
    // Folded BPM is clamped into this range.
    minBpm: 70,
    maxBpm: 180
}

function createTracker(options) {
    var opts = options || {}
    return {
        frameDuration: typeof opts.frameDuration === "number" ? opts.frameDuration : 1 / 30,
        bassBars: typeof opts.bassBars === "number" ? opts.bassBars : defaultOptions.bassBars,
        onsetRatio: typeof opts.onsetRatio === "number" ? opts.onsetRatio : defaultOptions.onsetRatio,
        minEnergy: typeof opts.minEnergy === "number" ? opts.minEnergy : defaultOptions.minEnergy,
        minGapFrames: typeof opts.minGapFrames === "number" ? opts.minGapFrames : defaultOptions.minGapFrames,
        intervalHistory: typeof opts.intervalHistory === "number" ? opts.intervalHistory : defaultOptions.intervalHistory,
        minIntervalSeconds: typeof opts.minIntervalSeconds === "number" ? opts.minIntervalSeconds : defaultOptions.minIntervalSeconds,
        maxIntervalSeconds: typeof opts.maxIntervalSeconds === "number" ? opts.maxIntervalSeconds : defaultOptions.maxIntervalSeconds,
        minBpm: typeof opts.minBpm === "number" ? opts.minBpm : defaultOptions.minBpm,
        maxBpm: typeof opts.maxBpm === "number" ? opts.maxBpm : defaultOptions.maxBpm,

        average: 0.0,
        variance: 0.0,
        framesSinceBeat: 0,
        intervals: [],
        bpm: 0,
        pulse: 0
    }
}

// Weighted mean of the low-frequency bars; earlier bars weigh slightly more.
function bassEnergy(tracker, values) {
    if (!values || !values.length)
        return 0
    var count = Math.min(tracker.bassBars, values.length)
    var sum = 0
    var weightSum = 0
    for (var i = 0; i < count; i++) {
        var weight = count - i
        sum += values[i] * weight
        weightSum += weight
    }
    return weightSum > 0 ? sum / weightSum : 0
}

function foldBpm(bpm) {
    var folded = bpm
    var guard = 0
    while (folded < defaultOptions.minBpm && guard < 8) {
        folded *= 2
        guard += 1
    }
    guard = 0
    while (folded > defaultOptions.maxBpm && guard < 8) {
        folded /= 2
        guard += 1
    }
    if (folded < defaultOptions.minBpm || folded > defaultOptions.maxBpm)
        return 0
    return folded
}

function median(values) {
    var sorted = values.slice().sort(function (a, b) { return a - b })
    var mid = Math.floor(sorted.length / 2)
    if (sorted.length % 2 === 1)
        return sorted[mid]
    return (sorted[mid - 1] + sorted[mid]) / 2
}

// Consume one spectrum frame; returns true when an onset (beat) registered.
function feedFrame(tracker, values) {
    tracker.pulse *= 0.85
    if (tracker.pulse < 0.01)
        tracker.pulse = 0
    tracker.framesSinceBeat += 1

    var bass = bassEnergy(tracker, values)

    // Adaptive baseline via exponential moving statistics.
    var delta = bass - tracker.average
    tracker.average += delta * 0.12
    tracker.variance += (delta * delta - tracker.variance) * 0.12

    var dynamicFloor = Math.max(tracker.minEnergy, tracker.average * 0.5)
    var aboveThreshold = bass > tracker.average * tracker.onsetRatio && bass > dynamicFloor
    var gapOk = tracker.framesSinceBeat >= tracker.minGapFrames

    if (!aboveThreshold || !gapOk)
        return false

    var fired = false
    if (tracker.framesSinceBeat > tracker.minGapFrames) {
        // Fold the raw interval into the musical window (half/double tempo)
        // so very fast or slow pulses still land inside the sane BPM band.
        var seconds = tracker.framesSinceBeat * tracker.frameDuration
        var guard = 0
        while (seconds < tracker.minIntervalSeconds && guard < 8) {
            seconds *= 2
            guard += 1
        }
        guard = 0
        while (seconds > tracker.maxIntervalSeconds && guard < 8) {
            seconds /= 2
            guard += 1
        }
        if (seconds >= tracker.minIntervalSeconds && seconds <= tracker.maxIntervalSeconds) {
            tracker.intervals.push(seconds)
            if (tracker.intervals.length > tracker.intervalHistory)
                tracker.intervals.shift()
            var estimated = foldBpm(60 / median(tracker.intervals))
            if (estimated > 0) {
                // Light smoothing keeps the readout stable between beats.
                tracker.bpm = tracker.bpm > 0 ? tracker.bpm * 0.7 + estimated * 0.3 : estimated
            }
            fired = true
        }
    }

    tracker.framesSinceBeat = 0
    tracker.pulse = 1
    return fired
}

// Reset all adaptive state (track change / stream idle).
function resetTracker(tracker) {
    tracker.average = 0
    tracker.variance = 0
    tracker.framesSinceBeat = 0
    tracker.intervals = []
    tracker.bpm = 0
    tracker.pulse = 0
}
