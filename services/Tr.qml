pragma Singleton
import QtQuick
import "./" as Services
import "i18n/I18nLogic.js" as Logic
import "i18n/Strings.js" as Strings

// The shell's single translation entry point.
//
// Every visible string in the shell resolves through `Tr.q("key")`, and the
// language it resolves to lives in settings (`appearance.language`). Because
// `q()` reads `language` while a binding evaluates, a language change
// re-evaluates every label that calls it — no restart, and no second store of
// translated text to keep in sync.
//
// Keys, not English sentences, are the identity. `Tr.q` returns the key itself
// when an entry is missing, so a gap shows up on screen as the id to add rather
// than as a blank or as the wrong language.
QtObject {
    id: root

    // Stored preference: "auto" (follow the OS locale), "zh", "en".
    readonly property string setting: Services.SettingsService
        ? String(Services.SettingsService.appearance.language || "auto")
        : "auto"
    // The language actually rendered. "auto" is resolved once here, against the
    // process locale, so no caller has to think about the fallback.
    readonly property string language: Logic.resolveLanguage(setting, Qt.locale().name)
    readonly property bool isChinese: root.language === Logic.LANGUAGE_ZH
    // The locale NAME matching the rendered language, for date and weekday
    // names. A string rather than a QLocale: handing a QLocale through a
    // property and back into Qt.formatDate arrives as a plain object and the
    // call fails with "incompatible arguments". Callers build the locale at the
    // call site with Qt.locale(Tr.qtLocaleName).
    readonly property string qtLocaleName: root.isChinese ? "zh_CN" : "en_US"

    // Translate one key. `args` fills `{name}` placeholders; a missing argument
    // leaves its placeholder visible instead of silently collapsing the line.
    function q(key, args) {
        return Logic.lookup(Strings.strings, key, root.language, args || null, NaN)
    }

    // Translate one count-carrying key. Entries with `one`/`other` pick by
    // `count`; plain entries still get `{n}` filled from the same argument.
    function n(key, count, args) {
        var merged = { n: count }
        if (args) {
            for (var name in args)
                merged[name] = args[name]
        }
        return Logic.lookup(Strings.strings, key, root.language, merged, count)
    }
}
