pragma Singleton
import QtQuick

// Centralize the lazer bar's visual language. Geometry tokens stay static;
// color tokens follow the wallpaper-extracted Material palette when the
// Theme Adaptation setting is enabled, otherwise they fall back to the
// built-in violet/osu defaults.
// Injection design: keep the singleton loadable without Quickshell so
// qmltestrunner harnesses remain deterministic, while the live shell
// injects the palette at startup (see shell.qml). When no palette is
// injected, adapt stays false and every token resolves to the built-in
// fallback, preserving existing test expectations.
QtObject {
    id: root

    // Injected by the shell runtime; null in qmltestrunner.
    // The shell binds these to Services.SettingsService / Services.Color
    // so the palette stays reactive without this singleton importing Services.
    property var settingsService: null
    property var colorService: null

    // Recolor from the ColorService palette (wallpaper extraction OR a
    // selected color scheme preset) unless the user is on the legacy
    // built-in palette: adaptation on, or adaptation off with a preset.
    readonly property bool adapt: settingsService
        ? (settingsService.appearance.themeAdaptation !== false
           || String(settingsService.appearance.presetScheme || "") !== "")
        : false

    // Wrap a palette color with an explicit alpha so translucent overlays
    // keep their original compositing while adopting the extracted hue.
    function shade(baseColor, alpha) {
        return Qt.rgba(baseColor.r, baseColor.g, baseColor.b, alpha)
    }

    // Linear RGB blend used to mute light-scheme surfaces toward paper white.
    // Monotonic in lightness so the panel < section < card order is preserved.
    function mix(firstColor, secondColor, ratio) {
        var t = Number(ratio)
        if (!isFinite(t))
            t = 0.5
        t = Math.max(0, Math.min(1, t))
        return Qt.rgba(firstColor.r + (secondColor.r - firstColor.r) * t,
            firstColor.g + (secondColor.g - firstColor.g) * t,
            firstColor.b + (secondColor.b - firstColor.b) * t,
            firstColor.a + (secondColor.a - firstColor.a) * t)
    }

    readonly property color bgDark: adapt && colorService ? colorService.mSurface : "#18171C"
    // Light-scheme bar surface follows the extracted palette the same way
    // bgDark does (Color switches palettes by effective scheme); the fixed
    // value only serves the wallpaper-adaptation opt-out.
    readonly property color bgLight: adapt && colorService ? colorService.mSurface : "#F2F0F5"
    readonly property color modeContainer: adapt && colorService ? shade(colorService.mSurface, 0x24 / 255) : "#241F272B"
    readonly property color modeContainerBorder: "#0FFFFFFF"
    readonly property color osuPink: adapt && colorService ? colorService.mPrimary : "#FF66AA"
    readonly property color osuGreen: adapt && colorService ? colorService.mTertiary : "#00FFA2"
    readonly property color iconInactive: adapt && colorService ? shade(colorService.mOnSurfaceVariant, 0.72) : "#A0A0A0"
    readonly property color textPrimary: adapt && colorService ? colorService.mOnSurface : "#FFFFFF"
    readonly property color textMuted: adapt && colorService ? colorService.mOnSurfaceVariant : "#B8B4BC"
    // Top-bar secondary text — A+C: brighter muted derived from
    // textPrimary (white/mOnSurface) at 0.82 alpha so 10px subtitles
    // stay readable on bgDark/mSurface without collapsing hierarchy.
    readonly property color barSubtitle: shade(textPrimary, 0.82)
    readonly property color hoverForeground: lightScheme ? barIcon : "#FFFFFF"
    // Interactive feedback inverts with the scheme: light surfaces take a
    // low-alpha ink wash (white washes are invisible there); pressed stays
    // fainter than hover. Active highlight reads as a container tint in
    // light mode instead of a translucent mid-tone patch.
    readonly property color hoverFill: lightScheme ? shade(barIcon, 0x14 / 255) : "#18FFFFFF"
    readonly property color pressedFill: lightScheme ? shade(barIcon, 0x0A / 255) : "#0FFFFFFF"
    // Bar glyph tint follows the painted bar surface: light scheme tints
    // with the palette's on-surface ink (fallback near-black), dark scheme
    // keeps white, independent of the wallpaper-adaptation opt-out so the
    // shared white-stroke glyph set stays legible on both schemes.
    readonly property bool lightScheme: settingsService ? settingsService.effectiveColorScheme === "light" : false
    readonly property color barIcon: lightScheme
        ? (adapt && colorService ? colorService.mOnSurface : "#1D1B20")
        : "#FFFFFF"
    readonly property color activeFill: adapt && colorService
        ? (lightScheme ? shade(colorService.mPrimaryContainer, 0x99 / 255)
                       : shade(colorService.mTertiary, 0x24 / 255))
        : "#2400FFA2"
    readonly property color focusRing: adapt && colorService ? colorService.mPrimary : "#FFF2F8"
    // Beat/tick flash wash: dark uses on-surface ink (near-white soft glow);
    // light brightens the accent toward its own luminous tint so the hue
    // survives like the dark glow does — pure white chalks saturated fills.
    readonly property color flashWash: !adapt || !colorService ? textPrimary
        : (lightScheme ? Qt.lighter(colorService.mPrimary, 1.65) : textPrimary)
    readonly property color divider: adapt && colorService ? shade(colorService.mOutline, 0.28) : "#2E2C32"
    readonly property color popupBackground: adapt && colorService ? shade(colorService.mSurface, 0xF2 / 255) : "#F21D1C22"
    readonly property color popupBorder: "#24FFFFFF"
    readonly property color osuButtonActive: adapt && colorService ? colorService.mPrimary : "#EB1C60"
    readonly property color osuButtonHover: adapt && colorService ? colorService.mSurfaceContainerHigh : "#333744"
    readonly property color musicBackground: adapt && colorService ? shade(colorService.mSurface, 0xE6 / 255) : "#E612131A"

    // Music page keeps its signature gold as a deliberate second accent;
    // every other accent follows the wallpaper palette.
    readonly property color musicGold: "#FFD000"
    readonly property color musicMuted: adapt && colorService ? shade(colorService.mOnSurfaceVariant, 0.72) : "#A0A0A0"

    // Warm-paper base for light-scheme blends; keeps the wallpaper hue at
    // a fraction of its chroma so text contrast survives vibrant palettes.
    readonly property color paperWhite: "#FFFFFF"
    // Settings surfaces reuse the extracted tonal steps instead of the
    // dedicated violet hierarchy when adaptation is on.
    readonly property color accentColor: adapt && colorService ? colorService.mPrimary : "#765BFF"
    readonly property color settingsAccent: accentColor
    readonly property color settingsControlSurface: adapt && colorService
        ? (lightScheme ? mix(colorService.mSurfaceContainerLow, paperWhite, 0.35) : colorService.mSurfaceContainerLow)
        : "#25222E"
    // Light scheme mirrors the dark anchor in reverse: dark presses the rail
    // darker to converge, light lifts the panel toward paper and mutes the
    // rail toward the surface instead of using the raw Highest peach.
    readonly property color settingsPanel: adapt && colorService
        ? (lightScheme ? mix(colorService.mSurface, paperWhite, 0.55) : colorService.mSurface)
        : "#18161D"
    readonly property color settingsSection: adapt && colorService
        ? (lightScheme ? mix(colorService.mSurfaceContainerHigh, paperWhite, 0.30) : colorService.mSurfaceContainerHigh)
        : "#282532"
    readonly property color settingsPanelBorder: "transparent"
    // Title/rail layers: dark scheme darkens the surface 15%; light scheme
    // blends Highest toward the surface so the sidebar anchors without going
    // orange. Fixed fallback serves the adaptation opt-out.
    readonly property color settingsRail: !adapt || !colorService ? "#131217"
        : lightScheme ? mix(colorService.mSurfaceContainerHighest, colorService.mSurface, 0.45)
        : Qt.darker(colorService.mSurface, 1.15)
    readonly property color settingsNavInactive: adapt && colorService
        ? (lightScheme ? shade(colorService.mOnSurfaceVariant, 0.78) : shade(colorService.mOnSurfaceVariant, 0.62))
        : "#8A8795"
    readonly property color settingsSearchSurface: adapt && colorService
        ? (lightScheme ? mix(colorService.mSurfaceContainerLow, paperWhite, 0.35) : colorService.mSurfaceContainerLow)
        : "#201E27"
    readonly property color settingsToggleOff: adapt && colorService
        ? (lightScheme ? settingsRail : colorService.mSurfaceContainerHighest)
        : "#322E3F"
    readonly property color settingsRow: "transparent"
    readonly property color settingsRowHover: adapt && colorService
        ? (lightScheme ? settingsRail : colorService.mSurfaceContainerHighest)
        : "#FF363842"
    readonly property color settingsCard: adapt && colorService
        ? (lightScheme ? mix(colorService.mSurfaceContainerLow, paperWhite, 0.60) : colorService.mSurfaceContainerLow)
        : "#221F2B"
    readonly property color settingsCardHover: adapt && colorService
        ? (lightScheme ? settingsRail : colorService.mSurfaceContainerHigh)
        : "#272332"
    readonly property color settingsSelected: adapt && colorService ? shade(colorService.mPrimary, 0x40 / 255) : "#40765BFF"
    readonly property real settingsScrimOpacity: 0.6
    readonly property int settingsRadius: 16
    readonly property int settingsSidebarContractedWidth: 70
    readonly property int settingsSidebarExpandedWidth: 170
    readonly property int settingsContentWidth: 400
    readonly property int settingsPanelWidth: 570

    readonly property int barHeight: 46
    readonly property int bottomRadius: 14
    readonly property int iconSize: 20
    readonly property int targetSize: 32
    readonly property int groupGap: 12
    readonly property int inlineGap: 6

    // osu toolbar widget metrics (ToolbarButton PADDING 3, icon 20 in HEIGHT 40):
    // hairline vertical gutters, square buttons, glyphs at half the live bar height.
    // Color tokens read the services layer, but geometry stays settings-free;
    // the production bar binds barHeightSetting to settings.
    property int barHeightSetting: 48
    readonly property int barWidgetGutter: 3
    readonly property int barLiveHeight:
        Math.max(40, Math.min(64, barHeightSetting))
    readonly property int barWidgetHeight: barLiveHeight - barWidgetGutter * 2
    readonly property int barGlyphSize: Math.max(16, Math.round(barLiveHeight * 0.5))

    // osu Nub and outlined control tokens shared by settings controls.
    readonly property real nubBorder: 3
    readonly property real nubBorderChecked: 8.5
    readonly property real nubGlowOpacity: 0.45
    readonly property color nubGlowColor: adapt && colorService ? shade(colorService.mPrimary, nubGlowOpacity) : "#66FF66AA"
    readonly property int settingsControlRadius: 5
    readonly property int settingsControlHeight: 40
    readonly property int settingsChoiceHeight: 52
    readonly property int settingsChoiceRadius: 6
    readonly property int settingsControlPadding: 9
    readonly property int settingsRangePadding: 8
    readonly property color settingsTrack: adapt && colorService
        ? (lightScheme ? settingsRail : colorService.mSurfaceContainerHighest)
        : "#2E2A3A"
    readonly property color settingsSliderThumb: adapt && colorService ? Qt.lighter(colorService.mPrimary, 1.35) : "#EBE5FF"
    readonly property color settingsSliderThumbLight: "#EBE5FF"
    readonly property color settingsResetSurface: adapt && colorService ? colorService.mPrimaryContainer : "#302A42"
    readonly property color settingsResetSurfaceHover: adapt && colorService ? Qt.lighter(colorService.mPrimaryContainer, 1.25) : "#403653"
    readonly property color settingsTrackFocus: adapt && colorService ? colorService.mOutline : "#4A4C59"
    readonly property color settingsMenuBackground: adapt && colorService ? shade(colorService.mSurface, 0xF5 / 255) : "#F51D1C22"
    readonly property color settingsMenuBorder: "#28FFFFFF"
    readonly property color settingsMenuHover: "#24FFFFFF"
    readonly property color tooltipBackground: adapt && colorService ? shade(colorService.mSurface, 0xF0 / 255) : "#F01B1C22"
    readonly property color tooltipBorder: "#28FFFFFF"
    readonly property real settingsDisabledAlpha: 0.3
    readonly property int tooltipMaxWidth: 320
    readonly property int dropdownMaxHeight: 200
}
