import QtQuick
import Quickshell
import "../../../services" as Services

// Shared rolling clock time block: HH:mm as four rolling digits.
Item {
    id: root

    property date currentTime: new Date()
    property bool showSeconds: false
    property color hourMutedColor: Services.Color.mOnSurfaceVariant
    property color hourColor: Services.Color.mOnSurface
    property color minuteMutedColor: Services.Color.mOnSurfaceVariant
    property color minuteColor: Services.Color.mOnSurface
    property color secondMutedColor: minuteMutedColor
    property color secondColor: minuteColor
    property int digitPixelSize: Services.TextSize.barContent
    property real digitScale: 1.0
    property string digitFontFamily: ""
    property int digitSpacing: 0
    property int separatorWidth: 0
    property int separatorHeight: 0
    property color separatorColor: minuteColor
    property real separatorOpacity: 1.0
    property string separatorText: ":"
    property color secondSeparatorColor: separatorColor
    property real secondSeparatorOpacity: separatorOpacity
    property string secondSeparatorText: ":"
    property int hourTransitionDuration: 180
    property int minuteTransitionDuration: 180
    property int secondTransitionDuration: 180
    property var transitionEasing: Easing.InOutCubic

    readonly property string hourText: Qt.formatDateTime(root.currentTime, "hh")
    readonly property string minuteText: Qt.formatDateTime(root.currentTime, "mm")
    readonly property string secondText: Qt.formatDateTime(root.currentTime, "ss")
    readonly property int hourTens: Number(root.hourText.charAt(0) || "0")
    readonly property int hourOnes: Number(root.hourText.charAt(1) || "0")
    readonly property int minuteTens: Number(root.minuteText.charAt(0) || "0")
    readonly property int minuteOnes: Number(root.minuteText.charAt(1) || "0")
    readonly property int secondTens: Number(root.secondText.charAt(0) || "0")
    readonly property int secondOnes: Number(root.secondText.charAt(1) || "0")

    implicitWidth: hourGroup.implicitWidth + separator.width + minuteGroup.implicitWidth + (root.showSeconds ? secondSeparator.width + secondGroup.implicitWidth : 0) + root.digitSpacing * (root.showSeconds ? 4 : 2)
    implicitHeight: Math.max(hourGroup.implicitHeight, minuteGroup.implicitHeight, secondGroup.implicitHeight)

    Row {
        id: clockRow
        anchors.centerIn: parent
        spacing: root.digitSpacing

        Row {
            id: hourGroup
            spacing: 0

            RollingDigit {
                targetDigit: root.hourTens
                digitColor: root.hourColor
                mutedDigitColor: root.hourColor
                digitPixelSize: root.digitPixelSize
                digitScale: root.digitScale
                digitFontFamily: root.digitFontFamily
                transitionDuration: root.hourTransitionDuration
                transitionEasing: root.transitionEasing
            }

            RollingDigit {
                targetDigit: root.hourOnes
                digitColor: root.hourColor
                mutedDigitColor: root.hourMutedColor
                digitPixelSize: root.digitPixelSize
                digitScale: root.digitScale
                digitFontFamily: root.digitFontFamily
                transitionDuration: root.hourTransitionDuration
                transitionEasing: root.transitionEasing
            }
        }

        Services.FluidText {
            id: separator
            anchors.verticalCenter: parent.verticalCenter
            text: root.separatorText
            color: root.separatorColor
            opacity: root.separatorOpacity
            basePixelSize: root.digitPixelSize
            font.bold: true
            visible: root.separatorText !== ""
        }

        Row {
            id: minuteGroup
            spacing: 0

            RollingDigit {
                targetDigit: root.minuteTens
                digitColor: root.minuteColor
                mutedDigitColor: root.minuteColor
                digitPixelSize: root.digitPixelSize
                digitScale: root.digitScale
                digitFontFamily: root.digitFontFamily
                transitionDuration: root.minuteTransitionDuration
                transitionEasing: root.transitionEasing
            }

            RollingDigit {
                targetDigit: root.minuteOnes
                digitColor: root.minuteColor
                mutedDigitColor: root.minuteMutedColor
                digitPixelSize: root.digitPixelSize
                digitScale: root.digitScale
                digitFontFamily: root.digitFontFamily
                transitionDuration: root.minuteTransitionDuration
                transitionEasing: root.transitionEasing
            }
        }

        Row {
            id: secondGroup
            spacing: 0
            visible: root.showSeconds

            Services.FluidText {
                id: secondSeparator
                anchors.verticalCenter: parent.verticalCenter
                text: root.secondSeparatorText
                color: root.secondSeparatorColor
                opacity: root.secondSeparatorOpacity
                basePixelSize: root.digitPixelSize
                font.bold: true
                visible: root.showSeconds && root.secondSeparatorText !== ""
            }

            RollingDigit {
                targetDigit: root.secondTens
                digitColor: root.secondColor
                mutedDigitColor: root.secondColor
                digitPixelSize: root.digitPixelSize
                digitScale: root.digitScale
                digitFontFamily: root.digitFontFamily
                transitionDuration: root.secondTransitionDuration
                transitionEasing: root.transitionEasing
            }

            RollingDigit {
                targetDigit: root.secondOnes
                digitColor: root.secondColor
                mutedDigitColor: root.secondMutedColor
                digitPixelSize: root.digitPixelSize
                digitScale: root.digitScale
                digitFontFamily: root.digitFontFamily
                transitionDuration: root.secondTransitionDuration
                transitionEasing: root.transitionEasing
            }
        }
    }
}
