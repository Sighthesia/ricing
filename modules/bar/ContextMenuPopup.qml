import Quickshell
import QtQuick
import qs.config

// Shared popup shell for bar-styled context menus.
PopupWindow {
    id: root

    property int contentMargin: ThemeCards.shellInset
    property int surfaceTransformOrigin: Item.Top
    property real openScale: 0.85
    property real closedScale: 0.88
    readonly property int enterOpacityDuration:
        Math.max(1, Math.round(Theme.anim.highlightDuration * 0.56))
    readonly property int enterScaleDuration:
        Math.max(1, Math.round(Theme.anim.springDuration * 0.36))
    readonly property int exitDuration:
        Math.max(1, Math.round(Theme.anim.highlightDuration * 0.44))
    property alias surface: menuSurface
    default property alias content: menuSurface.content

    visible: false
    color: "transparent"

    function playEnterAnimation() {
        menuSurface.opacity = 0
        menuSurface.scale = root.openScale
        enterAnim.restart()
    }

    function setClosedState() {
        menuSurface.opacity = 0
        menuSurface.scale = root.closedScale
        root.visible = false
    }

    // Shared popup surface.
    ContextMenuSurface {
        id: menuSurface

        anchors.fill: parent
        contentMargin: root.contentMargin
        opacity: 0
        scale: root.openScale
        transformOrigin: root.surfaceTransformOrigin
    }

    ParallelAnimation {
        id: enterAnim

        NumberAnimation {
            target: menuSurface
            property: "opacity"
            from: 0
            to: 1
            duration: root.enterOpacityDuration
            easing.type: Easing.OutQuad
        }

        NumberAnimation {
            target: menuSurface
            property: "scale"
            from: root.openScale
            to: 1.0
            duration: root.enterScaleDuration
            easing.type: Easing.OutBack
            easing.overshoot: 0.4
        }
    }
}
