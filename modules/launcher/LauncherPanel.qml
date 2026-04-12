import Quickshell
import QtQuick
import qs.config
import qs.services
import qs.modules.bar

// Launcher overlay panel — centred below the bar, opens/closes via LauncherService.isOpen.
// IPC: `qs ipc call launcher.toggle` / `qs ipc call launcher.openClipboard`
AnimatedPanelBase {
    id: panelWindow

    // Anchoring only top (no left/right) lets the Wayland compositor center
    // the window horizontally per the layer-shell protocol.
    // ExclusionMode.Ignore prevents the panel from pushing window content down —
    // the launcher must overlay, not reserve, screen space.
    anchors { top: true }
    margins { top: Theme.barHeight }
    exclusionMode: ExclusionMode.Ignore

    implicitWidth: ThemeLauncher.panelWidth
    implicitHeight: ThemeLauncher.panelHeight
    focusable: true

    active: LauncherService.isOpen

    onPanelOpening: {
        _core.openPanel()
        _core.runStructuralEnter()
    }
    onPanelClosing: {
        _core.runStructuralExit()
        _core.closePanel()
    }

    // Panel background card
    Rectangle {
        anchors.fill: parent
        anchors.topMargin: ThemeLauncher.panelInset
        anchors.bottomMargin: ThemeLauncher.panelInset
        radius: Theme.cornerRadius
        color: Colors.background
        border.color: Colors.border
        border.width: 1

        // Inner highlight border
        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: Theme.cornerRadius - 1
            color: "transparent"
            border.color: Qt.rgba(1, 1, 1, 0.04)
            border.width: 1
        }
    }

    LauncherCore {
        id: _core
        anchors {
            fill: parent
            topMargin: ThemeLauncher.panelInset
            leftMargin: ThemeLauncher.panelInset
            rightMargin: ThemeLauncher.panelInset
            bottomMargin: ThemeLauncher.panelInset
        }
    }
}
