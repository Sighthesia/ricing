import QtQuick
import ".."
import "../../lazerbar"
import "../../../services/WidgetSettingsRegistry.js" as WidgetSettingsRegistry

// Two-line clock driven by the clock widget's registry defaults.
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

    implicitWidth: Math.max(timeTextWidth, showDate ? dateTextWidth : 0) + 8
    implicitHeight: LazerTheme.barWidgetHeight
    readonly property real timeTextWidth: timeLabel.implicitWidth
    readonly property real dateTextWidth: dateLabel.implicitWidth

    Timer {
        interval: 10000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.now = new Date()
    }

    Column {
        anchors.centerIn: parent
        spacing: 1

        Text {
            id: timeLabel

            anchors.horizontalCenter: parent.horizontalCenter
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
            color: LazerTheme.textMuted
            font.family: "monospace"
            font.pixelSize: 10
        }
    }

}
