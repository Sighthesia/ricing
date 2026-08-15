pragma Singleton
import QtQuick

// Centralize the lazer bar's dark visual language.
QtObject {
    readonly property color bgDark: "#18171C"
    readonly property color modeContainer: "#241F272B"
    readonly property color modeContainerBorder: "#0FFFFFFF"
    readonly property color osuPink: "#FF66AA"
    readonly property color osuGreen: "#00FFA2"
    readonly property color iconInactive: "#A0A0A0"
    readonly property color textPrimary: "#FFFFFF"
    readonly property color textMuted: "#B8B4BC"
    readonly property color hoverForeground: "#FFFFFF"
    readonly property color hoverFill: "#18FFFFFF"
    readonly property color pressedFill: "#0FFFFFFF"
    readonly property color activeFill: "#2400FFA2"
    readonly property color focusRing: "#FFF2F8"
    readonly property color divider: "#2E2C32"
    readonly property color popupBackground: "#F21D1C22"
    readonly property color popupBorder: "#24FFFFFF"
    readonly property color osuButtonActive: "#EB1C60"
    readonly property color osuButtonHover: "#333744"
    readonly property color musicBackground: "#E612131A"
    readonly property color musicGold: "#FFD000"
    readonly property color musicMuted: "#A0A0A0"

    // Settings surfaces use the fixed flat shades from osu's side-panel hierarchy.
    readonly property color settingsPanel: "#EE24252D"
    readonly property color settingsPanelBorder: "transparent"
    readonly property color settingsRail: "#FF1B1C22"
    readonly property color settingsRow: "#FF292A33"
    readonly property color settingsRowHover: "#FF363842"
    readonly property color settingsSelected: "#40EB1C60"
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

    // osu Nub and outlined control tokens shared by settings controls.
    readonly property real nubBorder: 3
    readonly property real nubBorderChecked: 8.5
    readonly property real nubGlowOpacity: 0.45
    readonly property color nubGlowColor: "#66FF66AA"
    readonly property int settingsControlRadius: 5
    readonly property int settingsControlHeight: 40
    readonly property int settingsControlPadding: 10
    readonly property int settingsRangePadding: 25
    readonly property color settingsTrack: "#3A3B45"
    readonly property color settingsTrackFocus: "#4A4C59"
    readonly property color settingsMenuBackground: "#F51D1C22"
    readonly property color settingsMenuBorder: "#28FFFFFF"
    readonly property color settingsMenuHover: "#24FFFFFF"
    readonly property color tooltipBackground: "#F01B1C22"
    readonly property color tooltipBorder: "#28FFFFFF"
    readonly property real settingsDisabledAlpha: 0.3
    readonly property int tooltipMaxWidth: 320
    readonly property int dropdownMaxHeight: 200
}
