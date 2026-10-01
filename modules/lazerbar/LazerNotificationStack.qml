import QtQuick

// Arrange transient notifications from the selected screen corner.
Item {
    id: root
    property var popupModel: []
    property bool stackAtTop: true
    // osu DragContainer pads 3px vertically per card, giving a 6px gap.
    readonly property int spacing: 6
    signal popupDismissRequested(var notifId)
    signal popupActionRequested(var notifId, string identifier)
    implicitWidth: 360
    implicitHeight: popupList.contentHeight

    // The shell's single glow pulse, handed to each card. Injected here so the
    // card and the stack stay free of the services layer.
    property var glowPulse: null
    // Master switch for the pulse, passed through so the card never reads
    // settings itself.
    property bool glowEnabled: true
    // The output the ring is defined against, so every card masks the same ring
    // instead of fitting one to its own box.
    property real screenWidth: 0
    property real screenHeight: 0
    // Where this host's window sits on that output, in screen coordinates.
    property real hostScreenX: 0
    property real hostScreenY: 0
    // This stack's own place on the output, which each card adds its own x/y to.
    // Resolved here rather than in the cards because `mapToGlobal` is a call, not
    // a dependency: a binding over it in a card would keep whatever it first
    // computed, and a card created mid-frame has been seen answering with a
    // stale 0 — which threw the shared ring a whole card's width off it. A card
    // inside a host that never moves can be placed from plain geometry, so this
    // is the one place that has to ask the scene anything, and it asks once the
    // layout has settled.
    property real selfScreenX: 0
    property real selfScreenY: 0

    function latchSelfOnScreen() {
        const point = mapToGlobal(0, 0)
        selfScreenX = root.hostScreenX + Number(point.x)
        selfScreenY = root.hostScreenY + Number(point.y)
    }

    Component.onCompleted: Qt.callLater(latchSelfOnScreen)

    // Re-read whenever a pulse arrives, so a stack whose host window has moved
    // (a re-keyed output, a screen layout change) still places its cards.
    Connections {
        target: root.glowPulse
        function onTokenChanged() { root.latchSelfOnScreen() }
    }

    // The live card at `index`, for diagnostics and tests. The list itself is
    // private, so this is the only way to ask one specific card what it is
    // showing — which is what the two-consecutive-cards case needs.
    function cardAt(index) {
        return popupList.itemAtIndex(index)
    }

    // Play the osu fling exit on one popup without touching the model.
    // Returns false when no live delegate exists for the id.
    function closeAnimated(notifId) {
        for (let i = 0; i < popupList.count; ++i) {
            if (String(popupModel.get(i).notifId) === String(notifId)) {
                const item = popupList.itemAtIndex(i)
                if (item)
                    item.requestClose(true)
                return item !== null
            }
        }
        return false
    }

    // Keep the stack's hit mask limited to visible notification cards.
    ListView {
        id: popupList
        anchors.fill: parent
        model: root.popupModel
        spacing: root.spacing
        interactive: false
        clip: false
        verticalLayoutDirection: root.stackAtTop ? ListView.TopToBottom : ListView.BottomToTop

        add: Transition {
            NumberAnimation { properties: "opacity,scale"; duration: MotionTokens.fast; easing.type: Easing.OutCubic }
        }
        remove: Transition {
            NumberAnimation { property: "opacity"; to: 0; duration: MotionTokens.fast; easing.type: Easing.InCubic }
            NumberAnimation { property: "scale"; to: MotionTokens.reducedMotion ? 1 : 0.96; duration: MotionTokens.fast; easing.type: Easing.InCubic }
        }
        displaced: Transition {
            NumberAnimation { properties: "x,y"; duration: MotionTokens.medium; easing.type: Easing.OutCubic }
        }

        // Render each service entry as an independently dismissible popup.
        // Bind roles explicitly via `model.` — required properties on this
        // delegate silently fail to inject because LazerNotificationPopup
        // already declares appName/summary/body itself.
        delegate: LazerNotificationPopup {
            width: ListView.view.width
            appName: model.appName ?? ""
            summary: model.summary ?? ""
            body: model.body ?? ""
            iconSource: model.icon ?? ""
            actionsText: model.actionsJson ?? ""
            glowPulse: root.glowPulse
            glowEnabled: root.glowEnabled
            glowScreenWidth: root.screenWidth
            glowScreenHeight: root.screenHeight
            glowStackScreenX: root.selfScreenX
            glowStackScreenY: root.selfScreenY
            onDismissRequested: root.popupDismissRequested(model.notifId)
            onActionRequested: identifier => root.popupActionRequested(model.notifId, identifier)
        }
    }
}
