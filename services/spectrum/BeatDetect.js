// Bass-onset pulse + autocorrelation BPM estimation over cava spectrum frames.
// No QML dependencies — operates on plain arrays and numbers.
//
// Two signals come out of the same frame stream:
// - beat pulse: adaptive-threshold bass onset, drives `pulse` and the beat
//   return value (visual accents).
// - bpm: an onset-strength envelope is accumulated over ~8 seconds and a
//   normalized autocorrelation over musically relevant lags picks the dominant
//   tempo. Integrating over time makes the readout far more stable than
//   per-beat interval medians, which break on a single missed/false onset.

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

    // --- autocorrelation tempo estimation ---
    // Envelope history kept for analysis (frames). At 30fps this is ~8s,
    // which gives several periods of support across the whole band.
    envelopeLength: 240,
    // Perceived tapping tempo lives mostly in 80..170 BPM; searching only
    // that band sidesteps octave ambiguity (a true 180 would otherwise fight
    // its own 90 subharmonic whenever kick/snare alternate in strength).
    // Tempi outside the band report their nearest in-band metrical relative.
    minBpmSearch: 80,
    maxBpmSearch: 170,
    // Recompute tempo every N frames (~0.33s at 30fps) to bound CPU cost
    // while keeping tempo-change response snappy.
    analyzeEveryFrames: 10,
    // Need at least this many envelope frames before trusting an estimate
    // (2s at 30fps — the pending-switch guard absorbs early instability).
    minEnvelopeFrames: 60,
    // Readout clamp (mirrors the search band).
    minBpm: 80,
    maxBpm: 170
}

function createTracker(options) {
    var opts = options || {}
    return {
        frameDuration: typeof opts.frameDuration === "number" ? opts.frameDuration : 1 / 30,
        bassBars: typeof opts.bassBars === "number" ? opts.bassBars : defaultOptions.bassBars,
        onsetRatio: typeof opts.onsetRatio === "number" ? opts.onsetRatio : defaultOptions.onsetRatio,
        minEnergy: typeof opts.minEnergy === "number" ? opts.minEnergy : defaultOptions.minEnergy,
        minGapFrames: typeof opts.minGapFrames === "number" ? opts.minGapFrames : defaultOptions.minGapFrames,
        envelopeLength: typeof opts.envelopeLength === "number" ? opts.envelopeLength : defaultOptions.envelopeLength,
        minBpmSearch: typeof opts.minBpmSearch === "number" ? opts.minBpmSearch : defaultOptions.minBpmSearch,
        maxBpmSearch: typeof opts.maxBpmSearch === "number" ? opts.maxBpmSearch : defaultOptions.maxBpmSearch,
        analyzeEveryFrames: typeof opts.analyzeEveryFrames === "number" ? opts.analyzeEveryFrames : defaultOptions.analyzeEveryFrames,
        minEnvelopeFrames: typeof opts.minEnvelopeFrames === "number" ? opts.minEnvelopeFrames : defaultOptions.minEnvelopeFrames,
        minBpm: typeof opts.minBpm === "number" ? opts.minBpm : defaultOptions.minBpm,
        maxBpm: typeof opts.maxBpm === "number" ? opts.maxBpm : defaultOptions.maxBpm,

        average: 0.0,
        variance: 0.0,
        framesSinceBeat: 0,
        pulse: 0,

        envelope: [],
        previousBass: 0,
        frameCounter: 0,
        bpm: 0,
        pendingBpm: 0,
        pendingCount: 0
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

// Accept a raw estimate when it lands on the search band (parabolic
// interpolation may overshoot the edge slightly); otherwise reject.
function clampBpm(tracker, bpm) {
    if (!(bpm > 0))
        return 0
    if (bpm < tracker.minBpm * 0.97 || bpm > tracker.maxBpm * 1.03)
        return 0
    return Math.min(Math.max(bpm, tracker.minBpm), tracker.maxBpm)
}

// Half-wave rectified difference of bass energy — a classic onset envelope:
// only rises count, so sustained bass does not smear the periodicity peak.
function appendEnvelope(tracker, bass) {
    var rise = bass - tracker.previousBass
    tracker.previousBass = bass
    tracker.envelope.push(rise > 0 ? rise : 0)
    if (tracker.envelope.length > tracker.envelopeLength)
        tracker.envelope.shift()
}

function autocorrAt(env, n, lag) {
    var sum = 0
    for (var t = lag; t < n; t++)
        sum += env[t] * env[t - lag]
    return sum
}

// Normalized autocorrelation of the onset envelope over the BPM search band.
// Plain correlation: the band-limited search already removes octave fights,
// and a harmonic boost only amplifies the fast side of every ambiguity.
function estimateTempo(tracker) {
    var env = tracker.envelope
    var n = env.length
    if (n < tracker.minEnvelopeFrames)
        return 0

    var minLag = Math.max(2, Math.floor(1800 / tracker.maxBpmSearch))
    var maxLag = Math.min(n >> 1, Math.ceil(1800 / tracker.minBpmSearch))

    var energy = 0
    for (var e = 0; e < n; e++)
        energy += env[e] * env[e]
    if (energy <= 1e-9)
        return 0

    // Reject near-silent envelopes: without enough recent onset activity a
    // lone stale rise must not produce a spurious peak from an empty window.
    var activeRises = 0
    for (var a = 0; a < n; a++)
        if (env[a] > 0.02)
            activeRises += 1
    if (activeRises < 8)
        return 0

    var bestLag = -1
    var bestScore = 0
    for (var lag = minLag; lag <= maxLag; lag++) {
        var score = autocorrAt(env, n, lag) / energy
        if (score > bestScore) {
            bestScore = score
            bestLag = lag
        }
    }

    if (bestLag < 0 || bestScore < 0.05)
        return 0

    // Parabolic interpolation around the peak for sub-lag resolution.
    var refined = bestLag
    if (bestLag > minLag && bestLag < maxLag) {
        var rPrev = autocorrAt(env, n, bestLag - 1)
        var rHere = autocorrAt(env, n, bestLag)
        var rNext = autocorrAt(env, n, bestLag + 1)
        var denom = rPrev - 2 * rHere + rNext
        if (Math.abs(denom) > 1e-12)
            refined = bestLag + 0.5 * (rPrev - rNext) / denom
    }

    return refined > 0 ? 1800.0 / refined : 0
}

// Consume one spectrum frame; returns true when an onset (beat) registered.
function feedFrame(tracker, values) {
    tracker.pulse *= 0.85
    if (tracker.pulse < 0.01)
        tracker.pulse = 0
    tracker.framesSinceBeat += 1
    tracker.frameCounter += 1

    var bass = bassEnergy(tracker, values)
    appendEnvelope(tracker, bass)

    // Periodic tempo re-analysis over the accumulated envelope. A candidate
    // that disagrees with the current readout must persist for several
    // analyses before it takes over, so one noisy window cannot flip the
    // tempo, but a real track change still wins within ~1 second.
    if (tracker.frameCounter % tracker.analyzeEveryFrames === 0) {
        var raw = estimateTempo(tracker)
        if (raw > 0) {
            var folded = clampBpm(tracker, raw)
            if (folded > 0) {
                var agrees = tracker.bpm <= 0 || Math.abs(folded - tracker.bpm) / tracker.bpm < 0.08
                if (agrees) {
                    tracker.pendingBpm = 0
                    tracker.pendingCount = 0
                    tracker.bpm = tracker.bpm > 0 ? tracker.bpm * 0.6 + folded * 0.4 : folded
                } else {
                    if (Math.abs(folded - tracker.pendingBpm) / folded < 0.08)
                        tracker.pendingCount += 1
                    else
                        tracker.pendingCount = 1
                    tracker.pendingBpm = folded
                    if (tracker.pendingCount >= 3) {
                        tracker.bpm = folded
                        tracker.pendingBpm = 0
                        tracker.pendingCount = 0
                    }
                }
            }
        }
    }

    // Adaptive baseline via exponential moving statistics (onset gate only).
    var delta = bass - tracker.average
    tracker.average += delta * 0.12
    tracker.variance += (delta * delta - tracker.variance) * 0.12

    var dynamicFloor = Math.max(tracker.minEnergy, tracker.average * 0.5)
    var aboveThreshold = bass > tracker.average * tracker.onsetRatio && bass > dynamicFloor
    var gapOk = tracker.framesSinceBeat >= tracker.minGapFrames

    if (!aboveThreshold || !gapOk)
        return false

    tracker.framesSinceBeat = 0
    tracker.pulse = 1
    return true
}

// Reset all state (track change / stream idle).
function resetTracker(tracker) {
    tracker.average = 0
    tracker.variance = 0
    tracker.framesSinceBeat = 0
    tracker.pulse = 0
    tracker.envelope = []
    tracker.previousBass = 0
    tracker.frameCounter = 0
    tracker.bpm = 0
    tracker.pendingBpm = 0
    tracker.pendingCount = 0
}
