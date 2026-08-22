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
            onDismissRequested: root.popupDismissRequested(model.notifId)
            onActionRequested: identifier => root.popupActionRequested(model.notifId, identifier)
        }
    }
}
