---
name: quickshell-process-stdio-hazards
description: "Use when an Afloat service shells out through Quickshell's Process/StdioCollector and gets wrong results, stale results, or results that flip between runs: a command that looks like it launched with the right arguments but didn't, a stdout handler that seems to run on empty input, a result that gets overwritten by the other stream, or a callback that reports the previous run's exit code."
---

# Quickshell Process / StdioCollector hazards

Three independent traps in `Quickshell.Io`. All three were hit while fixing the
Wi-Fi panel, and all three fail *silently* — the process exits 0 and nothing
warns, so the symptom is just "the data is wrong".

## 1. `running: true` in the same turn as a `command` input change launches the PREVIOUS argv

`Process.command` is a **binding**, and QML re-evaluates bindings lazily. This
is wrong and looks correct:

```qml
scanProcess.someArg = uuids      // invalidates the command binding
scanProcess.running = true       // starts with the OLD command value
```

The doc phrase "will affect the next started process" is not enough to trust:
starting in the same turn can use the pre-change value. The failure is
indistinguishable from success — nmcli simply runs with the wrong arguments.

**Rule: never assign a `command` input and `running: true` in the same turn.**
Separate them by one event-loop turn:

```qml
someArg = uuids
Qt.callLater(function () { if (!process.running) process.running = true })
// or a 0-interval Timer, which is the repo's other idiom
```

**Rule: one Process per distinct command shape.** Reusing one Process for two
phases (e.g. "modify the secret, then activate") means flipping `command`
between two `running` writes in a single turn, which starts the *old* phase
again. Two Processes is cheaper than the debugging.

**Rule: read the result from an immutable job snapshot, not from the Process's
own properties.** If the user can start a second run before the first settles,
`onExited` reading `process.someArg` reports run 1's exit code as run 2's
result. Copy the inputs into a plain object at submit time and read that.

## 2. `StdioCollector.onStreamFinished` fires on stream CLOSE, not on content

An empty stream still finishes. So this is a trap:

```qml
stderr: StdioCollector {
    onStreamFinished: { state = fallbackFrom(text) }   // runs on success too!
}
```

A clean run's stderr handler still executes and **overwrites** the result the
stdout handler just applied. Symptom: correct data, then mysteriously wrong
data one turn later; usually intermittent, because it depends on which stream
closes first.

**Rule: every stderr handler starts with `if (!text.trim()) return`.**

**Rule: when stderr is a *fallback* path (not just logging), also gate on
whether stdout already applied a result** — reset a per-run flag when you
launch, set it in the stdout handler:

```qml
Process {
    property bool resultApplied: false
    stdout: StdioCollector { onStreamFinished: { result = parse(text); resultApplied = true } }
    stderr: StdioCollector {
        onStreamFinished: {
            if (!text.trim() || resultApplied) return
            result = fallback()
        }
    }
}
```

## 3. `running` is Quickshell's to flip, so `if (!p.running)` guards lie mid-pipeline

`onExited` / `streamFinished` can run while `running` still reads `true` (the
process is exiting, not gone). So `if (p.running) return` before launching the
next stage of a chain silently drops that stage — and the pipeline just stops
with no error.

**Rule: do not use `running` as a "did this stage already start" flag.** Use an
explicit stage variable, and let each stage decide. Chain stages through
`Qt.callLater` so the previous Process is fully down first.

## 4. Never publish an empty "I don't know yet" state

Distinct from the mechanics, but this is how the above becomes a user-visible
bug: a transient hiccup that produced no rows was written as `state = ({})`,
and an empty map means "nothing is saved" — which is a *different, wrong*
claim, not a stale-but-safe one.

**Rule: only publish the empty state when the call genuinely succeeded with
zero rows. Any partial or failed read keeps the previous value.** Stale beats
wrong.

## Verification

These are timing bugs: a single green run proves nothing. Run the root-level
harness (`qs -p tst_*.qml`) **at least 10 times** before believing a fix, and
put a cross-check Process in the harness that re-reads the same source
independently and compares — that is what surfaced the overwrite in (2).
