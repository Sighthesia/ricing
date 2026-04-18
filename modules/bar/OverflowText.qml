import QtQuick
import qs.config

// Single-line text that can either elide or auto-scroll when it overflows.
Item {
    id: root

    property string text: ""
    property string overflowMode: "elide"
    property color textColor: Colors.text
    property string fontFamily: Theme.fontFamily
    property real fontPixelSize: Theme.fontSizeBody
    property int fontWeight: Font.Normal
    property real maximumWidth: -1
    property real scrollGap: Math.max(20, Math.round(Theme.barWidget.iconSpacing * 6))
    property int startPause: 900
    property int loopPause: 700
    property real pixelsPerSecond: 42

    readonly property real _resolvedMaxWidth: maximumWidth > 0 ? maximumWidth : _textMetrics.advanceWidth
    readonly property real _viewportWidth: Math.min(_resolvedMaxWidth, _textMetrics.advanceWidth)
    readonly property bool _scrollEnabled: overflowMode === "scroll" && _textMetrics.advanceWidth > _viewportWidth + 1
    readonly property int _scrollDuration: Math.max(
        1,
        Math.round(((_textMetrics.advanceWidth + scrollGap) / Math.max(1, pixelsPerSecond)) * 1000)
    )

    implicitWidth: _viewportWidth
    implicitHeight: _labelMetrics.height
    width: _viewportWidth
    height: implicitHeight
    clip: true

    on_ViewportWidthChanged: {
        if (!_scrollEnabled)
            _track.x = 0
    }

    on_ScrollEnabledChanged: {
        if (_scrollEnabled) {
            _scrollLoop.restart()
            return
        }

        _scrollLoop.stop()
        _track.x = 0
    }

    onTextChanged: {
        if (_scrollEnabled)
            _scrollLoop.restart()
    }

    // Measure the full text width.
    TextMetrics {
        id: _textMetrics

        text: root.text
        font.family: root.fontFamily
        font.pixelSize: root.fontPixelSize
        font.weight: root.fontWeight
    }

    // Measure the rendered line height.
    TextMetrics {
        id: _labelMetrics

        text: root.text !== "" ? root.text : " "
        font.family: root.fontFamily
        font.pixelSize: root.fontPixelSize
        font.weight: root.fontWeight
    }

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

            width: _primaryLabel.width + root.scrollGap + _secondaryLabel.width
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

                x: _primaryLabel.width + root.scrollGap
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

        PauseAnimation {
            duration: root.startPause
        }

        NumberAnimation {
            target: _track
            property: "x"
            from: 0
            to: -(_primaryLabel.width + root.scrollGap)
            duration: root._scrollDuration
            easing.type: Easing.Linear
        }

        PauseAnimation {
            duration: root.loopPause
        }

        ScriptAction {
            script: _track.x = 0
        }
    }
}
