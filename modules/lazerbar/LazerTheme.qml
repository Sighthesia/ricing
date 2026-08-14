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

    readonly property int barHeight: 46
    readonly property int bottomRadius: 14
    readonly property int iconSize: 20
    readonly property int targetSize: 32
    readonly property int groupGap: 12
    readonly property int inlineGap: 6
}
