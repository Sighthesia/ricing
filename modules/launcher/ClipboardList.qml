import QtQuick
import "../../services" as Services

// Filterable clipboard list with stable full-list model and per-delegate
// filtering.  Now includes a left-side preview panel for image and long-text
// entries, driven by hover or keyboard selection.
Item {
    id: root

    anchors.fill: parent

    // Hidden prewarm batch: instantiate a small representative set of
    // clipboard rows ahead of the first large search so row text/layout and
    // action subtrees are already warm when many matches are first revealed.
    property int _prewarmCount: 16
    property bool _prewarmArmed: false
    property var _prewarmItems: {
        const all = root.allItems || []
        if (!all || all.length === 0) return []
        return all.slice(0, Math.min(_prewarmCount, all.length))
    }

    // Debounce: avoid rapid filter cycles during fast typing.
    property string _debouncedQuery: Services.LauncherService.query.toLowerCase().trim()

    Timer {
        id: debounceTimer
        interval: 80
        repeat: false
        onTriggered: {
            _debouncedQuery = Services.LauncherService.query.toLowerCase().trim()
            // Clear preview when the search query changes.
            root._hoverActiveIndex = -1
            root._clearPreview()
        }
    }

    Connections {
        target: Services.LauncherService
        function onQueryChanged() {
            debounceTimer.restart()
        }
    }

    Component.onCompleted: {
        Services.ClipboardService.list()
        prewarmTimer.start()
    }

    Timer {
        id: prewarmTimer
        interval: 0
        repeat: false
        onTriggered: root._prewarmArmed = true
    }

    // Stable model: full clipboard items list.
    // Does not change on query so ListView avoids add/remove cycles.
    property var allItems: Services.ClipboardService.items || []

    // Clear preview when the clipboard items change (avoids stale index references).
    onAllItemsChanged: {
        root._hoverActiveIndex = -1
        root._clearPreview()
    }

    // ---- Preview tracking ----
    // Tracks the index of the currently hovered delegate (-1 if none).
    // Takes priority over keyboard selection so hover always wins.
    property int _hoverActiveIndex: -1

    // Check if an item qualifies for preview.
    function _isPreviewable(item) {
        return item && (item.isImage || (item.preview && item.preview.length > 80))
    }

    // Called by each delegate on hover enter/leave. Hover always takes priority.
    function _onDelegateHoverChanged(itemData, index, hovered) {
        if (hovered) {
            root._hoverActiveIndex = index
            root._updatePreviewToItem(index, itemData)
        } else if (root._hoverActiveIndex === index) {
            root._hoverActiveIndex = -1
            // Hover left; fall back to keyboard selection if previewable.
            var kidx = clipListView.currentIndex
            if (kidx >= 0 && kidx < root.allItems.length
                && root._isPreviewable(root.allItems[kidx])) {
                root._updatePreviewToItem(kidx, root.allItems[kidx])
            } else {
                root._clearPreview()
            }
        }
    }

    // Drive preview content and width for a specific item.
    function _updatePreviewToItem(index, item) {
        if (!item || !_isPreviewable(item)) {
            _clearPreview()
            return
        }
        clipPreview.isImage = item.isImage
        clipPreview.clipboardId = item.id
        clipPreview.previewText = item.preview || ""
        clipPreview.active = true
        clipPreview.targetPreviewWidth = item.isImage ? 300 : 420
    }

    // Clear the preview panel entirely.
    function _clearPreview() {
        clipPreview.targetPreviewWidth = 0
        clipPreview.active = false
        // Defer clipboardId clear so the fade-out renders without flicker.
        Qt.callLater(function() {
            if (!clipPreview.active)
                clipPreview.clipboardId = ""
        })
    }

    // Row layout: [Preview Panel] [ListView]
    Row {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 0
        clip: true

        // Left-side preview panel for image or long-text items.
        ClipboardPreview {
            id: clipPreview
            // width animated by targetPreviewWidth; height matches parent.
            height: parent.height
            z: 1
        }

        // Clipboard entry list fills remaining space.
        ListView {
            id: clipListView
            width: parent.width - clipPreview.width
            height: parent.height
            clip: true
            spacing: 4
            model: root.allItems
            currentIndex: -1
            boundsBehavior: Flickable.StopAtBounds

            delegate: ClipboardDelegate {
                query: root._debouncedQuery
                hoverHandler: root._onDelegateHoverChanged
            }

            displaced: Transition {
                NumberAnimation { properties: "x,y"; duration: 200; easing.type: Easing.OutCubic }
            }

            // Keyboard selection: only updates preview when no hover is active.
            onCurrentIndexChanged: {
                if (root._hoverActiveIndex >= 0) return
                if (currentIndex >= 0 && currentIndex < root.allItems.length) {
                    var item = root.allItems[currentIndex]
                    if (root._isPreviewable(item)) {
                        root._updatePreviewToItem(currentIndex, item)
                        return
                    }
                }
                root._clearPreview()
            }
        }
    }

    // Prewarm hidden delegates.
    Item {
        visible: false
        opacity: 0
        x: -10000
        y: -10000

        Repeater {
            model: root._prewarmArmed ? root._prewarmItems : []
            delegate: ClipboardDelegate {
                query: ""
                hoverHandler: root._onDelegateHoverChanged
            }
        }
    }
}
