import QtQuick
import Quickshell
import Quickshell.Io
import "LazerSettingsLogic.js" as Logic
import "../../services" as Services

// Preset color scheme picker for the appearance page (noctalia model):
// one card per bundled/user scheme from ColorSchemeService, swatches read
// from the scheme's own JSON. Selecting one activates it once wallpaper
// adaptation is off; Color.qml then consumes the preset's palette.
Item {
    id: root

    property string searchQuery: ""
    property var settingsObject: null
    property var saveCallback: null

    readonly property bool matchesSearch: Logic.matchesSearch("配色方案", "配色方案预设 scheme preset", searchQuery)
    readonly property bool searchVisible: matchesSearch
    readonly property bool searchHidden: Logic.normalizeSearchQuery(searchQuery).length > 0 && !matchesSearch
    // The preset only paints while wallpaper adaptation is off.
    readonly property bool presetActive: settingsObject ? settingsObject.themeAdaptation === false : false

    // Seat the picker title, description, and cards on one row-style card.
    Rectangle {
        id: background
        z: -1
        anchors.fill: parent
        radius: 6
        color: LazerTheme.settingsCard
    }

    implicitWidth: 400
    width: parent ? parent.width : implicitWidth
    readonly property real bottomPadding: 12
    readonly property real titleBandHeight: 10 + titleText.height + 2 + descriptionText.height + 6
    implicitHeight: grid.y + grid.height + bottomPadding
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

    // Same variant resolution as Color.applyColors so swatches match what
    // the shell will actually paint.
    readonly property bool useLight: Services.SettingsService.effectiveColorScheme === "light"

    Text {
        id: titleText
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.top: parent.top
        anchors.topMargin: 10
        text: "配色方案"
        color: LazerTheme.textMuted
        font.pixelSize: 11
    }

    Text {
        id: descriptionText
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.top: titleText.bottom
        anchors.topMargin: 2
        text: root.presetActive ? "" : "关闭「壁纸主题色」后生效"
        color: LazerTheme.textMuted
        font.pixelSize: 10
        opacity: 0.85
    }

    readonly property Item backgroundItem: background
    readonly property Item titleItem: titleText
    readonly property Item descriptionItem: descriptionText
    readonly property Item gridItem: grid

    Grid {
        id: grid
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: descriptionText.bottom
        anchors.topMargin: 6
        columns: 4
        columnSpacing: 6
        rowSpacing: 6
        opacity: root.presetActive ? 1 : 0.55

        Behavior on opacity { ColorAnimation { duration: MotionTokens.fast } }

        Repeater {
            model: Services.ColorSchemeService.schemes

            Item {
                id: card

                required property var modelData
                readonly property string schemeName: modelData ? modelData.name : ""
                readonly property var palette: swatchData
                    ? (root.useLight ? (swatchData.light || swatchData.dark) : (swatchData.dark || swatchData.light))
                    : null
                readonly property bool selected:
                    (settingsObject ? settingsObject.presetScheme : "") === schemeName
                readonly property bool hovered: hover.hovered
                property var swatchData: null

                width: (grid.width - grid.columnSpacing * 3) / 4
                height: 64

                // Swatches come from the scheme's own file; a plain JSON.parse
                // is enough since only a handful of keys are needed.
                FileView {
                    id: schemeFile
                    path: card.modelData ? card.modelData.path : ""
                    watchChanges: false
                    printErrors: false
                    onLoaded: {
                        try { card.swatchData = JSON.parse(this.text()) } catch (e) { card.swatchData = null }
                    }
                    onLoadFailed: card.swatchData = null
                }

                Rectangle {
                    id: surface
                    anchors.fill: parent
                    radius: LazerTheme.settingsControlRadius
                    color: card.hovered ? LazerTheme.settingsCardHover : LazerTheme.settingsCard
                    border.width: 1
                    border.color: card.selected ? LazerTheme.settingsAccent : "transparent"
                    Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
                }

                // Swatch strip: surface / primary / tertiary / container / outline.
                Rectangle {
                    id: swatchStrip
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 5
                    height: 30
                    radius: 3
                    clip: true
                    color: card.palette ? card.palette.surface : LazerTheme.settingsSection

                    Row {
                        anchors.fill: parent

                        Repeater {
                            model: [
                                card.palette ? card.palette.primary : "",
                                card.palette ? card.palette.tertiary : "",
                                card.palette ? card.palette.primary_container : "",
                                card.palette ? card.palette.surface_container_high : "",
                                card.palette ? card.palette.outline : "",
                            ]

                            Rectangle {
                                required property string modelData
                                width: swatchStrip.width / 5
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
                    text: card.modelData ? card.modelData.display : ""
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
                    if (!settingsObject || settingsObject.presetScheme === card.schemeName) return
                    flashAnimation.restart()
                    settingsObject.presetScheme = card.schemeName
                    if (saveCallback) saveCallback()
                }
            }
        }
    }
}
