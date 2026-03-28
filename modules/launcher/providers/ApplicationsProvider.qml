import Quickshell
import QtQuick

// Provides application launch results from XDG desktop entries.
// Uses DesktopEntries.applications — no filesystem scanning needed.
Item {
    id: root

    // Provider interface
    property bool handleSearch: true

    function _log(message) {
        console.info("[DymicShell:ApplicationsProvider]", message)
    }

    function _applicationEntries(): var {
        const applications = DesktopEntries.applications

        if (!applications) {
            root._log("applications model missing")
            return []
        }

        if (applications.values !== undefined) {
            root._log("using applications.values length=" + applications.values.length)
            return applications.values
        }

        const entries = []
        const count = Number(applications.count) || 0

        root._log("falling back to count/get count=" + count + " hasGet=" + (typeof applications.get === "function"))

        for (let index = 0; index < count; index++) {
            const entry = typeof applications.get === "function"
                ? applications.get(index)
                : null
            if (entry)
                entries.push(entry)
        }

        return entries
    }

    function onOpened(): void {
        root._log("opened")
    }

    // Returns [{name, description, icon, onActivate}] filtered by text.
    function getResults(text: string): var {
        let results = [];
        let query = text.trim().toLowerCase();
        let apps = root._applicationEntries();
        root._log("query='" + query + "' apps=" + apps.length)

        for (let i = 0; i < apps.length; i++) {
            let app = apps[i];
            if (app.noDisplay || app.hidden) continue;

            let nameMatch = app.name.toLowerCase().includes(query);
            let descMatch = app.comment ? app.comment.toLowerCase().includes(query) : false;
            let genericMatch = app.genericName ? app.genericName.toLowerCase().includes(query) : false;
            if (query !== "" && !nameMatch && !descMatch && !genericMatch) continue;

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

        root._log("results=" + results.length)
        return results.slice(0, 50);
    }
}
