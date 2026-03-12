import QtQuick
import QtQuick.Layouts
import qs.config

// Reactive bar-field background fed by normalized cava values.
Item {
    id: root

    property var bars: []
    property color barColor: Colors.highlight
    property real barOpacity: Theme.barWidget.mediaVisualizerBarOpacity
    property int barWidth: Theme.barWidget.mediaVisualizerBarWidth
    property int barGap: Theme.barWidget.mediaVisualizerBarGap
    readonly property int _barCount: root.bars.length
    readonly property int _contentMargin: Theme.barWidget.contentPaddingV
    readonly property int _resolvedGap: root._barCount > 1 ? root.barGap : 0
    readonly property int _availableWidth:
        Math.max(0, width - root._contentMargin * 2 - root._resolvedGap * Math.max(0, root._barCount - 1))
    readonly property real _resolvedBarWidth:
        root._barCount > 0
            ? Math.max(root.barWidth, root._availableWidth / root._barCount)
            : root.barWidth

    clip: true

    // Visualizer canvas.
    Item {
        anchors.fill: parent
        anchors.margins: Theme.barWidget.contentPaddingV

        // Visualizer repeater.
        Repeater {
            model: root._barCount

            // Visualizer bar.
            Rectangle {
                required property int index

                x: index * (root._resolvedBarWidth + root._resolvedGap)
                width: root._resolvedBarWidth
                height: Math.max(4, Math.round((root.bars[index] || 0) * parent.height))
                radius: width / 2
                color: root.barColor
                opacity: root.barOpacity
                y: parent.height - height

                Behavior on height {
                    NumberAnimation {
                        duration: Theme.anim.highlightDuration
                        easing.type: Theme.anim.highlightType
                    }
                }
            }
        }
    }
}