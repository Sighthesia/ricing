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
