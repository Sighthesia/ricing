import QtQuick
import "../lazerbar"
import "../../services" as Services
import "../../services/WidgetSettingsRegistry.js" as WidgetSettingsRegistry
import "./WidgetIcons.js" as WidgetIcons
import "./ContextMenuLogic.js" as MenuLogic
import "./widgets/ContextSettings.js" as ContextSettings

// The bar's right-click menu: a paged list of commands for the widget under the
// pointer (or for the bar itself when it hit an empty gap).
//
// One page at a time, not one long list. The root page carries what is used on
// its own; anything that expands into controls — a widget's settings, the widget
// catalog, the move routes — is a page reached from a disclosure row and left
// with the header's back arrow. That keeps the menu's height proportional to one
// decision instead of to the sum of all of them, and it never needs a second
// surface (and with it a second input region) to be arranged by the compositor.
Item {
    id: root

    property string widgetId: ""
    property string instanceKey: ""
    property string section: "center"
    property bool hasSettings: false
    property bool layoutMode: false
    property var availableWidgets: []
    property string actionKind: "context"
    // The page on top of the stack. "" is the root list.
    property string page: ""
    property var payload: null
    signal actionRequested(string action)

    implicitWidth: 260
    // Height is a property of the CONTENT, never of whether this item happens to
    // be on screen. Deriving it from `visible` made measurement and drawing
    // mutually dependent: the host installs a context intent and reads this
    // height in the same turn, and `visible` (driven by `actionKind`) had not
    // flipped yet, so the read returned 0. The host fell back to a 1px slot
    // while this body went on painting in full - the whole context menu appeared
    // outside its own clip, stacked under the menu it was replacing.
    implicitHeight: bodyColumn.implicitHeight + 16
    visible: root.actionKind === "context"
    // Empty-area menus carry no widget identity; widget rows need one.
    readonly property bool hasWidgetTarget: root.instanceKey !== ""

    // A widget either declares inline controls (rendered here as a page) or
    // owns a page in the settings panel, which stays the route for it. The row
    // is the same either way; only what a tap does differs.
    readonly property bool settingsInline: root.hasSettings
        && ContextSettings.available(WidgetSettingsRegistry, root.widgetId)
    readonly property bool settingsAvailable: root.hasSettings
    // Shape only — see ContextSettings.rows: carrying values here would rebuild
    // the delegate (and destroy the slider being dragged) on every settings write.
    readonly property var settingsRows: root.settingsInline
        ? ContextSettings.rows(WidgetSettingsRegistry, root.widgetId)
        : []
    // The stored object for THIS instance. The block reads it, and because the
    // service bumps its revision on every write, a read here is what makes each
    // control follow a value set from anywhere else.
    readonly property var settingsObject: {
        if (root.widgetId === "" || root.instanceKey === "")
            return null
        return Services.SettingsService.widgetSettingsObject(root.widgetId, root.instanceKey)
    }
    readonly property var rootBlocks: MenuLogic.rootBlocks(root.hasWidgetTarget)
    readonly property var moveRows: MenuLogic.rowsForMove(root.hasWidgetTarget)

    // Live value of one declared setting, defaulted against the registry.
    function settingValue(settingKey) {
        return ContextSettings.valueOf(WidgetSettingsRegistry, root.widgetId,
            root.settingsObject, String(settingKey))
    }

    // Write through the service so the widget, a reopened menu and the saved
    // file all read the same value; a context menu never owns settings state.
    //
    // No save() here: the service already schedules its own debounced write and
    // bumps the revision every control reads through, so calling it again would
    // re-arm the timer the service had just started.
    function commitSetting(settingKey, value) {
        if (String(settingKey) === "")
            return
        Services.SettingsService.setWidgetInstanceSettingValue(root.widgetId, root.instanceKey,
            String(settingKey), value)
    }

    function invoke(action) {
        var callbacks = root.payload || ({})
        var callback = callbacks[action]
        if (typeof callback === "function")
            callback(root.instanceKey, root.widgetId, root.section)
        root.actionRequested(action)
    }

    // Add a catalog widget into the menu's own section.
    function addWidgetById(widgetId) {
        var callbacks = root.payload || ({})
        var callback = callbacks["addWidget"]
        if (typeof callback === "function")
            callback(String(widgetId || ""), root.section)
        root.actionRequested("addWidget")
        // The catalog stays open: adding two widgets in a row is the normal
        // case, and dropping back to the root after each one makes it three
        // taps per widget.
    }

    function openPage(next) {
        if (next === root.page)
            return
        root.page = String(next)
    }

    function closePage() {
        root.page = ""
    }

    // A row's own behaviour: disclose a page, or run its command.
    function activateRow(row) {
        if (!row)
            return
        // The one row whose meaning depends on where a widget keeps its
        // settings: with inline controls it is a page here, otherwise it hands
        // over to the settings panel's page for it.
        if (row.id === "settings" && !root.settingsInline) {
            root.invoke("openSettings")
            return
        }
        if (row.child !== "") {
            root.openPage(row.child)
            return
        }
        root.invoke(row.action)
    }

    // Symbolic glyph names ("lazer:settings.svg") become real URLs here: the
    // tables are library files, so they name an icon set rather than resolving a
    // path that would only be right from one importer.
    function glyphUrl(iconName) {
        var name = String(iconName || "")
        if (name.indexOf("lazer:") === 0)
            return Qt.resolvedUrl("../lazerbar/icons/" + name.slice(6))
        if (name.indexOf("bar:") === 0)
            return Qt.resolvedUrl("icons/" + name.slice(4))
        return ""
    }

    // Height of the page currently on top, which is what the host measures.
    readonly property real pageHeight: {
        if (root.page === "")
            return rootPage.implicitHeight
        if (root.page === "move")
            return movePage.implicitHeight
        if (root.page === "add-widget")
            return addPage.implicitHeight
        return settingsPage.implicitHeight
    }

    // Remount on the root page with any drilled-down page closed whenever the
    // menu retargets another widget: a page belongs to the target that opened it.
    onInstanceKeyChanged: {
        root.page = ""
    }

    Column {
        id: bodyColumn

        x: 8
        y: 8
        width: parent.width - 16
        spacing: 6

        // Page header: a back arrow, then the page's name. It collapses to
        // nothing on the root page rather than showing a title nothing needs.
        //
        // The arrow is its own control, not part of a titled row: the page name
        // is a heading, and a heading that can be tapped to go elsewhere reads
        // as a link. So the arrow owns the tap and the name is painted beside it.
        Item {
            id: pageHeader

            width: bodyColumn.width
            height: root.page === "" ? 0 : 32
            visible: height > 0

            Rectangle {
                anchors.fill: parent
                radius: 6
                color: LazerTheme.settingsCard
            }

            Item {
                id: backButton

                width: 32
                height: parent.height
                anchors.left: parent.left

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 2
                    radius: 6
                    color: backHover.hovered ? LazerTheme.settingsCardHover : "transparent"
                    Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
                }

                BarIcon {
                    anchors.centerIn: parent
                    width: 16
                    height: 16
                    source: Qt.resolvedUrl("../lazerbar/icons/chevron-back.svg")
                    tint: LazerTheme.textPrimary
                }

                HoverHandler { id: backHover; blocking: false }
                TapHandler {
                    gesturePolicy: TapHandler.ReleaseWithinBounds
                    onTapped: root.closePage()
                }
            }

            Text {
                id: pageTitle

                anchors.left: backButton.right
                anchors.leftMargin: 4
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                text: Services.Tr.q(MenuLogic.pageTitleKey(root.page))
                color: LazerTheme.textPrimary
                font.pixelSize: 13
                font.bold: true
                elide: Text.ElideRight
                maximumLineCount: 1
            }
        }

        // One page at a time, clipped to a height that animates between them so
        // the host's geometry follows a glide instead of a jump. Only the page on
        // top is measured and accepts input; the others keep their content so a
        // return to them does not rebuild every row (which would drop a swatch's
        // selection rule and a slider's thumb back to their first frame).
        Item {
            id: pageHost

            width: bodyColumn.width
            // Height follows the ACTIVE page. Taking it from the root list was
            // the whole-menu bug: the host grew to the root list's height and
            // painted the drilled-down page inside that clip, so a longer page
            // (the catalog) was cut off at the root list's bottom edge.
            height: root.pageHeight
            clip: true
            Behavior on height {
                enabled: !MotionTokens.reducedMotion
                NumberAnimation { duration: MotionTokens.medium; easing.type: Easing.OutQuint }
            }

            // Root page: three blocks of commands. The gap between blocks carries
            // the grouping, so no block draws a header row.
            Column {
                id: rootPage

                width: pageHost.width
                spacing: 6
                y: 0
                enabled: root.page === ""
                // Paint only on top: every page shares this node, so an
                // invisible-but-painted page would show through the gaps of the
                // one above it. `visible` (not just opacity) is what keeps it
                // from being drawn and from contributing to measured size.
                visible: root.page === ""
                opacity: visible ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: MotionTokens.fast } }

                Repeater {
                    model: root.rootBlocks

                    delegate: Item {
                        id: blockHost

                        required property var modelData
                        required property int index

                        width: rootPage.width
                        height: blockColumn.implicitHeight

                        // One card per block, so the commands inside it read as
                        // the same group rather than as rows that happen to touch.
                        Rectangle {
                            anchors.fill: parent
                            radius: 6
                            color: LazerTheme.settingsCard
                        }

                        Column {
                            id: blockColumn

                            width: parent.width
                            spacing: 0

                            Repeater {
                                model: blockHost.modelData

                                delegate: ContextMenuRow {
                                    required property var modelData

                                    width: blockColumn.width
                                    labelText: Services.Tr.q(modelData.label)
                                    glyphSource: root.glyphUrl(modelData.glyph)
                                    trailing: modelData.trailing === "layout" ? "inline"
                                            : modelData.trailing === "chevron" ? "chevron" : ""
                                    trailingText: modelData.trailing === "layout"
                                            ? (root.layoutMode ? Services.Tr.q("common.on")
                                                               : Services.Tr.q("common.off"))
                                            : ""
                                    // The settings row greys out, rather than
                                    // vanishing, when the widget declares nothing
                                    // adjustable: the block keeps its shape for
                                    // every widget instead of collapsing and
                                    // reflowing the menu under the pointer.
                                    enabled: !(modelData.id === "settings" && !root.settingsAvailable)
                                    onActivated: root.activateRow(modelData)
                                }
                            }
                        }
                    }
                }
            }

            // Move page: the routes a widget can take, gathered out of the root
            // so it only carries the decision, not its three outcomes.
            Item {
                id: movePage

                width: pageHost.width
                implicitHeight: moveCard.implicitHeight
                height: implicitHeight
                y: 0
                visible: root.page === "move"
                enabled: visible
                opacity: visible ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: MotionTokens.fast } }

                Rectangle {
                    anchors.fill: moveCard
                    radius: 6
                    color: LazerTheme.settingsCard
                }

                Column {
                    id: moveCard

                    width: parent.width
                    spacing: 0

                    Repeater {
                        model: root.moveRows

                        delegate: ContextMenuRow {
                            required property var modelData

                            width: moveCard.width
                            labelText: Services.Tr.q(modelData.label)
                            glyphSource: root.glyphUrl(modelData.glyph)
                            onActivated: root.activateRow(modelData)
                        }
                    }
                }
            }

            // Add-widget page: the catalog as a two-column grid of icon+name
            // cells. As a single column this page was the longest thing in the
            // menu (one row per shipped widget); as a grid it is half the height
            // and reads as a picker instead of a list of prose.
            Item {
                id: addPage

                width: pageHost.width
                implicitHeight: addCard.implicitHeight
                height: implicitHeight
                y: 0
                visible: root.page === "add-widget"
                enabled: visible
                opacity: visible ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: MotionTokens.fast } }

                Rectangle {
                    anchors.fill: addCard
                    radius: 6
                    color: LazerTheme.settingsCard
                }

                Grid {
                    id: addCard

                    x: 2
                    y: 2
                    width: parent.width - 4
                    columns: 2
                    spacing: 2

                    Repeater {
                        model: root.availableWidgets || []

                        delegate: Item {
                            id: addCell

                            required property var modelData
                            required property int index

                            width: (addCard.width - addCard.spacing) / 2
                            height: 34

                            Rectangle {
                                anchors.fill: parent
                                radius: 6
                                color: addCellHover.hovered ? LazerTheme.settingsCardHover
                                                            : "transparent"
                                Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
                            }

                            BarIcon {
                                x: 8
                                anchors.verticalCenter: parent.verticalCenter
                                width: 14
                                height: 14
                                source: root.glyphUrl(WidgetIcons.sourceFor(addCell.modelData.id))
                                tint: LazerTheme.textMuted
                            }

                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: 30
                                anchors.right: parent.right
                                anchors.rightMargin: 6
                                anchors.verticalCenter: parent.verticalCenter
                                text: Services.Tr.q(String(addCell.modelData.label
                                                            || addCell.modelData.id || "widget.widget"))
                                color: LazerTheme.textPrimary
                                font.pixelSize: 12
                                elide: Text.ElideRight
                                maximumLineCount: 1
                            }

                            // The hover catcher is the whole cell, and the tap
                            // rides it: a cell has no separate control inside.
                            HoverHandler { id: addCellHover; blocking: false }
                            TapHandler {
                                gesturePolicy: TapHandler.ReleaseWithinBounds
                                onTapped: root.addWidgetById(addCell.modelData.id)
                            }
                        }
                    }
                }
            }

            // Settings page: the widget's own declared controls, drawn with the
            // settings panel's row so a percentage or a swatch reads the same
            // here as it does anywhere else in the shell.
            Column {
                id: settingsPage

                width: pageHost.width
                spacing: 0
                y: 0
                visible: root.page === "widget-settings"
                enabled: visible
                opacity: visible ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: MotionTokens.fast } }

                Repeater {
                    model: root.settingsRows

                    delegate: Loader {
                        id: settingsRowLoader

                        required property var modelData
                        required property int index

                        width: settingsPage.width
                        height: item ? item.height : 0
                        sourceComponent: modelData.kind === "slider" ? sliderRowComponent
                            : modelData.kind === "swatch" ? swatchRowComponent : null

                        // The row shape travels on the item itself: the
                        // component's inner controls cannot see this Loader's
                        // scope, and the VALUE stays a per-control binding so a
                        // live write never re-keys the delegate holding the
                        // pointer.
                        onLoaded: {
                            item.rowData = modelData
                            item.labelText = Services.Tr.q(String(modelData.labelKey || ""))
                            item.defaultValue = modelData.defaultValue
                        }
                    }
                }

                // Shown when a widget declares a page but no controls reached it
                // (an older registry entry, say) so the page is never blank.
                Text {
                    width: parent.width
                    height: visible ? 32 : 0
                    visible: root.page === "widget-settings" && root.settingsRows.length === 0
                    verticalAlignment: Text.AlignVCenter
                    horizontalAlignment: Text.AlignHCenter
                    text: Services.Tr.q("context.widgetSettingsEmpty")
                    color: LazerTheme.textMuted
                    font.pixelSize: 11
                }
            }
        }

        // Slider-backed setting: the bar popup reuses the settings panel's own
        // split row, so a percentage reads the same here as anywhere else.
        Component {
            id: sliderRowComponent

            LazerSettingsRow {
                id: sliderRow

                property var rowData: null

                width: settingsPage.width
                currentValue: Math.round(Number(root.settingValue(sliderRow.settingKey)))
                // The row's own crescent button restores the shipped default;
                // without a callback it would slide out and do nothing.
                resetCallback: function() {
                    root.commitSetting(sliderRow.settingKey, sliderRow.defaultValue)
                }

                readonly property string settingKey: rowData ? String(rowData.settingKey) : ""

                LazerSettingsSlider {
                    from: sliderRow.rowData ? sliderRow.rowData.from : 0
                    to: sliderRow.rowData ? sliderRow.rowData.to : 100
                    stepSize: sliderRow.rowData ? sliderRow.rowData.stepSize : 1
                    suffix: sliderRow.rowData ? sliderRow.rowData.suffix : ""
                    value: Math.round(Number(root.settingValue(sliderRow.settingKey)))
                    defaultValue: sliderRow.rowData ? sliderRow.rowData.defaultValue : undefined
                    onValueModified: function(next) {
                        root.commitSetting(sliderRow.settingKey, Math.round(Number(next)))
                    }
                }
            }
        }

        // Swatch-backed setting: named inks resolved from the theme here, so the
        // control itself holds no palette knowledge.
        Component {
            id: swatchRowComponent

            LazerSettingsRow {
                id: swatchRow

                property var rowData: null

                width: settingsPage.width
                currentValue: String(root.settingValue(swatchRow.settingKey))
                resetCallback: function() {
                    root.commitSetting(swatchRow.settingKey, swatchRow.defaultValue)
                }

                readonly property string settingKey: rowData ? String(rowData.settingKey) : ""

                LazerSettingsSwatch {
                    model: {
                        var declared = swatchRow.rowData ? (swatchRow.rowData.options || []) : []
                        var chips = []
                        for (var i = 0; i < declared.length; i++) {
                            // `source` names the theme token the swatch stands
                            // for (see WidgetSettingsRegistry.swatchPalette), so
                            // the registry never has to know a colour and a
                            // themed chip still follows the wallpaper palette.
                            var source = String(declared[i].source || "builtin")
                            // "builtin" has no colour of its own: it means the
                            // widget's own rule, which follows the palette. It
                            // is drawn hollow so it never reads as a swatch
                            // someone forgot to tint.
                            var ink = source === "textPrimary" ? LazerTheme.textPrimary
                                    : source === "textMuted" ? LazerTheme.textMuted
                                    : source === "osuPink" ? LazerTheme.osuPink
                                    : source === "osuGreen" ? LazerTheme.osuGreen
                                    : "transparent"
                            chips.push({ "value": declared[i].value, "color": ink,
                                "hollow": source === "builtin" })
                        }
                        return chips
                    }
                    currentValue: String(root.settingValue(swatchRow.settingKey))
                    onValueModified: function(value) {
                        root.commitSetting(swatchRow.settingKey, String(value))
                    }
                }
            }
        }
    }
}
