pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Widgets
import "../../lazerbar"
import "../../../services" as Services

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
    // is one Rectangle below; only this value moves when the active
    // workspace or the focused app changes.
    property real indicatorCenterX: 0
    property bool indicatorVisible: false
    property bool _indicatorPlaced: false

    readonly property int iconSize: 16
    readonly property int iconSpacing: 4
    readonly property int cellPadding: 8

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
        for (let i = model.count - 1; i >= 0; i--) {
            const id = String(model.get(i).winId)
            let keep = false
            for (let k = 0; k < rows.length; k++) {
                if (String(rows[k].winId) === id) {
                    keep = true
                    break
                }
            }
            if (!keep)
                model.remove(i, 1)
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
                model.insert(j, {
                    winId: want,
                    appId: appId
                })
            } else {
                if (at !== j)
                    model.move(at, j, 1)
                if (String(model.get(j).appId) !== appId)
                    model.setProperty(j, "appId", appId)
            }
        }
    }

    // Event-stream bursts coalesce into one rebuild per frame.
    Connections {
        target: Services.NiriService
        function onWindowsUpdated() {
            Qt.callLater(root.refreshWindowMap)
            Qt.callLater(root.updateIndicator)
        }
        function onWorkspacesUpdated() {
            Qt.callLater(root.updateIndicator)
        }
        function onWorkspaceActivated() {
            Qt.callLater(root.updateIndicator)
        }
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
        // Assign while unplaced so the first show never slides in from zero.
        // Key lands first so the tracker's change handler sees both values.
        root.indicatorTargetKey = focusedIndex >= 0 ? "w" + root.focusedWinId
                                                    : "s" + targetIndex
        root.indicatorCenterX = centerX
        if (!root.indicatorVisible)
            root.indicatorVisible = true
        if (!root._indicatorPlaced)
            root._indicatorPlaced = true
    }

    onFocusedWinIdChanged: Qt.callLater(root.updateIndicator)
    onWidthChanged: Qt.callLater(root.updateIndicator)
    onHeightChanged: Qt.callLater(root.updateIndicator)

    Component.onCompleted: {
        snapEdgesTo(indicatorCenterX, indicatorTargetKey)
        root.refreshWindowMap()
        Qt.callLater(root.updateIndicator)
    }

    implicitWidth: workspaceRow.implicitWidth
    implicitHeight: LazerTheme.barWidgetHeight

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

                width: hasWindows ? contentRow.implicitWidth + root.cellPadding * 2
                                  : LazerTheme.barWidgetHeight
                height: LazerTheme.barWidgetHeight

                onXChanged: Qt.callLater(root.updateIndicator)
                onWidthChanged: Qt.callLater(root.updateIndicator)

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
                            const p = item.mapToItem(root, item.width / 2, 0)
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
                    color: workspaceSquare.isActive
                           ? LazerTheme.activeFill
                           : workspaceSquare.hovered ? LazerTheme.hoverFill : "transparent"

                    Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
                }

                Row {
                    id: contentRow

                    anchors.centerIn: parent
                    spacing: root.iconSpacing

                    Text {
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

                        delegate: Item {
                            id: windowIcon

                            required property string winId
                            required property string appId

                            // Bound to the shared focus property: focus-only
                            // events never rebuild delegates, and the role
                            // props always reflect the model's live row.
                            readonly property bool isFocused: windowIcon.winId === root.focusedWinId
                            readonly property bool hovered: iconHover.hovered

                            width: root.iconSize
                            height: root.iconSize

                            IconImage {
                                anchors.fill: parent
                                source: root.iconPathForApp(windowIcon.appId)
                                // These tiny, persistent delegates should not
                                // keep feeding the long-lived async icon
                                // provider during compositor event bursts.
                                asynchronous: false
                                backer.fillMode: Image.PreserveAspectFit
                                smooth: true
                                opacity: windowIcon.isFocused
                                         ? 1
                                         : windowIcon.hovered ? 0.85 : 0.55

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
    // level bar, workspace green kept, top edge derived from the centered
    // bar glyph so it aligns with the volume/battery/brightness bars. Its
    // width is owned by the dual-speed edge tracker below.
    readonly property int indicatorBarWidth: LazerTheme.barWidgetHeight - 16
    // Identity of the current indicator target (focused window or active
    // workspace); lets the edge tracker tell genuine switches from re-anchors.
    property string indicatorTargetKey: ""
    onIndicatorCenterXChanged: root.retargetEdges(root.indicatorCenterX,
                                                  root.indicatorTargetKey)

    // Dual-speed tracker (旧分支 capsule 遗留): the bar edge x converges
    // fast while a shadow copy trails slowly, so the rendered span stretches
    // toward travel direction and contracts on arrival. Hosted on the Item
    // itself because Behaviors do not intercept plain QtObject properties.
    property string _edgeTargetKey: ""
    // Logical left-edge anchor: the committed target, never animated. All
    // dedupe/drift decisions read this instead of _edgeX, whose value is the
    // Behavior's in-flight animation frame (identical to _edgeShadowX until
    // the first animation tick, which made same-frame events look "settled"
    // and teleported the bar).
    property real _edgeAnchorX: 0
    property real _edgeX: 0
    property real _edgeShadowX: 0
    property bool _edgeSnapping: false
    // Same-anchor drift that arrives while a trail is in flight; applied as
    // one snap once the shadow catches up so the trail is never cut short.
    property real _edgePendingCenterX: -1
    readonly property real _edgeRectLeft: Math.min(_edgeX, _edgeShadowX)
    readonly property real _edgeSpan: indicatorBarWidth + Math.abs(_edgeX - _edgeShadowX)

    Timer {
        interval: 16
        repeat: true
        running: root._edgePendingCenterX >= 0
        onTriggered: {
            if (Math.abs(root._edgeX - root._edgeShadowX) >= 0.5)
                return
            var pending = root._edgePendingCenterX
            root._edgePendingCenterX = -1
            root.snapEdgesTo(pending, root._edgeTargetKey)
        }
    }

    Behavior on _edgeX {
        enabled: root._indicatorPlaced && !MotionTokens.reducedMotion && !root._edgeSnapping
        NumberAnimation { duration: MotionTokens.medium; easing.type: Easing.OutQuad }
    }
    Behavior on _edgeShadowX {
        enabled: root._indicatorPlaced && !MotionTokens.reducedMotion && !root._edgeSnapping
        // 3x the bar's own flight: the tail lingers long after the head
        // lands, which is what keeps the stretch readable.
        NumberAnimation { duration: MotionTokens.slow * 2; easing.type: Easing.OutSine }
    }

    // Commit bar and shadow together with the Behaviors suppressed. Both
    // writes use a precomputed target: reading _edgeX back would return the
    // Behavior's in-flight animation frame, not the committed value.
    function snapEdgesTo(centerX, key) {
        var target = centerX - indicatorBarWidth / 2
        _edgeSnapping = true
        _edgeTargetKey = key
        _edgeAnchorX = target
        _edgeX = target
        _edgeShadowX = target
        _edgeSnapping = false
    }

    // Route every indicator re-anchor through here. A genuine target switch
    // (key change after placement) desyncs bar and shadow into the trail;
    // duplicate updates are deduped against the logical anchor so an
    // in-flight trail survives even in the same frame as the switch (x and
    // shadow are numerically equal until the first animation tick); real
    // same-target layout drift snaps both so content churn never stretches
    // the bar; the first placement snaps so it never slides in from zero.
    function retargetEdges(centerX, key) {
        if (!isFinite(centerX))
            return
        var target = centerX - indicatorBarWidth / 2
        if (key !== _edgeTargetKey && _indicatorPlaced) {
            _edgePendingCenterX = -1
            _edgeTargetKey = key
            _edgeAnchorX = target
            _edgeX = target
            _edgeShadowX = target
            return
        }
        if (Math.abs(target - _edgeAnchorX) < 3)
            return
        if (Math.abs(_edgeX - _edgeShadowX) > 0.5) {
            _edgePendingCenterX = centerX
            return
        }
        snapEdgesTo(centerX, key)
    }

    Rectangle {
        id: activeIndicator

        width: root._edgeSpan
        height: 3
        radius: 1.5
        color: LazerTheme.osuGreen
        visible: root.indicatorVisible
        x: root._edgeRectLeft
        y: Math.round(root.height / 2 + (LazerTheme.barGlyphSize - 4) / 2 + 4)
    }
}
