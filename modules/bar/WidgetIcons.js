.pragma library

// One table mapping a widget id to the glyph that stands for it.
//
// The bar's right-click menu needs it twice — for the identity icon of the
// widget under the pointer and for every row of the "add widget" catalog — so
// it lives here rather than being spelled out at each site. Symbolic `source`
// names resolve to a real URL at the call site, because a library file cannot
// call `Qt.resolvedUrl` against a relative path and stay correct from every
// importer.
var glyphs = {
    "volume": { source: "bar:volume.svg" },
    "brightness": { source: "bar:brightness.svg" },
    "battery": { source: "bar:battery.svg" },
    "bluetooth": { source: "bar:bluetooth.svg" },
    // Network's wired/wifi choice depends on live state, so it carries two
    // names and the caller picks; see `networkSource`.
    "network": { source: "bar:wifi.svg", wired: "bar:network-wired.svg" },
    "media": { source: "lazer:music.svg" },
    "notifications": { source: "lazer:bell.svg" },
    "tray": { source: "lazer:apps.svg" },
    "clock": { source: "lazer:clock.svg" },
    "workspaces": { source: "lazer:workspaces.svg" },
    "active-window": { source: "lazer:window.svg" },
    "system-monitor": { source: "lazer:system-monitor.svg" },
    "launcher": { source: "lazer:launcher.svg" },
    "settings": { source: "lazer:settings.svg" },
    "divider": { source: "lazer:widget-divider.svg" },
}

function sourceFor(widgetId) {
    var entry = glyphs[String(widgetId || "")]
    return entry ? String(entry.source) : ""
}

// Network swaps its glyph with the live link, and only the caller knows that.
function networkSource(ethernetConnected) {
    return ethernetConnected === true
        ? String(glyphs["network"].wired) : String(glyphs["network"].source)
}
