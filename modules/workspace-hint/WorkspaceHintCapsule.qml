import QtQuick
import Quickshell.Widgets
import "../../services" as Services

// Render one workspace capsule using the shared slot-stage metrics.
Item {
    id: root

    required property var host
    required property var capsule
    required property real slotPosition
    required property int absoluteIndex

    readonly property var _metrics: host._workspaceMetricsForSlot(root.slotPosition, root.absoluteIndex)
    readonly property real _emphasis: root._metrics.emphasis
    readonly property bool _isPrimaryCapsule: root.capsule && (root.capsule.isCurrent || root.capsule.isTransitionCurrent)
    readonly property bool _isEmptyWorkspace: root.capsule && (root.capsule.icons || []).length === 0
    readonly property real _visualEmphasis: root._isEmptyWorkspace
        ? Math.max(root._isPrimaryCapsule ? 0.56 : 0.42, root._emphasis)
        : Math.max(root._isPrimaryCapsule ? 0.74 : 0, root._emphasis)
    readonly property color _surfaceColor: root._isEmptyWorkspace
        ? Qt.rgba(
            Services.Color.mSurfaceVariant.r,
            Services.Color.mSurfaceVariant.g,
            Services.Color.mSurfaceVariant.b,
            0.34 + (0.24 * root._visualEmphasis)
        )
        : Qt.rgba(
            Services.Color.mSurface.r,
            Services.Color.mSurface.g,
            Services.Color.mSurface.b,
            0.72 + (0.2 * root._visualEmphasis)
        )
    readonly property color _outlineColor: Qt.rgba(
        Services.Color.mOutline.r,
        Services.Color.mOutline.g,
        Services.Color.mOutline.b,
        0.18 + (0.12 * root._visualEmphasis)
    )
    readonly property color _textColor: root._isEmptyWorkspace
        ? (root._isPrimaryCapsule ? Services.Color.mOnSurface : Services.Color.mOnSurfaceVariant)
        : Services.Color.mOnSurface
    readonly property real _capsuleOpacity: root._isEmptyWorkspace
        ? Math.max(root._metrics.opacity, 0.62)
        : root._metrics.opacity
    readonly property real _iconSize: 14 + (2 * root._emphasis)
    readonly property real _iconSpacing: 4
    readonly property int _visibleIconCount: Math.min(3, root.capsule && root.capsule.icons ? root.capsule.icons.length : 0)
    readonly property int _focusedIconIndex: {
        const items = root.capsule && root.capsule.icons ? root.capsule.icons : []
        for (let index = 0; index < items.length; index++) {
            if (items[index] && items[index].isFocused)
                return index
        }
        return -1
    }
    readonly property real visibleY: root.y < 0 ? 0 : root.y
    readonly property real _surfaceOffsetY: root.visibleY - root.y

    x: root._metrics.x
    y: root._metrics.y
    width: root._metrics.width
    height: root._metrics.height
    opacity: root.capsule && root.capsule.visible ? root._capsuleOpacity : 0
    visible: root.capsule !== null && opacity > 0
    clip: false

    Behavior on opacity {
        enabled: !host._workspaceSettlePending

        NumberAnimation {
            duration: host._workspaceCapsuleOpacityDuration
            easing.type: Services.Motion.number.surfaceEasing
        }
    }

    // Keep the visible capsule surface attached to the stage even near the top edge.
    Rectangle {
        id: surface

        x: 0
        y: root._surfaceOffsetY
        width: root.width
        height: root.height
        radius: height / 2
        color: root._surfaceColor
        border.color: root._outlineColor
        border.width: 1
        antialiasing: true

        // Center the workspace label and icon strip inside the capsule.
        Item {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            clip: true

            Row {
                anchors.centerIn: parent
                spacing: 6

                // Show the workspace number as the capsule label.
                Text {
                    text: root.capsule ? String(root.capsule.workspaceIndex) : ""
                    color: root._textColor
                    font.pixelSize: 12
                    font.bold: root._emphasis >= 0.5
                    visible: text !== ""
                }

                // Keep the workspace icon strip aligned like DymicShell's stage capsules.
                Item {
                    implicitWidth: root._visibleIconCount > 0
                        ? root._visibleIconCount * root._iconSize + Math.max(0, root._visibleIconCount - 1) * root._iconSpacing
                        : 0
                    implicitHeight: root._iconSize + 8
                    width: implicitWidth
                    height: implicitHeight
                    visible: width > 0

                    Rectangle {
                        width: root._iconSize + 8
                        height: width
                        radius: height / 2
                        color: Qt.rgba(
                            Services.Color.mPrimary.r,
                            Services.Color.mPrimary.g,
                            Services.Color.mPrimary.b,
                            0.18 + (0.12 * root._emphasis)
                        )
                        opacity: root._focusedIconIndex >= 0 ? 1 : 0
                        visible: opacity > 0
                        x: root._focusedIconIndex >= 0
                            ? root._focusedIconIndex * (root._iconSize + root._iconSpacing) - 4
                            : 0
                        y: (parent.height - height) / 2

                        Behavior on x {
                            NumberAnimation {
                                duration: Services.Motion.number.contentDuration
                                easing.type: Services.Motion.number.contentEasing
                            }
                        }
                        Behavior on opacity {
                            NumberAnimation {
                                duration: Services.Motion.number.shortDuration
                                easing.type: Services.Motion.number.shortEasing
                            }
                        }
                    }

                    Row {
                        anchors.centerIn: parent
                        spacing: root._iconSpacing

                        Repeater {
                            model: root.capsule && root.capsule.icons ? root.capsule.icons.slice(0, 3) : []

                            delegate: Item {
                                required property var modelData

                                width: root._iconSize
                                height: root._iconSize
                                opacity: modelData.isFocused ? 0.96 : (0.58 + (0.24 * root._emphasis))

                                IconImage {
                                    anchors.fill: parent
                                    source: modelData.icon || ""
                                    implicitSize: root._iconSize
                                }
                            }
                        }
                    }
                }

                // Keep empty workspaces readable even without window icons.
                Text {
                    text: root._isEmptyWorkspace ? "空工作区" : ""
                    color: Services.Color.mOnSurfaceVariant
                    font.pixelSize: 11
                    opacity: 0.75
                    visible: text !== "" && root._emphasis >= 0.35
                }
            }
        }
    }
}
