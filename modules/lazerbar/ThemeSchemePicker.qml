import QtQuick
import Quickshell
import Quickshell.Io
import "LazerSettingsLogic.js" as Logic
import "../../services" as Services

// Theme template picker for the appearance page: one card per Material
// scheme type, each showing the wallpaper's extracted palette under that
// scheme. Previews come from ColorService's merged theme-previews.json.
Item {
    id: root

    property string searchQuery: ""
    property var settingsObject: null
    property var saveCallback: null
    property var defaults: ({})
    property var resetCallback: null

    readonly property bool matchesSearch: Logic.matchesSearch("主题模板", "主题模板配色方案 theme scheme", searchQuery)
    readonly property bool searchVisible: matchesSearch
    readonly property bool searchHidden: Logic.normalizeSearchQuery(searchQuery).length > 0 && !matchesSearch

    implicitWidth: 400
    width: parent ? parent.width : implicitWidth
    implicitHeight: titleText.height + 8 + grid.height + 14
    // Collapse like a search-hidden row so the section frees the space.
    height: searchHidden ? 0 : implicitHeight
    visible: !searchHidden || opacity > 0.01
    opacity: searchHidden ? 0 : 1

    Behavior on height {
        enabled: !MotionTokens.reducedMotion
        NumberAnimation { duration: MotionTokens.slow; easing.type: Easing.OutQuint }
    }
    Behavior on opacity {
        enabled: !MotionTokens.reducedMotion
        NumberAnimation { duration: MotionTokens.slow; easing.type: Easing.OutQuint }
    }

    // Same dark/light resolution as Color.applyColors so previews match
    // what the shell will actually apply.
    readonly property bool useLight: Services.SettingsService.appearance.colorScheme === "light"
    function paletteFor(scheme) {
        const entry = previews ? previews[scheme] : null
        if (!entry) return null
        const mode = useLight ? "light" : "dark"
        return entry[mode] || null
    }

    // Merged preview file written by ColorService.previewSchemes().
    property var previews: null
    // Card delegates in display order, exposed for tests and diagnostics.
    readonly property alias schemeCards: grid.children

    FileView {
        id: previewsFile
        path: Quickshell.cacheDir + "/theme-previews.json"
        watchChanges: true
        printErrors: false

        onFileChanged: reloadTimer.restart()
        onLoaded: root.previews = parsePreviews(text())
        onLoadFailed: root.previews = null
    }

    // A file created after startup never fires watchChanges, so re-check
    // whenever the preview batch finishes. A wallpaper swap while the panel
    // is open starts a fresh batch for the new image.
    Connections {
        target: Services.ColorService
        function onIsPreviewingChanged() {
            if (!Services.ColorService.isPreviewing)
                reloadTimer.restart()
        }
    }

    Connections {
        target: Services.SettingsService.appearance
        function onWallpaperPathChanged() {
            Services.ColorService.previewSchemes()
        }
    }

    function parsePreviews(raw) {
        try { return JSON.parse(raw) } catch (e) { return null }
    }

    Timer {
        id: reloadTimer
        interval: 200
        onTriggered: previewsFile.reload()
    }

    Text {
        id: titleText
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.top: parent.top
        text: "主题模板"
        color: LazerTheme.textMuted
        font.pixelSize: 11
    }

    Grid {
        id: grid
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: titleText.bottom
        anchors.topMargin: 8
        columns: 4
        columnSpacing: 6
        rowSpacing: 6

        Repeater {
            model: Services.ColorService.schemeTypes

            Item {
                id: card
                required property string modelData
                readonly property var schemePalette: paletteFor(modelData)
                readonly property bool selected:
                    (settingsObject ? settingsObject.themeScheme : "") === modelData
                readonly property bool hovered: hover.hovered

                width: (grid.width - grid.columnSpacing * 3) / 4
                height: 64

                // Card surface with the standard hover swap.
                Rectangle {
                    id: surface
                    anchors.fill: parent
                    radius: LazerTheme.settingsControlRadius
                    color: card.hovered ? LazerTheme.settingsCardHover : LazerTheme.settingsCard
                    border.width: 1
                    border.color: card.selected ? LazerTheme.settingsAccent : "transparent"
                    Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
                }

                // Swatch strip: primary / tertiary / surface / container steps.
                Rectangle {
                    id: swatchStrip
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 5
                    height: 30
                    radius: 3
                    clip: true
                    color: schemePalette ? schemePalette.surface : LazerTheme.settingsSection

                    Row {
                        anchors.fill: parent
                        Repeater {
                            model: [
                                schemePalette ? schemePalette.primary : "",
                                schemePalette ? schemePalette.tertiary : "",
                                schemePalette ? schemePalette.surface_container_high : "",
                                schemePalette ? schemePalette.outline : "",
                            ]

                            Rectangle {
                                required property string modelData
                                width: swatchStrip.width / 4
                                height: parent.height
                                color: modelData !== "" ? modelData : LazerTheme.settingsToggleOff
                                Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
                            }
                        }
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 4
                    text: schemeLabel(card.modelData)
                    color: card.selected ? LazerTheme.settingsAccent : LazerTheme.textPrimary
                    font.pixelSize: 10
                    Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
                }

                // Focus-style selection ring drawn above the surface border.
                Rectangle {
                    visible: card.selected
                    anchors.fill: parent
                    radius: surface.radius
                    color: "transparent"
                    border.width: 1.5
                    border.color: LazerTheme.settingsAccent
                }

                HoverHandler { id: hover }

                TapHandler {
                    onTapped: card.selectScheme()
                }

                // Unified click flash overlay per the settings-panel recipe.
                Rectangle {
                    id: flashOverlay
                    anchors.fill: parent
                    radius: surface.radius
                    color: LazerTheme.textPrimary
                    opacity: 0
                }

                NumberAnimation {
                    id: flashAnimation
                    target: flashOverlay
                    property: "opacity"
                    from: MotionTokens.clickFlashOpacity
                    to: 0
                    duration: MotionTokens.clickFlashDuration
                    easing.type: MotionTokens.clickFlashEasing
                }

                function selectScheme() {
                    if (!settingsObject || settingsObject.themeScheme === modelData) return
                    flashAnimation.restart()
                    settingsObject.themeScheme = modelData
                    if (saveCallback) saveCallback()
                }
            }
        }
    }

    function schemeLabel(scheme) {
        const labels = {
            "tonal-spot": "色调",
            "content": "原色",
            "fruit-salad": "果盘",
            "rainbow": "彩虹",
            "monochrome": "单色",
            "vibrant": "鲜活",
            "faithful": "忠实",
            "muted": "柔和",
        }
        return labels[scheme] || scheme
    }

    // Restore-to-default support consistent with sibling rows.
    function resetKey(key) {
        if (resetCallback && defaults && (key in defaults))
            resetCallback(key, defaults[key])
    }
}
