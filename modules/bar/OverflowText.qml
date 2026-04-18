import QtQuick
import QtQuick.Layouts
import qs.config

// Single-line text that can either elide or auto-scroll when it overflows.
Item {
    id: root

    property string text: ""
    property string overflowMode: "elide"    // "elide" or "scroll"
    property color textColor: Colors.text
    property string fontFamily: Theme.fontFamily
    property real fontPixelSize: Theme.fontSizeBody
    property int fontWeight: Font.Normal
    // Explicit component-level maximum width (takes precedence over Layout.maximumWidth)
    property real maximumWidth: -1
    property real scrollGap: Math.max(20, Math.round(Theme.barWidget.iconSpacing * 6))
    property int startPause: 900
    property int loopPause: 700
    property real pixelsPerSecond: 42
    property bool debug: false

    // A hidden, rendered text used to measure paintedWidth/height reliably.
    Text {
        id: _measurer
        text: root.text !== "" ? root.text : " "
        wrapMode: Text.NoWrap
        font.family: root.fontFamily
        font.pixelSize: root.fontPixelSize
        font.weight: root.fontWeight
        opacity: 0.0
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        // Re-evaluate when measurer's painted size updates.
        onPaintedWidthChanged: _updateScrollState()
        onPaintedHeightChanged: _updateScrollState()
    }

    // Effective measured text width and height (painted values are most reliable).
    readonly property real _textWidth: _measurer.paintedWidth
    readonly property real _textHeight: _measurer.paintedHeight

    // Prefer explicit maximumWidth, then Layout.maximumWidth (if set by caller),
    // then fall back to parent.width when available, otherwise treat as unconstrained.
    readonly property real _availableWidth: (
        maximumWidth > 0 ? maximumWidth :
        (Layout.maximumWidth && Layout.maximumWidth > 0 ? Layout.maximumWidth :
            (parent && parent.width > 0 ? parent.width : 0))
    )

    // Viewport is the visible width that the text may occupy.
    readonly property real _viewportWidth: (_availableWidth > 0 ? Math.min(_availableWidth, _textWidth) : _textWidth)
    readonly property bool _scrollEnabled: overflowMode === "scroll" && _textWidth > _viewportWidth + 1
    readonly property int _scrollDuration: Math.max(1, Math.round(((_textWidth + scrollGap) / Math.max(1, pixelsPerSecond)) * 1000))

    implicitWidth: _viewportWidth
    implicitHeight: _textHeight
    width: _viewportWidth
    height: implicitHeight
    clip: true

    // When visibility or measured size changes, ensure marquee restarts/stops.
    function _updateScrollState() {
        var available = maximumWidth > 0 ? maximumWidth : (Layout.maximumWidth && Layout.maximumWidth > 0 ? Layout.maximumWidth : (parent && parent.width > 0 ? parent.width : 0))
        var textW = _measurer.paintedWidth
        var viewport = (available > 0 ? Math.min(available, textW) : textW)
        var shouldScroll = (overflowMode === "scroll" && textW > viewport + 1)
        if (root.debug) console.log("OverflowText:update", root.text, "painted=", textW, "viewport=", viewport, "available=", available, "scroll=", shouldScroll)
        if (shouldScroll) {
            _scrollLoop.restart()
        } else {
            _scrollLoop.stop()
            _track.x = 0
        }
    }

    onVisibleChanged: {
        Qt.callLater(_updateScrollState)
    }

    onTextChanged: {
        // paintedWidth will update on the next frame; defer the check
        Qt.callLater(_updateScrollState)
    }

    onMaximumWidthChanged: {
        Qt.callLater(_updateScrollState)
    }

    Component.onCompleted: {
        Qt.callLater(_updateScrollState)
    }

    // Re-evaluate when the hidden measurer updates its painted size (handled by _measurer handlers).

    // Render a normal elided label when scrolling is not needed.
    Text {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: root.width
        visible: !root._scrollEnabled
        text: root.text
        color: root.textColor
        elide: Text.ElideRight
        maximumLineCount: 1
        wrapMode: Text.NoWrap
        font.family: root.fontFamily
        font.pixelSize: root.fontPixelSize
        font.weight: root.fontWeight
    }

    // Render the scrolling track when marquee mode is active.
    Item {
        anchors.fill: parent
        visible: root._scrollEnabled
        clip: true

        // Keep two copies of the text so the marquee loops seamlessly.
        Item {
            id: _track

            width: _primaryLabel.paintedWidth + root.scrollGap + _secondaryLabel.paintedWidth
            height: parent.height

            // Primary marquee label.
            Text {
                id: _primaryLabel

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: root.text
                color: root.textColor
                wrapMode: Text.NoWrap
                font.family: root.fontFamily
                font.pixelSize: root.fontPixelSize
                font.weight: root.fontWeight
            }

            // Secondary marquee label repeats after the configured gap.
            Text {
                id: _secondaryLabel

                x: _primaryLabel.paintedWidth + root.scrollGap
                anchors.verticalCenter: parent.verticalCenter
                text: root.text
                color: root.textColor
                wrapMode: Text.NoWrap
                font.family: root.fontFamily
                font.pixelSize: root.fontPixelSize
                font.weight: root.fontWeight
            }
        }
    }

    // Scroll the marquee track and snap back between loops.
    SequentialAnimation {
        id: _scrollLoop

        running: root._scrollEnabled
        loops: Animation.Infinite

        PauseAnimation { duration: root.startPause }

        NumberAnimation {
            target: _track
            property: "x"
            from: 0
            to: -(_primaryLabel.paintedWidth + root.scrollGap)
            duration: root._scrollDuration
            easing.type: Easing.Linear
        }

        PauseAnimation { duration: root.loopPause }

        ScriptAction { script: _track.x = 0 }
    }
}
