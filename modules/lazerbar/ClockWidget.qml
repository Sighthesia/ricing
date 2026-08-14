import QtQuick
import "LazerBarLogic.js" as Logic

// Show local time and real Linux system uptime.
Item {
    id: root
    property bool testMode: false
    property string testUptimeText: ""
    property string currentTimeText: "00:00:00"
    property string uptimeText: "已运行 --:--:--"
    implicitWidth: content.implicitWidth
    implicitHeight: 34

    function applyUptime(text) {
        var seconds = Logic.parseUptime(text)
        uptimeText = seconds >= 0 ? "已运行 " + Logic.formatDuration(seconds) : "已运行 --:--:--"
    }
    function refresh() {
        currentTimeText = Qt.formatTime(new Date(), "hh:mm:ss")
        if (testMode) applyUptime(testUptimeText)
        else {
            var request = new XMLHttpRequest()
            request.onreadystatechange = function() {
                if (request.readyState === XMLHttpRequest.DONE)
                    root.applyUptime(request.status === 0 || request.status === 200 ? request.responseText : "")
            }
            request.open("GET", "file:///proc/uptime")
            request.send()
        }
    }
    Timer { interval: 1000; repeat: true; running: true; triggeredOnStart: true; onTriggered: root.refresh() }

    Row {
        id: content
        spacing: 8
        anchors.verticalCenter: parent.verticalCenter
        Item {
            width: 24; height: 24
            Image { anchors.fill: parent; source: "icons/clock.svg"; opacity: 0.9 }
            Rectangle { width: 2; height: 7; radius: 1; color: LazerTheme.osuPink; anchors.centerIn: parent; anchors.verticalCenterOffset: -3 }
        }
        Column {
            spacing: 0
            Text { text: root.currentTimeText; color: LazerTheme.textPrimary; font.family: "monospace"; font.pixelSize: 13 }
            Text { text: root.uptimeText; color: LazerTheme.osuPink; font.family: "monospace"; font.pixelSize: 9 }
        }
    }
}
