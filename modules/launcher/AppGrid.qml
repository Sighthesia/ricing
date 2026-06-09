import QtQuick
import Quickshell
import "../../services" as Services

// Searchable application grid with soft add/remove filtering motion.
Item {
    id: root
    anchors.fill: parent

    property string query: Services.LauncherService.query.toLowerCase()
    property var filteredApps: {
        // Force re-evaluation when query changes
        const q = root.query;
        const all = DesktopEntries.applications.values;
        if (!all || all.length === 0) return [];
        const filtered = all.filter(a => {
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
        return filtered.sort((a, b) => {
            const ca = Services.LaunchCountService.getLaunchCount(a.id || "");
            const cb = Services.LaunchCountService.getLaunchCount(b.id || "");
            return cb - ca;
        });
    }

    function launchApp(app) {
        Services.LaunchCountService.recordLaunch(app.id || "");
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

        add: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 180; easing.type: Easing.OutCubic }
                NumberAnimation { property: "scale"; from: 0.94; to: 1; duration: 220; easing.type: Easing.OutCubic }
                NumberAnimation { property: "_filterOffset"; from: 28; to: 0; duration: 220; easing.type: Easing.OutCubic }
                NumberAnimation { property: "_filterSoftness"; from: 1; to: 0; duration: 220; easing.type: Easing.OutCubic }
            }
        }

        remove: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; to: 0; duration: 160; easing.type: Easing.InCubic }
                NumberAnimation { property: "scale"; to: 0.92; duration: 180; easing.type: Easing.InCubic }
                NumberAnimation { property: "_filterOffset"; to: 32; duration: 180; easing.type: Easing.InCubic }
                NumberAnimation { property: "_filterSoftness"; to: 1; duration: 180; easing.type: Easing.InCubic }
            }
        }

        displaced: Transition {
            NumberAnimation { properties: "x,y"; duration: 220; easing.type: Easing.OutCubic }
        }
    }
}
