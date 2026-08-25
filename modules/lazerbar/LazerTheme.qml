pragma Singleton
import QtQuick
import "../../services" as Services

// Centralize the lazer bar's visual language. Geometry tokens stay static;
// color tokens follow the wallpaper-extracted Material palette when the
// Theme Adaptation setting is enabled, otherwise they fall back to the
// built-in violet/osu defaults.
QtObject {
    id: root

    // Recolor from the wallpaper palette unless the user opts out.
    readonly property bool adapt: Services.SettingsService.appearance.themeAdaptation !== false

    // Wrap a palette color with an explicit alpha so translucent overlays
    // keep their original compositing while adopting the extracted hue.
    function shade(baseColor, alpha) {
        return Qt.rgba(baseColor.r, baseColor.g, baseColor.b, alpha)
    }

    readonly property color bgDark: adapt ? Services.Color.mSurface : "#18171C"
    readonly property color modeContainer: adapt ? shade(Services.Color.mSurface, 0x24 / 255) : "#241F272B"
    readonly property color modeContainerBorder: "#0FFFFFFF"
    readonly property color osuPink: adapt ? Services.Color.mPrimary : "#FF66AA"
    readonly property color osuGreen: adapt ? Services.Color.mTertiary : "#00FFA2"
    readonly property color iconInactive: adapt ? shade(Services.Color.mOnSurfaceVariant, 0.72) : "#A0A0A0"
    readonly property color textPrimary: adapt ? Services.Color.mOnSurface : "#FFFFFF"
    readonly property color textMuted: adapt ? Services.Color.mOnSurfaceVariant : "#B8B4BC"
    readonly property color hoverForeground: "#FFFFFF"
    readonly property color hoverFill: "#18FFFFFF"
    readonly property color pressedFill: "#0FFFFFFF"
    readonly property color activeFill: adapt ? shade(Services.Color.mTertiary, 0x24 / 255) : "#2400FFA2"
    readonly property color focusRing: adapt ? Services.Color.mPrimary : "#FFF2F8"
    readonly property color divider: adapt ? shade(Services.Color.mOutline, 0.28) : "#2E2C32"
    readonly property color popupBackground: adapt ? shade(Services.Color.mSurface, 0xF2 / 255) : "#F21D1C22"
    readonly property color popupBorder: "#24FFFFFF"
    readonly property color osuButtonActive: adapt ? Services.Color.mPrimary : "#EB1C60"
    readonly property color osuButtonHover: adapt ? Services.Color.mSurfaceContainerHigh : "#333744"
    readonly property color musicBackground: adapt ? shade(Services.Color.mSurface, 0xE6 / 255) : "#E612131A"

    // Music page keeps its signature gold as a deliberate second accent;
    // every other accent follows the wallpaper palette.
    readonly property color musicGold: "#FFD000"
    readonly property color musicMuted: adapt ? shade(Services.Color.mOnSurfaceVariant, 0.72) : "#A0A0A0"

    // Settings surfaces reuse the extracted tonal steps instead of the
    // dedicated violet hierarchy when adaptation is on.
    readonly property color accentColor: adapt ? Services.Color.mPrimary : "#765BFF"
    readonly property color settingsAccent: accentColor
    readonly property color settingsControlSurface: adapt ? Services.Color.mSurfaceContainerLow : "#25222E"
    readonly property color settingsPanel: adapt ? Services.Color.mSurface : "#18161D"
    readonly property color settingsSection: adapt ? Services.Color.mSurfaceContainerHigh : "#282532"
    readonly property color settingsPanelBorder: "transparent"
    readonly property color settingsRail: adapt ? Qt.darker(Services.Color.mSurface, 1.15) : "#131217"
    readonly property color settingsNavInactive: adapt ? shade(Services.Color.mOnSurfaceVariant, 0.62) : "#8A8795"
    readonly property color settingsSearchSurface: adapt ? Services.Color.mSurfaceContainerLow : "#201E27"
    readonly property color settingsToggleOff: adapt ? Services.Color.mSurfaceContainerHighest : "#322E3F"
    readonly property color settingsRow: "transparent"
    readonly property color settingsRowHover: adapt ? Services.Color.mSurfaceContainerHighest : "#FF363842"
    readonly property color settingsCard: adapt ? Services.Color.mSurfaceContainerLow : "#221F2B"
    readonly property color settingsCardHover: adapt ? Services.Color.mSurfaceContainerHigh : "#272332"
    readonly property color settingsSelected: adapt ? shade(Services.Color.mPrimary, 0x40 / 255) : "#40765BFF"
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
    readonly property color nubGlowColor: adapt ? shade(Services.Color.mPrimary, nubGlowOpacity) : "#66FF66AA"
    readonly property int settingsControlRadius: 5
    readonly property int settingsControlHeight: 40
    readonly property int settingsChoiceHeight: 52
    readonly property int settingsChoiceRadius: 6
    readonly property int settingsControlPadding: 9
    readonly property int settingsRangePadding: 0
    readonly property color settingsTrack: adapt ? Services.Color.mSurfaceContainerHighest : "#2E2A3A"
    readonly property color settingsSliderThumb: adapt ? Services.Color.mPrimary : "#9A86FF"
    readonly property color settingsSliderThumbLight: "#EBE5FF"
    readonly property color settingsResetSurface: adapt ? Services.Color.mPrimaryContainer : "#302A42"
    readonly property color settingsResetSurfaceHover: adapt ? Qt.lighter(Services.Color.mPrimaryContainer, 1.25) : "#403653"
    readonly property color settingsTrackFocus: adapt ? Services.Color.mOutline : "#4A4C59"
    readonly property color settingsMenuBackground: adapt ? shade(Services.Color.mSurface, 0xF5 / 255) : "#F51D1C22"
    readonly property color settingsMenuBorder: "#28FFFFFF"
    readonly property color settingsMenuHover: "#24FFFFFF"
    readonly property color tooltipBackground: adapt ? shade(Services.Color.mSurface, 0xF0 / 255) : "#F01B1C22"
    readonly property color tooltipBorder: "#28FFFFFF"
    readonly property real settingsDisabledAlpha: 0.3
    readonly property int tooltipMaxWidth: 320
    readonly property int dropdownMaxHeight: 200
}
