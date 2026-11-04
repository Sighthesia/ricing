import QtQuick
import "../../lazerbar" as Lazer

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
    property int digitWeight: Font.Bold
    property int digitSpacing: 0
    property int hourTransitionDuration: 180
    property int minuteTransitionDuration: 180
    property int secondTransitionDuration: 180
    property int transitionEasing: Easing.InOutCubic

    Behavior on digitColor {
        enabled: !Lazer.MotionTokens.reducedMotion
        ColorAnimation { duration: Lazer.MotionTokens.medium }
    }
    Behavior on mutedDigitColor {
        enabled: !Lazer.MotionTokens.reducedMotion
        ColorAnimation { duration: Lazer.MotionTokens.medium }
    }
    Behavior on separatorColor {
        enabled: !Lazer.MotionTokens.reducedMotion
        ColorAnimation { duration: Lazer.MotionTokens.medium }
    }

    readonly property string hourText: Qt.formatDateTime(root.currentTime, "hh")
    readonly property string minuteText: Qt.formatDateTime(root.currentTime, "mm")
    readonly property string secondText: Qt.formatDateTime(root.currentTime, "ss")
    readonly property int hourTens: Number(root.hourText.charAt(0) || "0")
    readonly property int hourOnes: Number(root.hourText.charAt(1) || "0")
    readonly property int minuteTens: Number(root.minuteText.charAt(0) || "0")
    readonly property int minuteOnes: Number(root.minuteText.charAt(1) || "0")
    readonly property int secondTens: Number(root.secondText.charAt(0) || "0")
    readonly property int secondOnes: Number(root.secondText.charAt(1) || "0")

    // The seconds pair is measured rather than gated on `showSeconds`: its width
    // is animated (see `secondsReveal`), so the implicit width has to keep
    // tracking the row while the pair is still on its way out.
    implicitWidth: hourGroup.implicitWidth + separator.implicitWidth + minuteGroup.implicitWidth
        + secondsReveal.implicitWidth + root.digitSpacing * 2
    implicitHeight: Math.max(hourGroup.implicitHeight, minuteGroup.implicitHeight, secondDigits.implicitHeight)

    // The pair sits as the last child of the time row and slides open and shut
    // over `showSeconds` instead of appearing and vanishing. Callers (the bar
    // clock's top-of-hour window) toggle the pair once an hour, so a hard cut
    // would read as the clock snapping wider. The Row places it by its animated
    // width, so it trails the minute pair while the box opens; the ink inside is
    // laid out at full width and wiped in by `clip`, never repositioned. The
    // box is as tall as the row, so `clip` only ever bites on the horizontal
    // axis it is there for.

    // Ink box of the digits actually drawn, in this item's coordinates. The
    // strip a digit rolls inside is taller than the glyphs it shows (the roll
    // needs over- and underscan so a mid-transition frame never clips), so a
    // caller stacking a second line underneath cannot use this item's height as
    // the distance to its own text: it has to ask where the ink ends instead.
    readonly property real digitInkTop: root._digitBaseline + _digitInk.tightBoundingRect.top
    readonly property real digitInkBottom: root._digitBaseline + _digitInk.tightBoundingRect.bottom
    readonly property real _digitBaseline: (root.implicitHeight - _digitFont.height) / 2
        + _digitFont.ascent

    FontMetrics {
        id: _digitFont
        font.family: root.digitFontFamily
        font.pixelSize: root.digitPixelSize
        font.weight: root.digitWeight
    }

    // The widest digit set, so the measured ink covers every numeral.
    TextMetrics {
        id: _digitInk
        font.family: root.digitFontFamily
        font.pixelSize: root.digitPixelSize
        font.weight: root.digitWeight
        text: "0123456789"
    }

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
                digitWeight: root.digitWeight
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
                digitWeight: root.digitWeight
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
            font.weight: root.digitWeight
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
                digitWeight: root.digitWeight
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
                digitWeight: root.digitWeight
                transitionDuration: root.minuteTransitionDuration
                transitionEasing: root.transitionEasing
            }
        }
    }

    // Seconds reveal box: sibling of the row, not a child of it. Positioners
    // exclude zero-width children from layout and never re-layout them when
    // the width comes back, so a closed reveal placed inside the Row stayed
    // parked at x=0 with its ink painted over the hour digits (seen in the
    // calendar popup). Anchored by hand to the minute pair's trailing edge
    // instead; the Row sits at 0,0, so its children's coordinates are this
    // item's coordinates. Its ink is always laid out at full width inside, so
    // opening reads as a wipe, never a slide of the digits themselves.
    Item {
        id: secondsReveal

        x: minuteGroup.x + minuteGroup.width + root.digitSpacing
        implicitWidth: root.showSeconds
            ? secondSeparator.implicitWidth + secondDigits.implicitWidth + root.digitSpacing
            : 0
        width: implicitWidth
        height: root.implicitHeight
        clip: true

        Behavior on implicitWidth {
            enabled: !Lazer.MotionTokens.reducedMotion
            NumberAnimation { duration: Lazer.MotionTokens.medium; easing.type: Easing.OutQuad }
        }

        Row {
            id: secondGroup
            spacing: 0
            anchors.verticalCenter: parent.verticalCenter

            Text {
                id: secondSeparator
                anchors.verticalCenter: parent.verticalCenter
                text: ":"
                color: root.separatorColor
                opacity: root.separatorOpacity
                font.family: root.digitFontFamily
                font.pixelSize: root.digitPixelSize
                font.weight: root.digitWeight
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
                    digitWeight: root.digitWeight
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
                    digitWeight: root.digitWeight
                    transitionDuration: root.secondTransitionDuration
                    transitionEasing: root.transitionEasing
                }
            }
        }
    }
}
