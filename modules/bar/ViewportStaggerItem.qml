import QtQuick
import qs.services

// Stagger wrapper that also animates when a list delegate enters or leaves the viewport.
StaggerItem {
    id: root

    required property Item listView

    property bool trackViewport: true
    property bool scrollAnimationsEnabled: true
    property bool ownerManagedEntry: false
    property int maxScrollSlots: 6
    property int scrollStep: SettingsService.data.animation.staggerExitStep
    property real viewportPadding: Math.max(8, enterOffsetY)

    readonly property real _contentY:
        listView && listView.contentY !== undefined ? Number(listView.contentY) : 0
    readonly property bool viewportVisible: {
        if (!trackViewport || !listView)
            return true

        if (height <= 0)
            return false

        let topBoundary = _contentY - viewportPadding
        let bottomBoundary = _contentY + listView.height + viewportPadding
        let itemTop = y
        let itemBottom = itemTop + height
        return itemBottom > topBoundary && itemTop < bottomBoundary
    }
    readonly property int viewportOrder: {
        if (!trackViewport || !listView || height <= 0)
            return 0

        let relativeTop = y - _contentY
        let slot = Math.round(relativeTop / Math.max(1, height))
        return Math.max(0, Math.min(maxScrollSlots - 1, slot))
    }

    property bool _viewportInitialized: false
    property bool _viewportShown: false

    function syncViewportState() {
        _viewportShown = viewportVisible
        _viewportInitialized = true
        opacity = viewportVisible ? 1 : 0
        _ty = viewportVisible ? 0 : enterOffsetY
    }

    function prepareOwnedEnter() {
        _viewportInitialized = true
        _viewportShown = viewportVisible
        opacity = 0
        _ty = enterOffsetY
    }

    function runViewportEnter() {
        delay = viewportOrder * scrollStep
        _viewportShown = true
        runEnter()
    }

    function runViewportExit() {
        exitDelay = viewportOrder * scrollStep
        _viewportShown = false
        runExit()
    }

    onViewportVisibleChanged: {
        if (!trackViewport)
            return

        if (!_viewportInitialized || !scrollAnimationsEnabled) {
            syncViewportState()
            return
        }

        if (viewportVisible === _viewportShown)
            return

        if (viewportVisible)
            runViewportEnter()
        else
            runViewportExit()
    }

    onScrollAnimationsEnabledChanged: {
        if (!scrollAnimationsEnabled && trackViewport)
            syncViewportState()
    }

    Component.onCompleted: {
        if (ownerManagedEntry)
            prepareOwnedEnter()
        else if (trackViewport && scrollAnimationsEnabled && viewportVisible)
            runViewportEnter()
        else
            syncViewportState()
    }
}
