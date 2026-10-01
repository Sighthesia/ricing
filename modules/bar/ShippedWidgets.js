.pragma library

// Widget ids that ship a frontend implementation; registry entries without an
// implementation are skipped so persisted layouts never warn. Shared with the
// bar layout tests so the shipped set cannot silently drift.
var ids = [
    "clock", "tray", "active-window", "workspaces", "brightness",
    "volume", "media", "notifications", "settings", "launcher",
    "battery", "bluetooth", "network",
]

function ships(widgetId) {
    return ids.indexOf(widgetId) !== -1
}

// Startup activation batch for a widget id. Batch 0 is the time-critical
// chrome (clock, active window), batch 1 the interactive core (workspaces,
// media, tray), and batch 2 everything else. Unknown ids land in the last
// batch so an unregistered entry can never stall an earlier one.
function startupBatch(widgetId) {
    if (widgetId === "clock" || widgetId === "active-window")
        return 0
    if (widgetId === "workspaces" || widgetId === "media" || widgetId === "tray")
        return 1
    return 2
}

// Total number of startup batches, derived from the classification above:
// one more than the highest batch any shipped id lands in, so adding a
// batch to startupBatch automatically extends the count BarContent binds.
var startupBatchCount = (function() {
    var highest = 0
    for (var index = 0; index < ids.length; index++) {
        var batch = startupBatch(ids[index])
        if (batch > highest)
            highest = batch
    }
    return highest + 1
})()

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
