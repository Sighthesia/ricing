pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Widgets
import "../../lazerbar"
import "../../../services" as Services

// Workspace overview squares that expand to show each workspace's app icons
// (noctalia-shell grouped mode): click a square to focus the workspace, click
// an app icon to focus that exact window. Empty workspaces stay compact
// numbered squares.
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

        return Quickshell.iconPath(normalizedAppId, "application-x-executable") || fallback
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
        // delegates stay alive and just rebind their tick/opacity.
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
        }
    }

    Component.onCompleted: root.refreshWindowMap()

    implicitWidth: workspaceRow.implicitWidth
    implicitHeight: LazerTheme.barWidgetHeight

    Row {
        id: workspaceRow

        anchors.centerIn: parent
        spacing: LazerTheme.inlineGap

        Repeater {
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
                    // window's icon stays bright with an accent tick below.
                    Repeater {
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
                                asynchronous: true
                                backer.fillMode: Image.PreserveAspectFit
                                smooth: true
                                opacity: windowIcon.isFocused
                                         ? 1
                                         : windowIcon.hovered ? 0.85 : 0.55

                                Behavior on opacity { NumberAnimation { duration: MotionTokens.fast } }
                            }

                            // Focused-window tick echoes the active
                            // workspace strip in miniature.
                            Rectangle {
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: -3
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: parent.width - 6
                                height: 2
                                color: LazerTheme.osuGreen
                                visible: windowIcon.isFocused
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

                // Active workspaces keep a thin accent strip along the bottom.
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: workspaceSquare.isActive ? parent.width - 8 : 0
                    height: 2
                    color: LazerTheme.osuGreen

                    Behavior on width { NumberAnimation { duration: MotionTokens.fast } }
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
}
