import QtQuick
import qs.services

// Stagger wrapper that also animates when a list delegate enters or leaves the viewport.
StaggerItem {
    id: root

    required property Item listView

    property bool trackViewport: true
    property bool scrollAnimationsEnabled: true
    property bool ownerManagedEntry: false
    property string managedEnterKey: ""
    property bool managedEnterJitterEnabled: true
    property real managedEnterStartOpacity: managedEnterFadeEnabled ? 0.38 : 1.0
    property real managedEnterStartOffsetY: Math.round(enterOffsetY * 0.45)
    property int managedEnterBaseDelay: 0
    property int viewportEnterBaseDelay: 0
    property int maxScrollSlots: 6
    property int scrollStep: SettingsService.effectiveAnimation.staggerExitStep
    property int managedEnterStep: SettingsService.effectiveAnimation.staggerLevel2Step
    property real viewportPadding: Math.max(8, enterOffsetY)
    property bool suppressViewportTransitions: ownerManagedEntry
    property bool syncViewportStateWhenSuppressed: false
    property bool managedEnterFadeEnabled: false
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
        if (typeof stopAnimations === "function")
            stopAnimations()

        _viewportShown = viewportVisible
        _viewportInitialized = true
        enterStartOpacity = 0
        enterStartOffsetX = enterOffsetX
        enterStartOffsetY = enterOffsetY
        opacity = viewportVisible ? 1 : 0
        _tx = viewportVisible ? 0 : enterOffsetX
        _ty = viewportVisible ? 0 : enterOffsetY
    }

    function prepareOwnedEnter() {
        _viewportInitialized = true
        _viewportShown = viewportVisible
        enterStartOpacity = managedEnterStartOpacity
        enterStartOffsetX = enterOffsetX
        enterStartOffsetY = managedEnterStartOffsetY
        opacity = enterStartOpacity
        _tx = enterStartOffsetX
        _ty = enterStartOffsetY
    }

    function autoManagedEnter() {
        if (!scrollAnimationsEnabled || !viewportVisible)
            return

        queueManagedEnter(viewportOrder, maxScrollSlots)
    }

    function _boundedWindow(total, step) {
        let cappedTotal = Math.max(0, Math.min(total, maxScrollSlots))
        return Math.max(0, cappedTotal - 1) * step
    }

    function _compressedDelay(rank, total, step) {
        if (total <= 1)
            return 0

        let window = _boundedWindow(total, step)
        return Math.round(window * (rank / Math.max(1, total - 1)))
    }

    function _stableHash(text) {
        let value = String(text || "")
        let hash = 0

        for (let index = 0; index < value.length; index++)
            hash = ((hash * 33) + value.charCodeAt(index)) & 0x7fffffff

        return hash
    }

    function _managedEnterDelay(order, total) {
        let orderedDelay = managedEnterBaseDelay + _compressedDelay(order, total, managedEnterStep)
        if (!managedEnterJitterEnabled)
            return orderedDelay

        let jitter = _stableHash(managedEnterKey) % Math.max(6, Math.round(managedEnterStep * 0.35))
        return orderedDelay + jitter
    }

    function queueManagedEnter(order, total) {
        delay = _managedEnterDelay(order, total)
        _viewportShown = true
        runEnter()
    }

    function _awaitingManagedEnter() {
        return opacity <= (enterStartOpacity + 0.001)
            && Math.abs(_ty - enterStartOffsetY) <= 0.5
    }

    function runViewportEnter() {
        delay = viewportEnterBaseDelay + _compressedDelay(viewportOrder, maxScrollSlots, scrollStep)
        _viewportShown = true
        runEnter()
    }

    function runViewportExit() {
        exitDelay = _compressedDelay(viewportOrder, maxScrollSlots, scrollStep)
        _viewportShown = false
        runExit()
    }

    onViewportVisibleChanged: {
        if (!trackViewport)
            return

        if (suppressViewportTransitions) {
            if (typeof stopAnimations === "function")
                stopAnimations()

            _viewportInitialized = true
            if (syncViewportStateWhenSuppressed)
                syncViewportState()
            else
                _viewportShown = viewportVisible
            return
        }

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

    onSuppressViewportTransitionsChanged: {
        if (suppressViewportTransitions)
            return

        syncViewportState()
    }

    Component.onCompleted: {
        if (ownerManagedEntry) {
            prepareOwnedEnter()
        } else if (suppressViewportTransitions) {
            if (typeof stopAnimations === "function")
                stopAnimations()

            _viewportInitialized = true
            // New delegates created during a suppressed filter/expand window must
            // adopt the current viewport state immediately, but they must not
            // start an independent viewport enter animation.
            syncViewportState()
        } else if (trackViewport && scrollAnimationsEnabled && viewportVisible)
            runViewportEnter()
        else
            syncViewportState()
    }
}
