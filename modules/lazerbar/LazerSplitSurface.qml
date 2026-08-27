import QtQuick
import "../bar/BarPopupMotion.js" as PopupMotion

// Shared split surface owning two independently animated background layers.
// Host drives revealProgress; header leads content with the settings timing contract.
// Content children are mounted inside contentSurface via the default alias.
Item {
    id: root

    // External reveal progress in 0..1 driven by the host overlay.
    property real revealProgress: 0
    // Whether the surface may become interactive once revealed.
    property bool interactive: true
    // Fixed header height; host may override for different popup sizes.
    property int headerHeight: 48
    // Content background color; defaults to the shared settings panel surface.
    property color contentColor: LazerTheme.settingsPanel
    // Header children are mounted in the rail surface, beside contentData.
    property alias headerData: headerSurface.data

    // Combined reveal duration mirrors BarPopupFrame's settings timing.
    readonly property int revealDuration: MotionTokens.settingsSidebarFade + MotionTokens.settingsContentDelay
    // Header fades from 0 while content is still delayed.
    readonly property real headerProgress: PopupMotion.headerProgress(revealProgress, revealDuration, MotionTokens.settingsSidebarFade)
    // Content starts after the configured delay and tracks the same fade.
    readonly property real contentProgress: PopupMotion.contentProgress(revealProgress, revealDuration, MotionTokens.settingsContentDelay, MotionTokens.settingsSidebarFade)
    // Interaction is enabled only when fully revealed and host allows it.
    readonly property bool interactable: interactive && contentProgress > 0.99

    // Default children are parented below the content background surface.
    default property alias contentData: contentSurface.data
    // Expose internal surfaces for host anchoring and geometry tests.
    readonly property alias headerSurfaceItem: headerSurface
    readonly property alias contentSurfaceItem: contentSurface
    readonly property alias dividerItem: divider

    implicitWidth: Math.max(headerSurface.implicitWidth, contentSurface.implicitWidth)
    implicitHeight: headerSurface.height + divider.height + contentSurface.implicitHeight
    clip: true

    // Header background surface with independent opacity and slide.
    Rectangle {
        id: headerSurface
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: root.headerHeight
        radius: 0
        color: LazerTheme.settingsRail
        border.width: 0
        opacity: root.headerProgress
        transform: Translate { y: -PopupMotion.offset(root.headerProgress, 12) }
    }

    // Thin divider separating header and content surfaces.
    Rectangle {
        id: divider
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: headerSurface.bottom
        height: 1
        color: LazerTheme.divider
    }

    // Content background surface sized by its children with independent motion.
    Rectangle {
        id: contentSurface
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: divider.bottom
        implicitHeight: childrenRect.height
        implicitWidth: childrenRect.width
        height: implicitHeight
        radius: 0
        color: root.contentColor
        border.width: 0
        opacity: root.contentProgress
        enabled: root.interactable
        transform: Translate { y: PopupMotion.offset(root.contentProgress, 14) }
    }
}
