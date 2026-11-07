pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Widgets
import "../../lazerbar"
import "../../../services" as Services
import "WorkspacesWheel.js" as WheelLogic
import "TraySlotLogic.js" as SlotLogic

// Workspace overview squares that expand to show each workspace's app icons
// (noctalia-shell grouped mode): click a square to focus the workspace, click
// an app icon to focus that exact window. Empty workspaces stay compact
// numbered squares. A single accent bar slides between the active workspace
// and the focused app icon, reusing the volume level bar geometry so its
// baseline aligns with the volume/battery/brightness bars.
Item {
    id: root

    // Widget identity contract filled by the layout loader.
    property string widgetId: ""
    property string instanceKey: ""
    property string section: ""
    property string screenName: ""

    // Workspace id -> stable icon ListModel. Each model's identity never
    // changes while its workspace is known, so icon Repeaters apply
    // incremental insert/remove/move instead of destroying the whole strip:
    // a wholesale JS-array swap rebuilds every delegate and floods the async
    // icon provider, which on Quickshell 0.3.1 can corrupt the delegate tree
    // (delegates survive with unreadable modelData, icons vanish permanently
    // while the data layer stays correct).
    property var workspaceModels: ({})
    // Bumped whenever workspaceModels gains or loses a key so the per-square
    // wins bindings re-resolve; row-level changes flow through the models'
    // own signals without touching this.
    property int _modelsRevision: 0
    property string _windowMapSignature: ""
    // Observability: counts real content syncs so focus-only churn is verifiable.
    property int mapSwaps: 0
    // Focus lives on its own so focus-only updates never rebuild icon
    // delegates; icon opacity and the single indicator bind to this instead.
    property string focusedWinId: ""
    // Single indicator state: center X in root coordinates. The bar itself
    // is the shared TrailIndicator below; only this value moves when the
    // active workspace or the focused app changes.
    property real indicatorCenterX: 0
    property bool indicatorVisible: false

    readonly property int iconSize: Math.round(LazerTheme.barGlyphSize * 0.75)
    readonly property int iconSpacing: 4
    readonly property int cellPadding: 8
    // The first population must not replay an arrival for every icon the shell already
    // had. Set one turn after the widget is built, so the initial sync lands settled and
    // only real changes animate after it.
    property bool _iconPrimed: false

    // Bumped whenever a slot's width or order changes.
    //
    // The strip's positions are sums over the slots' live `presence` values, and those are
    // plain properties of the delegates - so a slot opening, closing or moving notifies
    // nothing that a binding above it could depend on. Every one of those writes bumps this
    // instead, which is the one dependency the two sums (`contentRow.implicitWidth` and each
    // slot's `x`) are written against.
    property int _stripRevision: 0

    // Wheel throttle: one focus step per 120ms so a single flick never
    // floods niri with a burst of focus-window/focus-workspace calls.
    property double _lastWheelTimeMs: 0

    // Factory for stable per-workspace icon models (ListModel keeps row
    // delegates and their loaded images alive across syncs).
    Component {
        id: iconModelFactory

        ListModel {
        }
    }

    // Icon model for one workspace, or undefined when unknown. Reads
    // _modelsRevision so the binding re-resolves exactly when model keys
    // appear or disappear; row edits arrive via the model's own signals.
    function winsFor(wsId) {
        root._modelsRevision
        return root.workspaceModels[String(wsId)]
    }

    // Does this square still need the icon strip? A workspace whose last windows are
    // playing their exit still does: collapsing the square to a bare number on that frame
    // would clip the icons mid-dissolve, which is a worse cut than the one being removed.
    // The square closes when the last slot is retired, which is what `completeIconRetire`
    // asks for.
    function hasWindowsFor(wsId) {
        const model = root.winsFor(wsId)
        return !!model && model.count > 0
    }

    function mapSignature(map) {
        const workspaceIds = Object.keys(map)
        workspaceIds.sort()
        let signature = ""
        for (let i = 0; i < workspaceIds.length; i++) {
            const windows = map[workspaceIds[i]]
            signature += workspaceIds[i] + ":"
            for (let j = 0; j < windows.length; j++)
                signature += windows[j].winId + "|" + windows[j].colIdx + "|"
                    + windows[j].rowIdx + "|" + windows[j].appId + ";"
            signature += "#"
        }
        return signature
    }

    function windowOrder(left, right) {
        const leftColumn = left.colIdx == null ? 9999 : left.colIdx
        const rightColumn = right.colIdx == null ? 9999 : right.colIdx
        if (leftColumn !== rightColumn)
            return leftColumn - rightColumn

        const leftRow = left.rowIdx == null ? 9999 : left.rowIdx
        const rightRow = right.rowIdx == null ? 9999 : right.rowIdx
        if (leftRow !== rightRow)
            return leftRow - rightRow

        return String(left.winId).localeCompare(String(right.winId))
    }

    function iconPathForApp(appId) {
        return Services.WindowHintService.iconPathForApp(appId)
    }

    // Plain-array snapshots so the wheel resolver stays testable without
    // touching the live ListModels.
    function snapshotWorkspaces() {
        const rows = []
        const model = Services.NiriService.workspaces
        for (let i = 0; i < model.count; i++) {
            const ws = model.get(i)
            if (!ws)
                continue
            rows.push({
                wsId: String(ws.wsId),
                idx: Number(ws.idx),
                isActive: !!ws.isActive
            })
        }
        return rows
    }

    function snapshotWindows() {
        const rows = []
        const model = Services.NiriService.windows
        for (let i = 0; i < model.count; i++) {
            const win = model.get(i)
            if (!win)
                continue
            rows.push({
                winId: String(win.winId),
                workspaceId: String(win.workspaceId || ""),
                colIdx: win.colIdx,
                rowIdx: win.rowIdx
            })
        }
        return rows
    }

    // One wheel step: windows first inside the active workspace, crossing
    // into the neighbor workspace only at the edge (纵滚都切).
    function handleWheelScroll(direction) {
        const now = Date.now()
        if (now - root._lastWheelTimeMs < 120)
            return
        root._lastWheelTimeMs = now
        const step = WheelLogic.resolveWheelStep(root.snapshotWorkspaces(),
                                                 root.snapshotWindows(),
                                                 root.focusedWinId, direction)
        if (!step)
            return
        if (step.kind === "window") {
            Quickshell.execDetached([
                "niri", "msg", "action", "focus-window",
                "--id", String(step.winId)
            ])
        } else if (step.kind === "workspace") {
            Quickshell.execDetached([
                "niri", "msg", "action", "focus-workspace",
                String(step.idx)
            ])
        }
    }

    function refreshWindowMap() {
        const map = {}
        let focused = ""
        const model = Services.NiriService.windows
        for (let i = 0; i < model.count; i++) {
            const win = model.get(i)
            if (!win)
                continue
            if (win.isFocused)
                focused = String(win.winId)
            if (!win.workspaceId)
                continue
            if (!map[win.workspaceId])
                map[win.workspaceId] = []
            map[win.workspaceId].push(win)
        }

        const workspaceIds = Object.keys(map)
        for (let i = 0; i < workspaceIds.length; i++)
            map[workspaceIds[i]].sort(root.windowOrder)

        // Focus-only events (the most frequent) sync nothing: icon
        // delegates stay alive and just rebind their opacity.
        root.focusedWinId = focused
        const signature = root.mapSignature(map)
        if (signature === root._windowMapSignature)
            return
        root._windowMapSignature = signature
        root.mapSwaps += 1
        root.syncWorkspaceModels(map)
    }

    // Bring the stable per-workspace models to the freshly built map without
    // ever replacing a model object: vanished workspaces drop their model,
    // surviving ones diff-sync row by row so untouched windows keep their
    // delegates and loaded icons.
    function syncWorkspaceModels(map) {
        const models = root.workspaceModels
        const wanted = {}
        const ids = Object.keys(map)
        for (let i = 0; i < ids.length; i++) {
            const wsId = String(ids[i])
            wanted[wsId] = true
            let model = models[wsId]
            if (!model) {
                model = iconModelFactory.createObject(root)
                models[wsId] = model
                root._modelsRevision++
            }
            root.syncIconModel(model, map[ids[i]])
        }
        const known = Object.keys(models)
        for (let k = 0; k < known.length; k++) {
            if (!wanted[known[k]]) {
                models[known[k]].destroy()
                delete models[known[k]]
                root._modelsRevision++
            }
        }
    }

    // Reconcile one stable model with the desired ordered rows, keyed by
    // winId: remove gone rows, insert new ones in place, move drifted rows,
    // refresh changed app identities. Untouched rows (and their delegates
    // and images) are never modified.
    function syncIconModel(model, rows) {
        // A window that left is FLAGGED, not removed: its slot stays resident so the
        // delegate can play the exit, and the row is dropped by `completeIconRetire`
        // once that has run. Removing it here would be a cut - the strip would close
        // its gap and re-place every icon to its right on the same frame.
        const wanted = {}
        for (let k = 0; k < rows.length; k++)
            wanted[String(rows[k].winId)] = true
        let departing = 0
        for (let i = 0; i < model.count; i++)
            if (!wanted[String(model.get(i).winId)] && !model.get(i).retiring)
                departing++
        let goneSoFar = 0
        for (let i = model.count - 1; i >= 0; i--) {
            const id = String(model.get(i).winId)
            if (wanted[id] || model.get(i).retiring)
                continue
            // Departures cascade right to left, the same wavefront the tray strip uses
            // for the icons it loses.
            model.setProperty(i, "delayMs", SlotLogic.cascadeDelayMs(
                goneSoFar, departing, MotionTokens.windowRowStagger, true))
            model.setProperty(i, "retiring", true)
            goneSoFar++
        }
        let arriving = 0
        for (let j = 0; j < rows.length; j++)
            if (root.iconIndexFor(model, String(rows[j].winId)) < 0)
                arriving++
        let arrivedSoFar = 0
        for (let j = 0; j < rows.length; j++) {
            const want = String(rows[j].winId)
            const appId = String(rows[j].appId || "")
            let at = root.iconIndexFor(model, want)
            if (at < 0) {
                // Arrivals cascade left to right, and the slot opens before the ink
                // lands - see the delegate.
                model.insert(j, {
                    winId: want,
                    appId: appId,
                    retiring: false,
                    delayMs: SlotLogic.cascadeDelayMs(
                        arrivedSoFar, arriving, MotionTokens.windowRowStagger, false)
                })
                arrivedSoFar++
            } else {
                if (at !== j)
                    model.move(at, j, 1)
                if (String(model.get(j).appId) !== appId)
                    model.setProperty(j, "appId", appId)
                // A window that came back during its exit revives its slot rather than
                // growing a second one for the same identity.
                if (model.get(j).retiring)
                    model.setProperty(j, "retiring", false)
            }
        }
        root.settleIconOrder(model)
        // One bump for the whole batch: the sums are recomputed once, and each slot whose
        // place changed travels on its own `Behavior`. A per-move bump would restart every
        // slot's travel on every move of a cascade.
        root._stripRevision++
    }

    // The index of `winId` in a model, or -1. A function rather than a loop at each use,
    // because three of them now ask.
    function iconIndexFor(model, winId) {
        if (!model)
            return -1
        const target = String(winId)
        for (let i = 0; i < model.count; i++)
            if (String(model.get(i).winId) === target)
                return i
        return -1
    }

    // Is this window still on the workspace the model belongs to?
    function isIconLive(model, winId) {
        const target = String(winId)
        for (let w = 0; w < Services.NiriService.windows.count; w++) {
            const win = Services.NiriService.windows.get(w)
            if (String(win.winId) === target)
                return true
        }
        return false
    }

    // Push every retiring slot to the END of the model, past the live ones.
    //
    // The live icons' order is the contract: they are the strip the user reads, and a
    // slot on its way out must not hold one of them out of its place while it plays.
    // The retiring rows keep their own relative order, so the departures cascade in the
    // order they were flagged.
    function settleIconOrder(model) {
        let live = 0
        for (let i = 0; i < model.count; i++)
            if (!model.get(i).retiring)
                live++
        let tail = live
        for (let i = 0; i < model.count; i++) {
            if (!model.get(i).retiring)
                continue
            if (i !== tail)
                model.move(i, tail, 1)
            tail++
        }
    }

    // A retiring icon finished its exit. Drop the row only if the window really is gone;
    // one that came back during the exit revived its slot instead.
    function completeIconRetire(model, winId) {
        const at = root.iconIndexFor(model, winId)
        if (at < 0)
            return
        if (!model.get(at).retiring)
            return
        if (root.isIconLive(model, winId))
            return
        model.remove(at, 1)
        // The square may have just lost its last slot, in which case it now has to
        // collapse - and the strip it was holding open has to stop being counted.
        Qt.callLater(root.updateIndicator)
        Qt.callLater(root.updateHighlight)
    }

    // Event-stream bursts coalesce into one rebuild per frame.
    Connections {
        target: Services.NiriService
        function onWindowsUpdated() {
            Qt.callLater(root.refreshWindowMap)
            Qt.callLater(root.updateIndicator)
            Qt.callLater(root.updateHighlight)
        }
        function onWorkspacesUpdated() {
            Qt.callLater(root.updateIndicator)
            Qt.callLater(root.updateHighlight)
        }
        function onWorkspaceActivated() {
            Qt.callLater(root.updateIndicator)
            Qt.callLater(root.updateHighlight)
        }
    }

    // Sliding active-workspace highlight state (see activeHighlight below).
    property bool _highlightPlaced: false
    property real _highlightX: 0
    property real _highlightWidth: 0
    property bool _highlightOn: false

    // Track the active square's geometry so one continuous highlight surface
    // can glide between squares instead of each square popping its own fill.
    function updateHighlight() {
        if (!workspaceRepeater || workspaceRepeater.count === 0) {
            root._highlightOn = false
            return
        }
        const wsModel = Services.NiriService.workspaces
        let activeIndex = -1
        for (let i = 0; i < wsModel.count; i++) {
            const ws = wsModel.get(i)
            if (ws && ws.isActive)
                activeIndex = i
        }
        const item = activeIndex >= 0 ? workspaceRepeater.itemAt(activeIndex) : null
        if (!item) {
            root._highlightOn = false
            return
        }
        const p = item.mapToItem(root, 0, 0)
        root._highlightX = p.x
        root._highlightWidth = item.width
        if (!root._highlightOn)
            root._highlightOn = true
        if (!root._highlightPlaced)
            root._highlightPlaced = true
    }

    // Slide the single indicator to the focused app icon when there is one,
    // otherwise to the active workspace center. Prefers the focused window's
    // own workspace so one bar tracks both workspace and app switches.
    function updateIndicator() {
        if (!workspaceRepeater || workspaceRepeater.count === 0) {
            root.indicatorVisible = false
            return
        }
        const wsModel = Services.NiriService.workspaces
        let activeIndex = -1
        for (let i = 0; i < wsModel.count; i++) {
            const ws = wsModel.get(i)
            if (ws && ws.isActive)
                activeIndex = i
        }
        let focusedIndex = -1
        if (root.focusedWinId !== "") {
            for (let w = 0; w < workspaceRepeater.count; w++) {
                const wItem = workspaceRepeater.itemAt(w)
                if (!wItem || !wItem.wins || !wItem.wins.count)
                    continue
                const wins = wItem.wins
                for (let k = 0; k < wins.count; k++) {
                    const row = wins.get(k)
                    if (row && String(row.winId) === root.focusedWinId) {
                        focusedIndex = w
                        break
                    }
                }
                if (focusedIndex >= 0)
                    break
            }
        }
        const targetIndex = focusedIndex >= 0 ? focusedIndex : activeIndex
        if (targetIndex < 0 || targetIndex >= workspaceRepeater.count) {
            root.indicatorVisible = false
            return
        }
        const targetItem = workspaceRepeater.itemAt(targetIndex)
        if (!targetItem) {
            root.indicatorVisible = false
            return
        }
        let centerX = NaN
        if (focusedIndex >= 0) {
            try {
                centerX = targetItem.iconCenterXInRoot(root.focusedWinId)
            } catch (e) {
                centerX = NaN
            }
        }
        if (!isFinite(centerX)) {
            try {
                centerX = targetItem.centerXInRoot()
            } catch (e2) {
                centerX = NaN
            }
        }
        if (!isFinite(centerX))
            return
        // Publish the identity and the position together. The indicator
        // coalesces them into one commit per turn and treats its first valid
        // target as a placement, so neither the write order nor the first show
        // has to be defended here — the mark lands on its resting place instead
        // of sliding in from zero.
        root.indicatorTargetKey = focusedIndex >= 0 ? "w" + root.focusedWinId
                                                    : "s" + targetIndex
        root.indicatorCenterX = centerX
        if (!root.indicatorVisible)
            root.indicatorVisible = true
    }

    onFocusedWinIdChanged: Qt.callLater(root.updateIndicator)
    onWidthChanged: {
        Qt.callLater(root.updateIndicator)
        Qt.callLater(root.updateHighlight)
    }
    onHeightChanged: Qt.callLater(root.updateIndicator)

    Component.onCompleted: {
        root.refreshWindowMap()
        Qt.callLater(root.updateIndicator)
        Qt.callLater(root.updateHighlight)
        // Only after the first population has been written AND laid out: see
        // `_iconPrimed`. Two turns, because one is spent creating the delegates - their
        // first `x` is computed from a strip that has not measured itself yet, and priming
        // before that slides the whole strip in from the left edge.
        Qt.callLater(function () { Qt.callLater(function () { root._iconPrimed = true }) })
    }

    implicitWidth: workspaceRow.implicitWidth
    implicitHeight: LazerTheme.barWidgetHeight

    // Wheel-to-focus: vertical scroll steps windows first, neighbor
    // workspace only at the edge; horizontal scroll falls back the same way.
    WheelHandler {
        objectName: "workspacesWheelHandler"
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            const direction = WheelLogic.directionFromDeltas(
                event.angleDelta.y, event.angleDelta.x,
                event.pixelDelta.y, event.pixelDelta.x)
            if (direction === 0)
                return
            root.handleWheelScroll(direction)
            event.accepted = true
        }
    }

    Row {
        id: workspaceRow

        anchors.centerIn: parent
        spacing: LazerTheme.inlineGap

        onXChanged: Qt.callLater(root.updateIndicator)
        onWidthChanged: Qt.callLater(root.updateIndicator)

        Repeater {
            id: workspaceRepeater
            model: Services.NiriService.workspaces

            // One sharp square per workspace; occupied ones widen into an
            // app-icon strip while the active one keeps its accent fill.
            delegate: Item {
                id: workspaceSquare

                required property string wsId
                required property int idx
                required property bool isActive
                required property string name

                readonly property var wins: root.winsFor(wsId)
                readonly property bool hasWindows: root.hasWindowsFor(wsId)
                readonly property bool hovered: hoverHandler.hovered

                // The trailing gap is subtracted: every icon slot is `iconSize +
                // `iconSpacing` wide so that a closing one takes its gap with it, which
                // leaves one gap at the end of the strip that belongs to nothing.
                width: hasWindows
                    ? contentRow.implicitWidth - root.iconSpacing + root.cellPadding * 2
                    : LazerTheme.barWidgetHeight
                height: LazerTheme.barWidgetHeight

                onXChanged: {
                    Qt.callLater(root.updateIndicator)
                    Qt.callLater(root.updateHighlight)
                }
                onWidthChanged: {
                    Qt.callLater(root.updateIndicator)
                    Qt.callLater(root.updateHighlight)
                }

                // Center of this square in Workspaces coordinates: fallback
                // target when the focused app icon cannot be resolved.
                function centerXInRoot() {
                    const p = workspaceSquare.mapToItem(root, workspaceSquare.width / 2, 0)
                    return p.x
                }

                // Center of one app icon in Workspaces coordinates; NaN when
                // the window is not on this workspace (icons rebuilt).
                function iconCenterXInRoot(winId) {
                    const target = String(winId)
                    for (let i = 0; i < windowRepeater.count; i++) {
                        const item = windowRepeater.itemAt(i)
                        if (!item || item.winId === undefined)
                            continue
                        if (String(item.winId) === target) {
                            // The GLYPH's centre, not the slot's. A slot's width is
                            // `presence * (iconSize + iconSpacing)` - it carries the trailing
                            // gap so a closing slot takes that gap with it - so the middle of
                            // the slot sits half a gap to the right of the icon it holds.
                            // Mapping `width / 2` put the mark off-centre by that much on
                            // every icon, and by a moving amount while the slot animated.
                            const p = item.mapToItem(root,
                                item.width / 2 - root.iconSpacing / 2, 0)
                            return p.x
                        }
                    }
                    return NaN
                }

                Behavior on width {
                    enabled: !MotionTokens.reducedMotion
                    NumberAnimation {
                        duration: MotionTokens.fast
                        easing.type: Easing.OutQuad
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: 0
                    // The active arm moved to the sliding activeHighlight
                    // surface; squares keep only instant hover feedback.
                    color: !workspaceSquare.isActive && workspaceSquare.hovered
                           ? LazerTheme.hoverFill : "transparent"

                    Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
                }

                // NO POSITIONER, and that is what makes a reorder a travel.
                //
                // A `Row` places its children from their measured widths, and the model's
                // `move()` changes which delegate is where - so a window moved inside its
                // workspace was two icons trading places between two frames, with nothing to
                // animate: the positioner had already re-laid them out.
                //
                // Here each slot places ITSELF from the sum of the slots before it, and that
                // sum is a binding over their live `presence` values. A `move()` changes the
                // sum a slot sees, so the slot travels to its new place - and the ones it
                // crosses travel the other way on the same frame, because their sums changed
                // too. This is the mod-key hint's list, laid along the bar.
                Item {
                    id: contentRow
                    objectName: "workspaceStrip"

                    anchors.centerIn: parent
                    implicitWidth: {
                        // The revision is the dependency: `presence` lives on the delegates
                        // and is a plain property of an Item, so the width has to be asked
                        // for again whenever one of them moves.
                        workspaceSquare._stripRevision
                        let w = indexLabel.width
                        for (let i = 0; i < windowRepeater.count; i++) {
                            const item = windowRepeater.itemAt(i)
                            if (item)
                                w += item.width
                        }
                        return w
                    }
                    implicitHeight: root.iconSize
                    width: implicitWidth
                    height: implicitHeight

                    // The workspace number, which is the first thing in the strip and the
                    // one thing that never moves.
                    Text {
                        id: indexLabel
                        objectName: "workspaceIndexLabel"
                        x: 0
                        anchors.verticalCenter: parent.verticalCenter
                        text: workspaceSquare.idx
                        color: workspaceSquare.isActive
                               ? LazerTheme.textPrimary
                               : workspaceSquare.hovered ? LazerTheme.hoverForeground : LazerTheme.iconInactive
                        font.pixelSize: 14
                        font.bold: workspaceSquare.isActive
                    }

                    // One icon per window on this workspace; the focused
                    // window's icon stays bright while the single indicator
                    // below slides underneath it.
                    Repeater {
                        id: windowRepeater
                        model: workspaceSquare.wins

                        delegate: Item {
                            id: windowIcon

                            required property string winId
                            required property string appId
                            required property bool retiring
                            required property int delayMs
                            // Declared rather than relying on the injected `index`: the
                            // injected one is a context property of the delegate's own
                            // scope, and a binding that reads it from inside a child (the
                            // slot's `x` sum does) resolves it as undefined.
                            required property int index

                            // Bound to the shared focus property: focus-only
                            // events never rebuild delegates, and the role
                            // props always reflect the model's live row.
                            readonly property bool isFocused: windowIcon.winId === root.focusedWinId
                            readonly property bool hovered: iconHover.hovered

                            // The windowhint row recipe, at the bar's icon size: the slot
                            // opens before its ink lands, and closes only once the ink is
                            // gone. `presence` is the slot's WIDTH (this strip runs along
                            // the bar, so a slot opening is a width), `ink` is the icon's
                            // opacity.
                            //
                            // These live on the ITEM, not on the model row. A row is a
                            // plain object, so assigning a field on it notifies nothing -
                            // a width bound to it would keep the value it computed on the
                            // first frame and draw a slot that never moves.
                            // Written by `settle()`, not bound: a BINDING here would
                            // re-evaluate the moment `_iconPrimed` flips and drop every
                            // already-placed icon to zero, replaying an arrival for the
                            // whole strip. The initial value is the settled one, and only
                            // a real arrival animates from zero.
                            property real presence: 1
                            property real ink: 1
                            // Every frame of a slot opening or closing changes the sum the
                            // slots after it are placed by - see `_stripRevision`.
                            onPresenceChanged: root._stripRevision++
                            // `index` is injected by the `Repeater`, not a property of this
                            // item, so there is no `onIndexChanged` to hook. A `move()` is
                            // announced by the model's own `syncIconModel` instead, which
                            // bumps the revision once for the whole batch.

                            // The slot carries its own gap, so a slot closing to nothing
                            // takes its gap with it instead of leaving the strip one gap
                            // wider until the row is dropped.
                            width: presence * (root.iconSize + root.iconSpacing)
                            height: root.iconSize
                            anchors.verticalCenter: parent.verticalCenter

                            // WHERE THIS SLOT SITS: everything before it, and nothing else.
                            //
                            // `index` is the delegate's own place in the model, so a
                            // `move()` renumbers the slots rather than moving anything - and
                            // a slot whose index changed therefore has a different sum to
                            // travel to. That is the whole reorder: the model says where
                            // each window goes, and each slot computes the distance from
                            // the neighbours it has to cross.
                            //
                            // The sum reads every earlier slot's WIDTH, which is a live
                            // binding on their `presence` - so a slot arriving or leaving
                            // shifts the ones after it on the same frame, and a reorder
                            // slides the ones in between.
                            x: {
                                workspaceSquare._stripRevision
                                let left = indexLabel.width
                                for (let i = 0; i < windowIcon.index && i < windowRepeater.count; i++) {
                                    const item = windowRepeater.itemAt(i)
                                    if (item)
                                        left += item.width
                                }
                                return left
                            }

                            // The travel itself, on the slot's own clock. `OutCubic` rather
                            // than the hint list's `OutQuint`: this strip is one icon tall
                            // and a reorder moves it a few glyph widths, not the height of a
                            // panel, so the gentler start would read as a delay.
                            // Gated on `_iconPrimed` as well: the first population
                            // computes every slot's place from nothing, and animating that
                            // would slide the whole strip in from the left edge.
                            Behavior on x {
                                enabled: root._iconPrimed && !MotionTokens.reducedMotion
                                NumberAnimation {
                                    duration: MotionTokens.windowRowMove
                                    easing.type: Easing.OutCubic
                                }
                            }
                            // Off while it has no size or no ink: a slot mid-flight takes no
                            // hover and no tap.
                            enabled: !windowIcon.retiring && presence > 0.99 && ink > 0.99

                            // The indicator resolves its position through
                            // `iconCenterXInRoot`, which MAPS this item into the root - so
                            // both its width and its place are inputs, and neither has a
                            // binding to invalidate inside a function call.
                            //
                            // Width alone was not enough, and that was the fault: a slot
                            // arriving or leaving changes its width, but a REORDER changes
                            // only `x` - so the mark sat on the old place for the whole of a
                            // travel and then jumped to the new one when something else
                            // happened to ask. Measured on a two-icon swap, the icons crossed
                            // frame by frame while the indicator did not move at all.
                            onXChanged: Qt.callLater(root.updateIndicator)
                            onWidthChanged: Qt.callLater(root.updateIndicator)

                            // --- arrival: open the slot, then let the ink in ---------
                            SequentialAnimation {
                                id: iconEnter
                                animations: [
                                    NumberAnimation {
                                        target: windowIcon
                                        property: "presence"
                                        to: 1
                                        duration: MotionTokens.windowRowEnter
                                        easing.type: Easing.OutQuad
                                    },
                                    NumberAnimation {
                                        target: windowIcon
                                        property: "ink"
                                        to: 1
                                        duration: MotionTokens.windowRowEnterInk
                                        easing.type: Easing.OutQuad
                                    }
                                ]
                            }

                            Timer {
                                id: iconEnterDelay
                                onTriggered: iconEnter.restart()
                            }

                            // --- departure: dissolve the ink while the slot closes -----
                            ParallelAnimation {
                                id: iconExit
                                animations: [
                                    NumberAnimation {
                                        target: windowIcon
                                        property: "ink"
                                        to: 0
                                        duration: MotionTokens.windowRowExitInk
                                        easing.type: Easing.OutQuad
                                    },
                                    NumberAnimation {
                                        target: windowIcon
                                        property: "presence"
                                        to: 0
                                        duration: MotionTokens.windowRowExit
                                        easing.type: Easing.InQuad
                                    }
                                ]
                                // The row is dropped by the OWNER once the slot is empty,
                                // and it asks the model whether the window really left - a
                                // window that came back mid-exit revived its slot instead.
                                onFinished: root.completeIconRetire(
                                    windowRepeater.model, windowIcon.winId)
                            }

                            Timer {
                                id: iconExitDelay
                                onTriggered: iconExit.restart()
                            }

                            // The state this delegate was created into. A slot already on
                            // its way out picks up where the previous delegate left it -
                            // `retiring` is the model's answer, so a delegate rebuilt by an
                            // unrelated publish does not restart an exit that is half done.
                            function settle() {
                                if (!root._iconPrimed) {
                                    // The first population lands settled.
                                    windowIcon.presence = 1
                                    windowIcon.ink = 1
                                    return
                                }
                                // An arrival starts from nothing; a revival of a slot that
                                // was on its way out keeps whatever it had reached.
                                if (!windowIcon.retiring && windowIcon.presence > 0.01
                                        && windowIcon.presence < 0.99) {
                                    iconEnter.restart()
                                    return
                                }
                                if (windowIcon.retiring) {
                                    iconExitDelay.interval = windowIcon.delayMs
                                    if (iconExitDelay.interval > 0)
                                        iconExitDelay.restart()
                                    else
                                        iconExit.restart()
                                    return
                                }
                                iconEnterDelay.interval = windowIcon.delayMs
                                if (iconEnterDelay.interval > 0)
                                    iconEnterDelay.restart()
                                else
                                    iconEnter.restart()
                            }

                            onRetiringChanged: windowIcon.settle()
                            Component.onCompleted: windowIcon.settle()

                            // Reduced motion has no travel to show: the slot lands on its
                            // final state in one step, and a departure is retired at once.
                            Connections {
                                target: MotionTokens
                                function onReducedMotionChanged() {
                                    if (!MotionTokens.reducedMotion)
                                        return
                                    windowIcon.presence = windowIcon.retiring ? 0 : 1
                                    windowIcon.ink = windowIcon.retiring ? 0 : 1
                                    if (windowIcon.retiring)
                                        root.completeIconRetire(
                                            windowRepeater.model, windowIcon.winId)
                                }
                            }

                            // Resolve to the default theme icon when the requested
                            // icon is missing/broken (avoids black/purple blocks).
                            IconImage {
                                id: workspaceAppIcon

                                anchors.fill: parent
                                property string requestedSource: root.iconPathForApp(windowIcon.appId)
                                property string fallbackSource: Quickshell.iconPath("application-x-executable")
                                property bool useFallback: false
                                source: useFallback ? fallbackSource : requestedSource
                                onRequestedSourceChanged: useFallback = false
                                onStatusChanged: {
                                    if (status === Image.Error)
                                        useFallback = true
                                }
                                // These tiny, persistent delegates should not
                                // keep feeding the long-lived async icon
                                // provider during compositor event bursts.
                                asynchronous: false
                                backer.fillMode: Image.PreserveAspectFit
                                smooth: true
                                // `ink` is the slot's arrival/departure; the rest is the
                                // focus and hover treatment the strip already had.
                                opacity: windowIcon.ink * (windowIcon.isFocused
                                         ? 1
                                         : windowIcon.hovered ? 0.85 : 0.55)

                                Behavior on opacity { NumberAnimation { duration: MotionTokens.fast } }
                            }

                            HoverHandler {
                                id: iconHover
                            }

                            TapHandler {
                                gesturePolicy: TapHandler.ReleaseWithinBounds
                                onTapped: Quickshell.execDetached([
                                    "niri", "msg", "action", "focus-window",
                                    "--id", String(windowIcon.winId)
                                ])
                            }
                        }
                    }
                }

                HoverHandler {
                    id: hoverHandler
                }

                TapHandler {
                    gesturePolicy: TapHandler.ReleaseWithinBounds
                    onTapped: Quickshell.execDetached([
                        "niri", "msg", "action", "focus-workspace",
                        String(workspaceSquare.idx)
                    ])
                }
            }
        }
    }

    // Single workspace indicator: same width/height/radius as the volume
    // level bar, workspace green kept, top edge comes from
    // LazerTheme.barLevelTop so it shares one line with the
    // volume/battery/brightness level bars. Its
    // width is owned by the dual-speed edge tracker below.
    readonly property int indicatorBarWidth: LazerTheme.barWidgetHeight - 16
    // Identity of the current indicator target (focused window or active
    // workspace); lets the indicator tell genuine switches from re-anchors.
    property string indicatorTargetKey: ""

    // The indicator itself: the shell's shared dual-speed mark, so this widget
    // and both rails carry one wake rather than three implementations of it.
    // Its tracker used to live here verbatim (`_edgeX` / `_edgeShadowX` /
    // `_edgeSpan` / `retargetEdges`); see `modules/lazerbar/TrailIndicator.qml`
    // for the recipe and `lazer-motion-perf` for the record of what went wrong
    // on the way there.
    TrailIndicator {
        id: activeIndicator

        axis: "x"
        markLength: root.indicatorBarWidth
        markThickness: LazerTheme.barIndicatorHeight
        markRadius: LazerTheme.barIndicatorRadius
        markColor: LazerTheme.osuGreen
        targetCenter: root.indicatorCenterX
        targetKey: root.indicatorTargetKey
        // Nothing to aim at until the widget has published a target, which is
        // also what keeps the first one a placement rather than a switch.
        targetValid: root.indicatorVisible
        visible: root.indicatorVisible
        crossAxis: LazerTheme.barLevelTop
    }

    // Sliding active highlight behind the squares (z below the row).
    Rectangle {
        id: activeHighlight

        z: -1
        x: root._highlightX
        y: workspaceRow.y
        width: root._highlightWidth
        height: LazerTheme.barWidgetHeight
        visible: root._highlightOn
        color: LazerTheme.activeFill

        Behavior on x {
            enabled: root._highlightPlaced && !MotionTokens.reducedMotion
            NumberAnimation { duration: MotionTokens.medium; easing.type: Easing.OutQuad }
        }
        Behavior on width {
            enabled: root._highlightPlaced && !MotionTokens.reducedMotion
            NumberAnimation { duration: MotionTokens.medium; easing.type: Easing.OutQuad }
        }
    }
}
