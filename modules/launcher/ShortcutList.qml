import QtQuick
import "../../services" as Services

// Filterable list of niri shortcuts from binds.kdl.
Item {
    anchors.fill: parent

    property string filterText: {
        let q = Services.LauncherService.query
        return q.startsWith(">key ") ? q.slice(5) : q
    }

    ListView {
        anchors.fill: parent
        anchors.margins: 8
        clip: true
        spacing: 4
        model: Services.NiriShortcutService.shortcutsModel
        delegate: ShortcutDelegate {
            visible: {
                if (!filterText) return true
                let lower = filterText.toLowerCase()
                return model.label.toLowerCase().includes(lower)
                    || model.sequence.toLowerCase().includes(lower)
                    || model.category.toLowerCase().includes(lower)
            }
            height: visible ? 52 : 0
        }
    }

    // Status/error footer
    Text {
        anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter; bottomMargin: 8 }
        text: Services.NiriShortcutService.errorText || Services.NiriShortcutService.statusText
        color: Services.NiriShortcutService.errorText ? "#ff6666" : "#aaaaaa"
        font.pixelSize: 11
    }
}
