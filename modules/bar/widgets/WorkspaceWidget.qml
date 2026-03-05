import QtQuick
import Quickshell
import qs.config
import qs.services

// Enhanced workspace indicator — "Dynamic Island" style.
//
// Normal state: horizontal row of workspace pills, each showing small app icons
// for every open window in that workspace.
//
// When a window is focused: the island expands downward (below the bar's
// exclusiveZone) revealing the focused window title. The extra 30px surface area
// is provided by BarWindow's implicitHeight = barHeight + 30 while
// exclusiveZone stays at barHeight.
Item {
    id: root

    // --- layout (unchanged by island expansion) ---
    implicitHeight: Theme.barHeight
    implicitWidth: islandBackground.width
    clip: false

    // --- structure constants (not user-facing) ---
    readonly property int _padV:        4       // island ↔ bar top/bottom edge
    readonly property int _padH:        10      // island ↔ pill content horizontal margin
    readonly property int _iconSize:    14      // app icon square size
    readonly property int _iconSpacing: 2       // gap between icons inside a pill
    readonly property int _pillGap:     5       // gap between workspace pills
    readonly property int _pillPadH:    8       // horizontal padding inside each pill
    readonly property int _titleGap:    4       // separator between pills row and title
    readonly property int _titleRowH:   18      // height reserved for the title text row
    readonly property int _iconSpacing: 2       // tight gap between app icons inside a pill

    // Derived heights (collapsed = pills only, expanded = pills + title)
    readonly property int _collapsedH: Theme.barHeight - 2 * _padV
    readonly property int _expandedH:  _collapsedH + _titleGap + _titleRowH

    // --- reactive state ---
    property string focusedWindowTitle: ""
    readonly property bool _expanded: focusedWindowTitle.length > 0

    // --- icon resolution via Quickshell built-ins ---
    function _iconPath(appId) {
        if (!appId) return Quickshell.iconPath("application-x-executable")
        const entry = DesktopEntries.heuristicLookup(appId)
        if (entry && entry.icon)
            return Quickshell.iconPath(entry.icon, "application-x-executable")
        return Quickshell.iconPath("application-x-executable")
    }

    function _refreshFocused() {
        for (let i = 0; i < NiriService.windows.count; i++) {
            const w = NiriService.windows.get(i)
            if (w.isFocused) {
                // NiriService guarantees title is never empty ("Unknown" when unavailable).
                root.focusedWindowTitle = w.title
                return
            }
        }
        root.focusedWindowTitle = ""
    }

    Component.onCompleted: _refreshFocused()

    Connections {
        target: NiriService
        function onWindowsUpdated() { root._refreshFocused() }
    }

    // ─── Visual island background ──────────────────────────────────────────────
    // Width tracks the pills row; height animates to reveal/hide the title area.
    Rectangle {
        id: islandBackground

        x: 0
        y: root._padV
        width: pillsRow.implicitWidth + root._padH * 2
        // Height starts collapsed; states drive the asymmetric expand/collapse animation.
        height: root._collapsedH
        radius: Theme.cornerRadius
        color: Colors.background

        states: State {
            name: "expanded"; when: root._expanded
            PropertyChanges { target: islandBackground; height: root._expandedH }
        }

        transitions: [
            // Expand: elastic bounce-in — mirrors panel enter tokens.
            Transition {
                to: "expanded"
                NumberAnimation {
                    properties: "height"
                    duration: Theme.anim.enterDuration
                    easing.type: Theme.anim.enterType
                    easing.amplitude: Theme.anim.enterAmplitude
                    easing.period: Theme.anim.enterPeriod
                }
            },
            // Collapse: exponential snap-out — mirrors panel exit tokens.
            Transition {
                to: ""
                NumberAnimation {
                    properties: "height"
                    duration: Theme.anim.exitDuration
                    easing.type: Theme.anim.exitType
                }
            }
        ]

        Behavior on width {
            NumberAnimation {
                duration: Theme.anim.moveDuration
                easing.type: Theme.anim.moveType
            }
        }

        // ── Workspace pills row ─────────────────────────────────────────────
        Row {
            id: pillsRow
            x: root._padH
            // Vertically centred in the collapsed portion so position stays
            // stable as the island expands downward.
            y: (root._collapsedH - implicitHeight) / 2
            spacing: root._pillGap

            Repeater {
                model: NiriService.workspaces

                delegate: Item {
                    id: wsDelegate

                    required property string wsId
                    required property int    idx
                    required property bool   isActive

                    // Per-workspace app icon list; refreshed after every windows update.
                    property var _appIds: []

                    function _refreshIcons() {
                        let arr = []
                        for (let i = 0; i < NiriService.windows.count; i++) {
                            const w = NiriService.windows.get(i)
                            if (w.workspaceId === wsDelegate.wsId) arr.push(w.appId)
                        }
                        wsDelegate._appIds = arr
                    }

                    Component.onCompleted: _refreshIcons()

                    Connections {
                        target: NiriService
                        function onWindowsUpdated() { wsDelegate._refreshIcons() }
                    }

                    // Hide empty non-active workspaces (collapsed by row spacing).
                    visible: isActive || _appIds.length > 0

                    // Collapse layout space when hidden so the Row reflows.
                    width:  visible ? pill.implicitWidth  : 0
                    height: visible ? pill.implicitHeight : 0

                    // ── Pill ────────────────────────────────────────────────
                    Rectangle {
                        id: pill

                        implicitHeight: root._collapsedH
                        implicitWidth: Math.max(
                            iconRow.implicitWidth + root._pillPadH * 2,
                            root._collapsedH  // keeps pill square-ish when only one icon
                        )
                        radius: root._collapsedH / 2
                        color: wsDelegate.isActive ? Colors.highlight : Colors.surface

                        Behavior on implicitWidth {
                            NumberAnimation {
                                duration: Theme.anim.moveDuration
                                easing.type: Theme.anim.moveType
                            }
                        }

                        Behavior on color {
                            ColorAnimation { duration: Theme.anim.highlightDuration }
                        }

                        // App icons row (or workspace number when empty)
                        Row {
                            id: iconRow
                            anchors.centerIn: parent
                            spacing: root._iconSpacing

                            Repeater {
                                model: wsDelegate._appIds

                                delegate: Image {
                                    required property string modelData

                                    readonly property bool _ok: status === Image.Ready
                                    width:  _ok ? root._iconSize : 0
                                    height: _ok ? root._iconSize : 0

                                    source: root._iconPath(modelData)
                                    smooth: true
                                    fillMode: Image.PreserveAspectFit
                                }
                            }

                            // Workspace number — visible only when workspace is empty.
                            Text {
                                visible: wsDelegate._appIds.length === 0
                                text: wsDelegate.idx
                                font.family: Theme.fontMono
                                font.bold:   true
                                font.pixelSize: Theme.fontSizeBody
                                color: wsDelegate.isActive ? Colors.background : Colors.textMuted

                                Behavior on color {
                                    ColorAnimation { duration: Theme.anim.highlightDuration }
                                }
                            }
                        }

                        // FIXME: HoverRevealHighlight and ClickRipple unavailable here —
                        // circular module dependency (widgets/ is compiled as part of qs.modules.bar).
                        // Resolution: extract shared interactive primitives to a qs.components module.
                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            color: Colors.highlight
                            opacity: wsArea.containsMouse ? Colors.highlightAlpha : 0
                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Theme.anim.highlightDuration
                                    easing.type: Theme.anim.highlightType
                                }
                            }
                        }

                        // FIXME: ClickRipple missing — same circular dependency as above.
                        MouseArea {
                            id: wsArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Quickshell.execDetached([
                                "niri", "msg", "action",
                                "focus-workspace", wsDelegate.idx.toString()
                            ])
                        }
                    }
                }
            }
        }

        // ── Focused window title ────────────────────────────────────────────
        // Appears below the pills row as the island expands downward.
        Text {
            id: titleText
            x: root._padH
            y: root._collapsedH + root._titleGap
            width: islandBackground.width - root._padH * 2
            text: root.focusedWindowTitle
            elide: Text.ElideRight
            maximumLineCount: 1
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            color: Colors.textMuted
            opacity: root._expanded ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.anim.highlightDuration
                    easing.type: Theme.anim.highlightType
                }
            }
        }
    }
}
