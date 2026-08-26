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
    property var windowsByWorkspace: ({})

    readonly property int iconSize: 16
    readonly property int iconSpacing: 4
    readonly property int cellPadding: 8

    function refreshWindowMap() {
        const map = {}
        const model = Services.NiriService.windows
        for (let i = 0; i < model.count; i++) {
            const win = model.get(i)
            if (!win || !win.workspaceId)
                continue
            if (!map[win.workspaceId])
                map[win.workspaceId] = []
            map[win.workspaceId].push(win)
        }
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

                            readonly property bool isFocused: modelData.isFocused || false
                            readonly property bool hovered: iconHover.hovered

                            width: root.iconSize
                            height: root.iconSize

                            IconImage {
                                anchors.fill: parent
                                source: String(windowIcon.modelData.appId || "").length > 0
                                        ? Quickshell.iconPath(windowIcon.modelData.appId, true) : ""
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
