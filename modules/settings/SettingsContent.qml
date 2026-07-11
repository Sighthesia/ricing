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

    // Consume any pre-filter passed from a search result navigation.
    Component.onCompleted: {
        var filter = Services.IslandService.settingsInitialFilter
        if (filter && filter.trim().length > 0) {
            searchField.text = filter
            Services.IslandService.settingsInitialFilter = ""
        }
    }

    // Search field at the top
    TextField {
        id: searchField
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        placeholderText: "Search settings..."
        color: Services.Color.mOnSurface
        font.family: Services.SettingsService.appearance.fontDefault || Qt.application.font.family
        font.pixelSize: Math.round(13 * (Services.SettingsService.appearance.fontDefaultScale || 1.0))
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
            Services.FluidText {
                id: barHeader
                text: "Bar"
                color: Services.Color.mPrimary
                font.bold: true
                basePixelSize: 14
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
            Services.FluidText {
                id: appearanceHeader
                text: "Appearance"
                color: Services.Color.mPrimary
                font.bold: true
                basePixelSize: 14
                topPadding: 8
                height: (appWallpaper.filterVisible || appColorScheme.filterVisible || appPanelOpacity.filterVisible ||
                         appCornerRadius.filterVisible || appBlur.filterVisible ||
                          appBlurPasses.filterVisible || appBlurOffset.filterVisible ||
                          appBlurNoise.filterVisible || appBlurSaturation.filterVisible ||
                          appBlurSurfaceOpacity.filterVisible ||
                          appGlassHighlightWidth.filterVisible || appGlassHighlightIntensity.filterVisible ||
                          appGlassGlowWidth.filterVisible || appGlassGlowIntensity.filterVisible ||
                          appGlassThemeAdaptive.filterVisible ||
                          appRipplePulse.filterVisible || appRippleFullscreen.filterVisible ||
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

            SettingSlider {
                id: appBlurPasses
                settingLabel: "Blur Passes"
                description: "Higher = stronger blur, more GPU cost"
                from: 1; to: 6; stepSize: 1
                value: Services.SettingsService.appearance.blurPasses
                width: parent.width
                filterVisible: Services.SettingsService.appearance.enableBlur && root.settingMatches(settingLabel)
                onMoved: v => { Services.SettingsService.appearance.blurPasses = v }
            }

            SettingSlider {
                id: appBlurOffset
                settingLabel: "Blur Offset"
                description: "Higher = softer blur, may cause artifacts"
                from: 0.5; to: 6; stepSize: 0.5
                value: Services.SettingsService.appearance.blurOffset
                width: parent.width
                filterVisible: Services.SettingsService.appearance.enableBlur && root.settingMatches(settingLabel)
                onMoved: v => { Services.SettingsService.appearance.blurOffset = v }
            }

            SettingSlider {
                id: appBlurNoise
                settingLabel: "Blur Noise"
                description: "Reduces color banding"
                from: 0; to: 0.1; stepSize: 0.005
                value: Services.SettingsService.appearance.blurNoise
                width: parent.width
                filterVisible: Services.SettingsService.appearance.enableBlur && root.settingMatches(settingLabel)
                onMoved: v => { Services.SettingsService.appearance.blurNoise = v }
            }

            SettingSlider {
                id: appBlurSaturation
                settingLabel: "Blur Saturation"
                description: "Color intensity of blurred background"
                from: 0.5; to: 3; stepSize: 0.1
                value: Services.SettingsService.appearance.blurSaturation
                width: parent.width
                filterVisible: Services.SettingsService.appearance.enableBlur && root.settingMatches(settingLabel)
                onMoved: v => { Services.SettingsService.appearance.blurSaturation = v }
            }

            SettingSlider {
                id: appBlurSurfaceOpacity
                settingLabel: "Blur Surface Opacity"
                description: "Surface tint opacity when blur is enabled (0 = fully transparent)"
                from: 0.1; to: 1; stepSize: 0.05
                value: Services.SettingsService.appearance.blurSurfaceOpacity
                width: parent.width
                filterVisible: Services.SettingsService.appearance.enableBlur && root.settingMatches(settingLabel)
                onMoved: v => { Services.SettingsService.appearance.blurSurfaceOpacity = v }
            }

            // Keep the liquid-glass edge independently adjustable from compositor blur.
            SettingSlider {
                id: appGlassHighlightWidth
                settingLabel: "Glass Highlight Width"
                description: "Thickness of the fine refractive edge"
                from: 1; to: 4; stepSize: 1
                value: Services.SettingsService.appearance.glassHighlightWidth
                suffix: "px"
                width: parent.width
                filterVisible: root.settingMatches(settingLabel)
                onMoved: v => { Services.SettingsService.appearance.glassHighlightWidth = v }
            }

            // Control the brightness of the refractive glass edge.
            SettingSlider {
                id: appGlassHighlightIntensity
                settingLabel: "Glass Highlight Intensity"
                description: "Brightness of the refractive edge"
                from: 0.1; to: 1; stepSize: 0.05
                value: Services.SettingsService.appearance.glassHighlightIntensity
                width: parent.width
                filterVisible: root.settingMatches(settingLabel)
                onMoved: v => { Services.SettingsService.appearance.glassHighlightIntensity = v }
            }

            // Control the soft outer glow without changing surface geometry.
            SettingSlider {
                id: appGlassGlowWidth
                settingLabel: "Theme Glow Width"
                description: "Spread of the soft outer glow"
                from: 1; to: 10; stepSize: 1
                value: Services.SettingsService.appearance.glassGlowWidth
                suffix: "px"
                width: parent.width
                filterVisible: root.settingMatches(settingLabel)
                onMoved: v => { Services.SettingsService.appearance.glassGlowWidth = v }
            }

            // Control the theme-color contribution around glass edges.
            SettingSlider {
                id: appGlassGlowIntensity
                settingLabel: "Theme Glow Intensity"
                description: "Strength of the theme-color outer glow"
                from: 0; to: 0.6; stepSize: 0.05
                value: Services.SettingsService.appearance.glassGlowIntensity
                width: parent.width
                filterVisible: root.settingMatches(settingLabel)
                onMoved: v => { Services.SettingsService.appearance.glassGlowIntensity = v }
            }

            // Switch between wallpaper-derived color and a neutral glass edge.
            SettingToggle {
                id: appGlassThemeAdaptive
                settingLabel: "Theme Adaptation"
                description: "Match glass highlights to wallpaper-derived theme colors"
                checked: Services.SettingsService.appearance.glassThemeAdaptive
                width: parent.width
                filterVisible: root.settingMatches(settingLabel)
                onToggled: v => { Services.SettingsService.appearance.glassThemeAdaptive = v }
            }

            SettingToggle {
                id: appRipplePulse
                settingLabel: "Ripple Pulse"
                description: "Flash a screen-centered ring when island panels or transient messages appear"
                checked: Services.SettingsService.appearance.ripplePulseEnabled
                width: parent.width
                filterVisible: root.settingMatches(settingLabel)
                onToggled: v => { Services.SettingsService.appearance.ripplePulseEnabled = v }
            }

            SettingToggle {
                id: appRippleFullscreen
                settingLabel: "Ripple Fullscreen Overlay"
                description: "Let the pulse cover the full screen instead of only shell surfaces"
                checked: Services.SettingsService.appearance.ripplePulseFullscreen
                width: parent.width
                filterVisible: Services.SettingsService.appearance.ripplePulseEnabled && root.settingMatches(settingLabel)
                onToggled: v => { Services.SettingsService.appearance.ripplePulseFullscreen = v }
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

            Services.FluidText {
                id: fontsHeader
                text: "Fonts"
                color: Services.Color.mPrimary
                font.bold: true
                basePixelSize: 14
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
            Services.FluidText {
                id: notifHeader
                text: "Notifications"
                color: Services.Color.mPrimary
                font.bold: true
                basePixelSize: 14
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

            // ── Controls ────────────────────────────────────────────────────────

            // Controls category header
            Services.FluidText {
                id: controlsHeader
                text: "Controls"
                color: Services.Color.mPrimary
                font.bold: true
                basePixelSize: 14
                topPadding: 8
                height: (volStep.filterVisible || briStep.filterVisible) ? implicitHeight : 0
                opacity: height > 0 ? 1 : 0
                visible: height > 1 || opacity > 0.01
                Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.InOutCubic } }
                Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
            }

            SettingSlider {
                id: volStep
                settingLabel: "Volume Step"
                description: "Increment per scroll tick or shortcut press"
                from: 0.01; to: 0.20; stepSize: 0.01
                value: Services.SettingsService.controls.volumeStep
                suffix: ""
                width: parent.width
                filterVisible: root.settingMatches(settingLabel)
                onMoved: v => { Services.SettingsService.controls.volumeStep = v }
            }

            SettingSlider {
                id: briStep
                settingLabel: "Brightness Step"
                description: "Increment per scroll tick or shortcut press"
                from: 0.01; to: 0.20; stepSize: 0.01
                value: Services.SettingsService.controls.brightnessStep
                suffix: ""
                width: parent.width
                filterVisible: root.settingMatches(settingLabel)
                onMoved: v => { Services.SettingsService.controls.brightnessStep = v }
            }

            // Empty-search fallback message
            Services.FluidText {
                width: parent.width
                text: "No matching settings"
                color: Services.Color.mOnSurfaceVariant
                basePixelSize: 13
                horizontalAlignment: Text.AlignHCenter
                topPadding: 16
                // Visible only when all rows are hidden by the search filter
                visible: !barHeader.visible && !appearanceHeader.visible && !fontsHeader.visible && !notifHeader.visible && !controlsHeader.visible
            }
        }
    }
}
