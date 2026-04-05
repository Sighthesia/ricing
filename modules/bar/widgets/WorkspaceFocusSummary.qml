import QtQuick
import qs.config

// Focus-mode summary row showing the active app icon and title.
Item {
    id: root
    objectName: "workspaceFocusRow"

    required property string focusedWindowId
    required property string focusedAppId
    required property string focusedTitle
    required property int iconSize
    required property int iconTitleGap
    required property int focusPulsePad
    required property int titleMaxWidth
    required property real flashScale
    required property bool flashActive
    required property bool showOverview
    required property var iconPathProvider

    property real pulseOpacity: 0

    implicitWidth: _focusContent.implicitWidth
    implicitHeight: _focusContent.implicitHeight
    width: implicitWidth
    height: implicitHeight
    clip: false
    scale: root.flashActive ? root.flashScale : 1.0
    opacity: root.flashActive ? 0.6 : (root.showOverview ? 0 : 1)

    Rectangle {
        x: -root.focusPulsePad
        y: -root.focusPulsePad
        width: parent.width + root.focusPulsePad * 2
        height: parent.height + root.focusPulsePad * 2
        radius: height / 2
        color: Colors.highlight
        opacity: root.pulseOpacity
    }

    Behavior on scale {
        NumberAnimation {
            duration: Theme.anim.moveDuration
            easing.type: Theme.anim.moveType
        }
    }

    Behavior on opacity {
        NumberAnimation {
            duration: Theme.anim.moveDuration
            easing.type: Theme.anim.moveType
        }
    }

    Row {
        id: _focusContent

        anchors.centerIn: parent
        spacing: root.iconTitleGap

        Image {
            visible: root.focusedAppId.length > 0
            width: visible ? root.iconSize : 0
            height: root.iconSize
            anchors.verticalCenter: parent.verticalCenter
            source: root.iconPathProvider ? root.iconPathProvider(root.focusedAppId) : ""
            smooth: true
            fillMode: Image.PreserveAspectFit
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, root.titleMaxWidth)
            text: root.focusedTitle
            elide: Text.ElideRight
            maximumLineCount: 1
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeBody
            color: Colors.text
        }
    }

    function triggerFocusChangePulse() {
        if (root.focusedWindowId.length === 0 || root.focusedTitle.length === 0)
            return
        if (root.opacity <= 0)
            return

        _focusPulseAnim.stop()
        root.pulseOpacity = 0
        _focusPulseAnim.start()
    }

    SequentialAnimation {
        id: _focusPulseAnim

        NumberAnimation {
            target: root
            property: "pulseOpacity"
            from: 0
            to: 0.16
            duration: Theme.anim.highlightDuration
            easing.type: Theme.anim.highlightType
        }

        NumberAnimation {
            target: root
            property: "pulseOpacity"
            to: 0
            duration: Theme.anim.moveDuration
            easing.type: Theme.anim.moveType
        }
    }
}
