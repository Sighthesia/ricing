import QtQuick
import Quickshell
import "../../../services" as Services

// Shared rolling clock time block: HH:mm as four rolling digits.
Item {
    id: root

    property date currentTime: new Date()
    property color hourMutedColor: Services.Color.mOnSurfaceVariant
    property color hourColor: Services.Color.mOnSurface
    property color minuteMutedColor: Services.Color.mOnSurfaceVariant
    property color minuteColor: Services.Color.mOnSurface
    property int digitPixelSize: Services.TextSize.barContent
    property real digitScale: 1.0
    property string digitFontFamily: ""
    property int digitSpacing: 0
    property int separatorWidth: 0
    property int separatorHeight: 0
    property color separatorColor: minuteColor
    property real separatorOpacity: 0.3
    property string separatorText: ":"

    readonly property string hourText: Qt.formatDateTime(root.currentTime, "hh")
    readonly property string minuteText: Qt.formatDateTime(root.currentTime, "mm")
    readonly property int hourTens: Number(root.hourText.charAt(0) || "0")
    readonly property int hourOnes: Number(root.hourText.charAt(1) || "0")
    readonly property int minuteTens: Number(root.minuteText.charAt(0) || "0")
    readonly property int minuteOnes: Number(root.minuteText.charAt(1) || "0")

    implicitWidth: hourGroup.implicitWidth + separator.width + minuteGroup.implicitWidth + root.digitSpacing * 2
    implicitHeight: Math.max(hourGroup.implicitHeight, minuteGroup.implicitHeight)

    Row {
        id: clockRow
        anchors.centerIn: parent
        spacing: root.digitSpacing

        Row {
            id: hourGroup
            spacing: 0

            RollingDigit {
                targetDigit: root.hourTens
                digitColor: root.hourMutedColor
                mutedDigitColor: root.hourMutedColor
                digitPixelSize: root.digitPixelSize
                digitScale: root.digitScale
                digitFontFamily: root.digitFontFamily
            }

            RollingDigit {
                targetDigit: root.hourOnes
                digitColor: root.hourColor
                mutedDigitColor: root.hourMutedColor
                digitPixelSize: root.digitPixelSize
                digitScale: root.digitScale
                digitFontFamily: root.digitFontFamily
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
                digitColor: root.minuteMutedColor
                mutedDigitColor: root.minuteMutedColor
                digitPixelSize: root.digitPixelSize
                digitScale: root.digitScale
                digitFontFamily: root.digitFontFamily
            }

            RollingDigit {
                targetDigit: root.minuteOnes
                digitColor: root.minuteColor
                mutedDigitColor: root.minuteMutedColor
                digitPixelSize: root.digitPixelSize
                digitScale: root.digitScale
                digitFontFamily: root.digitFontFamily
            }
        }
    }
}
