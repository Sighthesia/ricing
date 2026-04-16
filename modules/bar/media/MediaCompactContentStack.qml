import QtQuick
import qs.config
import "." as MediaParts

// Stacks current, outgoing, and incoming compact media content layers.
Item {
    id: root

    property bool swapActive: false
    property real outgoingOpacity: 1
    property real outgoingY: 0
    property real incomingOpacity: 0
    property real incomingY: 0
    property int artworkSize: Theme.barWidget.pillHeight - Theme.barWidget.contentPaddingV * 2
    property int textMaxWidth: Theme.barWidget.mediaCompactMaxTitleWidth
    property var currentContent: ({ title: "", artist: "", artUrl: "" })
    property var outgoingContent: ({ title: "", artist: "", artUrl: "" })
    property var incomingContent: ({ title: "", artist: "", artUrl: "" })

    implicitWidth: Math.max(_currentLayer.implicitWidth, _outgoingLayer.implicitWidth, _incomingLayer.implicitWidth)
    implicitHeight: Math.max(_currentLayer.implicitHeight, _outgoingLayer.implicitHeight, _incomingLayer.implicitHeight)

    MediaParts.MediaCompactContent {
        id: _currentLayer
        anchors.left: parent.left
        anchors.right: parent.right
        visible: !root.swapActive
        opacity: 1
        y: 0
        title: root.currentContent.title || ""
        artist: root.currentContent.artist || ""
        artUrl: root.currentContent.artUrl || ""
        artworkSize: root.artworkSize
        textMaxWidth: root.textMaxWidth
    }

    MediaParts.MediaCompactContent {
        id: _outgoingLayer
        anchors.left: parent.left
        anchors.right: parent.right
        visible: root.swapActive
        opacity: root.swapActive ? root.outgoingOpacity : 0
        y: root.swapActive ? root.outgoingY : 0
        title: root.outgoingContent.title || ""
        artist: root.outgoingContent.artist || ""
        artUrl: root.outgoingContent.artUrl || ""
        artworkSize: root.artworkSize
        textMaxWidth: root.textMaxWidth
    }

    MediaParts.MediaCompactContent {
        id: _incomingLayer
        anchors.left: parent.left
        anchors.right: parent.right
        visible: root.swapActive
        opacity: root.swapActive ? root.incomingOpacity : 0
        y: root.swapActive ? root.incomingY : 0
        title: root.incomingContent.title || ""
        artist: root.incomingContent.artist || ""
        artUrl: root.incomingContent.artUrl || ""
        artworkSize: root.artworkSize
        textMaxWidth: root.textMaxWidth
    }
}
