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

    // Recolor from the wallpaper palette unless the user opts out.
    readonly property bool adapt: settingsService ? settingsService.appearance.themeAdaptation !== false : false

    // Wrap a palette color with an explicit alpha so translucent overlays
    // keep their original compositing while adopting the extracted hue.
    function shade(baseColor, alpha) {
        return Qt.rgba(baseColor.r, baseColor.g, baseColor.b, alpha)
    }

    readonly property color bgDark: adapt && colorService ? colorService.mSurface : "#18171C"
    readonly property color modeContainer: adapt && colorService ? shade(colorService.mSurface, 0x24 / 255) : "#241F272B"
    readonly property color modeContainerBorder: "#0FFFFFFF"
    readonly property color osuPink: adapt && colorService ? colorService.mPrimary : "#FF66AA"
    readonly property color osuGreen: adapt && colorService ? colorService.mTertiary : "#00FFA2"
    readonly property color iconInactive: adapt && colorService ? shade(colorService.mOnSurfaceVariant, 0.72) : "#A0A0A0"
    readonly property color textPrimary: adapt && colorService ? colorService.mOnSurface : "#FFFFFF"
    readonly property color textMuted: adapt && colorService ? colorService.mOnSurfaceVariant : "#B8B4BC"
    readonly property color hoverForeground: "#FFFFFF"
    readonly property color hoverFill: "#18FFFFFF"
    readonly property color pressedFill: "#0FFFFFFF"
    readonly property color activeFill: adapt && colorService ? shade(colorService.mTertiary, 0x24 / 255) : "#2400FFA2"
    readonly property color focusRing: adapt && colorService ? colorService.mPrimary : "#FFF2F8"
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

    // Settings surfaces reuse the extracted tonal steps instead of the
    // dedicated violet hierarchy when adaptation is on.
    readonly property color accentColor: adapt && colorService ? colorService.mPrimary : "#765BFF"
    readonly property color settingsAccent: accentColor
    readonly property color settingsControlSurface: adapt && colorService ? colorService.mSurfaceContainerLow : "#25222E"
    readonly property color settingsPanel: adapt && colorService ? colorService.mSurface : "#18161D"
    readonly property color settingsSection: adapt && colorService ? colorService.mSurfaceContainerHigh : "#282532"
    readonly property color settingsPanelBorder: "transparent"
    readonly property color settingsRail: adapt && colorService ? Qt.darker(colorService.mSurface, 1.15) : "#131217"
    readonly property color settingsNavInactive: adapt && colorService ? shade(colorService.mOnSurfaceVariant, 0.62) : "#8A8795"
    readonly property color settingsSearchSurface: adapt && colorService ? colorService.mSurfaceContainerLow : "#201E27"
    readonly property color settingsToggleOff: adapt && colorService ? colorService.mSurfaceContainerHighest : "#322E3F"
    readonly property color settingsRow: "transparent"
    readonly property color settingsRowHover: adapt && colorService ? colorService.mSurfaceContainerHighest : "#FF363842"
    readonly property color settingsCard: adapt && colorService ? colorService.mSurfaceContainerLow : "#221F2B"
    readonly property color settingsCardHover: adapt && colorService ? colorService.mSurfaceContainerHigh : "#272332"
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
    readonly property int settingsRangePadding: 0
    readonly property color settingsTrack: adapt && colorService ? colorService.mSurfaceContainerHighest : "#2E2A3A"
    readonly property color settingsSliderThumb: adapt && colorService ? colorService.mPrimary : "#9A86FF"
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
