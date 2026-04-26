import QtQuick
import qs.config

// Renders the title capsules for the window-hint presentations.
Item {
    id: root

    required property Item card
    property real revealProgress: 1

    implicitWidth: _capsuleRow.implicitWidth
    implicitHeight: root.card._barExpandedTitleCapsuleHeight
    width: implicitWidth
    height: implicitHeight

    // Title capsules stay centered while the host reveal progresses.
    Row {
        id: _capsuleRow

        anchors.centerIn: parent
        spacing: root.card._capsuleGap

        // One capsule maps directly to one window title.
        Repeater {
            model: root.card._hint.windows || []

            // Title capsule wrapper preserves the per-window reveal motion.
            delegate: Item {
                required property int index
                required property var modelData

                readonly property bool _focused: index === root.card._hint.currentIndex
                readonly property string _titleText: modelData ? (modelData.title || "") : ""
                readonly property string _iconSource: modelData ? (modelData.icon || "") : ""
                readonly property real _titleMeasuredWidth: _titleMeasurer.paintedWidth
                readonly property real _iconContentWidth:
                    _iconSource !== "" ? root.card._compactIcon + Theme.barWidget.badgePaddingH : 0
                readonly property real _minimumCapsuleWidth:
                    root.card._padH * 2 + Math.max(root.card._compactIcon, Math.round(Theme.fontSizeSmall * 2.6))
                readonly property real _maximumCapsuleWidth:
                    _focused ? root.card._titlePrimaryWidth : root.card._titleSideWidth

                implicitWidth: Math.max(
                    _minimumCapsuleWidth,
                    Math.min(
                        _maximumCapsuleWidth,
                        root.card._padH * 2 + _iconContentWidth + _titleMeasuredWidth
                    )
                )
                implicitHeight: root.card._barExpandedTitleCapsuleHeight
                width: implicitWidth
                height: implicitHeight
                y: (1 - root.revealProgress) * Math.max(6, Theme.barWidget.contentPaddingV * 1.5)
                scale: 0.96 + root.revealProgress * 0.04

                // Lift the capsule into place without changing its width contract.
                Behavior on y {
                    NumberAnimation {
                        duration: Theme.anim.moveDuration
                        easing.type: Theme.anim.moveType
                    }
                }

                // Restore full scale as the reveal settles.
                Behavior on scale {
                    NumberAnimation {
                        duration: Theme.anim.highlightDuration
                        easing.type: Theme.anim.highlightType
                    }
                }

                // Hidden measurer keeps the text width aligned with the rendered title.
                Text {
                    id: _titleMeasurer

                    text: _titleText !== "" ? _titleText : " "
                    wrapMode: Text.NoWrap
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    font.bold: _focused
                    opacity: 0
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                }

                // Capsule backdrop mirrors the current focus state.
                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: root.card._mixColor(root.card._secondaryCapsuleFill, root.card._primaryCapsuleFill, _focused ? 1 : 0.25)
                }

                // Capsule content keeps icon and title clipped to the rounded shape.
                Item {
                    anchors.fill: parent
                    anchors.leftMargin: root.card._padH
                    anchors.rightMargin: root.card._padH
                    clip: true

                    // Title capsule row keeps icon and text on one line.
                    Row {
                        anchors.fill: parent
                        spacing: Theme.barWidget.badgePaddingH

                        // Optional icon follows the title text.
                        Image {
                            anchors.verticalCenter: parent.verticalCenter
                            width: root.card._compactIcon
                            height: width
                            source: _iconSource
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            visible: source !== ""
                        }

                        // Title text trims to the available capsule width.
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.max(0, parent.width - (_iconSource !== "" ? root.card._compactIcon + Theme.barWidget.badgePaddingH : 0))
                            text: _titleText
                            color: Colors.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            font.bold: _focused
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }
            }
        }
    }
}
