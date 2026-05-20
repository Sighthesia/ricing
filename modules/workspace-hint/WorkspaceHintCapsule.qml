import QtQuick
import Quickshell.Widgets
import "../../services" as Services
import "WorkspaceHintViewportModel.js" as ViewportModel

// Render one workspace hint capsule driven by continuous focus-morphing values.
Item {
    id: root

    property int workspaceIndex: -1
    property int workspacePosition: -1
    property real relativeOffset: 0
    property real focusProgress: 0
    property real cameraDistance: 0
    property bool active: false
    property bool expanded: false
    property real baseY: 0
    property var icons: []
    property var windows: []
    property string currentWindowTitle: ""
    property string currentWindowIcon: ""
    property bool useFocusedGeometry: false
    readonly property real _collapsedSize: 28
    readonly property real _capsulePitch: 36
    readonly property real _fadeDistance: _capsulePitch * 3
    readonly property real _focusCenterY: baseY + 36
    readonly property real _distanceCompression: Math.min(10, Math.abs(root.relativeOffset) * 4)
    readonly property real _directionOffset: root.relativeOffset === 0 ? 0 : (root.relativeOffset > 0 ? _distanceCompression : -_distanceCompression)
    readonly property real _animatedY: _focusCenterY + (root.relativeOffset * _capsulePitch) + _directionOffset
    readonly property real _collapsedWidth: ViewportModel.neighborBaseWidth(_collapsedSize, 72)
    readonly property real _focusedWidth: root.useFocusedGeometry
        ? Math.max(activeContent.implicitWidth + 20, _collapsedSize)
        : Math.max(neighborContent.implicitWidth + 28, 72)
    readonly property real _focusWidth: ViewportModel.focusWidth(
        _collapsedWidth, _focusedWidth, root.focusProgress)
    readonly property real _focusOpacity: ViewportModel.opacityForDistance(
        Math.abs(root.relativeOffset), _capsulePitch, _fadeDistance)
    readonly property real _expandedWidth: root.useFocusedGeometry
        ? Math.max(activeContent.implicitWidth + 20, _collapsedSize)
        : Math.max(neighborContent.implicitWidth + 28, 72)
    readonly property real _expandedHeight: root.useFocusedGeometry
        ? Math.max(root._contentHeight + 16, root._collapsedSize)
        : root._collapsedSize
    readonly property real expandedHeightHint: root._expandedHeight
    readonly property real visibleY: root.y < 0 ? 0 : root.y
    readonly property real _surfaceOffsetY: root.visibleY - root.y
    readonly property real _contentHeight: root.useFocusedGeometry
        ? activeContent.implicitHeight
        : neighborContent.implicitHeight
    readonly property color _surfaceColor: root.useFocusedGeometry
        ? Qt.rgba(
            Services.Color.mSurface.r,
            Services.Color.mSurface.g,
            Services.Color.mSurface.b,
            0.92
        )
        : Qt.rgba(
            Services.Color.mSurface.r,
            Services.Color.mSurface.g,
            Services.Color.mSurface.b,
            0.82
        )
    readonly property color _outlineColor: root.useFocusedGeometry
        ? Qt.rgba(
            Services.Color.mOutline.r,
            Services.Color.mOutline.g,
            Services.Color.mOutline.b,
            0.25
        )
        : Qt.rgba(
            Services.Color.mOutline.r,
            Services.Color.mOutline.g,
            Services.Color.mOutline.b,
            0.28
        )

    y: root.expanded ? root._animatedY : 0
    width: root.expanded ? root._focusWidth : root._collapsedSize
    height: root.expanded ? (_collapsedSize + ((_expandedHeight - _collapsedSize) * root.focusProgress)) : root._collapsedSize
    opacity: root.expanded ? root._focusOpacity : 1
    clip: false

    Behavior on width {
        NumberAnimation {
            duration: Services.Motion.number.surfaceDuration
            easing.type: Services.Motion.number.surfaceEasing
        }
    }
    Behavior on opacity {
        NumberAnimation {
            duration: Services.Motion.number.surfaceDuration
            easing.type: Services.Motion.number.surfaceEasing
        }
    }
    Behavior on y {
        SpringAnimation {
            spring: Services.Motion.hover.spring
            damping: Services.Motion.hover.damping
            mass: Services.Motion.hover.mass
            epsilon: Services.Motion.hover.epsilon
        }
    }
    // Reference: afloat `modules/bar/DockzoneSurfaceRoot.qml`; keep motion on the owner item and render the visible surface on a child node to avoid top-edge clipping.
    // Keep the visible capsule surface attached to the screen edge even when the spring rebounds above y = 0.
    Rectangle {
        id: surface

        x: 0
        y: root._surfaceOffsetY
        width: root.width
        height: root.height
        radius: height / 2
        scale: 1
        color: root._surfaceColor
        border.color: root._outlineColor
        border.width: 1
        antialiasing: true

        Behavior on color {
            ColorAnimation {
                duration: Services.Motion.number.shortDuration
                easing.type: Services.Motion.number.shortEasing
            }
        }
        Behavior on border.color {
            ColorAnimation {
                duration: Services.Motion.number.shortDuration
                easing.type: Services.Motion.number.shortEasing
            }
        }

        // Keep the content clipped horizontally while the capsule background morphs.
        Item {
            id: contentMask
            x: 0
            y: 0
            width: surface.width
            height: surface.height
            clip: true
            // Keep the active workspace content on one horizontal line.
            Row {
                id: activeContent
                anchors.centerIn: contentMask
                spacing: 8
                opacity: root.focusProgress

                Behavior on opacity {
                    NumberAnimation {
                        duration: Services.Motion.number.shortDuration
                        easing.type: Services.Motion.number.shortEasing
                    }
                }

                // Keep the active workspace number pinned to the left.
                Text {
                    text: String(root.workspaceIndex)
                    font.pixelSize: 12
                    font.bold: true
                    color: Services.Color.mOnSurface
                }

                // Restore the old horizontal title-card row for active windows.
                Row {
                    id: windowTitleRow
                    spacing: 6

                    Repeater {
                        model: root.windows

                        // Render one active-workspace window title card.
                        Rectangle {
                            required property var modelData
                            required property int index

                            width: Math.max(winCardRow.implicitWidth + 14, 100)
                            height: 28
                            radius: 8
                            color: modelData.isFocused
                                ? Qt.rgba(
                                    Services.Color.mPrimary.r,
                                    Services.Color.mPrimary.g,
                                    Services.Color.mPrimary.b,
                                    0.18
                                )
                                : Qt.rgba(
                                    Services.Color.mSurfaceVariant.r,
                                    Services.Color.mSurfaceVariant.g,
                                    Services.Color.mSurfaceVariant.b,
                                    0.35
                                )

                            Behavior on width {
                                NumberAnimation {
                                    duration: Services.Motion.number.contentDuration
                                    easing.type: Services.Motion.number.contentEasing
                                }
                            }
                            Behavior on color {
                                ColorAnimation {
                                    duration: Services.Motion.number.shortDuration
                                    easing.type: Services.Motion.number.shortEasing
                                }
                            }

                            // Keep the focus dot and title aligned like the old hint.
                            Row {
                                id: winCardRow
                                anchors.centerIn: parent
                                spacing: 5

                                // Show the window icon inside each title card.
                                Item {
                                    width: modelData.icon ? 14 : 0
                                    height: 14

                                    Behavior on width {
                                        NumberAnimation {
                                            duration: Services.Motion.number.contentDuration
                                            easing.type: Services.Motion.number.contentEasing
                                        }
                                    }

                                    IconImage {
                                        anchors.fill: parent
                                        source: modelData.icon || ""
                                        implicitSize: 14
                                        visible: parent.width > 0
                                    }
                                }

                                // Mark the focused window card.
                                Rectangle {
                                    width: 5
                                    height: 5
                                    radius: 2.5
                                    color: Services.Color.mPrimary
                                    visible: modelData.isFocused
                                }

                                // Show one window title with the old elide rules.
                                Text {
                                    text: modelData.title
                                    font.pixelSize: 11
                                    font.bold: modelData.isFocused
                                    color: modelData.isFocused
                                        ? Services.Color.mOnSurface
                                        : Services.Color.mOnSurfaceVariant
                                    elide: Text.ElideRight
                                    maximumLineCount: 1
                                    width: Math.min(implicitWidth, 140)
                                }
                            }
                        }
                    }

                    // Preserve the empty active-workspace fallback.
                    Text {
                        visible: root.expanded && (root.windows || []).length === 0
                        text: "空工作区"
                        font.pixelSize: 12
                        color: Services.Color.mOnSurfaceVariant
                        opacity: 0.5
                    }
                }
            }

            // Keep neighbor workspaces compact with only number and icons.
            Row {
                id: neighborContent
                anchors.centerIn: contentMask
                spacing: 6
                opacity: 1 - root.focusProgress

                Behavior on opacity {
                    NumberAnimation {
                        duration: Services.Motion.number.shortDuration
                        easing.type: Services.Motion.number.shortEasing
                    }
                }

                // Show the neighbor workspace number.
                Text {
                    text: String(root.workspaceIndex)
                    font.pixelSize: 12
                    color: Services.Color.mOnSurfaceVariant
                }

                // Show up to three icons for the neighbor workspace.
                Repeater {
                    model: (root.icons || []).slice(0, 3)

                    // Render one compact neighbor icon.
                    Item {
                        required property var modelData

                        width: 14
                        height: 14

                        IconImage {
                            anchors.fill: parent
                            source: modelData.icon
                            implicitSize: 14
                        }
                    }
                }
            }
        }
    }
}
