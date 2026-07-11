.pragma library

// Lightweight settings-entry search index for the island overview launcher.
// Provides searchable entries that match setting labels and categories
// against the user's query. Each entry maps to a settings-center navigation
// target. Out-of-scope: full-text indexing of all settings content.

var settingsEntries = [
    // ── Bar ──
    { label: "Bar Height", category: "Bar", description: "Status bar height in pixels", targetCategory: "bar" },
    { label: "Bar Position", category: "Bar", description: "Top or bottom placement", targetCategory: "bar" },
    { label: "Floating", category: "Bar", description: "Enable floating bar mode", targetCategory: "bar" },
    { label: "Floating Margin", category: "Bar", description: "Edge margin when floating", targetCategory: "bar" },
    { label: "Corner Radius", category: "Bar", description: "Bar corner rounding", targetCategory: "bar" },

    // ── Appearance ──
    { label: "Wallpaper Path", category: "Appearance", description: "Custom wallpaper image path", targetCategory: "appearance" },
    { label: "Color Scheme", category: "Appearance", description: "Auto, dark, or light mode", targetCategory: "appearance" },
    { label: "Panel Opacity", category: "Appearance", description: "Panel transparency setting", targetCategory: "appearance" },
    { label: "Enable Blur", category: "Appearance", description: "Toggle background blur effects", targetCategory: "appearance" },
    { label: "Ripple Pulse", category: "Appearance", description: "Flash screen ring on panel open", targetCategory: "appearance" },
    { label: "Overview Background", category: "Appearance", description: "Toggle overview background style", targetCategory: "appearance" },
    { label: "Overview Solid Color", category: "Appearance", description: "Solid color vs blurred overview", targetCategory: "appearance" },
    { label: "Overview Blur", category: "Appearance", description: "Background blur intensity", targetCategory: "appearance" },
    { label: "Overview Tint", category: "Appearance", description: "Background tint opacity", targetCategory: "appearance" },

    // ── Fonts ──
    { label: "Default Font", category: "Fonts", description: "UI text font family", targetCategory: "fonts" },
    { label: "Monospace Font", category: "Fonts", description: "Monospace font for numerals", targetCategory: "fonts" },
    { label: "Default Font Scale", category: "Fonts", description: "Default font size multiplier", targetCategory: "fonts" },
    { label: "Monospace Font Scale", category: "Fonts", description: "Monospace font size multiplier", targetCategory: "fonts" },

    // ── Notifications ──
    { label: "Max Visible", category: "Notifications", description: "Maximum visible notifications", targetCategory: "notifications" },
    { label: "Notification Timeout", category: "Notifications", description: "Auto-dismiss delay", targetCategory: "notifications" },
    { label: "Notification Position", category: "Notifications", description: "Screen corner placement", targetCategory: "notifications" },
    { label: "Do Not Disturb", category: "Notifications", description: "Silence all notifications", targetCategory: "notifications" },
]

function search(query) {
    if (!query || query.trim().length === 0)
        return []

    var q = query.toLowerCase().trim()
    var results = []
    for (var i = 0; i < settingsEntries.length; i++) {
        var entry = settingsEntries[i]
        if (matches(entry, q))
            results.push(entry)
    }
    return results
}

function allEntries() {
    return settingsEntries
}

function matches(entry, query) {
    if (!entry || !query || query.trim().length === 0)
        return false

    var q = query.toLowerCase().trim()
    return entry.label.toLowerCase().includes(q) || entry.category.toLowerCase().includes(q)
}
