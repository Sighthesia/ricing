import Quickshell
import QtQuick

// Provides application launch results from XDG desktop entries.
// Uses DesktopEntries.applications — no filesystem scanning needed.
Item {
    id: root

    // Provider interface
    property bool handleSearch: true

    function onOpened(): void {
        // DesktopEntries is always up-to-date; nothing to preload.
    }

    // Returns [{name, description, icon, onActivate}] filtered by text.
    function getResults(text: string): var {
        let results = [];
        let query = text.trim().toLowerCase();
        let apps = DesktopEntries.applications.values;

        for (let i = 0; i < apps.length; i++) {
            let app = apps[i];
            if (app.noDisplay || app.hidden) continue;

            let nameMatch = app.name.toLowerCase().includes(query);
            let descMatch = app.comment ? app.comment.toLowerCase().includes(query) : false;
            if (query !== "" && !nameMatch && !descMatch) continue;

            results.push({
                name:        app.name,
                description: app.comment || app.genericName || "",
                icon:        app.icon    || "application-x-executable",
                onActivate:  (function(a) {
                    // DesktopEntry.execute() is the correct Quickshell API.
                    return function() { a.execute(); };
                })(app)
            });
        }

        // Sort: exact name-start matches first, then alphabetical.
        results.sort(function(a, b) {
            let aStart = a.name.toLowerCase().startsWith(query) ? 0 : 1;
            let bStart = b.name.toLowerCase().startsWith(query) ? 0 : 1;
            if (aStart !== bStart) return aStart - bStart;
            return a.name.localeCompare(b.name);
        });

        return results.slice(0, 50);
    }
}
