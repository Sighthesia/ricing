import QtQuick
import qs.config
import "." as SuperIslandParts
import "./SuperIslandWindowHintPresentationAdapter.js" as HintPresentationAdapter

// Crossfades between the hint handoff card and expanded overlay deck content.
Item {
    id: root

    required property bool active
    required property bool overlaySessionActive
    required property bool overlayHintHandoffActive
    required property bool detachedHintActive
    required property bool showOverlayHandoffHint
    required property var hintEvent
    required property var handoffHintEvent

    readonly property real hintPulseOpacity:
        (hintCardLoader.item && hintCardLoader.item._switchPulseOpacity !== undefined)
            ? hintCardLoader.item._switchPulseOpacity
            : 0

    function _resolvedHintEvent() {
        const source = root.overlaySessionActive && root.overlayHintHandoffActive
            ? root.handoffHintEvent
            : root.hintEvent
        return HintPresentationAdapter.resolvedDeckHintEvent(source, root.overlaySessionActive)
    }

    Loader {
        id: hintCardLoader

        property var eventData: root._resolvedHintEvent()

        active: root.active && (root.detachedHintActive || root.overlayHintHandoffActive)
        anchors.fill: parent
        anchors.margins: 1
        opacity: root.overlaySessionActive
            ? (root.showOverlayHandoffHint ? 1 : 0)
            : 1
        sourceComponent: hintCardComponent

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.anim.highlightDuration
                easing.type: Theme.anim.highlightType
            }
        }
    }

    Loader {
        id: overlayDeckLoader

        active: root.active && root.overlaySessionActive
        anchors.fill: parent
        anchors.margins: 1
        opacity: root.overlaySessionActive
            ? (root.showOverlayHandoffHint ? 0 : 1)
            : 0
        sourceComponent: overlayDeckComponent

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.anim.highlightDuration
                easing.type: Theme.anim.highlightType
            }
        }
    }

    Component {
        id: hintCardComponent

        SuperIslandParts.IslandWindowHintCard {
            event: hintCardLoader.eventData
        }
    }

    Component {
        id: overlayDeckComponent

        SuperIslandParts.ExpandedPanelDeck {
            drawSurface: false
        }
    }
}
