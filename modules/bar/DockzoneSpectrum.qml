import QtQuick
import "../../services" as Services

// Render a mirrored low-opacity spectrum that can sit behind dockzone widgets.
Item {
    id: root

    property var values: []
    property color barColor: Qt.rgba(Services.Color.mPrimary.r, Services.Color.mPrimary.g, Services.Color.mPrimary.b, 0.34)

    readonly property int valuesCount: (root.values && root.values.length !== undefined) ? root.values.length : 0
    readonly property int totalBars: root.valuesCount > 0 ? root.valuesCount * 2 : 0
    readonly property real slotWidth: root.totalBars > 0 ? root.width / root.totalBars : 0
    readonly property real floorInset: 4
    readonly property real usableHeight: Math.max(0, root.height - root.floorInset)

    // Paint mirrored bars so the spectrum stays centered inside the dockzone body.
    Repeater {
        model: root.totalBars

        // Keep each bar as a cheap rounded rectangle for per-frame updates.
        Rectangle {
            readonly property int mirroredIndex: index < root.valuesCount ? root.valuesCount - 1 - index : index - root.valuesCount
            readonly property real amplitude: (root.values && root.values[mirroredIndex] !== undefined) ? root.values[mirroredIndex] : 0
            readonly property real emphasis: {
                if (root.totalBars <= 1)
                    return 1

                var center = (root.totalBars - 1) / 2
                var distance = Math.abs(index - center) / Math.max(1, center)
                return 0.8 + ((1 - distance) * 0.45)
            }

            width: Math.max(1, root.slotWidth * 0.42)
            height: root.usableHeight * amplitude
            radius: width / 2
            x: index * root.slotWidth + ((root.slotWidth - width) / 2)
            y: root.height - height - root.floorInset
            color: Qt.rgba(root.barColor.r, root.barColor.g, root.barColor.b, root.barColor.a * emphasis)
            visible: height > 0.5 && root.visible
        }
    }
}
