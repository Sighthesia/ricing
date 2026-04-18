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
    property bool textOnlySwap: false
    property var currentContent: ({ title: "", artist: "", artUrl: "" })
    property var outgoingContent: ({ title: "", artist: "", artUrl: "" })
    property var incomingContent: ({ title: "", artist: "", artUrl: "" })

    readonly property real _fullLayerWidth: Math.max(_currentLayer.implicitWidth, _incomingLayer.implicitWidth)
    readonly property real _textLayerWidth: Math.max(_currentTextLayer.implicitWidth, _incomingTextLayer.implicitWidth)
    implicitWidth: root.textOnlySwap
        ? (_artworkLayer.implicitWidth + (root.showTextStage ? Theme.barWidget.iconLabelSpacing : 0) + _textLayerWidth)
        : _fullLayerWidth
    implicitHeight: root.textOnlySwap
        ? Math.max(_artworkLayer.implicitHeight, _textStage.implicitHeight)
        : Math.max(_currentLayer.implicitHeight, _incomingLayer.implicitHeight)
    readonly property bool showTextStage: _textLayerWidth > 0

    // Static artwork lane for lyric-only swaps.
    MediaParts.MediaCompactContent {
        id: _artworkLayer
        visible: root.textOnlySwap
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        title: root.currentContent.title || ""
        artist: root.currentContent.artist || ""
        artUrl: root.currentContent.artUrl || ""
        artworkSize: root.artworkSize
        textMaxWidth: root.textMaxWidth
        showArtwork: true
        showText: false
    }

    // Text-only stage for lyric-only swaps.
    Item {
        id: _textStage
        visible: root.textOnlySwap
        x: _artworkLayer.implicitWidth + (root.showTextStage ? Theme.barWidget.iconLabelSpacing : 0)
        width: root._textLayerWidth
        implicitWidth: root._textLayerWidth
        implicitHeight: Math.max(_currentTextLayer.implicitHeight, _incomingTextLayer.implicitHeight)
        anchors.verticalCenter: parent.verticalCenter

        MediaParts.MediaCompactContent {
            id: _currentTextLayer
            anchors.left: parent.left
            visible: !root.swapActive
            opacity: 1
            y: 0
            title: root.currentContent.title || ""
            artist: root.currentContent.artist || ""
            artUrl: root.currentContent.artUrl || ""
            artworkSize: root.artworkSize
            textMaxWidth: root.textMaxWidth
            showArtwork: false
            showText: true
        }

        MediaParts.MediaCompactContent {
            id: _outgoingTextLayer
            anchors.left: parent.left
            visible: root.swapActive
            opacity: root.swapActive ? root.outgoingOpacity : 0
            y: root.swapActive ? root.outgoingY : 0
            title: root.outgoingContent.title || ""
            artist: root.outgoingContent.artist || ""
            artUrl: root.outgoingContent.artUrl || ""
            artworkSize: root.artworkSize
            textMaxWidth: root.textMaxWidth
            showArtwork: false
            showText: true
        }

        MediaParts.MediaCompactContent {
            id: _incomingTextLayer
            anchors.left: parent.left
            visible: root.swapActive
            opacity: root.swapActive ? root.incomingOpacity : 0
            y: root.swapActive ? root.incomingY : 0
            title: root.incomingContent.title || ""
            artist: root.incomingContent.artist || ""
            artUrl: root.incomingContent.artUrl || ""
            artworkSize: root.artworkSize
            textMaxWidth: root.textMaxWidth
            showArtwork: false
            showText: true
        }
    }

    MediaParts.MediaCompactContent {
        id: _currentLayer
        anchors.left: parent.left
        visible: !root.textOnlySwap && !root.swapActive
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
        visible: !root.textOnlySwap && root.swapActive
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
        visible: !root.textOnlySwap && root.swapActive
        opacity: root.swapActive ? root.incomingOpacity : 0
        y: root.swapActive ? root.incomingY : 0
        title: root.incomingContent.title || ""
        artist: root.incomingContent.artist || ""
        artUrl: root.incomingContent.artUrl || ""
        artworkSize: root.artworkSize
        textMaxWidth: root.textMaxWidth
    }
}
