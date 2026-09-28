import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../services" as Services
import "ScreenCornerMask.js" as MaskLogic

// Fake rounded display corners: one always-on-top, click-through surface per
// screen that masks the bezel corners above every other layer-shell surface, so
// the desktop reads as a rounded panel. Fullscreen apps keep the mask (no
// special-casing) and the session lock surface still sits on top.
//
// The corners the bar physically covers are painted by the bar itself, from its
// own surface. This surface and the bar are both overlay-layer surfaces, and a
// client cannot order one against the other, so a corner claimed by both ends up
// showing whichever surface the compositor put on top — the bar's translucent
// fill washing the bezel out to a light tint. Splitting ownership keeps every
// corner inside a single surface.
Variants {
    id: root
    model: Quickshell.screens

    // Per-screen bezel surface
    Scope {
        id: screenScope

        required property var modelData

        PanelWindow {
            id: cornerWindow

            readonly property var cfg: Services.SettingsService.appearance
            readonly property real radius: Math.max(0, Number(cfg.screenCornerRadius) || 0)
            // Corners the bar paints itself, so this surface leaves them alone.
            readonly property int ownCorners: MaskLogic.barFreeCornerMask(
                String(Services.SettingsService.bar.position || "top"),
                Services.SettingsService.bar.floating === true)

            screen: screenScope.modelData
            color: "transparent"
            implicitWidth: Math.max(1, screenScope.modelData.width)
            implicitHeight: Math.max(1, screenScope.modelData.height)
            // Unmap while the feature is off so the compositor never composites
            // an all-transparent overlay; a 0 radius needs no mask either.
            visible: cfg.screenRoundedCorners !== false && radius > 0
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            WlrLayershell.namespace: "afloat:screen-corners"

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            // Bezel is decoration only: the desktop keeps every pointer event.
            mask: Region {}

            // Corner wedges painted above the wallpaper, minus the ones the bar
            // covers on its own surface.
            ScreenCornerMask {
                anchors.fill: parent
                radius: cornerWindow.radius
                corners: cornerWindow.ownCorners
            }
        }
    }
}
