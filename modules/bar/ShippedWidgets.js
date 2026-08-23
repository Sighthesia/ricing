.pragma library

// Widget ids that ship a frontend implementation; registry entries without an
// implementation are skipped so persisted layouts never warn. Shared with the
// bar layout tests so the shipped set cannot silently drift.
var ids = [
    "clock", "tray", "active-window", "workspaces", "brightness",
    "volume", "media", "notifications", "settings", "launcher",
]

function ships(widgetId) {
    return ids.indexOf(widgetId) !== -1
}

// Filter layout entries down to widgets that ship a frontend implementation.
// This is the single authoritative render filter: BarContent delegates here
// and tests exercise this seam directly, so a registry id without an
// implementation can never silently drop a default-layout widget again.
function loadable(entries) {
    var loadable = []
    if (!entries)
        return loadable
    for (var index = 0; index < entries.length; index++) {
        if (ships(entries[index] && entries[index].id))
            loadable.push(entries[index])
    }
    return loadable
}
