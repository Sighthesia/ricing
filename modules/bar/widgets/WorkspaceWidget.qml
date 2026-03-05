import QtQuick
import Quickshell
import qs.config
import qs.services

// Two-state workspace indicator ("Dynamic Island" morph style).
//
// Focus Mode (default): single pill — focused app icon + window title.
// Overview Mode: per-workspace pills showing open window app icons.
//
// Mode transitions:
//   - Focus is active whenever a window is focused.
//   - Overview activates when the desktop has no focused window.
//   - Hover flips to the opposite mode temporarily.
//   - Workspace switch triggers a 1.5 s overview flash, then returns to Focus.
Item {
    id: root

    // --- layout ---
    implicitHeight: Theme.barHeight
    // implicitWidth is set after the visual layer is added (Task 5)
    implicitWidth: 60  // placeholder; replaced in Task 5

    // --- structure constants ---
    readonly property int _padV:         4    // vertical gap (pill ↔ bar top/bottom)
    readonly property int _padH:         10   // horizontal padding inside the pill
    readonly property int _iconSize:     16   // app icon in focus mode
    readonly property int _smallIcon:    13   // app icon inside workspace pills
    readonly property int _iconSpacing:  2    // gap between icons in a workspace pill
    readonly property int _pillGap:      6    // gap between workspace pills
    readonly property int _pillPadH:     8    // horizontal padding inside each workspace pill
    readonly property int _iconTitleGap: 6    // gap between focus icon and title text
    readonly property int _titleMaxW:    240  // max title render width (ElideRight after this)
    readonly property int _pillH:        Theme.barHeight - 2 * _padV

    // --- state machine ---
    // _mode is the base/preferred mode.
    // Hover XOR-flips to the other mode while the mouse is over the widget.
    // workspaceActivated fires _flashTimer to force overview for 1.5 s.
    property string _mode: "focus"    // "focus" | "overview"
    property bool   _hovered: false

    // _showOverview: the fully resolved, render-driving boolean.
    // Truth table:
    //   no focused window → always overview
    //   focused + _mode="focus"    + not hovered → false (focus)
    //   focused + _mode="focus"    + hovered     → true  (overview via hover flip)
    //   focused + _mode="overview" + not hovered → true  (overview)
    //   focused + _mode="overview" + hovered     → false (focus via hover flip)
    readonly property bool _showOverview: {
        if (_focusedTitle.length === 0) return true
        return (_mode === "overview") !== _hovered   // XOR
    }

    // --- focused window data ---
    property string _focusedAppId: ""
    property string _focusedTitle:  ""

    function _refreshFocus() {
        for (let i = 0; i < NiriService.windows.count; i++) {
            const w = NiriService.windows.get(i)
            if (w.isFocused) {
                root._focusedAppId = w.appId
                root._focusedTitle = (w.title === "Unknown") ? w.appId : w.title
                return
            }
        }
        root._focusedAppId = ""
        root._focusedTitle = ""
    }

    // --- icon resolution ---
    function _iconPath(appId) {
        if (!appId) return Quickshell.iconPath("application-x-executable")
        const entry = DesktopEntries.heuristicLookup(appId)
        if (entry && entry.icon)
            return Quickshell.iconPath(entry.icon, "application-x-executable")
        return Quickshell.iconPath("application-x-executable")
    }

    // --- flash timer: workspace switch → show overview for 1.5 s then return ---
    Timer {
        id: _flashTimer
        interval: 1500
        repeat: false
        onTriggered: root._mode = "focus"
    }

    Component.onCompleted: _refreshFocus()

    Connections {
        target: NiriService
        function onWindowsUpdated()      { root._refreshFocus() }
        function onWorkspaceActivated()  {
            // Temporarily show overview so the user sees the new workspace.
            root._mode = "overview"
            _flashTimer.restart()
        }
    }

}
