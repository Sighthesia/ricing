import QtQuick
import "../../services" as Services

// Filterable clipboard list with stable full-list model and per-delegate
// filtering to avoid expensive model replacement on every keystroke.
Item {
    id: root

    anchors.fill: parent

    // Hidden prewarm batch: instantiate a small representative set of
    // clipboard rows ahead of the first large search so row text/layout and
    // action subtrees are already warm when many matches are first revealed.
    property int _prewarmCount: 16
    property bool _prewarmArmed: false
    property var _prewarmItems: {
        const all = root.allItems || []
        if (!all || all.length === 0) return []
        return all.slice(0, Math.min(_prewarmCount, all.length))
    }

    // Debounce: avoid rapid filter cycles during fast typing.
    property string _debouncedQuery: Services.LauncherService.query.toLowerCase().trim()

    Timer {
        id: debounceTimer
        interval: 80
        repeat: false
        onTriggered: {
            _debouncedQuery = Services.LauncherService.query.toLowerCase().trim()
        }
    }

    Connections {
        target: Services.LauncherService
        function onQueryChanged() {
            debounceTimer.restart()
        }
    }

    Component.onCompleted: {
        Services.ClipboardService.list()
        prewarmTimer.start()
    }

    Timer {
        id: prewarmTimer
        interval: 0
        repeat: false
        onTriggered: root._prewarmArmed = true
    }

    // Stable model: full clipboard items list.
    // Does not change on query so ListView avoids add/remove cycles.
    property var allItems: Services.ClipboardService.items || []

    ListView {
        anchors.fill: parent
        anchors.margins: 8
        clip: true
        spacing: 4
        model: root.allItems
        delegate: ClipboardDelegate {
            query: root._debouncedQuery
        }

        displaced: Transition {
            NumberAnimation { properties: "x,y"; duration: 200; easing.type: Easing.OutCubic }
        }
    }

    Item {
        visible: false
        opacity: 0
        x: -10000
        y: -10000

        Repeater {
            model: root._prewarmArmed ? root._prewarmItems : []
            delegate: ClipboardDelegate {
                query: ""
            }
        }
    }
}
