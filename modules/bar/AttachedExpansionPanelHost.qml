import QtQuick
import qs.config

// Hosts attached expansion content with reveal clipping while staying layout-detached.
Item {
    id: root

    required property Item anchorItem
    required property bool active
    required property bool collapseTailHidden
    required property bool expanded
    required property real visibleWidth
    required property real visibleHeight
    required property real detachedY
    required property real attachmentOverlap
    required property real revealLift
    required property real revealYOffset
    required property real surfaceOpacity
    required property real surfaceScale
    required property real contentOpacity
    property real throwOffsetY: 0

    default property alias contentData: contentHost.data

    visible: root.active && !root.collapseTailHidden
    enabled: root.active && !root.collapseTailHidden
    width: root.visibleWidth
    height: root.visibleHeight
    y: root.detachedY - root.attachmentOverlap + (root.expanded ? 0 : -root.revealLift) - root.revealYOffset + root.throwOffsetY
    opacity: root.surfaceOpacity
    scale: root.surfaceScale
    clip: true
    anchors.horizontalCenter: root.anchorItem.horizontalCenter
    transformOrigin: Item.Top

    Behavior on opacity {
        NumberAnimation {
            duration: Theme.anim.highlightDuration
            easing.type: Theme.anim.highlightType
        }
    }

    Item {
        id: contentHost
        anchors.fill: parent
        opacity: root.contentOpacity
    }
}
