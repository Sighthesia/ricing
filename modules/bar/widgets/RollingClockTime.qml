import QtQuick
import "../../lazerbar"

// Shared rolling clock time block ported from the pre-lazer bar (main branch
// RollingClockTime.qml): HH:mm as four RollingDigit strips plus an optional
// seconds pair. Hour digits roll on MotionTokens.slow, minutes on medium,
// seconds on fast, matching the old hour*8 / minute*4 / second*1 weighting.
Item {
    id: root

    property date currentTime: new Date()
    property bool showSeconds: false
    property color digitColor: "white"
    property color mutedDigitColor: "white"
    property color separatorColor: "white"
    property real separatorOpacity: 1.0
    property int digitPixelSize: 15
    property string digitFontFamily: "monospace"
    property bool digitBold: true
    property int digitSpacing: 0

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
                mutedDigitColor: root.mutedDigitColor
                digitPixelSize: root.digitPixelSize
                digitFontFamily: root.digitFontFamily
                digitBold: root.digitBold
                transitionDuration: MotionTokens.slow
            }

            RollingDigit {
                targetDigit: root.hourOnes
                digitColor: root.digitColor
                mutedDigitColor: root.mutedDigitColor
                digitPixelSize: root.digitPixelSize
                digitFontFamily: root.digitFontFamily
                digitBold: root.digitBold
                transitionDuration: MotionTokens.slow
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
                mutedDigitColor: root.mutedDigitColor
                digitPixelSize: root.digitPixelSize
                digitFontFamily: root.digitFontFamily
                digitBold: root.digitBold
                transitionDuration: MotionTokens.medium
            }

            RollingDigit {
                targetDigit: root.minuteOnes
                digitColor: root.digitColor
                mutedDigitColor: root.mutedDigitColor
                digitPixelSize: root.digitPixelSize
                digitFontFamily: root.digitFontFamily
                digitBold: root.digitBold
                transitionDuration: MotionTokens.medium
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
                    mutedDigitColor: root.mutedDigitColor
                    digitPixelSize: root.digitPixelSize
                    digitFontFamily: root.digitFontFamily
                    digitBold: root.digitBold
                    transitionDuration: MotionTokens.fast
                }

                RollingDigit {
                    targetDigit: root.secondOnes
                    digitColor: root.digitColor
                    mutedDigitColor: root.mutedDigitColor
                    digitPixelSize: root.digitPixelSize
                    digitFontFamily: root.digitFontFamily
                    digitBold: root.digitBold
                    transitionDuration: MotionTokens.fast
                }
            }
        }
    }
}
