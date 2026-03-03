import QtQuick
import qs.config
import qs.services

// Scrollable settings panel content with three grouped sections.
// Designed to be embedded inside SettingsPanelWindow.
// Uses components from the same directory (implicit relative import).
Item {
    id: root

    implicitWidth: 296
    implicitHeight: Math.min(flickable.contentHeight + 8, 480)

    Flickable {
        id: flickable
        anchors.fill: parent
        contentWidth: width
        contentHeight: col.implicitHeight
        clip: true
        boundsMovement: Flickable.StopAtBounds

        Column {
            id: col
            width: flickable.width
            spacing: 2

            // ── Appearance ─────────────────────────────────────────
            Item { width: 1; height: 6 }

            Text {
                leftPadding: 12
                text: "外观"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.DemiBold
                color: Colors.textMuted
            }

            ColorSection {
                label: "强调色"
                value: SettingsService.data.appearance.accentColor
                onValueCommitted: (v) => SettingsService.data.appearance.accentColor = v
            }

            ColorSection {
                label: "背景色"
                value: SettingsService.data.appearance.backgroundColor
                onValueCommitted: (v) => SettingsService.data.appearance.backgroundColor = v
            }

            ColorSection {
                label: "表面色"
                value: SettingsService.data.appearance.surfaceColor
                onValueCommitted: (v) => SettingsService.data.appearance.surfaceColor = v
            }

            // ── Bar ────────────────────────────────────────────────
            Item { width: 1; height: 6 }

            Text {
                leftPadding: 12
                text: "Bar"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.DemiBold
                color: Colors.textMuted
            }

            SliderSection {
                label: "高度"
                value: SettingsService.data.bar.height
                from: 24; to: 60; stepSize: 1; unit: "px"
                onValueCommitted: (v) => SettingsService.data.bar.height = v
            }

            SliderSection {
                label: "透明度"
                value: SettingsService.data.bar.backgroundOpacity
                from: 0.0; to: 1.0; stepSize: 0.05
                onValueCommitted: (v) => SettingsService.data.bar.backgroundOpacity = v
            }

            SliderSection {
                label: "动画速度"
                value: SettingsService.data.animation.speedFactor
                from: 0.2; to: 3.0; stepSize: 0.1; unit: "×"
                onValueCommitted: (v) => SettingsService.data.animation.speedFactor = v
            }

            // ── Behavior ───────────────────────────────────────────
            Item { width: 1; height: 6 }

            Text {
                leftPadding: 12
                text: "行为"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.DemiBold
                color: Colors.textMuted
            }

            BehaviorSection {}

            // Bottom padding
            Item { width: 1; height: 10 }
        }
    }
}
