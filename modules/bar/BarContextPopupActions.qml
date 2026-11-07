import QtQuick
import "../lazerbar"
import "../../services" as Services
import "../../services/WidgetSettingsRegistry.js" as WidgetSettingsRegistry
import "widgets/ContextSettings.js" as ContextSettings

// Compact context actions for the bar's second popup layer.
Item {
    id: root

    property string widgetId: ""
    property string instanceKey: ""
    property string section: "center"
    property bool hasSettings: false
    property bool layoutMode: false
    property var availableWidgets: []
    property string actionKind: "context"
    property bool widgetsExpanded: false
    property bool settingsExpanded: false
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
    implicitHeight: actionColumn.implicitHeight + 16
    visible: root.actionKind === "context"
    // Empty-area menus carry no widget identity; widget rows need one.
    readonly property bool hasWidgetTarget: root.instanceKey !== ""

    // The settings block is registry-driven: a widget that declares inline
    // controls expands them here, and one whose settings live on a full page in
    // the settings panel (clock, active window, media...) keeps that route. The
    // menu therefore never needs editing when a widget adds a setting.
    readonly property bool settingsInline: root.hasSettings
        && ContextSettings.available(WidgetSettingsRegistry, root.widgetId)
    readonly property bool settingsPanel: root.hasSettings && !root.settingsInline
    readonly property bool settingsAvailable: root.settingsInline || root.settingsPanel
    // Shape only — see ContextSettings.rows: carrying values here would rebuild
    // the delegate (and destroy the slider being dragged) on every settings write.
    readonly property var settingsRows: root.settingsAvailable
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

    // Live value of one declared setting, defaulted against the registry.
    function settingValue(settingKey) {
        return ContextSettings.valueOf(WidgetSettingsRegistry, root.widgetId,
            root.settingsObject, String(settingKey))
    }

    function toggleSettingsExpanded() {
        if (!root.settingsInline)
            return
        root.settingsExpanded = !root.settingsExpanded
    }

    // Write through the service so the widget, a reopened menu and the saved
    // file all read the same value; a context menu never owns settings state.
    //
    // No save() here: the service already schedules its own debounced write and
    // bumps the revision every control reads through, so calling it again would
    // re-arm the timer the service had just started.
    function commitSetting(settingKey, value) {
        if (!root.settingsAvailable || String(settingKey) === "")
            return
        Services.SettingsService.setWidgetInstanceSettingValue(root.widgetId, root.instanceKey,
            String(settingKey), value)
    }

    // Remount both expandable blocks collapsed whenever the menu retargets
    // another widget. One handler, because a second `onInstanceKeyChanged` is a
    // duplicate property assignment and fails the whole component.
    onInstanceKeyChanged: {
        root.settingsExpanded = false
        root.widgetsExpanded = false
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
    }

    function toggleWidgetsExpanded() {
        widgetsExpanded = !widgetsExpanded
    }

    // Render each context command as a compact settings-style row.
    Column {
        id: actionColumn
        anchors.fill: parent
        anchors.margins: 8
        spacing: 2

        // Layout-mode entry stays on top so it is reachable from any target.
        Item {
            width: actionColumn.width
            height: 32

            Rectangle {
                anchors.fill: parent
                radius: 6
                color: layoutHover.hovered ? LazerTheme.settingsCardHover : LazerTheme.settingsCard
                Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
            }

            Text {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 44
                verticalAlignment: Text.AlignVCenter
                text: root.layoutMode ? Services.Tr.q("context.exitLayoutMode") : Services.Tr.q("context.enterLayoutMode")
                color: LazerTheme.textPrimary
                font.pixelSize: 13
                elide: Text.ElideRight
            }

            Text {
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                text: root.layoutMode ? Services.Tr.q("common.on") : Services.Tr.q("common.off")
                color: LazerTheme.textMuted
                font.pixelSize: 11
            }

            HoverHandler { id: layoutHover; blocking: false }
            TapHandler {
                gesturePolicy: TapHandler.ReleaseWithinBounds
                onTapped: root.invoke("toggleLayoutMode")
            }
        }

        // Shell settings entry opens the settings center through the bridge.
        Item {
            width: actionColumn.width
            height: 32

            Rectangle {
                anchors.fill: parent
                radius: 6
                color: shellHover.hovered ? LazerTheme.settingsCardHover : LazerTheme.settingsCard
                Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
            }

            Text {
                anchors.fill: parent
                anchors.leftMargin: 10
                verticalAlignment: Text.AlignVCenter
                text: Services.Tr.q("context.shellSettings")
                color: LazerTheme.textPrimary
                font.pixelSize: 13
                elide: Text.ElideRight
            }

            HoverHandler { id: shellHover; blocking: false }
            TapHandler {
                gesturePolicy: TapHandler.ReleaseWithinBounds
                onTapped: root.invoke("openShellSettings")
            }
        }

        Repeater {
            model: root.hasWidgetTarget ? [
                { action: "moveLeft", label: Services.Tr.q("context.moveLeft") },
                { action: "moveRight", label: Services.Tr.q("context.moveRight") },
                { action: "moveToSection", label: Services.Tr.q("context.moveToSection") },
                { action: "remove", label: Services.Tr.q("context.removeWidget") },
            ] : []

            delegate: Item {
                required property var modelData
                width: actionColumn.width
                height: 32

                Rectangle {
                    anchors.fill: parent
                    radius: 6
                    color: actionHover.hovered ? LazerTheme.settingsCardHover : LazerTheme.settingsCard
                    Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
                }

                Text {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    verticalAlignment: Text.AlignVCenter
                    text: modelData.label
                    color: LazerTheme.textPrimary
                    font.pixelSize: 13
                }

                HoverHandler { id: actionHover; blocking: false }
                TapHandler {
                    gesturePolicy: TapHandler.ReleaseWithinBounds
                    onTapped: root.invoke(modelData.action)
                }
            }
        }

        // The widget's own settings, opened in place rather than in another
        // surface: the widget this menu belongs to stays on screen, so the
        // colour picker writes to something the user is looking at.
        Item {
            width: settingsHeaderRow.width
            height: settingsHeaderRow.height
            visible: root.hasWidgetTarget

            Item {
                id: settingsHeaderRow
                width: actionColumn.width
                height: 32
                enabled: root.settingsAvailable
                // A widget with nothing adjustable greys out instead of
                // vanishing, so the menu keeps the same shape for every widget.
                opacity: root.settingsAvailable ? 1 : LazerTheme.settingsDisabledAlpha

                Rectangle {
                    anchors.fill: parent
                    radius: 6
                    color: settingsHeaderHover.hovered && root.settingsAvailable
                        ? LazerTheme.settingsCardHover : LazerTheme.settingsCard
                    Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
                }

                Text {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 28
                    verticalAlignment: Text.AlignVCenter
                    text: root.settingsAvailable
                        ? Services.Tr.q("context.widgetSettings")
                        : Services.Tr.q("context.widgetSettingsEmpty")
                    color: root.settingsAvailable ? LazerTheme.textPrimary
                        : LazerTheme.textMuted
                    font.pixelSize: 13
                    elide: Text.ElideRight
                }

                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.settingsInline
                    text: root.settingsExpanded ? "▾" : "▸"
                    color: LazerTheme.textMuted
                    font.pixelSize: 13
                }

                HoverHandler { id: settingsHeaderHover; blocking: false }
                TapHandler {
                    gesturePolicy: TapHandler.ReleaseWithinBounds
                    enabled: root.settingsAvailable
                    onTapped: {
                        if (root.settingsInline)
                            root.toggleSettingsExpanded()
                        else
                            root.invoke("openSettings")
                    }
                }
            }
        }

        // Settings rows grow the popup in place. The body is clipped and fades
        // with its own height so a collapse never leaves a painted band behind.
        Item {
            id: settingsHost
            width: actionColumn.width
            implicitHeight: root.settingsExpanded ? settingsColumn.implicitHeight : 0
            height: implicitHeight
            clip: true
            opacity: root.settingsExpanded ? 1 : 0
            visible: opacity > 0.01 || root.settingsExpanded
            Behavior on implicitHeight {
                enabled: !MotionTokens.reducedMotion
                NumberAnimation { duration: MotionTokens.slow; easing.type: Easing.InOutQuad }
            }
            Behavior on opacity { NumberAnimation { duration: MotionTokens.fast } }

            Column {
                id: settingsColumn
                width: parent.width
                // Rows carry an 8px list gap of their own, so the column adds none.
                spacing: 0

                Repeater {
                    model: root.settingsRows

                    delegate: Loader {
                        id: settingsRowLoader

                        required property var modelData
                        required property int index

                        width: settingsColumn.width
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

                Text {
                    width: parent.width
                    height: 24
                    visible: root.settingsRows.length === 0
                    verticalAlignment: Text.AlignVCenter
                    horizontalAlignment: Text.AlignHCenter
                    text: Services.Tr.q("context.widgetSettingsEmpty")
                    color: LazerTheme.textMuted
                    font.pixelSize: 10
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

                width: settingsColumn.width
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

                width: settingsColumn.width
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

        // Expandable widget catalog for the current section.
        Item {
            width: actionColumn.width
            height: 32

            Rectangle {
                anchors.fill: parent
                radius: 6
                color: catalogHover.hovered ? LazerTheme.settingsCardHover : LazerTheme.settingsCard
                Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
            }

            Text {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 28
                verticalAlignment: Text.AlignVCenter
                text: Services.Tr.q("context.addWidgets")
                color: LazerTheme.textPrimary
                font.pixelSize: 13
                elide: Text.ElideRight
            }

            Text {
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                text: root.widgetsExpanded ? "▾" : "▸"
                color: LazerTheme.textMuted
                font.pixelSize: 13
            }

            HoverHandler { id: catalogHover; blocking: false }
            TapHandler {
                gesturePolicy: TapHandler.ReleaseWithinBounds
                onTapped: root.toggleWidgetsExpanded()
            }
        }

        // Clipped catalog list grows the popup height when expanded.
        Item {
            id: catalogHost
            width: actionColumn.width
            implicitHeight: root.widgetsExpanded ? catalogColumn.implicitHeight : 0
            height: implicitHeight
            clip: true
            opacity: root.widgetsExpanded ? 1 : 0
            visible: opacity > 0.01 || root.widgetsExpanded
            Behavior on implicitHeight { NumberAnimation { duration: MotionTokens.slow; easing.type: Easing.InOutQuad } }
            Behavior on opacity { NumberAnimation { duration: MotionTokens.fast } }

            Column {
                id: catalogColumn
                width: parent.width
                spacing: 2

                Repeater {
                    model: root.availableWidgets || []

                    delegate: Item {
                        required property var modelData
                        required property int index
                        width: catalogColumn.width
                        height: 44

                        Rectangle {
                            anchors.fill: parent
                            radius: 6
                            color: widgetHover.hovered ? LazerTheme.settingsCardHover : LazerTheme.settingsCard
                            Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
                        }

                        Column {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 30
                            anchors.topMargin: 5
                            anchors.bottomMargin: 5
                            spacing: 1

                            Text {
                                width: parent.width
                                // The catalog hands over i18n keys, so a widget
                                // names itself the same way here as it does in
                                // its hover popup.
                                text: Services.Tr.q(String(modelData.label || modelData.id
                                                          || "widget.widget"))
                                color: LazerTheme.textPrimary
                                font.pixelSize: 13
                                elide: Text.ElideRight
                                maximumLineCount: 1
                            }

                            Text {
                                width: parent.width
                                text: modelData.description !== undefined
                                      ? Services.Tr.q(String(modelData.description)) : ""
                                color: LazerTheme.textMuted
                                font.pixelSize: 10
                                elide: Text.ElideRight
                                maximumLineCount: 1
                                visible: text !== ""
                            }
                        }

                        Text {
                            anchors.right: parent.right
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            text: "+"
                            color: LazerTheme.textMuted
                            font.pixelSize: 16
                        }

                        HoverHandler { id: widgetHover; blocking: false }
                        TapHandler {
                            gesturePolicy: TapHandler.ReleaseWithinBounds
                            onTapped: root.addWidgetById(modelData.id)
                        }
                    }
                }
            }
        }

    }
}
