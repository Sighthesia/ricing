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
    // fraction from the current readout are held out of the history. Must
    // stay wider than aubio's natural timestamp jitter (~±5-9% on busy
    // sections) or normal micro-timing trips a relock storm.
    lockBandFraction: 0.14,
    // After this many consecutive out-of-band beats the tempo genuinely
    // changed: drop the history and relock onto the new tempo.
    relockAfterBeats: 8,
    // Consecutive consistent intervals required to confirm a new tempo
    // after a relock before the display switches over.
    minConfirmBeats: 5
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
        minConfirmBeats: typeof opts.minConfirmBeats === "number" ? opts.minConfirmBeats : defaultOptions.minConfirmBeats,
        lastBeatSeconds: -1,
        intervals: [],
        bpm: 0,
        divergentStreak: 0,
        // Relock confirmation: after a reset the old readout stays on
        // display until the new tempo proves itself (minConfirmBeats
        // mutually-consistent intervals). Prevents garbage sections from
        // hijacking the readout for seconds at a time.
        rebuilding: false,
        confirmIntervals: [],
        // Slow-moving reference tempo built over steady stretches; used to
        // reject excursion levels (double-time tracking etc.) on relock.
        anchorBpm: 0,
        steadyBeats: 0,
        rejectedStreak: 0,
        rebuildBeats: 0
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
    // do not drag it away. A sustained divergence enters rebuilding: the old
    // readout stays displayed until fresh intervals prove a stable new tempo.
    if (clock.bpm > 0 && !clock.rebuilding) {
        var impliedNow = 60 / elapsed
        if (Math.abs(impliedNow - clock.bpm) / clock.bpm > clock.lockBandFraction) {
            clock.divergentStreak += 1
            if (clock.divergentStreak < clock.relockAfterBeats)
                return clock.bpm
            // Genuine tempo change: rebuild behind the old display value.
            clock.divergentStreak = 0
            clock.rebuilding = true
            clock.confirmIntervals = [elapsed]
            return clock.bpm
        }
        clock.divergentStreak = 0

        // Slow reference tempo for excursion rejection (see rebuild path).
        clock.steadyBeats = Math.min(clock.steadyBeats + 1, 200)
        if (clock.bpm > 0)
            clock.anchorBpm = clock.anchorBpm > 0
                ? clock.anchorBpm + (clock.bpm - clock.anchorBpm) * 0.03
                : clock.bpm
    }

    // Rebuild guard: with fewer than three intervals an outlier seed must
    // not anchor the median — replace the seed instead of stacking on it.
    if (clock.intervals.length > 0 && clock.intervals.length < 3) {
        var seedMedian = median(clock.intervals)
        if (Math.abs(elapsed - seedMedian) / seedMedian > 0.3) {
            clock.intervals = [elapsed]
            return clock.bpm
        }
    }

    // While rebuilding, only switch the display once the candidate tempo is
    // internally consistent for minConfirmBeats consecutive intervals.
    if (clock.rebuilding) {
        var consistent = clock.confirmIntervals.length === 0
            || Math.abs(elapsed - median(clock.confirmIntervals)) / median(clock.confirmIntervals) <= 0.06
        if (!consistent) {
            clock.confirmIntervals = [elapsed]
            return clock.bpm
        }
        clock.confirmIntervals.push(elapsed)
        clock.rebuildBeats += 1

        // Candidate ready for evaluation once enough consistent intervals
        // are in; adoption may still be vetoed by the anchor guard below.
        if (clock.confirmIntervals.length >= clock.minConfirmBeats || clock.rebuildBeats >= 60)
        {
            var candidateNow = clampBpm(clock, 60 / median(clock.confirmIntervals))
            var anchorTrusted = clock.anchorBpm > 0 && clock.steadyBeats >= 20
            var strays = candidateNow <= 0
                || (anchorTrusted && Math.abs(candidateNow - clock.anchorBpm) / clock.anchorBpm > 0.20)

            // A long-running rebuild eventually wins: the excursion really
            // is the song now (or capture went away and came back different).
            var forceAdopt = clock.rebuildBeats >= 60 && candidateNow > 0

            if (strays && !forceAdopt) {
                // Hold the old readout; visuals still pulse to beats.
                if (clock.rejectedStreak < 5)
                    clock.rejectedStreak += 1
                if (clock.confirmIntervals.length >= clock.minConfirmBeats)
                    clock.confirmIntervals = []
                return clock.bpm
            }

            clock.rejectedStreak = 0
            clock.rebuilding = false
            clock.divergentStreak = 0
            clock.intervals = clock.confirmIntervals.slice(-clock.intervalHistory)
            clock.bpm = candidateNow
            clock.anchorBpm = candidateNow
            clock.steadyBeats = 0
            clock.rebuildBeats = 0
            clock.confirmIntervals = []
            return clock.bpm
        }
        return clock.bpm
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
    clock.rebuilding = false
    clock.confirmIntervals = []
    clock.anchorBpm = 0
    clock.steadyBeats = 0
    clock.rejectedStreak = 0
    clock.rebuildBeats = 0
}
