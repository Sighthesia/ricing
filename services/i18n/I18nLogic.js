.pragma library

// Resolution rules for the shell's single translation table (Strings.js).
// Kept free of QML so the fallback chain can be reasoned about without a
// running shell: a missing key must be visible, never a blank.

var LANGUAGE_AUTO = "auto"
var LANGUAGE_ZH = "zh"
var LANGUAGE_EN = "en"

var SUPPORTED = [LANGUAGE_AUTO, LANGUAGE_ZH, LANGUAGE_EN]

// Anything unrecognised falls back to "auto" rather than to a hardcoded
// language: a settings file written by an older build must not pin the shell
// to a language the user never picked.
function normalizeLanguage(value) {
    var raw = value == null ? "" : String(value).trim().toLowerCase()
    for (var i = 0; i < SUPPORTED.length; i++) {
        if (SUPPORTED[i] === raw)
            return raw
    }
    return LANGUAGE_AUTO
}

// Resolve the stored preference against the OS locale. "auto" reads the
// locale's language subtag only ("zh_CN.UTF-8" and "zh-Hans-CN" both mean zh),
// so region and encoding never decide the interface language.
function resolveLanguage(setting, systemLocale) {
    var normalized = normalizeLanguage(setting)
    if (normalized !== LANGUAGE_AUTO)
        return normalized
    return localeLanguage(systemLocale) === "zh" ? LANGUAGE_ZH : LANGUAGE_EN
}

function localeLanguage(systemLocale) {
    var raw = systemLocale == null ? "" : String(systemLocale).trim().toLowerCase()
    if (raw === "")
        return ""
    // Drop encoding (".UTF-8") and modifier ("@modifier") before the separator
    // split, because both can contain characters the split would misread.
    var base = raw.split(".")[0].split("@")[0]
    return base.split(/[_\-]/)[0]
}

// One entry holds both languages. A plain string is used everywhere; an object
// with `one`/`other` is used where the line carries a count.
function pick(entry, language, count) {
    if (entry == null)
        return ""
    var localized = entry[language]
    if (localized === undefined || localized === null)
        localized = entry[LANGUAGE_EN]
    if (localized === undefined || localized === null)
        return ""
    if (typeof localized === "object") {
        var n = Number(count)
        if (isFinite(n) && n === 1)
            return String(localized.one !== undefined ? localized.one : localized.other)
        return String(localized.other !== undefined ? localized.other : localized.one)
    }
    return String(localized)
}

// Replace `{name}` placeholders. An argument that was not supplied leaves the
// placeholder in place, which is how a missing argument shows up in a
// screenshot instead of collapsing the sentence around an empty string.
function format(template, args) {
    if (args == null)
        return template
    return String(template).replace(/\{(\w+)\}/g, function (match, name) {
        if (args[name] === undefined || args[name] === null)
            return match
        return String(args[name])
    })
}

// The whole lookup. An unknown key returns the key itself: a screenshot of
// `context.moveLeft` names the exact entry to add, while an empty string would
// read as a layout bug.
function lookup(table, key, language, args, count) {
    var entry = table ? table[key] : null
    if (entry === undefined || entry === null)
        return String(key)
    var text = pick(entry, language, count)
    if (text === "")
        return String(key)
    return format(text, args)
}
