import QtQuick
import Quickshell.Widgets
import "../../services" as Services

// Render one workspace hint capsule in active or neighbor mode.
Rectangle {
    id: root

    property int workspaceIndex: -1
    property bool active: false
    property bool expanded: false
    property real baseY: 0
    property var icons: []
    property var windows: []
    property string currentWindowTitle: ""
    property string currentWindowIcon: ""
    readonly property real _collapsedSize: 28
    readonly property real _expandedWidth: root.active
        ? Math.max(activeContent.implicitWidth + 20, _collapsedSize)
        : Math.max(neighborContent.implicitWidth + 28, 72)
    readonly property real _expandedHeight: root.active
        ? Math.max(activeContent.implicitHeight + 20, _collapsedSize)
        : _collapsedSize
    readonly property real _expandedRadius: root.active ? 12 : 14
    readonly property real expandedHeightHint: root._expandedHeight
    readonly property real _contentHeight: root.active
        ? activeContent.implicitHeight
        : neighborContent.implicitHeight

    y: root.expanded ? root.baseY : 0
    width: root.expanded ? root._expandedWidth : root._collapsedSize
    height: root.expanded ? root._expandedHeight : root._collapsedSize
    radius: root.expanded ? root._expandedRadius : height / 2
    scale: root.expanded ? 1 : 0.88
    clip: false

    color: root.active
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
    border.color: root.active
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
    border.width: 1

    Behavior on width {
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
    Behavior on height {
        NumberAnimation {
            duration: Services.Motion.number.surfaceDuration
            easing.type: Services.Motion.number.surfaceEasing
        }
    }
    Behavior on scale {
        NumberAnimation {
            duration: Services.Motion.number.surfaceDuration
            easing.type: Services.Motion.number.surfaceEasing
        }
    }
    Behavior on radius {
        NumberAnimation {
            duration: Services.Motion.number.surfaceDuration
            easing.type: Services.Motion.number.surfaceEasing
        }
    }
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
        y: root.expanded ? (root.height - height) / 2 : 0
        width: root.width
        height: Math.max(root._contentHeight, root._collapsedSize)
        clip: true

        Behavior on y {
            SpringAnimation {
                spring: Services.Motion.hover.spring
                damping: Services.Motion.hover.damping
                mass: Services.Motion.hover.mass
                epsilon: Services.Motion.hover.epsilon
            }
        }
    }

    // Keep the active workspace content on one horizontal line.
    Row {
        id: activeContent
        anchors.centerIn: contentMask
        spacing: 8
        visible: root.active

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
        visible: !root.active

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
