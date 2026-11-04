pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "./" as Services
import "nirishortcuts/NiriShortcutParser.js" as ShortcutParser
import "nirishortcuts/NiriKeybindMatch.js" as KeyMatch
import "nirishortcuts/NiriActionLabel.js" as ActionLabel
import "nirishortcuts/XkbKeycodes.js" as Keycodes

// Which niri bind is the key the user just pressed?
//
// The mod-key window hint shows what mod does, and its title rail names the
// action of the shortcut currently being held. That question has three parts and
// they live in three places, so this service is the seam between them:
//
//   * the BINDS come from niri's own config, read the way niri reads it - every
//     file named by an `include`, and every `binds {}` block in each of them
//     (`NiriShortcutParser`);
//   * the KEYS come from `WindowHintTriggerService`, which reads the keyboard
//     device and reports evdev key codes plus a modifier mask;
//   * the ANSWER is `NiriKeybindMatch`, a port of niri's own bind resolution, so
//     the name shown is the action the compositor is about to run.
//
// The latch is the part that is not obvious. A bound key is TAPPED while mod is
// held - space is down for ~100ms - so a live "which keys are down right now"
// answer would flash the action name for a frame and fall back to "Overview".
// The rail therefore reports the last bind that a press RESOLVED to, and keeps
// it until another bound key resolves or the hold ends. A press that resolves to
// nothing leaves the answer alone: the user's stray key must not wipe the thing
// they just asked about.
Singleton {
    id: root

    // Every parsed bind, in the order niri merges them - which is also the order
    // niri resolves overlapping binds in, so this list's order is load-bearing.
    property var binds: []
    property bool bindsLoaded: false

    // The latched bind: the last one a key press resolved to, kept for as long as
    // the hint is held. Null when the hold began and no bound key has arrived.
    property var liveBind: null
    // Its canonical sequence ("Super+Space"), built from the keys that were
    // pressed rather than copied from the config file's spelling.
    property string liveSequence: ""
    // Its action, as `{ key, args }` for `Tr.q`. Resolved in QML because a
    // translation is a binding on the language, not a value to cache.
    property var liveLabel: null

    // What the rail should say, translated. Empty means "nothing bound is being
    // held", and the rail falls back to the panel's own name.
    readonly property string bindLabel: root.liveLabel === null
        ? "" : Services.Tr.q(String(root.liveLabel.key || ""), root.liveLabel.args || {})
    readonly property string bindSequence: root.liveSequence

    // The sequence line while the rail is naming the PANEL rather than an action:
    // the mod key that is holding it open, so the overview says "Super" where a
    // bound key says "Super+Space". Empty when no modifier is held at all.
    //
    // Read off the live modifier mask rather than remembered from the press that
    // opened the panel, because that is the same source the bound-key labels use -
    // a rail that named one from a mask and the other from a latch could print two
    // different notions of what is currently down.
    readonly property string holdSequence: {
        if (root.liveSequence !== "")
            return root.liveSequence
        const modifiers = Services.WindowHintTriggerService.liveModifiers
        if (!modifiers || modifiers.super !== true)
            return ""
        return KeyMatch.sequenceLabel(KeyMatch.SUPER, "")
    }

    // Emitted when the ANSWER changes, not when a key moves: the rail only cares
    // about which action it is naming. Named `bindResolved` rather than
    // `liveBindChanged` because that one already exists as the property's own
    // change signal, and QML forbids overriding it.
    signal bindResolved()

    // ---- config reading ---------------------------------------------------

    // The files niri actually reads, in include order, and the keyboard layout
    // their key names are read in. Produced by `scripts/niri_config_dump.py`
    // rather than by reading the files here, and the reason is the include walk:
    // the file list is not known until `config.kdl` has been parsed, and a
    // reader created on demand cannot hand its text back on the frame it was
    // created - which is exactly what a synchronous walk needs. One process that
    // does the walk itself has no such question.
    //
    // Cheap because it is rare: once at startup, and again only when a config
    // file changes.
    property var sources: []
    property string xkbLayout: "us"
    readonly property bool reloadRunning: _configDump.running

    // The command is declared ONCE, on the process itself. Assigning it here and
    // starting in the same turn is the trap that makes a `Process` run the
    // previous argv: `command` is a binding input, so the launch is deferred a
    // turn and picks up whatever the property holds then. Restarting is
    // therefore only `running`, and the start is deferred explicitly so a
    // reload arriving in the same turn collapses into one run.
    function reload() {
        if (_configDump.running) {
            root._reloadPending = true
            return
        }
        root._reloadPending = false
        _configDump.running = true
    }

    property bool _reloadPending: false

    Process {
        id: _configDump

        // The command is a plain property here, assigned once. Restarting is
        // therefore only `running` (see `reload`), which is also what keeps a
        // reload from running the previous argv.
        command: ["python3", Quickshell.shellDir + "/scripts/niri_config_dump.py"]
        running: false

        // `StdioCollector`, not `SplitParser`: the dump is ONE line of JSON and
        // a split parser hands it over by dropping the newline, which is fine -
        // but a collector delivers it attached to the process having finished,
        // which is the moment the file list is actually complete. Either works
        // for one line; this one cannot be reached before the walk is done.
        stdout: StdioCollector {
            onStreamFinished: root._applyDump(String(text))
        }

        stderr: StdioCollector {
            onStreamFinished: {
                const message = String(text).trim()
                if (message !== "")
                    console.warn("[afloat:NiriKeybindService]", message)
            }
        }

        onExited: (exitCode) => {
            if (exitCode !== 0)
                console.warn("[afloat:NiriKeybindService] config dump exited with", exitCode)
            if (root._reloadPending)
                root.reload()
        }
    }

    function _applyDump(raw) {
        const text = String(raw || "").trim()
        if (text === "")
            return
        let dump = null
        try {
            dump = JSON.parse(text)
        } catch (error) {
            console.warn("[afloat:NiriKeybindService] could not parse the config dump:", error)
            return
        }

        const files = dump && dump.files ? dump.files : []
        root.sources = files
        const layout = dump && dump.xkb ? String(dump.xkb.layout || "") : ""
        root.xkbLayout = layout !== "" ? layout : "us"

        const entries = ShortcutParser.parseShortcutEntriesFromSources(files)
        root.binds = entries
        root.bindsLoaded = true
        root._watchSources()
    }

    // Config edits are rare and the answer is a list of strings, so a poll would
    // be both wasteful and racy. One watcher per source file, rebuilt when the
    // list changes - which is also what makes an `include` added to `config.kdl`
    // take effect.
    property var _watchers: []
    property var _watchedPaths: []

    function _watchSources() {
        const paths = []
        for (let index = 0; index < root.sources.length; index++)
            paths.push(String(root.sources[index].path || ""))
        if (paths.join("\n") === root._watchedPaths.join("\n"))
            return

        for (let index = 0; index < root._watchers.length; index++)
            root._watchers[index].destroy()
        root._watchers = []
        root._watchedPaths = paths

        for (let index = 0; index < paths.length; index++) {
            const watcher = watcherComponent.createObject(root, { path: paths[index] })
            if (watcher)
                root._watchers.push(watcher)
        }
    }

    Component {
        id: watcherComponent

        FileView {
            // `watchChanges` is the whole of this object: it does not read
            // anything, it only tells the service that a config file moved.
            blockLoading: false
            watchChanges: true
            printErrors: false
            onFileChanged: root.reload()
        }
    }

    // A zero-interval timer rather than `Component.onCompleted`: the process has
    // to be started from an event-loop turn, not from inside the singleton's own
    // construction. Started there, this `Process` is *created* - `onStarted`
    // fires - but its output is never delivered, and the shell runs on with an
    // empty bind list and no error to explain it. One turn later it behaves.
    Timer {
        interval: 0
        running: true
        repeat: false
        onTriggered: root.reload()
    }

    // ---- live keys --------------------------------------------------------

    Connections {
        target: Services.WindowHintTriggerService

        function onKeyFrame(frame) {
            root._handleFrame(frame)
        }

        function onActiveChanged() {
            // The hold ended: the panel is closing, so the answer goes with it.
            // Kept until now rather than cleared on release, which is the whole
            // reason the rail can name a key the user has already let go of.
            if (!Services.WindowHintTriggerService.active)
                root._clearLatch()
        }
    }

    function _handleFrame(frame) {
        if (!frame)
            return

        // Only presses latch. A release is what makes the answer STICK: the rail
        // keeps naming the action after the key is let go, which is the whole
        // reason a 100ms tap is readable at all.
        if (Number(frame.value) !== 1)
            return

        const keysym = Keycodes.keysymFor(Number(frame.pressed))
        if (keysym === "")
            return

        // A press of the mod key itself is what OPENS the panel, not a bind. The
        // mask a frame carries already includes the key it is reporting (the
        // helper adds it before emitting), so a bare mod press arrives as
        // "super held, key super" - which must not resolve to anything.
        if (root._isModifierKeysym(keysym))
            return

        const modifiers = root._modifierBits(frame.modifiers || {})
        const entry = KeyMatch.matchBind(root.binds, keysym, modifiers)
        if (!entry)
            return

        root._latch(entry, keysym, modifiers)
    }

    function _modifierBits(modifiers) {
        let bits = 0
        if (modifiers.shift)
            bits |= KeyMatch.SHIFT
        if (modifiers.ctrl)
            bits |= KeyMatch.CTRL
        if (modifiers.alt)
            bits |= KeyMatch.ALT
        if (modifiers.super)
            bits |= KeyMatch.SUPER
        if (modifiers.iso5)
            bits |= KeyMatch.ISO5
        return bits
    }

    function _isModifierKeysym(keysym) {
        const name = String(keysym).toLowerCase()
        return name === "super_l" || name === "super_r"
            || name === "control_l" || name === "control_r"
            || name === "shift_l" || name === "shift_r"
            || name === "alt_l" || name === "alt_r"
            || name === "iso_level3_shift" || name === "iso_level5_shift"
            || name === "caps_lock" || name === "num_lock"
    }

    function _latch(entry, keysym, modifiers) {
        const label = ActionLabel.labelForEntry(entry)
        const sequence = KeyMatch.sequenceLabel(modifiers, keysym)
        // Same bind, same sequence: nothing to announce. A held key repeating
        // must not re-trigger the rail's text transition.
        if (root.liveBind && String(root.liveBind.id) === String(entry.id)
                && root.liveSequence === sequence)
            return

        root.liveBind = entry
        root.liveSequence = sequence
        root.liveLabel = label
        root.bindResolved()
    }

    // Silent on purpose: this runs when the hold ENDS, and the rail is already
    // being torn down. Announcing the clear there rewrote the panel's lines on the
    // way out - the last action's name dropping back to the overview while the
    // panel was leaving - which reads as the same answer arriving twice. The next
    // hold republishes from scratch (`setHintHeld(true)` refreshes), so nothing is
    // lost by not announcing it.
    function _clearLatch() {
        if (root.liveBind === null && root.liveSequence === "")
            return
        root.liveBind = null
        root.liveSequence = ""
        root.liveLabel = null
    }
}
