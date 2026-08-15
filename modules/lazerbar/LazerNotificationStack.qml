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
        delegate: LazerNotificationPopup {
            required property var notifId
            required property string appName
            required property string summary
            required property string body
            required property string icon
            width: ListView.view.width
            iconSource: icon
            onDismissRequested: root.popupDismissRequested(notifId)
        }
    }
}
