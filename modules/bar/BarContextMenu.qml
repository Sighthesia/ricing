import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import "../lazerbar"
import "../../services" as Services
import "BarPopupMotion.js" as PopupMotion

// Shell menu rendered as a two-level vertical panel in the settings-panel
// language: a darker rail listing component names (level one) and a content
// column showing the selected component's actions and related entries
// (level two). The host drops it flush beneath the bar with the shared
// occlusion reveal.
LazerSplitSurface {
    id: root

    signal openSettingsRequested()
    signal layoutModeToggled()

    // Vertical room the host window offers, so the panel can fill it.
    property real availHeight: 480

    readonly property int railWidth: LazerTheme.settingsSidebarExpandedWidth
    readonly property int contentWidth: 264
    contentColor: LazerTheme.settingsSection
    // The host drives this shared layered reveal; the header leads the two
    // lower columns with the same offsets as BarPopupFrame and tray menus.
    // One entry shape for every rail row: widgets, tray items, and the two
    // global actions all ride the same selection model.
    readonly property var railEntries: {
        var entries = []
        var model = Services.BarLayoutService.layoutModel
        var seenCounts = {}
        for (var i = 0; i < model.widgets.length; i++) {
            var widgetEntry = model.widgets[i]
            if (!widgetEntry.enabled)
                continue
            var definition = null
            var available = Services.BarLayoutService.availableWidgets
            for (var d = 0; d < available.length; d++)
                if (available[d].id === widgetEntry.id)
                    definition = available[d]
            var label = definition ? definition.label : widgetEntry.id
            seenCounts[widgetEntry.id] = (seenCounts[widgetEntry.id] || 0) + 1
            if (seenCounts[widgetEntry.id] > 1)
                label += " " + seenCounts[widgetEntry.id]
            entries.push({
                key: "widget:" + widgetEntry.instanceKey,
                kind: "widget",
                label: label,
                instanceKey: widgetEntry.instanceKey,
                widgetId: widgetEntry.id,
                section: widgetEntry.section,
            })
        }
        entries.push({ key: "divider:widgets", kind: "divider" })
        var trayItems = SystemTray.items && SystemTray.items.values
                        ? SystemTray.items.values : []
        for (var t = 0; t < trayItems.length; t++) {
            var trayItem = trayItems[t]
            entries.push({
                key: "tray:" + (trayItem.id || t),
                kind: "tray",
                label: trayItem.title || trayItem.tooltipTitle || trayItem.id || "Tray item",
                payload: trayItem,
            })
        }
        if (trayItems.length > 0)
            entries.push({ key: "divider:tray", kind: "divider" })
        entries.push({ key: "global:settings", kind: "global", action: "settings", label: "Open Settings" })
        entries.push({ key: "global:layout", kind: "global", action: "layout",
                       label: Services.BarLayoutService.settingsMode ? "Exit Layout Mode" : "Enter Layout Mode" })
        return entries
    }

    function railEntryFor(key) {
        for (var i = 0; i < railEntries.length; i++)
            if (railEntries[i].key === key)
                return railEntries[i]
        return null
    }

    function selectFirstEntry() {
        for (var i = 0; i < railEntries.length; i++) {
            if (railEntries[i].kind !== "divider") {
                selectedKey = railEntries[i].key
                return
            }
        }
        selectedKey = ""
    }

    // Selection survives model rebuilds because it tracks keys, not indexes;
    // a fresh open lands on the first real entry so level two is never empty.
    property string selectedKey: ""
    readonly property var selectedEntry: railEntryFor(selectedKey)
    onRailEntriesChanged: {
        if (!selectedEntry)
            selectFirstEntry()
    }
    Component.onCompleted: {
        if (!selectedEntry)
            selectFirstEntry()
    }

    implicitWidth: railWidth + contentWidth
    implicitHeight: Math.max(240, availHeight - 8)
    clip: true

    // Header title follows the shared rail surface reveal.
    Text {
        parent: root.headerSurfaceItem
        anchors.left: parent.left
        anchors.leftMargin: 16
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        text: root.selectedEntry && root.selectedEntry.label ? root.selectedEntry.label : "Components"
        color: LazerTheme.textPrimary
        font.pixelSize: 14
        font.weight: Font.DemiBold
        elide: Text.ElideRight
        maximumLineCount: 1
    }

    // ── Level one: rail card (settingsPanel) ──

    Rectangle {
        id: railCard

        parent: root.contentSurfaceItem
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: root.railWidth
        radius: 0
        color: LazerTheme.settingsPanel
        border.width: 0
        opacity: 1
    }

    Flickable {
        parent: root.contentSurfaceItem
        anchors.fill: railCard
        anchors.margins: 6
        contentHeight: railColumn.implicitHeight + 16
        clip: true
        interactive: contentHeight > height
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: railColumn

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            topPadding: 10
            spacing: 2

            Repeater {
                model: root.railEntries

                delegate: RailRow {}
            }
        }
    }

    // ── Level two: content card (settingsSection) ──

    Rectangle {
        id: contentCard

        parent: root.contentSurfaceItem
        anchors.left: railCard.right
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        radius: 0
        color: LazerTheme.settingsSection
        border.width: 0
        opacity: 1
    }

    Item {
        id: contentArea

        parent: root.contentSurfaceItem
        anchors.fill: contentCard
        anchors.margins: 8

        // Widget target: its operations as card rows. Tray target: the SNI
        // menu entries rendered with the same row language.
        Flickable {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            contentHeight: contentColumn.implicitHeight + 20
            clip: true
            interactive: contentHeight > height
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: contentColumn

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                topPadding: 12
                spacing: 8

                Loader {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    active: root.selectedEntry !== null
                    sourceComponent: root.selectedEntry && root.selectedEntry.kind === "tray"
                                     ? trayContentComponent : widgetContentComponent
                }
            }
        }
    }

    Component {
        id: widgetContentComponent

        Column {
            spacing: 8

            readonly property var entry: root.selectedEntry

            // Related content first: jump into this instance's settings page.
            ActionRow {
                visible: entry !== null
                         && Services.BarLayoutService.widgetSupportsSettings(entry.widgetId || "")
                label: "Widget Settings"
                onActivated: {
                    if (entry === null)
                        return
                    Services.BarPopupService.close()
                    Services.BarLayoutService.openWidgetSettings(
                        entry.instanceKey, entry.widgetId, 0, "", entry.section)
                }
            }

            ActionRow {
                visible: entry !== null && entry.section !== "left"
                label: "Move to Left"
                onActivated: root.moveSelectedTo("left")
            }

            ActionRow {
                visible: entry !== null && entry.section !== "center"
                label: "Move to Center"
                onActivated: root.moveSelectedTo("center")
            }

            ActionRow {
                visible: entry !== null && entry.section !== "right"
                label: "Move to Right"
                onActivated: root.moveSelectedTo("right")
            }

            ActionRow {
                visible: entry !== null
                label: "Remove Widget"
                danger: true
                onActivated: {
                    if (entry === null)
                        return
                    Services.BarLayoutService.removeWidget(entry.instanceKey)
                }
            }
        }
    }

    Component {
        id: trayContentComponent

        Column {
            id: trayColumn

            spacing: 8

            readonly property var entry: root.selectedEntry

            QsMenuOpener {
                id: trayOpener

                menu: trayColumn.entry !== null && trayColumn.entry.payload
                      && trayColumn.entry.payload.hasMenu
                      ? trayColumn.entry.payload.menu : null
            }

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 4
                text: trayColumn.entry !== null && trayColumn.entry.payload
                      && trayColumn.entry.payload.hasMenu ? "" : "No menu available"
                color: LazerTheme.textMuted
                font.pixelSize: 12
                visible: text !== ""
            }

            Repeater {
                model: [...trayOpener.children.values]

                delegate: ActionRow {
                    required property var modelData

                    label: String(modelData.text || "").replace(/[\n\r]+/g, " ")
                    enabledRow: modelData.enabled ?? true
                    onActivated: {
                        if (typeof modelData.triggered === "function")
                            modelData.triggered()
                    }
                }
            }
        }
    }

    function moveSelectedTo(sectionName) {
        var entry = root.selectedEntry
        if (!entry || entry.kind !== "widget")
            return
        Services.BarPopupService.close()
        Services.BarLayoutService.moveWidget(
            entry.instanceKey, sectionName,
            Services.BarLayoutService.sectionWidgets(sectionName).length)
    }

    // ── Shared row recipes copied from the settings-panel authorities ──

    // Level-one nav row: hover swap on the settingsRowHover surface and the
    // accent pill marking the active entry (LazerSettingsNavItem recipe).
    component RailRow: Item {
        id: railRow

        required property var modelData

        width: railColumn.width
        implicitHeight: modelData.kind === "divider" ? 9 : 40

        Rectangle {
            anchors.fill: parent
            anchors.margins: 2
            radius: 8
            color: railHover.hovered && railRow.modelData.kind !== "divider"
                   ? LazerTheme.settingsRowHover : "transparent"

            Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: 1
            color: LazerTheme.divider
            visible: railRow.modelData.kind === "divider"
        }

        // Accent pill only for the selected entry, matching the sidebar's
        // 4x24 rounded strip.
        Rectangle {
            x: 4
            anchors.verticalCenter: parent.verticalCenter
            width: 4
            height: 24
            radius: 2
            color: LazerTheme.settingsAccent
            visible: root.selectedKey === railRow.modelData.key
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 18
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: railRow.modelData.label || ""
            color: root.selectedKey === railRow.modelData.key
                   || (railHover.hovered && railRow.modelData.kind !== "divider")
                   ? LazerTheme.textPrimary : LazerTheme.settingsNavInactive
            font.pixelSize: 13
            elide: Text.ElideRight
            maximumLineCount: 1

            Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
        }

        HoverHandler {
            id: railHover

            enabled: railRow.modelData.kind !== "divider"
        }

        TapHandler {
            enabled: railRow.modelData.kind !== "divider"
            gesturePolicy: TapHandler.ReleaseWithinBounds
            onTapped: {
                var entry = railRow.modelData
                if (entry.kind === "widget" || entry.kind === "tray") {
                    root.selectedKey = entry.key
                    return
                }
                if (entry.action === "settings") {
                    root.openSettingsRequested()
                    return
                }
                if (entry.action === "layout")
                    root.layoutModeToggled()
            }
        }
    }

    // Level-two action row: settings-card recipe — card surface,
    // brightness-diff hover, click flash overlay, accent danger tint.
    component ActionRow: Item {
        id: actionRow

        property string label: ""
        property bool danger: false
        property bool enabledRow: true
        signal activated()

        implicitHeight: 40

        Rectangle {
            id: cardSurface

            anchors.fill: parent
            radius: 6
            color: actionRow.enabledRow && cardHover.hovered
                   ? LazerTheme.settingsCardHover : LazerTheme.settingsCard

            Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
        }

        Rectangle {
            id: flashOverlay

            z: 1
            anchors.fill: parent
            radius: cardSurface.radius
            color: LazerTheme.textPrimary
            opacity: 0
            enabled: false
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: actionRow.label
            color: !actionRow.enabledRow ? LazerTheme.settingsNavInactive
                   : actionRow.danger ? LazerTheme.osuButtonActive : LazerTheme.textPrimary
            opacity: actionRow.enabledRow ? 1 : MotionTokens.disabledOpacity
            font.pixelSize: 13
            elide: Text.ElideRight
            maximumLineCount: 1
        }

        HoverHandler {
            id: cardHover

            enabled: actionRow.enabledRow
        }

        TapHandler {
            enabled: actionRow.enabledRow
            gesturePolicy: TapHandler.ReleaseWithinBounds
            onTapped: actionRow.activate()
        }

        function activate() {
            if (!actionRow.enabledRow)
                return
            if (!MotionTokens.reducedMotion)
                flashAnimation.restart()
            else
                flashOverlay.opacity = 0
            actionRow.activated()
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
    }
}
