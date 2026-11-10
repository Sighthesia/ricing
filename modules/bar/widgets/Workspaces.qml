pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Widgets
import "../../lazerbar"
import "../../../services" as Services
import "WorkspacesWheel.js" as WheelLogic

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
    property bool _modelsReady: false
    property bool _layoutBusy: false
    property bool indicatorTargetMoving: false

    // Settle geometry before committing a newly inserted focus target.
    Timer {
        interval: MotionTokens.motionFrame
        repeat: true
        running: root._layoutBusy
        onTriggered: {
            let moving = false
            for (let i = 0; i < workspaceRepeater.count; i++) {
                const square = workspaceRepeater.itemAt(i)
                if (square && square.iconsMoving())
                    moving = true
            }
            root.updateIndicator()
            root.updateHighlight()
            if (!moving) {
                root._layoutBusy = false
                root.updateIndicator()
            }
        }
    }
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

    readonly property int iconSize: 16
    readonly property int iconSpacing: 4
    readonly property int cellPadding: 8
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
        const fallback = Quickshell.iconPath("application-x-executable")
        const normalizedAppId = String(appId || "")
        if (!normalizedAppId)
            return fallback

        const entry = Quickshell.desktopEntries
            ? Quickshell.desktopEntries.byId(normalizedAppId)
            : null
        const iconName = entry && entry.icon ? String(entry.icon) : normalizedAppId
        return Quickshell.iconPath(iconName, "application-x-executable") || fallback
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
        root._layoutBusy = root._modelsReady && !MotionTokens.reducedMotion
        root.syncWorkspaceModels(map)
    }

    // Bring the stable per-workspace models to the freshly built map without
    // ever replacing a model object: vanished workspaces drop their model,
    // surviving ones diff-sync row by row so untouched windows keep their
    // delegates and loaded icons.
    function syncWorkspaceModels(map) {
        const models = root.workspaceModels
        const animateRows = root._modelsReady && !MotionTokens.reducedMotion
        const wanted = {}
        const ids = Object.keys(map)
        // An empty workspace still owns its retiring icons until their exits complete.
        for (const id of Object.keys(models)) {
            if (ids.indexOf(id) < 0) {
                map[id] = []
                ids.push(id)
            }
        }
        for (let i = 0; i < ids.length; i++) {
            const wsId = String(ids[i])
            wanted[wsId] = true
            let model = models[wsId]
            if (!model) {
                model = iconModelFactory.createObject(root)
                models[wsId] = model
                root._modelsRevision++
            }
            root.syncIconModel(model, map[ids[i]], animateRows)
        }
        const known = Object.keys(models)
        for (let k = 0; k < known.length; k++) {
            if (!wanted[known[k]]) {
                models[known[k]].destroy()
                delete models[known[k]]
                root._modelsRevision++
            }
        }
        root._modelsReady = true
    }

    // Reconcile one stable model with the desired ordered rows, keyed by
    // winId: remove gone rows, insert new ones in place, move drifted rows,
    // refresh changed app identities. Untouched rows (and their delegates
    // and images) are never modified.
    function syncIconModel(model, rows, animateRows) {
        const wanted = {}
        for (let n = 0; n < rows.length; n++)
            wanted[String(rows[n].winId)] = true

        // Keep a missing icon as a zero-width retiring delegate until its fade finishes.
        // Removing it immediately would destroy the only object that still knows its old
        // physical position, so the following icons would jump instead of travelling.
        for (let i = model.count - 1; i >= 0; i--) {
            const id = String(model.get(i).winId)
            if (wanted[id]) {
                if (model.get(i).retiring)
                    model.setProperty(i, "retiring", false)
                continue
            }
            if (animateRows) {
                if (!model.get(i).retiring) {
                    for (let w = 0; w < workspaceRepeater.count; w++) {
                        const square = workspaceRepeater.itemAt(w)
                        if (square && square.wins === model)
                            square.freezeIcon(id)
                    }
                }
                model.setProperty(i, "retiring", true)
                model.setProperty(i, "entering", false)
            } else {
                model.remove(i, 1)
            }
        }

        // Keep retiring delegates in their original model slots. Live rows reorder in
        // the remaining slots, so closing the focused item cannot push it to the edge.
        function liveSlot(n) {
            let live = 0
            for (let i = 0; i < model.count; i++) {
                if (model.get(i).retiring)
                    continue
                if (live++ === n)
                    return i
            }
            return model.count
        }
        for (let j = 0; j < rows.length; j++) {
            const want = String(rows[j].winId)
            const appId = String(rows[j].appId || "")
            let at = -1
            for (let m = 0; m < model.count; m++) {
                if (String(model.get(m).winId) === want) {
                    at = m
                    break
                }
            }
            if (at < 0) {
                model.insert(liveSlot(j), {
                    winId: want,
                    appId: appId,
                    entering: !!animateRows,
                    retiring: false
                })
                if (animateRows) {
                    Qt.callLater(function() {
                        for (let k = 0; k < model.count; k++) {
                            if (String(model.get(k).winId) === want
                                && !model.get(k).retiring) {
                                model.setProperty(k, "entering", false)
                                break
                            }
                        }
                    })
                }
            } else {
                const slot = liveSlot(j)
                // Moving through ghosts shifts their indices too. Wait for those exits
                // before a simultaneous genuine reorder; membership updates still apply.
                let ghosts = false
                for (let g = 0; g < model.count; g++)
                    ghosts = ghosts || model.get(g).retiring
                if (!ghosts && at !== slot) {
                    model.move(at, slot, 1)
                    at = slot
                }
                model.setProperty(at, "appId", appId)
                model.setProperty(at, "retiring", false)
                model.setProperty(at, "entering", false)
            }
        }
    }

    // Retiring icons paint behind the live row, above the workspace highlight.
    Item {
        id: exitGhostLayer
        anchors.fill: parent
        z: -0.5
        enabled: false
    }

    function exitVisualHost() {
        return exitGhostLayer
    }

    function removeRetiredIcon(wsId, winId) {
        const model = root.workspaceModels[String(wsId)]
        if (!model)
            return
        for (let i = model.count - 1; i >= 0; i--) {
            const row = model.get(i)
            if (String(row.winId) === String(winId) && row.retiring) {
                model.remove(i, 1)
                const current = []
                for (let w = 0; w < Services.NiriService.windows.count; w++) {
                    const win = Services.NiriService.windows.get(w)
                    if (String(win.workspaceId) === String(wsId))
                        current.push(win)
                }
                current.sort(root.windowOrder)
                root.syncIconModel(model, current, !MotionTokens.reducedMotion)
                root._layoutBusy = !MotionTokens.reducedMotion
                return
            }
        }
    }

    // Reduced motion also finalizes delegates already playing an exit.
    Connections {
        target: MotionTokens
        function onReducedMotionChanged() {
            if (!MotionTokens.reducedMotion)
                return
            for (const id of Object.keys(root.workspaceModels)) {
                const model = root.workspaceModels[id]
                for (let i = model.count - 1; i >= 0; i--) {
                    if (model.get(i).retiring)
                        model.remove(i, 1)
                    else
                        model.setProperty(i, "entering", false)
                }
            }
            root._layoutBusy = false
            root.indicatorTargetMoving = false
            Qt.callLater(root.updateIndicator)
        }
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
        // A focused window can arrive before its model/delegate. Hold the previous
        // mark until that exact window exists rather than aiming at a workspace center.
        if (root.focusedWinId !== "" && focusedIndex < 0)
            return
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
        if (focusedIndex >= 0 && !isFinite(centerX))
            return
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
        root.indicatorTargetMoving = root._layoutBusy
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

                width: Math.max(LazerTheme.barWidgetHeight,
                    contentRow.implicitWidth + root.cellPadding * 2)
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

                function freezeIcon(key) {
                    for (let i = 0; i < windowRepeater.count; i++) {
                        const item = windowRepeater.itemAt(i)
                        if (item && item.winId === key)
                            item.freezeExit()
                    }
                }

                function iconSlotX(index) {
                    let x = workspaceNumber.width
                    for (let i = 0; i < index; i++) {
                        const item = windowRepeater.itemAt(i)
                        if (item)
                            x += item.width
                    }
                    return x
                }

                property bool carryingSlots: false
                function placeIcons(carry) {
                    workspaceSquare.carryingSlots = carry === true
                    for (let i = 0; i < windowRepeater.count; i++) {
                        const item = windowRepeater.itemAt(i)
                        if (item && !item.retiring)
                            item.slotTargetX = workspaceSquare.iconSlotX(i)
                    }
                    workspaceSquare.carryingSlots = false
                }

                function iconsMoving() {
                    workspaceSquare.placeIcons()
                    for (let i = 0; i < windowRepeater.count; i++) {
                        const item = windowRepeater.itemAt(i)
                        if (item && (item.entering || item.retiring
                            || item.widthMotion.running || item.positionMotion.running))
                            return true
                    }
                    return Math.abs(width - (hasWindows
                        ? contentRow.implicitWidth + root.cellPadding * 2
                        : LazerTheme.barWidgetHeight)) > 0.5
                }

                function iconsWidth() {
                    let width = workspaceNumber.width
                    for (let i = 0; i < windowRepeater.count; i++) {
                        const item = windowRepeater.itemAt(i)
                        if (item)
                            width += item.width
                    }
                    return width
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
                            const p = item.mapToItem(root, root.iconSpacing + root.iconSize / 2, 0)
                            return p.x
                        }
                    }
                    return NaN
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

                Item {
                    id: contentRow
                    anchors.centerIn: parent
                    implicitWidth: workspaceSquare.iconsWidth()
                    implicitHeight: root.iconSize

                    Text {
                        id: workspaceNumber
                        anchors.verticalCenter: parent.verticalCenter
                        text: workspaceSquare.idx
                        color: workspaceSquare.isActive
                               ? LazerTheme.textPrimary
                               : workspaceSquare.hovered ? LazerTheme.hoverForeground : LazerTheme.iconInactive
                        font.pixelSize: 13
                        font.bold: workspaceSquare.isActive
                    }

                    // One icon per window on this workspace; the focused
                    // window's icon stays bright while the single indicator
                    // below slides underneath it.
                    Repeater {
                        id: windowRepeater
                        model: workspaceSquare.wins
                        onItemAdded: Qt.callLater(function() {
                            contentRow.implicitWidth = workspaceSquare.iconsWidth()
                            workspaceSquare.placeIcons()
                        })
                        onItemRemoved: Qt.callLater(function() {
                            contentRow.implicitWidth = workspaceSquare.iconsWidth()
                            workspaceSquare.placeIcons()
                        })

                        delegate: Item {
                            id: windowIcon

                            required property int index
                            required property string winId
                            required property string appId
                            required property bool entering
                            required property bool retiring

                            readonly property bool motionEnabled: !MotionTokens.reducedMotion
                            Timer {
                                id: retireTimer
                                interval: Math.max(MotionTokens.windowGhostExit,
                                    MotionTokens.windowGhostSlotDelay + MotionTokens.workspaceIconExit)
                                running: windowIcon.retiring && windowIcon.motionEnabled
                                repeat: false
                                onTriggered: root.removeRetiredIcon(
                                    workspaceSquare.wsId, windowIcon.winId)
                            }

                            // Bound to the shared focus property: focus-only
                            // events never rebuild delegates, and the role
                            // props always reflect the model's live row.
                            readonly property bool isFocused: windowIcon.winId === root.focusedWinId
                            readonly property bool hovered: iconHover.hovered

                            property bool placed: false
                            property real slotTargetX: 0
                            readonly property alias widthMotion: slotWidthMotion
                            readonly property alias positionMotion: iconPositionMotion
                            x: windowIcon.slotTargetX
                            y: 0
                            property bool ghostActive: false
                            property bool closeSlot: false
                            property point ghostSceneOrigin: Qt.point(0, 0)
                            Timer {
                                interval: MotionTokens.windowGhostSlotDelay
                                running: windowIcon.retiring && windowIcon.motionEnabled
                                onTriggered: windowIcon.closeSlot = true
                            }
                            property real ghostX: 0
                            property real ghostY: 0
                            property Item ghostHost: null
                            function freezeExit() {
                                if (windowIcon.ghostActive || !windowIcon.placed)
                                    return
                                windowIcon.ghostSceneOrigin = windowIcon.mapToItem(null, root.iconSpacing, 0)
                                windowIcon.ghostHost = root.exitVisualHost()
                                const point = windowIcon.mapToItem(windowIcon.ghostHost, root.iconSpacing, 0)
                                windowIcon.ghostX = point.x
                                windowIcon.ghostY = point.y
                                windowIcon.ghostActive = true
                            }
                            onRetiringChanged: {
                                if (windowIcon.retiring)
                                    windowIcon.freezeExit()
                                else {
                                    windowIcon.ghostActive = false
                                    windowIcon.closeSlot = false
                                }
                            }
                            width: windowIcon.entering || windowIcon.closeSlot
                                ? 0 : root.iconSize + root.iconSpacing
                            z: windowIcon.retiring ? 1 : 0
                            height: root.iconSize
                            enabled: !windowIcon.retiring && !windowIcon.entering
                            onWidthChanged: {
                                contentRow.implicitWidth = workspaceSquare.iconsWidth()
                                workspaceSquare.placeIcons(true)
                            }
                            Component.onCompleted: {
                                windowIcon.slotTargetX = workspaceSquare.iconSlotX(windowIcon.index)
                                windowIcon.placed = true
                                Qt.callLater(root.updateIndicator)
                            }
                            onIndexChanged: {
                                if (windowIcon.placed && !windowIcon.retiring)
                                    windowIcon.slotTargetX = workspaceSquare.iconSlotX(windowIcon.index)
                            }

                            Behavior on x {
                                enabled: windowIcon.motionEnabled && windowIcon.placed
                                    && !workspaceSquare.carryingSlots
                                NumberAnimation {
                                    id: iconPositionMotion
                                    duration: MotionTokens.workspaceIconMove
                                    easing.type: Easing.OutQuint
                                }
                            }
                            Behavior on width {
                                enabled: windowIcon.motionEnabled
                                NumberAnimation {
                                    id: slotWidthMotion
                                    duration: windowIcon.retiring
                                        ? MotionTokens.workspaceIconExit
                                        : MotionTokens.workspaceIconEnter
                                    easing.type: Easing.OutQuint
                                }
                            }

                            // Reference: MarqueeLabel ghost drop and scan-character reveal.
                            IconImage {
                                parent: windowIcon.ghostActive ? windowIcon.ghostHost : windowIcon
                                enabled: !windowIcon.ghostActive
                                x: windowIcon.ghostActive ? windowIcon.ghostX : root.iconSpacing
                                y: windowIcon.ghostActive ? windowIcon.ghostY : 0
                                z: 0
                                Timer {
                                    interval: MotionTokens.motionFrame
                                    running: windowIcon.ghostActive
                                    repeat: true
                                    onTriggered: {
                                        const point = windowIcon.ghostHost.mapFromItem(null,
                                            windowIcon.ghostSceneOrigin.x, windowIcon.ghostSceneOrigin.y)
                                        windowIcon.ghostX = point.x
                                        windowIcon.ghostY = point.y
                                    }
                                }
                                transformOrigin: Item.TopLeft
                                scale: (windowIcon.entering || windowIcon.retiring)
                                    ? MotionTokens.windowGhostScale : 1
                                Behavior on scale {
                                    enabled: windowIcon.motionEnabled
                                    NumberAnimation {
                                        duration: MotionTokens.windowGhostExit
                                        easing.type: Easing.BezierSpline
                                        easing.bezierCurve: MotionTokens.outSoft
                                    }
                                }
                                transform: Translate {
                                    x: (windowIcon.entering || windowIcon.retiring)
                                        ? MotionTokens.windowGhostOffset : 0
                                    y: (windowIcon.entering || windowIcon.retiring)
                                        ? MotionTokens.windowGhostOffset : 0
                                    Behavior on x {
                                        enabled: windowIcon.motionEnabled
                                        NumberAnimation {
                                            duration: MotionTokens.windowGhostExit
                                            easing.type: Easing.OutQuint
                                        }
                                    }
                                    Behavior on y {
                                        enabled: windowIcon.motionEnabled
                                        NumberAnimation {
                                            duration: MotionTokens.windowGhostExit
                                            easing.type: Easing.OutQuint
                                        }
                                    }
                                }
                                width: root.iconSize
                                height: root.iconSize
                                source: root.iconPathForApp(windowIcon.appId)
                                // These tiny, persistent delegates should not
                                // keep feeding the long-lived async icon
                                // provider during compositor event bursts.
                                asynchronous: false
                                backer.fillMode: Image.PreserveAspectFit
                                smooth: true
                                opacity: windowIcon.entering || windowIcon.retiring ? 0
                                         : windowIcon.isFocused
                                           ? 1
                                           : windowIcon.hovered ? 0.85 : 0.55

                                Behavior on opacity {
                                    enabled: windowIcon.motionEnabled
                                    NumberAnimation {
                                        duration: windowIcon.retiring
                                            ? MotionTokens.windowGhostExit
                                            : MotionTokens.windowListReveal
                                        easing.type: windowIcon.retiring
                                            ? MotionTokens.windowListFadeEasing
                                            : MotionTokens.windowListRevealEasing
                                    }
                                }
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
    // level bar, workspace green kept, top edge derived from the centered
    // bar glyph so it aligns with the volume/battery/brightness bars. Its
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
        targetMoving: root.indicatorTargetMoving
        // Nothing to aim at until the widget has published a target, which is
        // also what keeps the first one a placement rather than a switch.
        targetValid: root.indicatorVisible
        visible: root.indicatorVisible
        crossAxis: Math.round(root.height / 2 + (LazerTheme.barGlyphSize - 4) / 2 + 4)
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
