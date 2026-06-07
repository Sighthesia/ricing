import Quickshell
import Quickshell.Wayland
import QtQuick
import "../../services" as Services
import "." as WorkspaceHint

// Floating-capsule window hint: one independent overlay per screen that mounts
// the shared WorkspaceHintStageView and drops the capsules in from the bar
// edge. Only used in floating-capsule mode (attached-island mode extends the
// island instead — see IslandBody).
Variants {
    id: root

    model: Quickshell.screens

    // Keep one independent workspace-hint overlay per screen.
    PanelWindow {
        id: hintWindow

        required property var modelData

        screen: modelData
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.exclusiveZone: -1

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        mask: Region { item: stageView.hitRegionItem }
        visible: hintWindow._windowVisible

        property bool _windowVisible: false
        property var testHintHeld: null
        property var testHintData: null
        property bool _hintActive: testHintHeld !== null ? testHintHeld : Services.WindowHintService.hintVisible
        property var _hintData: testHintData !== null ? testHintData : Services.WindowHintService.activeHint

        Component.onCompleted: Services.WindowHintService.setCenterSurfaceWidth(modelData.name, stageView.width)
        Component.onDestruction: Services.WindowHintService.setCenterSurfaceWidth(modelData.name, 0)
        on_WindowVisibleChanged: Services.WindowHintService.setCenterSurfaceWidth(modelData.name, _windowVisible ? stageView.width : 0)

        // Keep the window alive through the exit grace so the reverse
        // animation can play before hiding; the stage's own reveal logic is
        // gated declaratively by `active` below.
        on_HintActiveChanged: {
            if (_hintActive) {
                _windowVisible = true
            }
        }

        on_HintDataChanged: {
            if (_hintActive && !_windowVisible)
                _windowVisible = true
        }

        // Own the centered stage inside the transparent overlay; drop the
        // capsules in from the bar edge like the legacy floating hint.
        Item {
            id: hintContainer
            anchors.fill: parent

            WorkspaceHint.WorkspaceHintStageView {
                id: stageView

                x: (parent.width - width) / 2
                y: Services.BarLayoutService.barHeight + 16
                width: stageWidth
                height: stageHeight

                hintData: hintWindow._hintData
                active: hintWindow._hintActive
                stageTargetY: Services.BarLayoutService.barHeight + 16
                screenWidth: hintWindow.screen ? hintWindow.screen.width : hintWindow.width
                capsuleEdgeInset: 24
                onExitCompleteChanged: {
                    if (exitComplete)
                        hintWindow._windowVisible = false
                }
                onWidthChanged: Services.WindowHintService.setCenterSurfaceWidth(modelData.name, hintWindow._windowVisible ? width : 0)
            }
        }

        BackgroundEffect.blurRegion: Services.SettingsService.appearance.enableBlur ? hintBlurRegion : null

        // Track blur to each visible hint capsule instead of the bounding envelope.
        property Variants hintBlurRegions: Variants {
            model: stageView.capsuleItems

            Region {
                required property Item modelData

                item: modelData.visible && modelData.blurActive && modelData.blurSourceItem ? modelData.blurSourceItem : null
                radius: modelData.height / 2
            }
        }

        Region {
            id: hintBlurRegion

            regions: hintBlurRegions.instances
        }
    }
}
