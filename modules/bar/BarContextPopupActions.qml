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

    // Page swap state: the page being left stays mounted beside the page being
    // entered, and the two slide past each other inside the same clip. This is
    // the popup host's own exchange - one clock, a cross-fade, and a distance
    // frozen for the whole move - because a page change here IS the same kind of
    // move the host makes between two hover menus, and it should read the same.
    property string _outgoingPage: ""
    // Height the clip started from when the current swap began.
    property real _pageFromHeight: 0
    // True from the first frame of a swap until its clock has landed.
    property bool _pageSwapActive: false
    property real pageSlideProgress: 1
    property int pageSlideSign: 1
    readonly property real pageSlideDistance: Math.max(pageHost.width, 260)

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

    // Enter a page from the right, leave it to the left: the same direction rule
    // the host uses, where the incoming face arrives from the edge the content
    // is travelling toward.
    function openPage(next) {
        root.beginPageSwap(String(next), 1)
    }

    function closePage() {
        root.beginPageSwap("", -1)
    }

    function beginPageSwap(next, sign) {
        if (next === root.page && root._outgoingPage === "")
            return
        // A swap already in flight lands before the next one starts: two tracks
        // overlapping would make the direction describe neither move.
        if (root.pageSlideProgress < 1) {
            pageSlideMotion.stop()
            root.pageSlideProgress = 1
        }
        // Freeze the height the clip starts from, and start the clock BEFORE the
        // page changes. Both orders matter: `pageHeight` is a binding on
        // `root.page`, so the moment that property moves it reports the incoming
        // page's height. Reading it afterwards - or leaving `pageSlideProgress`
        // at 1 for even one binding evaluation - made the clip snap straight to
        // the destination and the whole interpolation was dead on arrival
        // (measured: clip at 286 on the very frame the swap started).
        root._pageFromHeight = root.naturalPageHeight(root.page)
        root.pageSlideSign = Number(sign) < 0 ? -1 : 1
        if (MotionTokens.reducedMotion) {
            root._pageSwapActive = false
            root._outgoingPage = ""
            root.page = next
            root.pageSlideProgress = 1
            return
        }
        // Raise the flag and zero the clock BEFORE the page changes: the clip's
        // height reads both, and it must already be at the start of the move when
        // the incoming page's own height becomes the target.
        root._pageSwapActive = true
        root.pageSlideProgress = 0
        root._outgoingPage = root.page
        root.page = next
        pageSlideMotion.restart()
    }

    function pageVisible(name) {
        return root.page === name || root._outgoingPage === name
    }

    function pageX(name) {
        if (root.page === name)
            return root.pageSlideSign * root.pageSlideDistance * (1 - root.pageSlideProgress)
        if (root._outgoingPage === name)
            return -root.pageSlideSign * root.pageSlideDistance * root.pageSlideProgress
        return 0
    }

    function pageOpacity(name) {
        if (root.page === name)
            return root.pageSlideProgress
        if (root._outgoingPage === name)
            return 1 - root.pageSlideProgress
        return 0
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

    // How much of the page header's slot is open, 0..1, driven by the slide.
    //
    // Three cases, because the header belongs to the page being entered or left
    // and not to the swap itself:
    //   * entering a page from the root list  -> opens as the page arrives
    //   * returning to the root list          -> closes as the page leaves
    //   * one page to another                 -> stays open, the title swaps
    // At rest (`_outgoingPage` empty) it is simply "is a page on top".
    readonly property real headerWeight: {
        if (root._outgoingPage === "")
            return root.page === "" ? 0 : root.pageSlideProgress
        if (root.page === "")
            return 1 - root.pageSlideProgress
        return 1
    }

    // Natural height of one named page ("" is the root list).
    function naturalPageHeight(name) {
        if (name === "")
            return rootPage.implicitHeight
        if (name === "move")
            return movePage.implicitHeight
        if (name === "add-widget")
            return addPage.implicitHeight
        return settingsPage.implicitHeight
    }

    // Height of the page currently on top, which is what the host measures.
    readonly property real pageHeight: root.naturalPageHeight(root.page)

    // The clip the pages are painted inside. While a swap runs it interpolates
    // from the page being left to the page being entered on the slide's own
    // clock, so the panel opens exactly as fast as the incoming page travels and
    // never lags behind it. At rest it is simply the page's own height.
    //
    // `_pageSwapActive` is what makes the interpolation possible at all: while
    // the swap is being set up, `pageSlideProgress` is still 1 (the previous
    // move's end state), so a formula keyed on the progress alone would evaluate
    // to the DESTINATION height on the very frame the swap begins and the panel
    // would snap. The flag goes up before anything else moves and only comes down
    // once the clock has landed.
    readonly property real pageClipHeight: !root._pageSwapActive
        ? root.pageHeight
        : root._pageFromHeight + (root.pageHeight - root._pageFromHeight) * root.pageSlideProgress

    // Remount on the root page with any drilled-down page closed whenever the
    // menu retargets another widget: a page belongs to the target that opened it.
    onInstanceKeyChanged: {
        pageSlideMotion.stop()
        root._outgoingPage = ""
        root._pageFromHeight = 0
        root._pageSwapActive = false
        root.pageSlideProgress = 1
        root.page = ""
    }

    // Two slots, positioned explicitly instead of stacked in a Column.
    //
    // A Column sums its children's `height`, and an item with a `Behavior` on
    // height still reports its OLD height for the frames the animation runs -
    // measured: the header animated 32 -> 0 while the column stayed at 204 the
    // whole time, so the page below never moved up and the menu kept a band
    // above it until the header's animation ended. Offsetting each slot from
    // numbers this component owns makes the two move together on the same frame.
    Item {
        id: bodyColumn

        x: 8
        y: 8
        width: parent.width - 16
        // The gap travels with the header, so the collapse has no 6px pop at
        // the end when the slot finishes closing.
        readonly property real headerGap: 6 * root.headerWeight
        readonly property real headerSlotHeight: pageHeader.height + headerGap
        implicitHeight: headerSlotHeight + pageHost.height
        height: implicitHeight

        // Page header: a back arrow, then the page's name. It collapses to
        // nothing on the root page rather than showing a title nothing needs.
        //
        // The arrow is its own control, not part of a titled row: the page name
        // is a heading, and a heading that can be tapped to go elsewhere reads
        // as a link. So the arrow owns the tap and the name is painted beside it.
        // The header belongs to the page that owns it, so it travels with it:
        // going back slides the root list in from the left and this title leaves
        // to the right, which is what makes the two read as one surface moving
        // rather than as a title that blinks out of existence.
        Item {
            id: pageHeader

            width: bodyColumn.width
            y: 0
            // The slot opens and closes ON the page-slide clock, not after it.
            // Waiting for the slide to finish before collapsing left a 32px band
            // above the returning list for the whole exit - the header was still
            // 32px high while `_outgoingPage` was set, and only started shrinking
            // once that cleared. Riding the slide keeps the two in step: the band
            // is gone by the frame the incoming page is centred.
            height: 32 * root.headerWeight
            visible: height > 0.5
            x: root.page === ""
                ? -root.pageSlideSign * root.pageSlideDistance * root.pageSlideProgress
                : root.pageSlideSign * root.pageSlideDistance * (1 - root.pageSlideProgress)
            opacity: root.page === ""
                ? 1 - root.pageSlideProgress
                : root.pageSlideProgress

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
                    source: Qt.resolvedUrl("../lazerbar/icons/chevron-left.svg")
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
                // While the header leaves, it still names the page that is
                // leaving; reading `page` alone would relabel it mid-slide.
                text: Services.Tr.q(MenuLogic.pageTitleKey(root.page !== ""
                    ? root.page : root._outgoingPage))
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
            y: bodyColumn.headerSlotHeight
            // Height follows the ACTIVE page. Taking it from the root list was
            // the whole-menu bug: the host grew to the root list's height and
            // painted the drilled-down page inside that clip, so a longer page
            // (the catalog) was cut off at the root list's bottom edge.
            //
            // No Behavior here. A second clock on this clip is exactly what made
            // the panel and its content disagree: the clip eased over 160ms while
            // the page slid over 240ms, so the height only finished after the
            // crossing was over. `pageClipHeight` is already a function of the
            // slide, so this reads one motion, not two.
            height: root.pageClipHeight
            clip: true

            // The swap clock. Same duration and curve as the host's content
            // slide, so a page change and a menu change are one motion in the
            // eye; reduced motion lands the page without travel.
            NumberAnimation {
                id: pageSlideMotion

                target: root
                property: "pageSlideProgress"
                from: 0
                to: 1
                duration: MotionTokens.reducedMotion ? 0 : MotionTokens.slow
                easing.type: Easing.OutCubic
                onFinished: {
                    if (root.pageSlideProgress >= 1) {
                        root._outgoingPage = ""
                        root._pageSwapActive = false
                    }
                }
            }

            // Root page: three blocks of commands. The gap between blocks carries
            // the grouping, so no block draws a header row.
            Column {
                id: rootPage

                width: pageHost.width
                spacing: 6
                // A page is painted while it is entering or leaving, and only
                // then: the swap slides the two past each other, so both must be
                // drawn for the length of the move and neither may be left
                // painting afterwards (a page sharing this node would show
                // through the gaps of the one above it).
                y: 0
                x: root.pageX("")
                visible: root.pageVisible("")
                enabled: root.page === ""
                opacity: root.pageOpacity("")

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
                x: root.pageX("move")
                visible: root.pageVisible("move")
                enabled: root.page === "move"
                opacity: root.pageOpacity("move")

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
                x: root.pageX("add-widget")
                visible: root.pageVisible("add-widget")
                enabled: root.page === "add-widget"
                opacity: root.pageOpacity("add-widget")

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
                x: root.pageX("widget-settings")
                visible: root.pageVisible("widget-settings")
                enabled: root.page === "widget-settings"
                opacity: root.pageOpacity("widget-settings")

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
