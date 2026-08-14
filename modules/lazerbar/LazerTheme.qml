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

    // Settings overlay surfaces use the same dark glass language as the bar.
    readonly property color settingsPanel: "#F21D1C22"
    readonly property color settingsPanelBorder: "#38FFFFFF"
    readonly property color settingsRail: "#2418171C"
    readonly property color settingsRow: "#141D1C22"
    readonly property color settingsRowHover: "#241F2028"
    readonly property color settingsSelected: "#40EB1C60"
    readonly property real settingsScrimOpacity: 0.6
    readonly property int settingsRadius: 16

    readonly property int barHeight: 46
    readonly property int bottomRadius: 14
    readonly property int iconSize: 20
    readonly property int targetSize: 32
    readonly property int groupGap: 12
    readonly property int inlineGap: 6
}
