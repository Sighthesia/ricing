import QtQuick

// Arrange transient notifications from the selected screen corner.
Item {
    id: root
    property var popupModel: []
    property bool stackAtTop: true
    readonly property int spacing: 8
    signal popupDismissRequested(var notifId)
    implicitWidth: 360
    implicitHeight: popupList.contentHeight

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
            onDismissRequested: root.popupDismissRequested(model.notifId)
        }
    }
}
