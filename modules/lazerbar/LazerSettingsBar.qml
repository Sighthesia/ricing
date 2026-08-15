import QtQuick

// Present the supported top-bar settings in a scrollable category page.
Flickable {
    id: root
    property var settingsObject: null
    property var saveCallback: null
    property string title: "顶部栏"
    property string searchQuery: ""
    readonly property int visibleResultCount:
        (heightRow.searchVisible ? 1 : 0)
        + (positionRow.searchVisible ? 1 : 0)
        + (floatingRow.searchVisible ? 1 : 0)
        + (floatingMarginRow.searchVisible ? 1 : 0)
        + (cornerRadiusRow.searchVisible ? 1 : 0)
    property alias heightSlider: heightSliderControl
    property alias positionChoice: positionChoiceControl
    property alias floatingToggle: floatingToggleControl
    property alias floatingMarginSlider: floatingMarginSliderControl
    property alias floatingMarginRow: floatingMarginRow
    property alias cornerRadiusSlider: cornerRadiusSliderControl
    property alias heightRow: heightRow
    contentWidth: width; contentHeight: pageColumn.implicitHeight; clip: true
    boundsBehavior: Flickable.StopAtBounds

    function save() { if (root.saveCallback) root.saveCallback() }

    function normalizePosition(value) {
        return value === "bottom" ? "bottom" : "top"
    }

    // Keep top-bar controls grouped in one vertically scrollable column.
    Column {
        id: pageColumn; width: root.width; spacing: 8
        Text { text: root.title; color: LazerTheme.textPrimary; font.pixelSize: 22; leftPadding: 16; topPadding: 12 }
        LazerSettingsRow {
            id: heightRow
            width: pageColumn.width - 16; x: 8
            searchQuery: root.searchQuery
            labelText: "顶部栏高度"; descriptionText: "范围 40 到 64 像素"
            LazerSettingsSlider { id: heightSliderControl; from: 40; to: 64; stepSize: 1; value: root.settingsObject ? root.settingsObject.height : 48; onValueModified: function(value) { if (root.settingsObject) { root.settingsObject.height = Math.round(Math.max(40, Math.min(64, value))); root.save() } } }
        }
        LazerSettingsRow {
            id: positionRow
            width: pageColumn.width - 16; x: 8
            searchQuery: root.searchQuery
            labelText: "栏位置"
            LazerSettingsChoice { id: positionChoiceControl; model: [{ value: "top", label: "顶部" }, { value: "bottom", label: "底部" }]; currentValue: root.normalizePosition(root.settingsObject ? root.settingsObject.position : "top"); onValueSelected: function(value) { if (root.settingsObject && (value === "top" || value === "bottom")) { root.settingsObject.position = value; root.save() } } }
        }
        LazerSettingsRow {
            id: floatingRow
            width: pageColumn.width - 16; x: 8
            searchQuery: root.searchQuery
            labelText: "浮动模式"
            LazerSettingsToggle { id: floatingToggleControl; checked: root.settingsObject ? root.settingsObject.floating : false; onToggled: function(value) { if (root.settingsObject) { root.settingsObject.floating = value; root.save() } } }
        }
        LazerSettingsRow {
            id: floatingMarginRow
            width: pageColumn.width - 16; x: 8
            searchQuery: root.searchQuery
            enabled: root.settingsObject ? root.settingsObject.floating : false; labelText: "浮动边距"; descriptionText: "范围 0 到 24 像素"
            LazerSettingsSlider { id: floatingMarginSliderControl; from: 0; to: 24; stepSize: 1; value: root.settingsObject ? root.settingsObject.floatingMargin : 4; onValueModified: function(value) { if (root.settingsObject) { root.settingsObject.floatingMargin = Math.round(Math.max(0, Math.min(24, value))); root.save() } } }
        }
        LazerSettingsRow {
            id: cornerRadiusRow
            width: pageColumn.width - 16; x: 8
            searchQuery: root.searchQuery
            labelText: "圆角半径"; descriptionText: "范围 0 到 24 像素"
            LazerSettingsSlider { id: cornerRadiusSliderControl; from: 0; to: 24; stepSize: 1; value: root.settingsObject ? root.settingsObject.cornerRadius : 12; onValueModified: function(value) { if (root.settingsObject) { root.settingsObject.cornerRadius = Math.round(Math.max(0, Math.min(24, value))); root.save() } } }
        }
    }
}
