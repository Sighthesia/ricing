import QtQuick
import ".."
import "../../lazerbar"
import "./" as ClockParts
import "../../../services/WidgetSettingsRegistry.js" as WidgetSettingsRegistry

// Two-line clock driven by the clock widget's registry defaults. The time
// line uses the pre-lazer rolling-digit strips so digits flip on change;
// the date line stays static text.
Item {
    id: root

    // Widget identity contract filled by the layout loader.
    property string widgetId: ""
    property string instanceKey: ""
    property string section: ""
    property string screenName: ""

    readonly property var defaults: WidgetSettingsRegistry.defaults("clock")
    readonly property bool showDate: defaults.showDate !== false
    readonly property string formatParts:
        typeof defaults.timeFormat === "string" ? defaults.timeFormat : "yyyy.MM.dd|HH:mm"
    readonly property string timeFormat: {
        var parts = root.formatParts.split("|")
        return parts.length > 1 ? parts[1] : "HH:mm"
    }
    readonly property string dateFormat: {
        var parts = root.formatParts.split("|")
        return parts.length > 0 ? parts[0] : "yyyy.MM.dd"
    }
    property date now: new Date()
    readonly property string timeText: Qt.formatTime(root.now, root.timeFormat)
    readonly property string dateText: Qt.formatDate(root.now, root.dateFormat)
    // Rolling strips only model HH:mm[:ss]; fall back to static text for
    // exotic formats, otherwise show the seconds pair when configured.
    readonly property bool useRollingDigits: root.timeFormat === "HH:mm" || root.timeFormat === "hh:mm"
        || root.timeFormat === "HH:mm:ss" || root.timeFormat === "hh:mm:ss"
    readonly property bool showSeconds: root.timeFormat.indexOf("s") >= 0

    implicitWidth: Math.max(timeSlotWidth, showDate ? dateTextWidth : 0) + 8
    implicitHeight: LazerTheme.barWidgetHeight
    readonly property real timeSlotWidth: useRollingDigits ? rollingTime.implicitWidth : timeLabel.implicitWidth
    readonly property real dateTextWidth: dateLabel.implicitWidth

    // Poll every second so minute flips land on time; cheap for two labels.
    Timer {
        interval: 1000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.now = new Date()
    }

    Column {
        anchors.centerIn: parent
        spacing: 1

        // Time line: rolling digit strips with the flip transition.
        ClockParts.RollingClockTime {
            id: rollingTime

            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.useRollingDigits
            currentTime: root.now
            showSeconds: root.showSeconds
            digitPixelSize: 15
            digitFontFamily: "monospace"
            digitBold: true
            digitColor: LazerTheme.textPrimary
            mutedDigitColor: LazerTheme.textPrimary
            separatorColor: LazerTheme.textPrimary
        }

        Text {
            id: timeLabel

            anchors.horizontalCenter: parent.horizontalCenter
            visible: !root.useRollingDigits
            text: root.timeText
            color: LazerTheme.textPrimary
            font.family: "monospace"
            font.pixelSize: 15
            font.bold: true
        }

        Text {
            id: dateLabel

            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.showDate
            text: root.dateText
            color: LazerTheme.barSubtitle
            font.family: "monospace"
            font.pixelSize: 10
        }
    }

}
