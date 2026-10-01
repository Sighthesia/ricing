import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import ".."
import "../../lazerbar"
import "TraySlotLogic.js" as SlotLogic

// StatusNotifier tray icons with activate and secondary actions.
//
// The strip is not a Repeater over `SystemTray.items.values`: that array swap
// rebuilds every delegate (flooding the async icon provider) and destroys a
// leaving icon before it can animate out. Instead the live list is diffed into
// a stable ListModel, so a surviving icon keeps its delegate and its decoded
// pixmap while a departing slot stays resident for its exit.
Item {
    id: root

    // Widget identity contract filled by the layout loader.
    property string widgetId: ""
    property string instanceKey: ""
    property string section: ""
    property string screenName: ""

    // Gap between slots. It lives *inside* each slot rather than in
    // Row.spacing so a slot collapsing to zero takes its gap with it; with
    // Row.spacing the icons after it would jump the gap's width the moment the
    // row is finally dropped.
    readonly property int slotGap: 2

    // Read off `_liveKeys`, which syncSlots reassigns: a binding cannot see a
// nested field of a JS object being mutated in place, so `_registry.keys`
// would freeze at whatever it held when the binding first evaluated.
    readonly property int liveCount: root._liveKeys.length
    // Downward travel of a leaving icon, sized so the bar never slices it.
    readonly property real fallDistance: SlotLogic.fallDistance(LazerTheme.barWidgetHeight, LazerTheme.barGlyphSize)

    implicitWidth: Math.max(0, trayRow.implicitWidth - root.slotGap)
    implicitHeight: LazerTheme.barWidgetHeight

    // Opt-in hover intent publication for BarPopupHost (per-delegate).
    signal popupRequested(var intent)
    signal popupCloseRequested()
    signal popupAnchorUpdate(var intent)

    // Track current hovered delegate for anchor updates when the tray moves.
    property var hoveredTrayModel: null
    property Item hoveredTrayDelegate: null

    // --- Stable slot model -------------------------------------------------
    // One row per live tray item plus any slot still playing its exit.
    ListModel { id: slotModel }

    // Live list from the tray service; the diff below is what mutates the model.
    // `liveValuesOverride` is a test seam: a harness cannot unbind a QML
    // property, so it swaps the service list for a synthetic batch through this
    // instead. It stays null in production, leaving the binding as the only
    // source.
    property var liveValuesOverride: null
    property var liveValues: root.liveValuesOverride !== null
            ? root.liveValuesOverride
            : ((SystemTray.items && SystemTray.items.values)
                    ? SystemTray.items.values : [])
    property var _liveKeys: []
    property var _liveItems: ({})
    // Registered object -> slot key, kept for as long as the object stays
    // registered. See TraySlotLogic: a string derived from the item is not
    // unique enough to file a slot under.
    property var _registry: SlotLogic.emptyRegistry()

    // The very first population must not replay an arrival for every icon the
    // shell already had on screen.
    property bool _primed: false
    readonly property bool primed: root._primed

    onLiveValuesChanged: Qt.callLater(root.syncSlots)

    Component.onCompleted: {
        root.syncSlots()
        Qt.callLater(function() { root._primed = true })
    }

    // Re-publish the hovered icon's intent after the strip moves. Only the
    // delegate that currently owns the hover may do this: a delegate whose
    // HoverHandler still reports hovered for the frame after the pointer has
    // already crossed to its neighbour would otherwise swap the popup back to
    // the icon the pointer just left, mid-sweep between two icons - which is
    // what painted the previous menu beside the new one.
    function republishHoveredAnchor() {
        var delegate = root.hoveredTrayDelegate
        if (!delegate)
            return
        root.popupAnchorUpdate(root.buildTrayIntent(root.hoveredTrayModel, delegate))
    }

    // Build hover intent for a specific tray delegate.
    function resolveIconSource(source) {
        var normalized = String(source || "").trim()
        if (normalized === "" || normalized.indexOf(":") >= 0)
            return normalized
        if (normalized.charAt(0) === "." || normalized.charAt(0) === "/")
            return Qt.resolvedUrl(normalized)
        return String(Quickshell.iconPath(normalized, true) || "")
    }

    function normalizeTrayIconSource(source) {
        var normalized = String(source || "").trim()
        var pathSplit = normalized.indexOf("?path=")
        if (pathSplit < 0)
            return resolveIconSource(normalized)
        var name = normalized.substring(0, pathSplit)
        var dir = normalized.substring(pathSplit + 6)
        return resolveIconSource("file://" + dir + "/"
                + name.substring(name.lastIndexOf("/") + 1))
    }

    function iconSourceFor(item) {
        if (!item) return ""
        return root.normalizeTrayIconSource(item.icon || "")
    }

    function labelFor(item) {
        if (!item) return "Tray item"
        return item.title || item.tooltipTitle || item.id || "Tray item"
    }

    function slotIndexFor(key) {
        for (var i = 0; i < slotModel.count; i++) {
            if (slotModel.get(i).slotKey === key)
                return i
        }
        return -1
    }

    // Live StatusNotifier object behind a slot, or null once it is leaving.
    function liveItemFor(key) {
        root._liveItems
        return root._liveItems[key] || null
    }

    // One tray refresh, expressed as surgery on the stable model: arrivals are
    // appended, departures are flagged (their delegate keeps them alive for the
    // exit) and surviving rows only have their snapshot roles rewritten.
    function syncSlots() {
        var values = root.liveValues || []
        // Identity first: every live object keeps the slot key it already had,
        // so a reordered list moves slots instead of re-deriving their names.
        var registry = root._registry
        var keys = SlotLogic.reindex(registry, values)
        var items = ({})
        for (var i = 0; i < keys.length; i++)
            items[keys[i]] = registry.items[i]

        var change = SlotLogic.diff(root._liveKeys, keys)
        root._liveKeys = keys
        root._liveItems = items

        var rows = ({})
        for (var r = 0; r < slotModel.count; r++)
            rows[slotModel.get(r).slotKey] = r

        // Departures first: an arrival landing in the same batch must not be
        // mistaken for the item that just left.
        for (var d = 0; d < change.removed.length; d++) {
            var gone = change.removed[d]
            var goneIndex = rows[gone]
            var goneRow = goneIndex === undefined ? null : slotModel.get(goneIndex)
            // A slot can be dropped by its own retire timer between two syncs,
            // so every index is re-read rather than trusted.
            if (!goneRow || goneRow.retiring) continue
            // Delay first: the delegate reads it the moment `retiring` flips.
            slotModel.setProperty(goneIndex, "delayMs",
                    SlotLogic.cascadeDelayMs(goneIndex, change.removed.length,
                            MotionTokens.trayIconStagger, true))
            slotModel.setProperty(goneIndex, "retiring", true)
        }

        for (var a = 0; a < change.added.length; a++) {
            var added = change.added[a]
            if (rows[added] !== undefined) continue
            slotModel.append({
                slotKey: added,
                iconSource: root.iconSourceFor(items[added]),
                label: root.labelFor(items[added]),
                retiring: false,
                delayMs: SlotLogic.cascadeDelayMs(a, change.added.length,
                        MotionTokens.trayIconStagger, false)
            })
        }

        for (var k = 0; k < keys.length; k++) {
            var liveKey = keys[k]
            var index = rows[liveKey]
            var row = index === undefined ? null : slotModel.get(index)
            if (!row) continue
            if (row.retiring) {
                // The item came back mid-exit: revive the slot instead of
                // adding a second copy of the same identity.
                slotModel.setProperty(index, "retiring", false)
                slotModel.setProperty(index, "iconSource", root.iconSourceFor(items[liveKey]))
                slotModel.setProperty(index, "label", root.labelFor(items[liveKey]))
                continue
            }
            root.writeSnapshot(liveKey)
        }
    }

    // Refresh one live row's snapshot, addressed by key rather than by index.
//
// `ListModel.get()` does not reject a bad index — handed `undefined` it
// returns the *first* row. A delegate cannot supply a trustworthy row index
// anyway (`index` is injected into its scope, not a property of the item), so
// an app changing its icon wrote itself over slot 0 and QQ wore the input
// method's glyph. Looking the row up by key removes the whole hazard.
    function writeSnapshot(key) {
        var item = root.liveItemFor(key)
        if (!item) return
        var index = root.slotIndexFor(key)
        if (index < 0) return
        var row = slotModel.get(index)
        if (!row || row.slotKey !== key) return
        // An app that briefly reports no icon (mid-reload) must not blank the
        // slot: an empty source makes the icon vanish, and it only comes back if
        // the app signs another icon change.
        var source = root.iconSourceFor(item)
        if (source !== "" && row.iconSource !== source)
            slotModel.setProperty(index, "iconSource", source)
        var label = root.labelFor(item)
        if (row.label !== label)
            slotModel.setProperty(index, "label", label)
    }

    // The slot finished collapsing. Drop the row only if the item really is
    // gone — one that returned during the exit keeps its slot.
    function completeRetire(key) {
        if (root.liveItemFor(key) !== null) return
        var index = root.slotIndexFor(key)
        if (index >= 0)
            slotModel.remove(index)
    }

    // Reduced motion has no exit to show: the slot leaves in one step.
    function retireNow(key) {
        var index = root.slotIndexFor(key)
        if (index >= 0)
            slotModel.remove(index)
    }

    function buildTrayIntent(modelData, delegateItem) {
        var centerX = 0
        try { centerX = delegateItem.mapToGlobal(delegateItem.width / 2, delegateItem.height / 2).x } catch (e) {
            try { centerX = delegateItem.mapToItem(root, delegateItem.width / 2, 0).x + root.mapToGlobal(0, 0).x } catch (e2) { centerX = 0 }
        }
        if (!isFinite(centerX)) centerX = 0
        var titleText = (delegateItem && delegateItem.label) ? delegateItem.label : (modelData.title || modelData.tooltipTitle || modelData.id || "Tray item")
        // Tray delegates share widgetId/instanceKey, so the host tells icons
        // apart by this key. It must be the slot key: an item's own `id` is not
        // unique across registered items, and a collision here makes the popup
        // replace itself with another icon's card. The same icon refreshing its
        // label keeps the popup live; a different icon gets the full
        // glide/slide replacement.
        var delegateKey = String((delegateItem && delegateItem.slotKey)
                || (modelData && modelData.id) || titleText || "tray")
        var iconSrc = normalizeTrayIconSource((delegateItem && delegateItem.iconSource)
                ? delegateItem.iconSource : (modelData.icon || ""))
        var summaryText = modelData.tooltipTitle || modelData.tooltipSubTitle || ""
        return {
            widgetId: root.widgetId,
            instanceKey: root.instanceKey,
            delegateKey: delegateKey,
            screenName: root.screenName,
            title: titleText,
            iconSource: iconSrc,
            summary: summaryText,
            actionKind: "tray",
            anchorX: centerX,
            payload: {
                trayModel: modelData,
                trayItem: modelData,
                title: titleText,
                iconSource: iconSrc,
                hasMenu: !!(modelData && (modelData.hasMenu || modelData.menu)),
                menuHandle: modelData ? modelData.menu : null,
                onActivate: function() { try { modelData.activate() } catch (e) {} },
                onSecondaryActivate: function() { try { modelData.secondaryActivate() } catch (e) {} }
            }
        }
    }

    onXChanged: republishHoveredAnchor()
    onWidthChanged: republishHoveredAnchor()

    Row {
        id: trayRow

        // The gap rides inside each slot, so this stays 0 (see root.slotGap).
        spacing: 0
        anchors.verticalCenter: parent.verticalCenter
        anchors.horizontalCenter: parent.horizontalCenter
        // The row is one gap wider than the widget; shift it back so the icons
        // land exactly where the old spacing-based layout put them.
        anchors.horizontalCenterOffset: root.slotGap / 2

        Repeater {
            model: slotModel

            // One slot per tray item. The slot is the layout box: it opens
            // before its ink starts and closes only once the ink is gone, so
            // the strip never drags a neighbour across a half-drawn icon.
            delegate: Item {
                id: trayIcon

                // Snapshot contract from the stable model. Everything an exit
                // needs lives here, so a leaving slot never reads a
                // SystemTrayItem that has already been unregistered.
                required property string slotKey
                required property string iconSource
                required property string label
                required property bool retiring
                required property int delayMs

                // Live object for activation, menus and hover. Null the moment
                // the slot starts leaving.
                readonly property var liveItem: trayIcon.retiring
                        ? null : root.liveItemFor(trayIcon.slotKey)

                // 0 while the slot is closed, 1 while it is open. Drives the
                // box width only, so the falling icon keeps the position it had.
                property real presence: root.primed ? 0 : 1
                // Ink opacity: 0 until the box has finished opening, 0 again
                // once the icon has dissolved under the closing box.
                property real ink: root.primed ? 0 : 1
                // Downward travel of a leaving icon.
                property real fall: 0

                width: (LazerTheme.barWidgetHeight + root.slotGap) * trayIcon.presence
                height: LazerTheme.barWidgetHeight
                // Off while invisible: a slot mid-flight takes no hover, no tap.
                enabled: !trayIcon.retiring && trayIcon.ink > 0.99
                // Nothing clips here — the icon has to be able to leave the
                // shrinking box, the same contract the marquee ghosts ride.
                Accessible.role: Accessible.Button
                Accessible.name: trayIcon.label

                readonly property bool hovered: iconHover.hovered

                // Test seam: the enter/exit recipes, exposed the way
                // OsuTopBarButton exposes its flash animation so a harness can
                // assert the contract instead of sampling a frame mid-flight.
                readonly property Animation openAnimationItem: openAnim
                readonly property Animation enterAnimationItem: enterInkAnim
                readonly property Animation exitAnimationItem: exitInkAnim
                readonly property Animation fallAnimationItem: fallAnim
                readonly property Animation closeAnimationItem: closeAnim

                // One hover square per tray item; icons stay theme-provided.
                // It fills the open slot, so it tracks the box as it collapses.
                Rectangle {
                    anchors.fill: parent
                    radius: 0
                    color: trayIcon.hovered ? LazerTheme.hoverFill : "transparent"

                    Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
                }

                // The icon rides the slot's open box, not its shrinking width,
                // so a closing slot closes around the falling icon instead of
                // dragging it sideways.
                IconImage {
                    id: glyph

                    x: (LazerTheme.barWidgetHeight - LazerTheme.barGlyphSize) / 2
                    y: (LazerTheme.barWidgetHeight - LazerTheme.barGlyphSize) / 2 + trayIcon.fall
                    width: LazerTheme.barGlyphSize
                    height: LazerTheme.barGlyphSize
                    asynchronous: true
                    backer.fillMode: Image.PreserveAspectFit
                    source: trayIcon.iconSource
                    // Failed loads stay invisible instead of rendering blank.
                    opacity: trayIcon.ink * (status === Image.Ready ? 1 : 0)
                }

                // --- Arrival: open the box, then fade the ink in. ---
                // Sequential on purpose. The slot has to be fully open before
                // any ink lands in it, otherwise the icon it is pushing aside
                // would slide across a half-drawn neighbour.
                SequentialAnimation {
                    id: enterAnim

                    animations: [openAnim, enterInkAnim]
                }
                Timer {
                    id: enterDelay

                    interval: trayIcon.delayMs
                    onTriggered: enterAnim.restart()
                }
                NumberAnimation {
                    id: openAnim

                    target: trayIcon
                    property: "presence"
                    to: 1
                    duration: MotionTokens.fast
                    easing.type: Easing.OutQuad
                }
                NumberAnimation {
                    id: enterInkAnim

                    target: trayIcon
                    property: "ink"
                    to: 1
                    duration: MotionTokens.trayIconEnter
                    easing.type: Easing.OutQuad
                }

                // --- Departure: drop and dissolve while the box closes. ---
                // The ink fade is front-loaded and the box's collapse is
                // InQuad on purpose: together they keep the neighbour that
                // slides into the freed slot from ever crossing a readable icon.
                ParallelAnimation {
                    id: exitAnim

                    animations: [exitInkAnim, fallAnim, closeAnim]
                }
                Timer {
                    id: exitDelay

                    interval: trayIcon.delayMs
                    onTriggered: exitAnim.restart()
                }
                // The row is dropped on its own clock rather than from the
                // collapse's onFinished: an animation nested in a group does
                // not reliably report completion, and a slot left behind would
                // hold its gap open forever.
                Timer {
                    id: retireTimer

                    interval: trayIcon.delayMs + MotionTokens.slow
                    onTriggered: root.completeRetire(trayIcon.slotKey)
                }
                NumberAnimation {
                    id: exitInkAnim

                    target: trayIcon
                    property: "ink"
                    to: 0
                    duration: MotionTokens.trayIconExit
                    easing.type: Easing.OutQuad
                }
                NumberAnimation {
                    id: fallAnim

                    target: trayIcon
                    property: "fall"
                    to: root.fallDistance
                    duration: MotionTokens.trayIconExit
                    easing.type: Easing.OutQuad
                }
                NumberAnimation {
                    id: closeAnim

                    target: trayIcon
                    property: "presence"
                    to: 0
                    duration: MotionTokens.slow
                    easing.type: Easing.InQuad
                }

                function startEnter() {
                    exitDelay.stop()
                    retireTimer.stop()
                    exitAnim.stop()
                    enterDelay.stop()
                    if (MotionTokens.reducedMotion || !root.primed) {
                        trayIcon.presence = 1
                        trayIcon.ink = 1
                        trayIcon.fall = 0
                        return
                    }
                    if (trayIcon.presence >= 1 && trayIcon.ink >= 1)
                        return
                    // Captured before the restart: the sequential group reads
                    // each `from` when its own leg begins.
                    openAnim.from = trayIcon.presence
                    enterInkAnim.from = trayIcon.ink
                    enterDelay.restart()
                }

                function startExit() {
                    enterDelay.stop()
                    enterAnim.stop()
                    if (MotionTokens.reducedMotion) {
                        root.retireNow(trayIcon.slotKey)
                        return
                    }
                    exitInkAnim.from = trayIcon.ink
                    fallAnim.from = trayIcon.fall
                    closeAnim.from = trayIcon.presence
                    exitDelay.restart()
                    retireTimer.restart()
                }

                onRetiringChanged: trayIcon.retiring ? trayIcon.startExit() : trayIcon.startEnter()
                Component.onCompleted: trayIcon.startEnter()

                Component.onDestruction: {
                    if (root.hoveredTrayDelegate === trayIcon) {
                        root.hoveredTrayModel = null
                        root.hoveredTrayDelegate = null
                        root.popupCloseRequested()
                    }
                }

                // An app that swaps its own icon mid-life reuses the slot.
                Connections {
                    target: trayIcon.liveItem
                    function onIconChanged() { root.writeSnapshot(trayIcon.slotKey) }
                    function onTitleChanged() { root.writeSnapshot(trayIcon.slotKey) }
                    function onTooltipTitleChanged() { root.writeSnapshot(trayIcon.slotKey) }
                }

                HoverHandler {
                    id: iconHover
                    objectName: "trayHoverHandler"
                    onHoveredChanged: {
                        if (hovered) {
                            if (!trayIcon.liveItem) return
                            root.hoveredTrayModel = trayIcon.liveItem
                            root.hoveredTrayDelegate = trayIcon
                            root.popupRequested(root.buildTrayIntent(trayIcon.liveItem, trayIcon))
                        } else {
                            if (root.hoveredTrayDelegate === trayIcon) {
                                root.hoveredTrayModel = null
                                root.hoveredTrayDelegate = null
                                root.popupCloseRequested()
                            }
                        }
                    }
                }

                // Update anchor while the delegate or bar layout moves. The
                // ownership check is the point: `iconHover.hovered` alone is
                // stale for a frame after the pointer crosses to the next icon.
                onXChanged: {
                    if (root.hoveredTrayDelegate === trayIcon)
                        root.republishHoveredAnchor()
                }

                TapHandler {
                    objectName: "trayActivateTap"
                    acceptedButtons: Qt.LeftButton
                    gesturePolicy: TapHandler.ReleaseWithinBounds
                    onTapped: if (trayIcon.liveItem) trayIcon.liveItem.activate()
                }

                TapHandler {
                    objectName: "traySecondaryTap"
                    acceptedButtons: Qt.RightButton
                    gesturePolicy: TapHandler.ReleaseWithinBounds
                    onTapped: if (trayIcon.liveItem) trayIcon.liveItem.secondaryActivate()
                }
            }
        }
    }
}
