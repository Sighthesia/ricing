import QtQuick
import "LazerBarLogic.js" as Logic

// Retain the highest-priority utilities as horizontal space contracts.
Item {
    id: root
    property real availableWidth: 1000
    property bool musicActive: false
    property alias musicButtonItem: musicButton
    signal musicOverlayRequested(bool open)
    signal musicTooltipRequested(bool visible)
    signal routeRequested(string route, Item opener)
    readonly property var visibleIds: Logic.visibleUtilityIds(availableWidth, LazerTheme.targetSize, LazerTheme.groupGap)
    readonly property var entries: [
        { id: "news", name: "News", source: "icons/news.svg" },
        { id: "changelog", name: "Changelog", source: "icons/code.svg" },
        { id: "wiki", name: "Wiki", source: "icons/book.svg" },
        { id: "ranking", name: "Ranking", source: "icons/podium.svg" },
        { id: "library", name: "Beatmap library", source: "icons/library.svg" },
        { id: "chat", name: "Chat", source: "icons/chat.svg" },
        { id: "community", name: "Community", source: "icons/globe.svg" }
    ]
    implicitWidth: row.implicitWidth
    implicitHeight: LazerTheme.barHeight

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: LazerTheme.groupGap
        Repeater {
            model: root.entries
            delegate: IconButton {
                required property var modelData
                visible: root.visibleIds.indexOf(modelData.id) >= 0
                opacity: visible ? 1 : 0
                source: modelData.source
                accessibleName: modelData.name
                Behavior on opacity { NumberAnimation { duration: MotionTokens.fast } }
                onClicked: root.routeRequested(modelData.id === "library" ? "beatmap" : modelData.id === "wiki" ? "wiki" : modelData.id === "news" ? "news" : "", this)
            }
        }
        Rectangle { visible: root.visibleIds.indexOf("music") >= 0; width: visible ? 1 : 0; height: 22; anchors.verticalCenter: parent.verticalCenter; color: LazerTheme.divider
            Behavior on width { NumberAnimation { duration: MotionTokens.fast } }
        }
        OsuTopBarButton {
            id: musicButton
            visible: root.visibleIds.indexOf("music") >= 0
            iconSource: "icons/music.svg"
            titleText: "音乐播放器"
            subtitleText: "播放控制"
            isActive: root.musicActive
            onClicked: root.musicOverlayRequested(!root.musicActive)
            onTooltipRequestedChanged: root.musicTooltipRequested(tooltipRequested)
        }
    }
}
