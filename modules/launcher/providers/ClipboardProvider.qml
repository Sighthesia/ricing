import Quickshell
import QtQuick
import qs.services

// Provides clipboard history results for the launcher.
// Activated when the launcher search text starts with ">clip ".
// Prefix is stripped before calling getResults().
Item {
    id: root

    // Provider interface — not the default; activated by prefix matching only.
    property bool handleSearch: false

    // Called when the launcher opens; pre-fetches history so results appear immediately.
    function onOpened(): void {
        ClipboardService.list(100);
    }

    // Returns up to 50 clipboard items whose preview contains `text` (case-insensitive).
    // An empty `text` returns the most recent entries unfiltered.
    function getResults(text: string): var {
        let results = [];
        let query   = text.trim().toLowerCase();
        let items   = ClipboardService.items;

        for (let i = 0; i < items.length; i++) {
            let item    = items[i];
            let preview = item.preview || "";

            if (query !== "" && !preview.toLowerCase().includes(query)) continue;

            let displayName = preview.length > 60
                ? preview.substring(0, 60) + "…"
                : preview;

            results.push({
                key:         "clip:" + String(item.id),
                name:        item.isImage ? "[图片]" : displayName,
                description: item.isImage ? preview : "",
                icon:        item.isImage ? "image-x-generic" : "edit-paste",
                // Capture `id` by value so each closure refers to its own entry.
                onActivate: (function(id) {
                    return function() { ClipboardService.copyToClipboard(id); };
                })(item.id)
            });
        }

        return results;
    }
}
