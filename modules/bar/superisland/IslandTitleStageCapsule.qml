import QtQuick
import qs.config
import qs.services

// Title capsule renderer for window-hint stage slots.
Item {
    id: titleCapsule

    required property Item host
    required property var capsule
    required property real slotPosition
    property bool hiddenForMotion: false
    property real forcedOpacity: -1

    readonly property var _metrics: host._titleMetrics(titleCapsule.slotPosition)
    readonly property real _emphasis: _metrics.emphasis
    readonly property color _fill: host._mixColor(host._secondaryCapsuleFill, host._primaryCapsuleFill, _emphasis)
    readonly property color _textColor: host._mixColor(Colors.textMuted, Colors.text, _emphasis)
    readonly property real _iconOpacity: host._lerp(0.68, 0.92, _emphasis)
    readonly property int _iconSize: Math.round(host._lerp(Math.max(10, host._compactIcon - 1), host._compactIcon, _emphasis))
    readonly property int _elideMode: titleCapsule.slotPosition > 0.25 ? Text.ElideLeft : Text.ElideRight
    readonly property int _horizontalAlignment: titleCapsule.slotPosition > 0.25 ? Text.AlignRight : Text.AlignLeft

    x: _metrics.x
    y: 0
    width: _metrics.width
    height: host._titleCapsuleHeight
    opacity: hiddenForMotion ? 0 : (forcedOpacity >= 0 ? forcedOpacity * _metrics.opacity : (capsule && capsule.visible ? _metrics.opacity : 0))
    visible: capsule !== null && opacity > 0

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: titleCapsule._fill
    }

    Item {
        anchors.fill: parent
        anchors.leftMargin: Theme.barWidget.badgePaddingH * 2
        anchors.rightMargin: Theme.barWidget.badgePaddingH * 2
        clip: true

        Row {
            id: _titleContentRow

            anchors.fill: parent
            spacing: Theme.barWidget.badgePaddingH

            Image {
                id: _titleIcon

                anchors.verticalCenter: parent.verticalCenter
                width: titleCapsule._iconSize
                height: width
                source: titleCapsule.capsule ? (titleCapsule.capsule.icon || "") : ""
                fillMode: Image.PreserveAspectFit
                smooth: true
                visible: source !== ""
                opacity: titleCapsule._iconOpacity
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(0, _titleContentRow.width - (_titleIcon.visible ? _titleIcon.width + _titleContentRow.spacing : 0))
                text: titleCapsule.capsule ? (titleCapsule.capsule.title || "") : ""
                color: titleCapsule._textColor
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                font.bold: titleCapsule._emphasis >= 0.5
                elide: titleCapsule._elideMode
                maximumLineCount: 1
                horizontalAlignment: titleCapsule._horizontalAlignment
                verticalAlignment: Text.AlignVCenter
            }
        }
    }
}
