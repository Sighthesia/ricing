import QtQuick
import Quickshell
import "../../services" as Services

Item {
    id: root
    anchors.fill: parent

    property string query: Services.LauncherService.query.toLowerCase()
    property var filteredApps: {
        // Force re-evaluation when query changes
        const q = root.query;
        const all = DesktopEntries.applications.values;
        if (!all || all.length === 0) return [];
        return all.filter(a => {
            if (!q) return true;
            const name = (a.name || "").toLowerCase();
            const comment = (a.comment || "").toLowerCase();
            const genericName = (a.genericName || "").toLowerCase();
            const id = (a.id || "").toLowerCase();
            const keywords = (a.keywords || []).join(" ").toLowerCase();
            return name.includes(q) || comment.includes(q)
                || genericName.includes(q) || id.includes(q)
                || keywords.includes(q);
        });
    }

    function launchApp(app) {
        app.execute();
        Services.LauncherService.close();
    }

    GridView {
        id: grid
        anchors { fill: parent; margins: 8 }
        cellWidth: 120
        cellHeight: 110
        clip: true
        model: root.filteredApps
        delegate: AppGridDelegate {}
        focus: true
        Keys.onReturnPressed: if (currentItem) launchApp(currentItem.modelData)
    }
}
