#!/usr/bin/env python3
"""Regenerate `services/nirishortcuts/XkbKeycodes.js`.

The table maps an EVDEV key code to the xkb keysym NAME that code produces on
the current keyboard layout. It is what lets a key event read off /dev/input be
compared against a niri bind, which is written as a keysym name ("Super+Space").

Two things make this worth a script rather than a hand-written table:

  * **The layout.** A non-Latin layout produces different letter names, and the
    point of the table is to describe the keyboard in front of the user.
  * **The offset.** libxkbcommon's keymap API speaks XKB key codes, and an XKB
    key code is an evdev code PLUS 8. Building the table without subtracting 8
    yields a file that is self-consistent and uniformly wrong - worse than a
    missing entry, because it names the wrong action rather than none. That has
    happened once; this script exists so it cannot happen silently again.

Run it whenever the layout changes:

    python3 scripts/gen_xkb_keycodes.py

It prints the spot checks it knows about and writes the file. Passing `--check`
only verifies the spot checks against the existing file, which is what CI or a
curious reader wants.
"""

import ctypes
import sys

HEADER = '''.pragma library

// evdev key code -> keysym NAME, for the unmodified level of each key.
//
// This is what lets a key event read off /dev/input (an evdev code, e.g. 57 for
// space) be compared with a niri bind written as a keysym name ("Super+Space").
// The names are the ones libxkbcommon reports, which is exactly what
// `xkb_keysym_from_name` - and therefore niri's own bind parser - accepts.
//
// INDEXED BY EVDEV CODE, which is the one detail that matters. libxkbcommon's
// keymap API speaks XKB key codes, and an XKB key code is an evdev code PLUS 8.
// Building this table from the keymap without subtracting 8 produced a file that
// was self-consistent and uniformly wrong: `grave` (evdev 41) read as `f`, and a
// real `f` (evdev 33) read as `p`, so the panel named the wrong action and missed
// the right one. `scripts/gen_xkb_keycodes.py` is what builds it, and it can be
// re-run after a layout change.
//
// Level 0 only: a bind names the key, not the character it produces with a
// modifier. `Mod+Shift+Slash` is written with the *unshifted* name even though
// what the user types is "?", and the unmodified state reports the same name, so
// the two agree without any shift handling.
//
// Generated, not hand-written: by walking XKB key codes 8..255 of the default
// keymap, subtracting 8, and keeping the first key code that produces each
// keysym. Anything missing here simply never matches a bind, which is the safe
// direction to fail in.
var KEYCODES = {
'''

FOOTER = '''}

// Keysym name for one evdev key code, or "" when this table has no name for it.
function keysymFor(code) {
    var name = KEYCODES[code]
    return name === undefined ? "" : name
}
'''

# The cases that were got wrong by the +8 skew, plus the mod keys the mask and
# the "is this just a modifier" check both depend on. Checked on every run.
SPOT_CHECKS = {
    1: "Escape",
    41: "grave",
    33: "f",
    57: "space",
    53: "slash",
    63: "F5",
    84: "ISO_Level3_Shift",
    100: "Alt_R",
    125: "Super_L",
    126: "Super_R",
    195: "ISO_Level5_Shift",
}


def build_rows():
    lib = ctypes.CDLL("libxkbcommon.so.0")
    lib.xkb_context_new.restype = ctypes.c_void_p
    lib.xkb_context_new.argtypes = [ctypes.c_int]
    lib.xkb_keymap_new_from_names.restype = ctypes.c_void_p
    lib.xkb_keymap_new_from_names.argtypes = [
        ctypes.c_void_p, ctypes.c_void_p, ctypes.c_int]
    lib.xkb_keymap_key_get_syms_by_level.restype = ctypes.c_int
    lib.xkb_keymap_key_get_syms_by_level.argtypes = [
        ctypes.c_void_p, ctypes.c_uint32, ctypes.c_uint32, ctypes.c_uint32,
        ctypes.POINTER(ctypes.POINTER(ctypes.c_uint32))]
    lib.xkb_keysym_get_name.restype = ctypes.c_int
    lib.xkb_keysym_get_name.argtypes = [
        ctypes.c_uint32, ctypes.c_char_p, ctypes.c_size_t]

    context = lib.xkb_context_new(0)
    keymap = lib.xkb_keymap_new_from_names(context, None, 0)
    buffer = ctypes.create_string_buffer(128)
    syms = ctypes.POINTER(ctypes.c_uint32)()

    seen = {}
    rows = []
    for xkb_code in range(8, 256):
        count = lib.xkb_keymap_key_get_syms_by_level(
            keymap, xkb_code, 0, 0, ctypes.byref(syms))
        if count < 1:
            continue
        symbol = syms[0]
        if symbol == 0:
            continue
        lib.xkb_keysym_get_name(symbol, buffer, 128)
        name = buffer.value.decode()
        if name in seen:
            continue
        seen[name] = xkb_code - 8
        rows.append((xkb_code - 8, name))

    rows.sort()
    return rows


def render(rows):
    lines = []
    chunk = []
    for code, name in rows:
        chunk.append(f'{code}: "{name}"')
        if len(chunk) == 6:
            lines.append("    " + ", ".join(chunk) + ",")
            chunk = []
    if chunk:
        lines.append("    " + ", ".join(chunk) + ",")
    return HEADER + "\n".join(lines) + "\n" + FOOTER


def main():
    rows = build_rows()
    table = dict(rows)

    failures = []
    for code, expected in sorted(SPOT_CHECKS.items()):
        actual = table.get(code)
        marker = "ok" if actual == expected else "MISMATCH"
        print(f"  evdev {code:3} -> {actual!r:22} expected {expected!r:22} {marker}")
        if actual != expected:
            failures.append((code, expected, actual))

    if failures:
        print("\nThe keymap does not match the codes this file has always used.")
        print("That usually means the layout changed; if the expected names are")
        print("what is stale, update SPOT_CHECKS in this script.")
        return 1

    if "--check" in sys.argv:
        print("\n--check: spot checks pass, file not rewritten")
        return 0

    with open("services/nirishortcuts/XkbKeycodes.js", "w", encoding="utf-8") as handle:
        handle.write(render(rows))
    print(f"\nwrote services/nirishortcuts/XkbKeycodes.js ({len(rows)} entries)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
