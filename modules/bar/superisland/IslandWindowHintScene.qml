import QtQuick
import qs.config
import qs.services
import "." as IslandParts
import "./SuperIslandWindowHintPresentationAdapter.js" as HintPresentationAdapter

// Owns the window-hint scene routing across default and bar-expanded surfaces.
Item {
    id: root

    required property Item card

    readonly property bool _defaultPresentation: HintPresentationAdapter.isDefaultPresentation(root.card.presentationMode)
    readonly property bool _barExpandedCombinedPresentation: HintPresentationAdapter.isBarExpandedCombinedPresentation(root.card.presentationMode)
    readonly property bool _barExpandedMainPresentation: HintPresentationAdapter.isBarExpandedMainPresentation(root.card.presentationMode)
    readonly property bool _barExpandedDetachedPresentation: HintPresentationAdapter.isBarExpandedDetachedPresentation(root.card.presentationMode)
    readonly property bool defaultPresentation: root._defaultPresentation
    readonly property bool barExpandedCombinedPresentation: root._barExpandedCombinedPresentation
    readonly property bool barExpandedMainPresentation: root._barExpandedMainPresentation
    readonly property bool barExpandedDetachedPresentation: root._barExpandedDetachedPresentation
    readonly property Item _activePresentationItem:
        root._defaultPresentation ? _defaultPresentationItem
        : (root._barExpandedCombinedPresentation ? _barExpandedCombinedPresentationItem
            : (root._barExpandedMainPresentation ? _barExpandedMainPresentationItem
                : _barExpandedDetachedPresentationItem))
    readonly property real titleRowImplicitWidth:
        _barExpandedCombinedPresentationItem
            ? _barExpandedCombinedPresentationItem.titleRowImplicitWidth
            : (_barExpandedMainPresentationItem ? _barExpandedMainPresentationItem.titleRowImplicitWidth : 0)
    readonly property real relocatedClockRowY:
        _barExpandedDetachedPresentationItem ? _barExpandedDetachedPresentationItem.relocatedClockRowY : 0
    readonly property real relocatedClockCenterY:
        _barExpandedDetachedPresentationItem ? _barExpandedDetachedPresentationItem.relocatedClockCenterY : 0

    implicitWidth: _activePresentationItem ? _activePresentationItem.implicitWidth : 0
    implicitHeight: _activePresentationItem ? _activePresentationItem.implicitHeight : 0
    width: implicitWidth
    height: implicitHeight

    // Default presentation stays in a thin composition shell.
    IslandParts.IslandWindowHintDefaultPresentation {
        id: _defaultPresentationItem

        anchors.centerIn: parent
        card: root.card
        visible: root._defaultPresentation
    }

    // Combined bar-expanded presentation keeps the title and workspace lanes together.
    IslandParts.IslandWindowHintBarExpandedCombinedPresentation {
        id: _barExpandedCombinedPresentationItem

        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        card: root.card
        visible: root._barExpandedCombinedPresentation
    }

    // Main bar-expanded presentation still owns the widened title lane.
    IslandParts.IslandWindowHintBarExpandedMainPresentation {
        id: _barExpandedMainPresentationItem

        anchors.centerIn: parent
        card: root.card
        visible: root._barExpandedMainPresentation
    }

    // Detached bar-expanded presentation stands alone when the combined shell is inactive.
    IslandParts.IslandWindowHintBarExpandedDetachedPresentation {
        id: _barExpandedDetachedPresentationItem

        anchors.top: parent.top
        anchors.topMargin: root.card._padV + root.card._stagePadV
        anchors.horizontalCenter: parent.horizontalCenter
        card: root.card
        sharedClockActive: root.card.sharedClockActive
        visible: root._barExpandedDetachedPresentation
    }
}
