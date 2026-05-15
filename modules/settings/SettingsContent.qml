import QtQuick
import QtQuick.Controls
import "../../services" as Services
import "controls"

// Scrollable settings panel with search filtering across all setting rows.
Item {
    id: root

    // Search field at the top
    TextField {
        id: searchField
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        placeholderText: "Search settings..."
        color: Services.Color.mOnSurface
        background: Rectangle {
            radius: 8
            color: Services.Color.mSurfaceVariant
            border.color: Services.Color.mOutline
            border.width: 1
        }
    }

    // Scrollable settings list
    Flickable {
        anchors.top: searchField.bottom
        anchors.topMargin: 8
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        contentHeight: settingsColumn.implicitHeight
        clip: true

        Column {
            id: settingsColumn
            width: parent.width
            spacing: 8

            // ── Bar ──────────────────────────────────────────────────────────

            // Bar category header
            Text {
                id: barHeader
                text: "Bar"
                color: Services.Color.mPrimary
                font.bold: true
                font.pixelSize: 14
                topPadding: 8
                visible: barHeight.visible || barPosition.visible || barFloating.visible ||
                         barFloatingMargin.visible || barBgOpacity.visible || barCornerRadius.visible
            }

            SettingSlider {
                id: barHeight
                settingLabel: "Height"
                from: 24; to: 64; stepSize: 2
                value: Services.SettingsService.bar.height
                suffix: "px"
                width: parent.width
                visible: settingLabel.toLowerCase().includes(searchField.text.toLowerCase())
                onMoved: v => { Services.SettingsService.bar.height = v }
            }

            SettingDropdown {
                id: barPosition
                settingLabel: "Position"
                model: ["top", "bottom"]
                currentValue: Services.SettingsService.bar.position
                width: parent.width
                visible: settingLabel.toLowerCase().includes(searchField.text.toLowerCase())
                onSelected: v => { Services.SettingsService.bar.position = v }
            }

            SettingToggle {
                id: barFloating
                settingLabel: "Floating"
                checked: Services.SettingsService.bar.floating
                width: parent.width
                visible: settingLabel.toLowerCase().includes(searchField.text.toLowerCase())
                onToggled: v => { Services.SettingsService.bar.floating = v }
            }

            SettingSlider {
                id: barFloatingMargin
                settingLabel: "Floating Margin"
                from: 0; to: 16; stepSize: 1
                value: Services.SettingsService.bar.floatingMargin
                suffix: "px"
                width: parent.width
                // Only visible when floating is enabled and matches search
                visible: Services.SettingsService.bar.floating &&
                         settingLabel.toLowerCase().includes(searchField.text.toLowerCase())
                onMoved: v => { Services.SettingsService.bar.floatingMargin = v }
            }

            SettingSlider {
                id: barBgOpacity
                settingLabel: "Background Opacity"
                from: 0; to: 1; stepSize: 0.05
                value: Services.SettingsService.bar.backgroundOpacity
                width: parent.width
                visible: settingLabel.toLowerCase().includes(searchField.text.toLowerCase())
                onMoved: v => { Services.SettingsService.bar.backgroundOpacity = v }
            }

            SettingSlider {
                id: barCornerRadius
                settingLabel: "Corner Radius"
                from: 0; to: 24; stepSize: 2
                value: Services.SettingsService.bar.cornerRadius
                suffix: "px"
                width: parent.width
                visible: settingLabel.toLowerCase().includes(searchField.text.toLowerCase())
                onMoved: v => { Services.SettingsService.bar.cornerRadius = v }
            }

            // ── Appearance ───────────────────────────────────────────────────

            // Appearance category header
            Text {
                id: appearanceHeader
                text: "Appearance"
                color: Services.Color.mPrimary
                font.bold: true
                font.pixelSize: 14
                topPadding: 8
                visible: appWallpaper.visible || appColorScheme.visible || appPanelOpacity.visible ||
                         appCornerRadius.visible || appBlur.visible
            }

            SettingText {
                id: appWallpaper
                settingLabel: "Wallpaper Path"
                text: Services.SettingsService.appearance.wallpaperPath
                placeholderText: "/path/to/wallpaper.png"
                width: parent.width
                visible: settingLabel.toLowerCase().includes(searchField.text.toLowerCase())
                onEdited: v => { Services.WallpaperService.changeWallpaper(v) }
            }

            SettingDropdown {
                id: appColorScheme
                settingLabel: "Color Scheme"
                model: ["auto", "dark", "light"]
                currentValue: Services.SettingsService.appearance.colorScheme
                width: parent.width
                visible: settingLabel.toLowerCase().includes(searchField.text.toLowerCase())
                onSelected: v => { Services.SettingsService.appearance.colorScheme = v }
            }

            SettingSlider {
                id: appPanelOpacity
                settingLabel: "Panel Opacity"
                from: 0; to: 1; stepSize: 0.05
                value: Services.SettingsService.appearance.panelOpacity
                width: parent.width
                visible: settingLabel.toLowerCase().includes(searchField.text.toLowerCase())
                onMoved: v => { Services.SettingsService.appearance.panelOpacity = v }
            }

            SettingSlider {
                id: appCornerRadius
                settingLabel: "Corner Radius"
                from: 0; to: 24; stepSize: 2
                value: Services.SettingsService.appearance.cornerRadius
                suffix: "px"
                width: parent.width
                visible: settingLabel.toLowerCase().includes(searchField.text.toLowerCase())
                onMoved: v => { Services.SettingsService.appearance.cornerRadius = v }
            }

            SettingToggle {
                id: appBlur
                settingLabel: "Enable Blur"
                checked: Services.SettingsService.appearance.enableBlur
                width: parent.width
                visible: settingLabel.toLowerCase().includes(searchField.text.toLowerCase())
                onToggled: v => { Services.SettingsService.appearance.enableBlur = v }
            }

            // ── Notifications ─────────────────────────────────────────────────

            // Notifications category header
            Text {
                id: notifHeader
                text: "Notifications"
                color: Services.Color.mPrimary
                font.bold: true
                font.pixelSize: 14
                topPadding: 8
                visible: notifMaxVisible.visible || notifTimeout.visible || notifPosition.visible || notifDnd.visible
            }

            SettingSlider {
                id: notifMaxVisible
                settingLabel: "Max Visible"
                from: 1; to: 10; stepSize: 1
                value: Services.SettingsService.notifications.maxVisible
                width: parent.width
                visible: settingLabel.toLowerCase().includes(searchField.text.toLowerCase())
                onMoved: v => { Services.SettingsService.notifications.maxVisible = v }
            }

            SettingSlider {
                id: notifTimeout
                settingLabel: "Timeout"
                from: 1000; to: 15000; stepSize: 500
                value: Services.SettingsService.notifications.timeout
                // Display as seconds
                suffix: "s"
                width: parent.width
                visible: settingLabel.toLowerCase().includes(searchField.text.toLowerCase())
                onMoved: v => { Services.SettingsService.notifications.timeout = v }
            }

            SettingDropdown {
                id: notifPosition
                settingLabel: "Position"
                model: ["top-right", "top-left", "bottom-right", "bottom-left"]
                currentValue: Services.SettingsService.notifications.position
                width: parent.width
                visible: settingLabel.toLowerCase().includes(searchField.text.toLowerCase())
                onSelected: v => { Services.SettingsService.notifications.position = v }
            }

            SettingToggle {
                id: notifDnd
                settingLabel: "Do Not Disturb"
                checked: Services.SettingsService.notifications.dnd
                width: parent.width
                visible: settingLabel.toLowerCase().includes(searchField.text.toLowerCase())
                onToggled: v => { Services.SettingsService.notifications.dnd = v }
            }

            // Empty-search fallback message
            Text {
                width: parent.width
                text: "No matching settings"
                color: Services.Color.mOnSurfaceVariant
                font.pixelSize: 13
                horizontalAlignment: Text.AlignHCenter
                topPadding: 16
                // Visible only when all rows are hidden by the search filter
                visible: !barHeader.visible && !appearanceHeader.visible && !notifHeader.visible
            }
        }
    }
}
