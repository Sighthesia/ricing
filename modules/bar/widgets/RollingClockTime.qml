import QtQuick

// Shared rolling clock time block ported from the pre-lazer bar (main branch
// RollingClockTime.qml): HH:mm as four RollingDigit strips plus an optional
// seconds pair. Tens digits stay bright, ones digits dim while idle; the bar
// caller drives the pacing with the MotionTokens clock flip tokens.
Item {
    id: root

    property date currentTime: new Date()
    property bool showSeconds: false
    property color digitColor: "white"
    property color mutedDigitColor: "white"
    property color separatorColor: "white"
    property real separatorOpacity: 1.0
    property int digitPixelSize: 14
    property real digitScale: 1.0
    property string digitFontFamily: "monospace"
    property bool digitBold: true
    property int digitSpacing: 0
    property int hourTransitionDuration: 180
    property int minuteTransitionDuration: 180
    property int secondTransitionDuration: 180
    property int transitionEasing: Easing.InOutCubic

    readonly property string hourText: Qt.formatDateTime(root.currentTime, "hh")
    readonly property string minuteText: Qt.formatDateTime(root.currentTime, "mm")
    readonly property string secondText: Qt.formatDateTime(root.currentTime, "ss")
    readonly property int hourTens: Number(root.hourText.charAt(0) || "0")
    readonly property int hourOnes: Number(root.hourText.charAt(1) || "0")
    readonly property int minuteTens: Number(root.minuteText.charAt(0) || "0")
    readonly property int minuteOnes: Number(root.minuteText.charAt(1) || "0")
    readonly property int secondTens: Number(root.secondText.charAt(0) || "0")
    readonly property int secondOnes: Number(root.secondText.charAt(1) || "0")

    implicitWidth: hourGroup.implicitWidth + separator.implicitWidth + minuteGroup.implicitWidth
        + (root.showSeconds ? secondSeparator.implicitWidth + secondDigits.implicitWidth : 0)
        + root.digitSpacing * (root.showSeconds ? 3 : 2)
    implicitHeight: Math.max(hourGroup.implicitHeight, minuteGroup.implicitHeight, secondDigits.implicitHeight)

    // Time row: hour pair, separator, minute pair, optional seconds pair.
    Row {
        id: clockRow
        spacing: root.digitSpacing

        Row {
            id: hourGroup
            spacing: 0

            RollingDigit {
                targetDigit: root.hourTens
                digitColor: root.digitColor
                mutedDigitColor: root.digitColor
                digitPixelSize: root.digitPixelSize
                digitScale: root.digitScale
                digitFontFamily: root.digitFontFamily
                digitBold: root.digitBold
                transitionDuration: root.hourTransitionDuration
                transitionEasing: root.transitionEasing
            }

            RollingDigit {
                targetDigit: root.hourOnes
                digitColor: root.digitColor
                mutedDigitColor: root.mutedDigitColor
                digitPixelSize: root.digitPixelSize
                digitScale: root.digitScale
                digitFontFamily: root.digitFontFamily
                digitBold: root.digitBold
                transitionDuration: root.hourTransitionDuration
                transitionEasing: root.transitionEasing
            }
        }

        Text {
            id: separator
            anchors.verticalCenter: parent.verticalCenter
            text: ":"
            color: root.separatorColor
            opacity: root.separatorOpacity
            font.family: root.digitFontFamily
            font.pixelSize: root.digitPixelSize
            font.bold: root.digitBold
        }

        Row {
            id: minuteGroup
            spacing: 0

            RollingDigit {
                targetDigit: root.minuteTens
                digitColor: root.digitColor
                mutedDigitColor: root.digitColor
                digitPixelSize: root.digitPixelSize
                digitScale: root.digitScale
                digitFontFamily: root.digitFontFamily
                digitBold: root.digitBold
                transitionDuration: root.minuteTransitionDuration
                transitionEasing: root.transitionEasing
            }

            RollingDigit {
                targetDigit: root.minuteOnes
                digitColor: root.digitColor
                mutedDigitColor: root.mutedDigitColor
                digitPixelSize: root.digitPixelSize
                digitScale: root.digitScale
                digitFontFamily: root.digitFontFamily
                digitBold: root.digitBold
                transitionDuration: root.minuteTransitionDuration
                transitionEasing: root.transitionEasing
            }
        }

        Row {
            id: secondGroup
            spacing: 0
            visible: root.showSeconds

            Text {
                id: secondSeparator
                anchors.verticalCenter: parent.verticalCenter
                text: ":"
                color: root.separatorColor
                opacity: root.separatorOpacity
                font.family: root.digitFontFamily
                font.pixelSize: root.digitPixelSize
                font.bold: root.digitBold
            }

            Row {
                id: secondDigits
                spacing: 0

                RollingDigit {
                    targetDigit: root.secondTens
                    digitColor: root.digitColor
                    mutedDigitColor: root.digitColor
                    digitPixelSize: root.digitPixelSize
                    digitScale: root.digitScale
                    digitFontFamily: root.digitFontFamily
                    digitBold: root.digitBold
                    transitionDuration: root.secondTransitionDuration
                    transitionEasing: root.transitionEasing
                }

                RollingDigit {
                    targetDigit: root.secondOnes
                    digitColor: root.digitColor
                    mutedDigitColor: root.mutedDigitColor
                    digitPixelSize: root.digitPixelSize
                    digitScale: root.digitScale
                    digitFontFamily: root.digitFontFamily
                    digitBold: root.digitBold
                    transitionDuration: root.secondTransitionDuration
                    transitionEasing: root.transitionEasing
                }
            }
        }
    }
}
