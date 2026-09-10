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

    // Workspace id -> live window rows. Rebuilt as plain JS arrays so
    // delegates never cross-index the windows ListModel reactively.
    // Replaced only when the window set/order/app identity actually
    // changes; a wholesale swap destroys every icon delegate and floods
    // the async icon provider with reloads, which on Quickshell 0.3.1 can
    // corrupt the delegate tree (icons vanish permanently).
    property var windowsByWorkspace: ({})
    property string _windowMapSignature: ""
    // Observability: counts real map swaps so focus-only churn is verifiable.
    property int mapSwaps: 0
    // Focus lives on its own so focus-only updates never rebuild icon
    // delegates; ticks and opacity bind to this instead.
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

        // Focus-only events (the most frequent) swap nothing: icon
        // delegates stay alive and just rebind their opacity.
        root.focusedWinId = focused
        const signature = root.mapSignature(map)
        if (signature === root._windowMapSignature)
            return
        root._windowMapSignature = signature
        root.mapSwaps += 1
        root.windowsByWorkspace = map
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
                if (!wItem || !wItem.wins)
                    continue
                const wins = wItem.wins
                for (let k = 0; k < wins.length; k++) {
                    if (wins[k] && String(wins[k].winId) === root.focusedWinId) {
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
        root.indicatorCenterX = centerX
        if (!root.indicatorVisible)
            root.indicatorVisible = true
        if (!root._indicatorPlaced)
            root._indicatorPlaced = true
    }

    onFocusedWinIdChanged: Qt.callLater(root.updateIndicator)
    onWindowsByWorkspaceChanged: Qt.callLater(root.updateIndicator)
    onWidthChanged: Qt.callLater(root.updateIndicator)
    onHeightChanged: Qt.callLater(root.updateIndicator)

    Component.onCompleted: {
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

                readonly property var wins: root.windowsByWorkspace[wsId] || []
                readonly property bool hasWindows: wins.length > 0
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
                        if (!item || !item.modelData)
                            continue
                        if (String(item.modelData.winId) === target) {
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

                            required property var modelData

                            // Bound to the shared focus property: focus-only
                            // events never rebuild delegates, so modelData's
                            // snapshot would be stale here.
                            readonly property bool isFocused: String(modelData.winId) === root.focusedWinId
                            readonly property bool hovered: iconHover.hovered

                            width: root.iconSize
                            height: root.iconSize

                            IconImage {
                                anchors.fill: parent
                                source: root.iconPathForApp(windowIcon.modelData.appId)
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
                                    "--id", String(windowIcon.modelData.winId)
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
    // bar glyph so it aligns with the volume/battery/brightness bars.
    Rectangle {
        id: activeIndicator

        width: LazerTheme.barWidgetHeight - 16
        height: 3
        radius: 1.5
        color: LazerTheme.osuGreen
        visible: root.indicatorVisible
        x: Math.round(root.indicatorCenterX - width / 2)
        y: Math.round(root.height / 2 + (LazerTheme.barGlyphSize - 4) / 2 + 4)

        Behavior on x {
            enabled: root._indicatorPlaced && !MotionTokens.reducedMotion
            NumberAnimation {
                duration: MotionTokens.fast
                easing.type: Easing.OutQuad
            }
        }
    }
}
