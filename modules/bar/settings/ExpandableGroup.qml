import QtQuick
import qs.config
import qs.services
import ".."

// A collapsible section with an animated expand/collapse toggle.
// Place settings controls as children — they appear below the header when expanded.
//
// Usage:
//   ExpandableGroup {
//     title: "颜色"
//     expanded: true
//     [child items...]
//   }
Item {
    id: root

    property string title: ""
    property bool expanded: true   // user-controlled expanded state
    // Override: set to true from outside (e.g., search) to force the group open
    // without permanently overwriting the user's manual expand/collapse preference.
    property bool forceExpand: false
    property bool filterVisible: true

    readonly property bool _open: expanded || forceExpand
    readonly property int _filterOrder: {
        if (!parent || !parent.children)
            return 0

        for (let index = 0; index < parent.children.length; index++) {
            if (parent.children[index] === root)
                return index
        }

        return 0
    }
    readonly property int _filterDelay: _filterOrder * SettingsService.effectiveAnimation.staggerExitStep

    // Total height: header + (content if open)
    implicitWidth: parent ? parent.width : ThemeSettings.rowWidth
    implicitHeight: header.height + (_open ? contentCol.implicitHeight : 0)
    height: filterVisible ? implicitHeight : 0
    visible: height > 0.5 || filterVisible

    Behavior on implicitHeight {
        NumberAnimation { duration: Theme.anim.moveDuration; easing.type: Theme.anim.moveType }
    }

    Behavior on height {
        SequentialAnimation {
            PauseAnimation { duration: root._filterDelay }
            NumberAnimation { duration: Theme.anim.moveDuration; easing.type: Theme.anim.moveType }
        }
    }

    clip: true

    // ── Header ──────────────────────────────────────────────────────
    Item {
        id: header
        width: parent.width
        height: ThemeSettings.groupHeaderHeight

        // Hover wipe highlight
        HoverRevealHighlight {
            id: headerHighlight
            anchors.fill: parent
            anchors.leftMargin: ThemeSettings.highlightInset
            anchors.rightMargin: ThemeSettings.highlightInset
            radius: ThemeSettings.highlightRadius
            hovered: headerArea.containsMouse
            highlightColor: Colors.surface
            highlightOpacity: 0.6
        }

        // Expand/collapse arrow
        Text {
            id: arrow
            anchors.left: parent.left
            anchors.leftMargin: ThemeSettings.presetSwatchInset
            anchors.verticalCenter: parent.verticalCenter
            text: "\uf105"   // Nerd Font right arrow (›)
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSizeSmall
            color: Colors.textMuted

            rotation: root._open ? 90 : 0
            Behavior on rotation {
                NumberAnimation {
                    duration: Theme.anim.moveDuration
                    easing.type: Theme.anim.moveType
                }
            }
        }

        // Section title
        Text {
            anchors.left: arrow.right
            anchors.leftMargin: ThemeSettings.presetSwatchGap
            anchors.verticalCenter: parent.verticalCenter
            text: root.title
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Font.Medium
            color: root._open ? Colors.text : Colors.textMuted

            Behavior on color { ColorAnimation { duration: Theme.anim.highlightDuration } }
        }

        ClickRipple {
            id: headerRipple
            anchors.fill: parent
            anchors.leftMargin: ThemeSettings.highlightInset
            anchors.rightMargin: ThemeSettings.highlightInset
            radius: ThemeSettings.highlightRadius
            rippleColor: Colors.highlight
        }

        // Click target
        MouseArea {
            id: headerArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: (mouse) => {
                headerRipple.triggerRipple(mouse.x, mouse.y)
                root.expanded = !root.expanded
            }
        }
    }

    // ── Content ──────────────────────────────────────────────────────
    Column {
        id: contentCol
        anchors.top: header.bottom
        width: parent.width
        spacing: 0

        move: Transition {
            NumberAnimation {
                properties: "x,y"
                duration: Theme.anim.moveDuration
                easing.type: Theme.anim.moveType
            }
        }

        // Children of ExpandableGroup are reparented here via default property
    }

    // Reparent all declarative children into contentCol
    default property alias content: contentCol.data

    // External persistent highlight — set to true after scroll-to-section.
    // Cleared by calling clearHighlight() or by the parent calling it externally.
    property bool highlighted: false

    function clearHighlight() {
        highlighted = false
    }

    // Briefly flash the header accent to draw attention after scroll-to-section.
    function flash() { flashAnim.restart() }

    // Persistent highlight overlay (stays on until clearHighlight is called)
    Rectangle {
        anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: ThemeSettings.highlightInset; rightMargin: ThemeSettings.highlightInset }
        height: header.height
        radius: ThemeSettings.highlightRadius
        color: Colors.highlight
        opacity: root.highlighted ? 0.22 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.anim.highlightDuration } }
    }

    // Brief flash overlay (one-shot animation on top of persistent highlight)
    Rectangle {
        id: flashOverlay
        anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: ThemeSettings.highlightInset; rightMargin: ThemeSettings.highlightInset }
        height: header.height
        radius: ThemeSettings.highlightRadius
        color: Colors.highlight
        opacity: 0
        SequentialAnimation {
            id: flashAnim
            NumberAnimation { target: flashOverlay; property: "opacity"; to: 0.28; duration: Math.max(1, Math.round(Theme.anim.highlightDuration * 0.78)) }
            NumberAnimation { target: flashOverlay; property: "opacity"; to: 0; duration: Math.max(1, Math.round(Theme.anim.moveDuration * 1.25)); easing.type: Easing.OutQuad }
        }
    }
}
