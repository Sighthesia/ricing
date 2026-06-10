import QtQuick
import QtQuick.Controls
import "../../services" as Services
import "controls"

// Scrollable settings panel with search filtering across all setting rows.
Item {
    id: root

    function settingMatches(label) {
        return label.toLowerCase().includes(searchField.text.toLowerCase())
    }

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
                height: (barHeight.filterVisible || barPosition.filterVisible || barFloating.filterVisible ||
                         barFloatingMargin.filterVisible || barBgOpacity.filterVisible || barCornerRadius.filterVisible) ? implicitHeight : 0
                opacity: height > 0 ? 1 : 0
                visible: height > 1 || opacity > 0.01
                Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.InOutCubic } }
                Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
            }

            SettingSlider {
                id: barHeight
                settingLabel: "Height"
                from: 24; to: 64; stepSize: 2
                value: Services.SettingsService.bar.height
                suffix: "px"
                width: parent.width
                filterVisible: root.settingMatches(settingLabel)
                onMoved: v => { Services.SettingsService.bar.height = v }
            }

            SettingDropdown {
                id: barPosition
                settingLabel: "Position"
                model: ["top", "bottom"]
                currentValue: Services.SettingsService.bar.position
                width: parent.width
                filterVisible: root.settingMatches(settingLabel)
                onSelected: v => { Services.SettingsService.bar.position = v }
            }

            SettingToggle {
                id: barFloating
                settingLabel: "Floating"
                checked: Services.SettingsService.bar.floating
                width: parent.width
                filterVisible: root.settingMatches(settingLabel)
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
                filterVisible: Services.SettingsService.bar.floating && root.settingMatches(settingLabel)
                onMoved: v => { Services.SettingsService.bar.floatingMargin = v }
            }

            SettingSlider {
                id: barBgOpacity
                settingLabel: "Background Opacity"
                from: 0; to: 1; stepSize: 0.05
                value: Services.SettingsService.bar.backgroundOpacity
                width: parent.width
                filterVisible: root.settingMatches(settingLabel)
                onMoved: v => { Services.SettingsService.bar.backgroundOpacity = v }
            }

            SettingSlider {
                id: barCornerRadius
                settingLabel: "Corner Radius"
                from: 0; to: 24; stepSize: 2
                value: Services.SettingsService.bar.cornerRadius
                suffix: "px"
                width: parent.width
                filterVisible: root.settingMatches(settingLabel)
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
                height: (appWallpaper.filterVisible || appColorScheme.filterVisible || appPanelOpacity.filterVisible ||
                         appCornerRadius.filterVisible || appBlur.filterVisible ||
                         appOverviewBg.filterVisible || appOverviewSolid.filterVisible ||
                         appOverviewBlur.filterVisible || appOverviewTint.filterVisible ||
                         fontDefault.filterVisible || fontFixed.filterVisible ||
                         fontDefaultScale.filterVisible || fontFixedScale.filterVisible) ? implicitHeight : 0
                opacity: height > 0 ? 1 : 0
                visible: height > 1 || opacity > 0.01
                Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.InOutCubic } }
                Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
            }

            SettingText {
                id: appWallpaper
                settingLabel: "Wallpaper Path"
                text: Services.SettingsService.appearance.wallpaperPath
                placeholderText: "/path/to/wallpaper.png"
                width: parent.width
                filterVisible: root.settingMatches(settingLabel)
                onEdited: v => { Services.WallpaperService.changeWallpaper(v) }
            }

            SettingDropdown {
                id: appColorScheme
                settingLabel: "Color Scheme"
                model: ["auto", "dark", "light"]
                currentValue: Services.SettingsService.appearance.colorScheme
                width: parent.width
                filterVisible: root.settingMatches(settingLabel)
                onSelected: v => { Services.SettingsService.appearance.colorScheme = v }
            }

            SettingSlider {
                id: appPanelOpacity
                settingLabel: "Panel Opacity"
                from: 0; to: 1; stepSize: 0.05
                value: Services.SettingsService.appearance.panelOpacity
                width: parent.width
                filterVisible: root.settingMatches(settingLabel)
                onMoved: v => { Services.SettingsService.appearance.panelOpacity = v }
            }

            SettingSlider {
                id: appCornerRadius
                settingLabel: "Corner Radius"
                from: 0; to: 24; stepSize: 2
                value: Services.SettingsService.appearance.cornerRadius
                suffix: "px"
                width: parent.width
                filterVisible: root.settingMatches(settingLabel)
                onMoved: v => { Services.SettingsService.appearance.cornerRadius = v }
            }

            SettingToggle {
                id: appBlur
                settingLabel: "Enable Blur"
                checked: Services.SettingsService.appearance.enableBlur
                width: parent.width
                filterVisible: root.settingMatches(settingLabel)
                onToggled: v => { Services.SettingsService.appearance.enableBlur = v }
            }

            SettingToggle {
                id: appOverviewBg
                settingLabel: "Overview Background"
                checked: Services.SettingsService.appearance.overviewBackground
                width: parent.width
                filterVisible: root.settingMatches(settingLabel)
                onToggled: v => { Services.SettingsService.appearance.overviewBackground = v }
            }

            SettingToggle {
                id: appOverviewSolid
                settingLabel: "Overview Solid Color"
                checked: Services.SettingsService.appearance.overviewBackgroundSolid
                width: parent.width
                filterVisible: Services.SettingsService.appearance.overviewBackground && root.settingMatches(settingLabel)
                onToggled: v => { Services.SettingsService.appearance.overviewBackgroundSolid = v }
            }

            SettingSlider {
                id: appOverviewBlur
                settingLabel: "Overview Blur"
                from: 0; to: 1; stepSize: 0.05
                value: Services.SettingsService.appearance.overviewBackgroundBlur
                width: parent.width
                filterVisible: Services.SettingsService.appearance.overviewBackground &&
                               !Services.SettingsService.appearance.overviewBackgroundSolid &&
                               root.settingMatches(settingLabel)
                onMoved: v => { Services.SettingsService.appearance.overviewBackgroundBlur = v }
            }

            SettingSlider {
                id: appOverviewTint
                settingLabel: "Overview Tint"
                from: 0; to: 1; stepSize: 0.05
                value: Services.SettingsService.appearance.overviewBackgroundTint
                width: parent.width
                filterVisible: Services.SettingsService.appearance.overviewBackground && root.settingMatches(settingLabel)
                onMoved: v => { Services.SettingsService.appearance.overviewBackgroundTint = v }
            }

            // ── Fonts ────────────────────────────────────────────────────────

            Text {
                id: fontsHeader
                text: "Fonts"
                color: Services.Color.mPrimary
                font.bold: true
                font.pixelSize: 14
                topPadding: 8
                height: (fontDefault.filterVisible || fontFixed.filterVisible ||
                         fontDefaultScale.filterVisible || fontFixedScale.filterVisible) ? implicitHeight : 0
                opacity: height > 0 ? 1 : 0
                visible: height > 1 || opacity > 0.01
                Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.InOutCubic } }
                Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
            }

            SettingFontCombo {
                id: fontDefault
                settingLabel: "Default Font"
                description: "UI text font family (empty = system default)"
                fontModel: Services.FontService.fontsLoaded ? Services.FontService.availableFonts : null
                currentKey: Services.SettingsService.appearance.fontDefault
                width: parent.width
                filterVisible: root.settingMatches(settingLabel)
                onSelected: k => { Services.SettingsService.appearance.fontDefault = k }
            }

            SettingFontCombo {
                id: fontFixed
                settingLabel: "Monospace Font"
                description: "Monospace font for numerals and code"
                fontModel: Services.FontService.fontsLoaded ? Services.FontService.monospaceFonts : null
                currentKey: Services.SettingsService.appearance.fontFixed
                width: parent.width
                filterVisible: root.settingMatches(settingLabel)
                onSelected: k => { Services.SettingsService.appearance.fontFixed = k }
            }

            SettingSlider {
                id: fontDefaultScale
                settingLabel: "Default Font Scale"
                from: 0.75; to: 1.25; stepSize: 0.01
                value: Services.SettingsService.appearance.fontDefaultScale
                suffix: "×"
                width: parent.width
                filterVisible: root.settingMatches(settingLabel)
                onMoved: v => { Services.SettingsService.appearance.fontDefaultScale = v }
            }

            SettingSlider {
                id: fontFixedScale
                settingLabel: "Monospace Font Scale"
                from: 0.75; to: 1.25; stepSize: 0.01
                value: Services.SettingsService.appearance.fontFixedScale
                suffix: "×"
                width: parent.width
                filterVisible: root.settingMatches(settingLabel)
                onMoved: v => { Services.SettingsService.appearance.fontFixedScale = v }
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
                height: (notifMaxVisible.filterVisible || notifTimeout.filterVisible || notifPosition.filterVisible || notifDnd.filterVisible) ? implicitHeight : 0
                opacity: height > 0 ? 1 : 0
                visible: height > 1 || opacity > 0.01
                Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.InOutCubic } }
                Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
            }

            SettingSlider {
                id: notifMaxVisible
                settingLabel: "Max Visible"
                from: 1; to: 10; stepSize: 1
                value: Services.SettingsService.notifications.maxVisible
                width: parent.width
                filterVisible: root.settingMatches(settingLabel)
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
                filterVisible: root.settingMatches(settingLabel)
                onMoved: v => { Services.SettingsService.notifications.timeout = v }
            }

            SettingDropdown {
                id: notifPosition
                settingLabel: "Position"
                model: ["top-right", "top-left", "bottom-right", "bottom-left"]
                currentValue: Services.SettingsService.notifications.position
                width: parent.width
                filterVisible: root.settingMatches(settingLabel)
                onSelected: v => { Services.SettingsService.notifications.position = v }
            }

            SettingToggle {
                id: notifDnd
                settingLabel: "Do Not Disturb"
                checked: Services.SettingsService.notifications.dnd
                width: parent.width
                filterVisible: root.settingMatches(settingLabel)
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
                visible: !barHeader.visible && !appearanceHeader.visible && !fontsHeader.visible && !notifHeader.visible
            }
        }
    }
}
