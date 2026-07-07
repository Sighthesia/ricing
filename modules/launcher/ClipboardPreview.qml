import QtQuick
import QtQuick.Controls
import "../../services" as Services

// Left-side inline preview for clipboard image or long-text items.
// Grows/shrinks inside the clipboard list as the host animates previewWidth.
// Displays image preview or scrollable text with optional full-content expand.
Item {
    id: root

    // Current preview state from the host
    property bool active: false
    property bool isImage: false
    property string clipboardId: ""
    property string previewText: ""
    // Animated width driven by the host — zero when no preview is shown.
    property real targetPreviewWidth: 0
    readonly property real restingWidth: isImage ? 200 : 280
    readonly property real contentInset: 12
    readonly property real contentWidth: Math.max(0, width - contentInset * 2)

    // Whether the pointer is hovering over the preview panel itself.
    // Set by the parent islandClipboard's Row-level mouse tracking.
    // When true, the clear timer skips this preview so it stays visible.
    property bool hovered: false

    // Internal preview content state
    property string _imageSource: ""
    property string _textContent: ""
    property bool _loading: false
    // Track the last requested clipboardId so stale async results are ignored.
    property string _requestedId: ""
    readonly property string _effectiveText: _textContent.length > 0 ? _textContent : previewText
    readonly property int _textCharCount: _effectiveText.length
    readonly property int _textLineCount: _effectiveText.length > 0 ? _effectiveText.split(/\r?\n/).length : 0

    // React to preview activation.
    onActiveChanged: {
        if (active && clipboardId) {
            loadContent()
        } else if (!active) {
            clearContent()
        }
    }
    onClipboardIdChanged: {
        if (active && clipboardId) {
            loadContent()
        } else {
            clearContent()
        }
    }

    function loadContent() {
        _imageSource = ""
        _textContent = ""
        _loading = true
        _requestedId = clipboardId

        if (!clipboardId) {
            _loading = false
            return
        }

        if (isImage) {
            Services.ClipboardService.requestPreview(clipboardId, true)
        } else {
            // Show any inline preview immediately, then always request full text.
            _textContent = previewText
            Services.ClipboardService.requestPreview(clipboardId, false)
        }
    }

    function clearContent() {
        _imageSource = ""
        _textContent = ""
        _loading = false
        Services.ClipboardService.discardPreview(_requestedId)
    }

    Connections {
        target: Services.ClipboardService
        function onPreviewDecoded(id, content) {
            if (id !== root.clipboardId || !root.active) return
            if (root.isImage) {
                root._imageSource = content
                root._loading = false
            } else if (content && content.trim().length > 0) {
                // Prefer decoded full text, but keep existing if empty.
                root._textContent = content
                root._loading = false
            } else {
                root._loading = false
            }
        }
    }

    // Animated width — the host sets targetPreviewWidth, we spring to it.
    Behavior on targetPreviewWidth {
        NumberAnimation {
            duration: Services.Motion.number.contentDuration
            easing.type: Services.Motion.number.contentEasing
        }
    }

    width: targetPreviewWidth
    height: parent.height
    clip: true
    visible: width > 1

    // Glass panel background matching the launcher surface aesthetic.
    Rectangle {
        id: bg
        anchors.fill: parent
        anchors.rightMargin: -12 // extend clip slightly for smooth reveal
        radius: 10
        color: Qt.alpha(Services.Color.mSurface, Services.SettingsService.panelSurfaceOpacity * 0.9)

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: "transparent"
            border.color: Qt.rgba(Services.Color.mOutline.r, Services.Color.mOutline.g, Services.Color.mOutline.b, 0.25)
            border.width: 1
        }
    }

    // Loading indicator.
    BusyIndicator {
        anchors.centerIn: parent
        running: root._loading
        visible: root._loading
        width: 24
        height: 24
    }

    // ---- Image preview (Column layout: image + metadata label) ----
    Column {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.leftMargin: root.contentInset
        anchors.topMargin: root.contentInset
        anchors.bottomMargin: root.contentInset
        width: root.contentWidth
        spacing: 4
        visible: root.isImage && !root._loading && root._imageSource.length > 0

        // Image fills most of the space above the label.
        Item {
            width: root.contentWidth
            height: parent.height - metaLabel.height - parent.spacing

            Image {
                anchors.fill: parent
                fillMode: Image.PreserveAspectFit
                source: root._imageSource
                smooth: true
                mipmap: true
            }
        }

        // Image metadata label.
        Services.FluidText {
            id: metaLabel
            width: root.contentWidth
            height: 18
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: {
                if (!root.clipboardId) return ""
                var preview = root.previewText || ""
                if (preview.startsWith("[") && preview.endsWith("]"))
                    return preview.replace(/^\[|\]$/g, "").toUpperCase() + " | #" + root.clipboardId
                return "IMAGE | #" + root.clipboardId
            }
            color: Services.Color.mOnSurfaceVariant
            basePixelSize: 10
            opacity: 0.6
        }
    }

    // ---- Text preview ----
    Column {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.leftMargin: root.contentInset
        anchors.topMargin: root.contentInset
        anchors.bottomMargin: root.contentInset
        width: root.contentWidth
        spacing: 4
        visible: !root.isImage && !root._loading

        // Scrollable text content.
        Item {
            id: textScrollContainer
            width: root.contentWidth
            height: parent.height - metaText.height - parent.spacing
            clip: true

            Flickable {
                id: textFlick
                anchors.fill: parent
                contentWidth: parent.width
                contentHeight: textContent.implicitHeight
                interactive: true
                boundsBehavior: Flickable.StopAtBounds
                flickDeceleration: 2000

                Services.FluidText {
                    id: textContent
                    width: textScrollContainer.width
                    text: root._textContent
                    wrapMode: Text.Wrap
                    textFormat: Text.PlainText
                    color: Services.Color.mOnSurface
                    basePixelSize: 12
                    useMonospace: false
                    elide: Text.ElideNone
                    maximumLineCount: 9999
                }

                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                    width: 4
                    onWidthChanged: {
                        if (width > 4) width = 4 // keep thin
                    }
                }
            }
        }

        Services.FluidText {
            id: metaText
            width: root.contentWidth
            height: 16
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: root._textCharCount + " chars | " + root._textLineCount + " lines | #" + root.clipboardId
            color: Services.Color.mOnSurfaceVariant
            basePixelSize: 10
            opacity: 0.68
        }
    }

    // Empty state for non-previewable items (shouldn't happen in practice).
    Services.FluidText {
        anchors.centerIn: parent
        text: "No preview available"
        color: Services.Color.mOnSurfaceVariant
        basePixelSize: 11
        opacity: 0.5
        visible: !root.isImage && !root._loading && root._textContent.length === 0
    }
}
