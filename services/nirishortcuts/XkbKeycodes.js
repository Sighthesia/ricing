.pragma library

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
// the right one. Generating it from the same skewed numbers hid the fault from
// the first round of checks.
//
// Level 0 only: a bind names the key, not the character it produces with a
// modifier. `Mod+Shift+Slash` is written with the *unshifted* name even though
// what the user types is "?", and the unmodified state reports the same name, so
// the two agree without any shift handling.
//
// Generated, not hand-written: on this machine (xkb layout `us`), by walking XKB
// key codes 8..255 of the default keymap, subtracting 8, and keeping the first
// key code that produces each keysym. 218 entries, one per physical key.
//
// A layout with non-Latin letters changes the letter names this produces (that
// is the point: it describes the keyboard in front of the user), so the file is
// worth regenerating when the layout changes. Anything missing here simply never
// matches a bind, which is the safe direction to fail in.
var KEYCODES = {
    1: "Escape", 2: "1", 3: "2", 4: "3", 5: "4", 6: "5",
    7: "6", 8: "7", 9: "8", 10: "9", 11: "0", 12: "minus",
    13: "equal", 14: "BackSpace", 15: "Tab", 16: "q", 17: "w", 18: "e",
    19: "r", 20: "t", 21: "y", 22: "u", 23: "i", 24: "o",
    25: "p", 26: "bracketleft", 27: "bracketright", 28: "Return", 29: "Control_L", 30: "a",
    31: "s", 32: "d", 33: "f", 34: "g", 35: "h", 36: "j",
    37: "k", 38: "l", 39: "semicolon", 40: "apostrophe", 41: "grave", 42: "Shift_L",
    43: "backslash", 44: "z", 45: "x", 46: "c", 47: "v", 48: "b",
    49: "n", 50: "m", 51: "comma", 52: "period", 53: "slash", 54: "Shift_R",
    55: "KP_Multiply", 56: "Alt_L", 57: "space", 58: "Caps_Lock", 59: "F1", 60: "F2",
    61: "F3", 62: "F4", 63: "F5", 64: "F6", 65: "F7", 66: "F8",
    67: "F9", 68: "F10", 69: "Num_Lock", 70: "Scroll_Lock", 71: "KP_Home", 72: "KP_Up",
    73: "KP_Prior", 74: "KP_Subtract", 75: "KP_Left", 76: "KP_Begin", 77: "KP_Right", 78: "KP_Add",
    79: "KP_End", 80: "KP_Down", 81: "KP_Next", 82: "KP_Insert", 83: "KP_Delete", 84: "ISO_Level3_Shift",
    85: "F24", 86: "less", 87: "F11", 88: "F12", 90: "Katakana", 91: "Hiragana",
    92: "Henkan_Mode", 93: "Hiragana_Katakana", 94: "Muhenkan", 96: "KP_Enter", 97: "Control_R", 98: "KP_Divide",
    99: "Print", 100: "Alt_R", 101: "Linefeed", 102: "Home", 103: "Up", 104: "Prior",
    105: "Left", 106: "Right", 107: "End", 108: "Down", 109: "Next", 110: "Insert",
    111: "Delete", 113: "XF86AudioMute", 114: "XF86AudioLowerVolume", 115: "XF86AudioRaiseVolume", 116: "XF86PowerOff", 117: "KP_Equal",
    118: "plusminus", 119: "Pause", 120: "XF86LaunchA", 121: "KP_Decimal", 122: "Hangul", 123: "Hangul_Hanja",
    125: "Super_L", 126: "Super_R", 127: "Menu", 128: "Cancel", 129: "Redo", 130: "SunProps",
    131: "Undo", 132: "SunFront", 133: "XF86Copy", 134: "XF86Open", 135: "XF86Paste", 136: "Find",
    137: "XF86Cut", 138: "Help", 139: "XF86MenuKB", 140: "XF86Calculator", 142: "XF86Sleep", 143: "XF86WakeUp",
    144: "XF86Explorer", 145: "XF86Send", 147: "XF86Xfer", 148: "XF86Launch1", 149: "XF86Launch2", 150: "XF86WWW",
    151: "XF86DOS", 152: "XF86ScreenSaver", 153: "XF86RotateWindows", 154: "XF86TaskPane", 155: "XF86Mail", 156: "XF86Favorites",
    157: "XF86MyComputer", 158: "XF86Back", 159: "XF86Forward", 161: "XF86Eject", 163: "XF86AudioNext", 164: "XF86AudioPlay",
    165: "XF86AudioPrev", 166: "XF86AudioStop", 167: "XF86AudioRecord", 168: "XF86AudioRewind", 169: "XF86Phone", 171: "XF86Tools",
    172: "XF86HomePage", 173: "XF86Reload", 174: "XF86Close", 177: "XF86ScrollUp", 178: "XF86ScrollDown", 179: "parenleft",
    180: "parenright", 181: "XF86New", 184: "XF86Launch5", 185: "XF86Launch6", 186: "XF86Launch7", 187: "XF86Launch8",
    188: "XF86Launch9", 189: "F19", 190: "XF86AudioMicMute", 191: "XF86TouchpadToggle", 192: "XF86TouchpadOn", 193: "XF86TouchpadOff",
    195: "ISO_Level5_Shift", 201: "XF86AudioPause", 202: "XF86Launch3", 203: "XF86Launch4", 204: "XF86LaunchB", 205: "XF86Suspend",
    208: "XF86AudioForward", 209: "XF86AudioBassBoost", 212: "XF86WebCam", 213: "XF86AudioPreset", 216: "XF86Messenger", 217: "XF86Search",
    218: "XF86Go", 219: "XF86Finance", 220: "XF86Game", 221: "XF86Shop", 224: "XF86MonBrightnessDown", 225: "XF86MonBrightnessUp",
    226: "XF86AudioMedia", 227: "XF86Display", 228: "XF86KbdLightOnOff", 229: "XF86KbdBrightnessDown", 230: "XF86KbdBrightnessUp", 232: "XF86Reply",
    233: "XF86MailForward", 234: "XF86Save", 235: "XF86Documents", 236: "XF86Battery", 237: "XF86Bluetooth", 238: "XF86WLAN",
    239: "XF86UWB", 241: "XF86Next_VMode", 242: "XF86Prev_VMode", 243: "XF86MonBrightnessCycle", 244: "XF86BrightnessAuto", 245: "XF86DisplayOff",
    246: "XF86WWAN", 247: "XF86RFKill",
}

// Keysym name for one evdev key code, or "" when this table has no name for it.
function keysymFor(code) {
    var name = KEYCODES[code]
    return name === undefined ? "" : name
}
