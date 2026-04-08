import Quickshell
import QtQuick
import Qt5Compat.GraphicalEffects
import qs.config

// Circular media artwork with icon fallback.
Item {
    id: root

    property string source: ""
    property string fallbackIcon: "audio-x-generic-symbolic"
    property int size: Theme.barWidget.compactMediaArtworkSize
    property bool roundedRect: false
    readonly property real cornerRadius: root.roundedRect ? Theme.cornerRadius : (width / 2)
    readonly property int _fallbackIconSize: Math.round(root.size * 0.52)

    implicitWidth: root.size
    implicitHeight: root.size

    // Artwork frame.
    Rectangle {
        anchors.fill: parent
        radius: root.cornerRadius
        color: Qt.rgba(1, 1, 1, 0.05)
        border.color: Colors.border
        border.width: 1
    }

    // Artwork mask container.
    Item {
        id: _maskContainer
        anchors.fill: parent
        layer.enabled: true
        visible: false

        // Artwork mask shape.
        Rectangle {
            anchors.fill: parent
            radius: root.cornerRadius
            color: "white"
        }
    }

    // Artwork image source.
    Image {
        id: _artSource
        anchors.fill: parent
        visible: false
        source: root.source
        fillMode: Image.PreserveAspectCrop
        smooth: true
    }

    Rectangle {
        anchors.fill: parent
        radius: root.cornerRadius
        color: "transparent"
        clip: true
        visible: root.source !== "" && !Theme.graphicalEffectsEnabled

        Image {
            anchors.fill: parent
            source: root.source
            fillMode: Image.PreserveAspectCrop
            smooth: true
        }
    }

    // Artwork masked output.
    OpacityMask {
        anchors.fill: parent
        visible: root.source !== "" && Theme.graphicalEffectsEnabled
        source: _artSource
        maskSource: _maskContainer
    }

    // Fallback note icon.
    Image {
        anchors.centerIn: parent
        visible: root.source === ""
        source: Quickshell.iconPath(root.fallbackIcon, "audio-x-generic")
        sourceSize.width: root._fallbackIconSize
        sourceSize.height: root._fallbackIconSize
        width: root._fallbackIconSize
        height: root._fallbackIconSize
        fillMode: Image.PreserveAspectFit
        opacity: Theme.barWidget.mediaFallbackIconOpacity
    }
}
