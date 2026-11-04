.pragma library

// Which niri bind does a key press resolve to?
//
// This mirrors `niri-config/src/binds.rs` (the sequence parser) and
// `src/input/mod.rs` (`bind_matches_trigger`), because the answer has to agree
// with the compositor: the panel shows the name of the action that is about to
// run, and an answer that disagreed would name a different action than the one
// the key press actually triggers.
//
// Pure JavaScript on purpose. It is the one part of this feature that can be
// read - and checked with `node` against the user's real config - without
// instantiating a service, a compositor or a shell.
//
// Reference: niri, GPL-3.0, https://github.com/YaLTeR/niri
//   niri-config/src/binds.rs  (FromStr for Key)
//   src/input/mod.rs          (bind_matches_trigger, find_bind)

// Modifier bits. The ORDER is niri's own modifier order, and the bit positions
// are what the key helper's output mask already uses (see
// `scripts/window_hint_trigger.py`), so a frame's mask needs no translation.
var SHIFT = 1 << 0
var CTRL = 1 << 1
var ALT = 1 << 2
var SUPER = 1 << 3
var ISO3 = 1 << 4
var ISO5 = 1 << 5
// `Mod` in a config file: the compositor's own mod key, not a modifier bit of
// its own. Kept as a separate bit so a bind written `Mod+Q` can be normalised
// against whichever physical modifier the compositor mod is.
var COMPOSITOR = 1 << 6

// The compositor mod key. niri's default on a TTY is Super; it is one named
// constant so the whole file agrees about it.
var MOD_KEY_NAME = "super"
var MOD_KEY_MODIFIER = SUPER

// Trigger kinds, so a sequence is parsed once into a comparable record rather
// than compared as a string. `keysym` is the only kind a keyboard can produce;
// the rest exist so they can be recognised and never match a key press.
var TRIGGER_KEYSYM = "keysym"
var TRIGGER_COMPOSITOR = "compositor"
var TRIGGER_MODIFIER = "modifier"
var TRIGGER_POINTER = "pointer"
var TRIGGER_SCROLL = "scroll"
var TRIGGER_TABLET = "tablet"

var _MODIFIER_WORDS = {
    "mod": COMPOSITOR,
    "ctrl": CTRL,
    "control": CTRL,
    "shift": SHIFT,
    "alt": ALT,
    "super": SUPER,
    "win": SUPER,
    "iso_level3_shift": ISO3,
    "mod5": ISO3,
    "iso_level5_shift": ISO5,
    "mod3": ISO5
}

// A generic-modifier trigger, as niri spells it. These are matched by the
// modifier they imply rather than by a keysym.
var _GENERIC_MODIFIER_TRIGGERS = {
    "ctrl": CTRL,
    "control": CTRL,
    "shift": SHIFT,
    "alt": ALT,
    "super": SUPER,
    "win": SUPER,
    "iso_level3_shift": ISO3,
    "mod5": ISO3,
    "iso_level5_shift": ISO5,
    "mod3": ISO5
}

var _POINTER_TRIGGERS = {
    "mouseleft": true,
    "mouseright": true,
    "mousemiddle": true,
    "mouseback": true,
    "mouseforward": true
}

// Parses one sequence ("Mod+Shift+Slash") into what a key press is compared
// against. Returns null for anything this file cannot represent - which is the
// safe direction: an unparsed bind simply never matches, so the panel keeps the
// previous answer instead of naming a wrong action.
function parseSequence(sequence) {
    var text = String(sequence == null ? "" : sequence)
    if (text.indexOf("\0") >= 0)
        return null

    var parts = text.split("+")
    var key = parts.length > 0 ? parts[parts.length - 1] : ""
    var modifiers = 0

    for (var index = 0; index < parts.length - 1; index++) {
        var word = String(parts[index]).trim().toLowerCase()
        if (_MODIFIER_WORDS[word] === undefined)
            return null
        modifiers |= _MODIFIER_WORDS[word]
    }

    var lowerKey = key.trim().toLowerCase()
    var trigger = { kind: TRIGGER_KEYSYM, keysym: lowerKey, modifier: 0 }

    if (_POINTER_TRIGGERS[lowerKey]) {
        trigger.kind = TRIGGER_POINTER
    } else if (lowerKey.indexOf("wheelscroll") === 0
            || lowerKey.indexOf("touchpadscroll") === 0) {
        trigger.kind = TRIGGER_SCROLL
    } else if (lowerKey.indexOf("tabletstylusbutton") === 0) {
        trigger.kind = TRIGGER_TABLET
    } else if (lowerKey === "mod") {
        trigger.kind = TRIGGER_COMPOSITOR
    } else if (_GENERIC_MODIFIER_TRIGGERS[lowerKey] !== undefined) {
        trigger.kind = TRIGGER_MODIFIER
        trigger.modifier = _GENERIC_MODIFIER_TRIGGERS[lowerKey]
    } else if (lowerKey === "") {
        return null
    }

    return { sequence: text, trigger: trigger, modifiers: modifiers }
}

// Does a press of `keysym` with `held` modifiers satisfy `parsed`?
//
// A direct port of niri's `bind_matches_trigger`, including the two
// normalisations that make `Mod+Q` and `Super+Q` the same bind and that make a
// bind ON the mod key itself work:
//
//  * `Mod` (COMPOSITOR) and the physical mod-key bit are interchangeable, so a
//    bind written either way matches either way;
//  * when the TRIGGER is the mod key, neither side requires it - which is how
//    `Mod { quit; }` fires from a bare press of super.
function matches(parsed, keysym, held) {
    if (!parsed)
        return false

    var trigger = parsed.trigger
    var pressed = String(keysym == null ? "" : keysym).toLowerCase()
    var heldModifiers = held | 0
    var required = parsed.modifiers | 0

    var triggerIsModKey = false
    if (trigger.kind === TRIGGER_COMPOSITOR) {
        triggerIsModKey = true
    } else if (trigger.kind === TRIGGER_MODIFIER) {
        triggerIsModKey = trigger.modifier === MOD_KEY_MODIFIER
    } else if (trigger.kind === TRIGGER_KEYSYM) {
        triggerIsModKey = _isModKeyKeysym(trigger.keysym)
    }

    if (triggerIsModKey) {
        heldModifiers &= ~MOD_KEY_MODIFIER
        required &= ~(COMPOSITOR | MOD_KEY_MODIFIER)
    } else {
        if (heldModifiers & MOD_KEY_MODIFIER)
            heldModifiers |= COMPOSITOR
        if (required & COMPOSITOR)
            required |= MOD_KEY_MODIFIER
        else if (required & MOD_KEY_MODIFIER)
            required |= COMPOSITOR
    }

    // The modifiers must match EXACTLY. A bind is not a prefix: `Mod+E` does not
    // fire from `Mod+Shift+E`, and treating it as a match would name an action
    // the compositor is not about to run.
    if (required !== heldModifiers)
        return false

    if (trigger.kind === TRIGGER_KEYSYM)
        return trigger.keysym === pressed

    if (trigger.kind === TRIGGER_COMPOSITOR)
        return _isModKeyKeysym(pressed)

    if (trigger.kind === TRIGGER_MODIFIER) {
        // A generic-modifier bind fires from a press of any key carrying that
        // modifier, which for a keyboard means the modifier key itself.
        return _impliedModifier(pressed) === trigger.modifier
    }

    // Pointer, wheel and tablet triggers cannot be produced by a key press.
    return false
}

function _isModKeyKeysym(keysym) {
    var name = String(keysym == null ? "" : keysym).toLowerCase()
    return name === "super_l" || name === "super_r" || name === "super"
}

// The modifier a keysym implies, which is how niri turns "the key that was
// pressed is shift" into "this is a shift bind".
function _impliedModifier(keysym) {
    switch (String(keysym == null ? "" : keysym).toLowerCase()) {
    case "shift_l":
    case "shift_r":
    case "shift":
        return SHIFT
    case "control_l":
    case "control_r":
    case "ctrl":
    case "control":
        return CTRL
    case "alt_l":
    case "alt_r":
    case "alt":
        return ALT
    case "super_l":
    case "super_r":
    case "super":
        return SUPER
    case "iso_level3_shift":
        return ISO3
    case "iso_level5_shift":
        return ISO5
    default:
        return 0
    }
}

// The first bind in `entries` that a press of `keysym` with `held` satisfies.
//
// FIRST, not best: niri resolves overlapping binds by definition order, so two
// binds on the same key resolve to whichever was written first, and this has to
// name the same one.
function matchBind(entries, keysym, held) {
    var list = entries || []
    for (var index = 0; index < list.length; index++) {
        var entry = list[index]
        if (!entry)
            continue
        var parsed = entry._parsed || parseSequence(entry.sequence)
        if (matches(parsed, keysym, held))
            return entry
    }
    return null
}

// ---- Display ----

// Modifier names as the user reads them, in the order a key combination is
// conventionally written. `Mod` is shown as the key it actually is, because the
// user is holding that key and a panel that said "Mod" would be naming the
// config file's spelling rather than the keyboard in front of them.
//
// The order is the order niri's own configs write them in (`Mod+Ctrl+Shift+Right`),
// so a bind the user can see in their config file reads back the same way here.
var _MODIFIER_LABELS = [
    { bit: SUPER, label: "Super" },
    { bit: CTRL, label: "Ctrl" },
    { bit: ALT, label: "Alt" },
    { bit: SHIFT, label: "Shift" },
    { bit: ISO5, label: "Level5" }
]

// Keysyms whose display name is not the keysym name. Everything not listed here
// keeps its keysym name with the first letter capitalised, which is right for
// `Space`, `Return`, `F5`, `Print` and every `XF86*` key.
var _KEYSYM_LABELS = {
    "space": "Space",
    "grave": "`",
    "minus": "-",
    "equal": "=",
    "slash": "/",
    "backslash": "\\",
    "bracketleft": "[",
    "bracketright": "]",
    "semicolon": ";",
    "apostrophe": "'",
    "comma": ",",
    "period": ".",
    "tab": "Tab",
    "return": "Enter",
    "escape": "Esc",
    "backspace": "Backspace",
    "prior": "PageUp",
    "next": "PageDown",
    "delete": "Delete",
    "insert": "Insert",
    "home": "Home",
    "end": "End",
    "left": "\u2190",
    "right": "\u2192",
    "up": "\u2191",
    "down": "\u2193"
}

function modifierLabel(modifiers) {
    var bits = modifiers | 0
    var labels = []
    for (var index = 0; index < _MODIFIER_LABELS.length; index++) {
        var entry = _MODIFIER_LABELS[index]
        if (bits & entry.bit)
            labels.push(entry.label)
    }
    return labels
}

function keysymLabel(keysym) {
    var name = String(keysym == null ? "" : keysym)
    if (name === "")
        return ""
    var lower = name.toLowerCase()
    if (_KEYSYM_LABELS[lower] !== undefined)
        return _KEYSYM_LABELS[lower]
    // A single character is a letter or a digit: upper-case it, so "e" reads as
    // "E" and the combination reads like the key cap.
    if (name.length === 1)
        return name.toUpperCase()
    return name.charAt(0).toUpperCase() + name.slice(1)
}

// The canonical display form of a key combination: "Super+Shift+Space".
//
// Built from the LIVE modifier mask and the pressed keysym rather than copied
// from the config file, so a bind written `Mod+E` reads as the keys the user
// actually pressed (`Super+E`). That is the whole point of showing it: the
// sequence confirms which key was understood.
//
// An EMPTY keysym means "just the modifiers", which is what the hint's rail
// shows while the mod key is held on its own: the panel is the overview, and the
// key standing it up is Super. Without this the label would end in a bare "+".
function sequenceLabel(modifiers, keysym) {
    var parts = modifierLabel(modifiers)
    var key = keysymLabel(keysym)
    if (key !== "")
        parts.push(key)
    return parts.join("+")
}

// The modifiers a sequence requires, as the display bits above - for a bind
// whose own spelling is what should be shown (a latched bind, after its key has
// been released and its live mask is gone).
function sequenceModifierBits(sequence) {
    var parsed = parseSequence(sequence)
    if (!parsed)
        return 0
    var bits = parsed.modifiers & ~COMPOSITOR
    if (parsed.modifiers & COMPOSITOR)
        bits |= MOD_KEY_MODIFIER
    return bits
}

function sequenceKeysym(sequence) {
    var parsed = parseSequence(sequence)
    if (!parsed)
        return ""
    if (parsed.trigger.kind === TRIGGER_KEYSYM)
        return parsed.trigger.keysym
    return ""
}

// The display form of a bind's own sequence, for the latched state.
function labelForSequence(sequence) {
    var bits = sequenceModifierBits(sequence)
    var keysym = sequenceKeysym(sequence)
    if (keysym === "")
        return String(sequence == null ? "" : sequence)
    return sequenceLabel(bits, keysym)
}
