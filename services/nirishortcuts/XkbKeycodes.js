.pragma library

// evdev key code -> keysym NAME, for the unmodified level of each key.
//
// This is what lets a key event read off /dev/input (an evdev code, e.g. 65)
// be compared with a niri bind written as a keysym name ("Super+Space"). The
// names are the ones libxkbcommon reports, which is exactly what
// `xkb_keysym_from_name` - and therefore niri's own bind parser - accepts.
//
// Level 0 only: a bind names the key, not the character it produces with a
// modifier. `Mod+Shift+Slash` is written with the *unshifted* name even though
// what the user types is "?", and `xkb_state_key_get_one_sym` on the unmodified
// state reports the same name, so the two agree without any shift handling.
//
// Generated, not hand-written: on this machine (xkb layout `us`), by walking
// key codes 8..255 of the default keymap and keeping the first key code that
// produces each keysym. 218 entries, one per physical key.
//
//   python3 - <<'EOF' > /tmp/keycodes.txt
//   import ctypes
//   lib = ctypes.CDLL("libxkbcommon.so.0")
//   ...
//   EOF
//
// A layout with non-Latin letters changes the letter names this produces
// (that is the point: it describes the keyboard in front of the user), so the
// file is worth regenerating when the layout changes. Anything missing here
// simply never matches a bind, which is the safe direction to fail in.
var KEYCODES = {
    9: "Escape", 10: "1", 11: "2", 12: "3", 13: "4", 14: "5",
    15: "6", 16: "7", 17: "8", 18: "9", 19: "0", 20: "minus",
    21: "equal", 22: "BackSpace", 23: "Tab", 24: "q", 25: "w", 26: "e",
    27: "r", 28: "t", 29: "y", 30: "u", 31: "i", 32: "o",
    33: "p", 34: "bracketleft", 35: "bracketright", 36: "Return", 37: "Control_L", 38: "a",
    39: "s", 40: "d", 41: "f", 42: "g", 43: "h", 44: "j",
    45: "k", 46: "l", 47: "semicolon", 48: "apostrophe", 49: "grave", 50: "Shift_L",
    51: "backslash", 52: "z", 53: "x", 54: "c", 55: "v", 56: "b",
    57: "n", 58: "m", 59: "comma", 60: "period", 61: "slash", 62: "Shift_R",
    63: "KP_Multiply", 64: "Alt_L", 65: "space", 66: "Caps_Lock", 67: "F1", 68: "F2",
    69: "F3", 70: "F4", 71: "F5", 72: "F6", 73: "F7", 74: "F8",
    75: "F9", 76: "F10", 77: "Num_Lock", 78: "Scroll_Lock", 79: "KP_Home", 80: "KP_Up",
    81: "KP_Prior", 82: "KP_Subtract", 83: "KP_Left", 84: "KP_Begin", 85: "KP_Right", 86: "KP_Add",
    87: "KP_End", 88: "KP_Down", 89: "KP_Next", 90: "KP_Insert", 91: "KP_Delete", 92: "ISO_Level3_Shift",
    93: "F24", 94: "less", 95: "F11", 96: "F12", 98: "Katakana", 99: "Hiragana",
    100: "Henkan_Mode", 101: "Hiragana_Katakana", 102: "Muhenkan", 104: "KP_Enter", 105: "Control_R", 106: "KP_Divide",
    107: "Print", 108: "Alt_R", 109: "Linefeed", 110: "Home", 111: "Up", 112: "Prior",
    113: "Left", 114: "Right", 115: "End", 116: "Down", 117: "Next", 118: "Insert",
    119: "Delete", 121: "XF86AudioMute", 122: "XF86AudioLowerVolume", 123: "XF86AudioRaiseVolume", 124: "XF86PowerOff", 125: "KP_Equal",
    126: "plusminus", 127: "Pause", 128: "XF86LaunchA", 129: "KP_Decimal", 130: "Hangul", 131: "Hangul_Hanja",
    133: "Super_L", 134: "Super_R", 135: "Menu", 136: "Cancel", 137: "Redo", 138: "SunProps",
    139: "Undo", 140: "SunFront", 141: "XF86Copy", 142: "XF86Open", 143: "XF86Paste", 144: "Find",
    145: "XF86Cut", 146: "Help", 147: "XF86MenuKB", 148: "XF86Calculator", 150: "XF86Sleep", 151: "XF86WakeUp",
    152: "XF86Explorer", 153: "XF86Send", 155: "XF86Xfer", 156: "XF86Launch1", 157: "XF86Launch2", 158: "XF86WWW",
    159: "XF86DOS", 160: "XF86ScreenSaver", 161: "XF86RotateWindows", 162: "XF86TaskPane", 163: "XF86Mail", 164: "XF86Favorites",
    165: "XF86MyComputer", 166: "XF86Back", 167: "XF86Forward", 169: "XF86Eject", 171: "XF86AudioNext", 172: "XF86AudioPlay",
    173: "XF86AudioPrev", 174: "XF86AudioStop", 175: "XF86AudioRecord", 176: "XF86AudioRewind", 177: "XF86Phone", 179: "XF86Tools",
    180: "XF86HomePage", 181: "XF86Reload", 182: "XF86Close", 185: "XF86ScrollUp", 186: "XF86ScrollDown", 187: "parenleft",
    188: "parenright", 189: "XF86New", 192: "XF86Launch5", 193: "XF86Launch6", 194: "XF86Launch7", 195: "XF86Launch8",
    196: "XF86Launch9", 197: "F19", 198: "XF86AudioMicMute", 199: "XF86TouchpadToggle", 200: "XF86TouchpadOn", 201: "XF86TouchpadOff",
    203: "ISO_Level5_Shift", 209: "XF86AudioPause", 210: "XF86Launch3", 211: "XF86Launch4", 212: "XF86LaunchB", 213: "XF86Suspend",
    216: "XF86AudioForward", 217: "XF86AudioBassBoost", 220: "XF86WebCam", 221: "XF86AudioPreset", 224: "XF86Messenger", 225: "XF86Search",
    226: "XF86Go", 227: "XF86Finance", 228: "XF86Game", 229: "XF86Shop", 232: "XF86MonBrightnessDown", 233: "XF86MonBrightnessUp",
    234: "XF86AudioMedia", 235: "XF86Display", 236: "XF86KbdLightOnOff", 237: "XF86KbdBrightnessDown", 238: "XF86KbdBrightnessUp", 240: "XF86Reply",
    241: "XF86MailForward", 242: "XF86Save", 243: "XF86Documents", 244: "XF86Battery", 245: "XF86Bluetooth", 246: "XF86WLAN",
    247: "XF86UWB", 249: "XF86Next_VMode", 250: "XF86Prev_VMode", 251: "XF86MonBrightnessCycle", 252: "XF86BrightnessAuto", 253: "XF86DisplayOff",
    254: "XF86WWAN", 255: "XF86RFKill",
}

// Keysym name for one evdev key code, or "" when this table has no name for it.
function keysymFor(code) {
    var name = KEYCODES[code]
    return name === undefined ? "" : name
}

// Every key code that produces this keysym name.
function codesForKeysym(name) {
    var wanted = String(name || "").toLowerCase()
    var codes = []
    if (wanted === "")
        return codes
    for (var code in KEYCODES) {
        if (KEYCODES[code].toLowerCase() === wanted)
            codes.push(Number(code))
    }
    return codes
}
