import QtQuick

// Scroll every category section in one flat column, tracking the section
// under the viewport center and offering animated navigation to any section.
Flickable {
    id: root

    property bool interactive: true
    property string searchQuery: ""
    property int currentIndex: 0
    property bool dropdownOpen: false
    property bool bottomBoundarySuppressed: false
    property real _lastContentY: 0
    property int _programmaticTargetIndex: -1
    readonly property int sectionCount: column.children.length
    readonly property int totalVisibleResultCount: _sumVisible()
    readonly property real overscrollDistance: 88
    readonly property bool edgeBouncing: edgeBounce.running

    // Sections are injected and stacked vertically in one column.
    default property alias sections: column.data

    contentWidth: width
    contentHeight: _totalContentHeight()
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    flickDeceleration: 2000

    property bool _syncingScroll: false
    property int _deferredScrollIndex: -1

    // True while any section or row is still armed or revealing from the
    // open-session wave; layout keeps shifting so viewport tracking pauses.
    readonly property bool entranceWaveActive: _anyHolderActive()

    // Stay busy until the final reveal transitions have fully landed.
    readonly property bool entranceBusy: entranceWaveActive || settleTimer.running

    Timer {
        id: settleTimer
        // Cover the trailing reveal transitions plus the stagger tail.
        interval: MotionTokens.slow + MotionTokens.slow / 2 + 100
        repeat: false
    }

    function _anyHolderActive() {
        var children = column.children
        for (var i = 0; i < children.length; i++) {
            var section = children[i]
            if (section.revealHeld === true || section.snapTransitions === true)
                return true
            var rows = section.contentRows || []
            for (var r = 0; r < rows.length; r++) {
                if (rows[r].revealHeld === true || rows[r].snapTransitions === true)
                    return true
            }
        }
        return false
    }

    onEntranceWaveActiveChanged: {
        if (root.entranceWaveActive)
            settleTimer.stop()
        else
            settleTimer.restart()
    }

    // Once the wave settles, land any deferred navigation or re-sync the
    // browsed section with wherever the user scrolled in the meantime.
    onEntranceBusyChanged: {
        if (root.entranceBusy)
            return
        if (root._deferredScrollIndex >= 0) {
            var deferred = root._deferredScrollIndex
            root._deferredScrollIndex = -1
            root.scrollTo(deferred)
        } else {
            root.recomputeCurrent()
        }
    }

    // Sum the actual heights of the sections that remain on screen.
    function _totalContentHeight() {
        var total = 0
        var children = column.children
        for (var i = 0; i < children.length; i++) {
            if (children[i].visible === false)
                continue
            total += Math.max(0, Number(children[i].height))
            total += column.spacing
        }
        return total > 0 ? total - column.spacing : 0
    }

    function _sumVisible() {
        var total = 0
        var children = column.children
        for (var i = 0; i < children.length; i++) {
            if (children[i].visibleResultCount !== undefined)
                total += children[i].visibleResultCount
        }
        return total
    }

    function _lastVisibleSectionIndex() {
        var children = column.children
        for (var i = children.length - 1; i >= 0; i--) {
            if (children[i].visible !== false && children[i].height > 0)
                return i
        }
        return -1
    }

    // Reset scroll position and boundary state for a fresh session.
    function resetScrollState() {
        edgeBounce.stop()
        scrollAnim.stop()
        root._syncingScroll = false
        root._programmaticTargetIndex = -1
        root.bottomBoundarySuppressed = false
        root.currentIndex = 0
        root._lastContentY = 0
        root.contentY = 0
    }

    // Forward the shared query and the browsed-section state to every section.
    function syncSections() {
        var children = column.children
        for (var i = 0; i < children.length; i++) {
            if (children[i].searchQuery !== undefined)
                children[i].searchQuery = root.searchQuery
            if (children[i].sectionActive !== undefined)
                children[i].sectionActive = i === root.currentIndex
        }
    }

    // Play the open-session wave: sections then rows appear top-to-bottom.
    function playEntranceWave() {
        if (MotionTokens.reducedMotion)
            return
        var baseDelay = 120
        var slotInterval = 18
        var slot = 0
        var children = column.children
        for (var i = 0; i < children.length; i++) {
            var section = children[i]
            if (section.holdInstantly === undefined)
                continue
            section.holdInstantly()
            section.playReveal(baseDelay + slot * slotInterval)
            slot++
            var rows = section.contentRows || []
            for (var r = 0; r < rows.length; r++) {
                if (rows[r].holdInstantly === undefined)
                    continue
                rows[r].holdInstantly()
                rows[r].playReveal(baseDelay + slot * slotInterval)
                slot++
            }
        }
    }

    // Cancel an unfinished wave, restoring every holder instantly.
    function cancelEntranceWave() {
        var children = column.children
        for (var i = 0; i < children.length; i++) {
            var section = children[i]
            if (section.releaseInstantly === undefined)
                continue
            if (section.revealHeld === true || section.snapTransitions === true)
                section.releaseInstantly()
            var rows = section.contentRows || []
            for (var r = 0; r < rows.length; r++) {
                if (rows[r].releaseInstantly === undefined)
                    continue
                if (rows[r].revealHeld === true || rows[r].snapTransitions === true)
                    rows[r].releaseInstantly()
            }
        }
    }

    onSearchQueryChanged: syncSections()
    onCurrentIndexChanged: syncSections()

    function recomputeCurrent() {
        if (root._syncingScroll)
            return
        if (root.dropdownOpen)
            return
        if (root.entranceBusy)
            return
        if (root._programmaticTargetIndex >= 0)
            return
        var children = column.children
        var maximumY = Math.max(0, root.contentHeight - root.height)
        var movedDown = root.contentY > root._lastContentY + 0.5
        if (root.bottomBoundarySuppressed && movedDown)
            root.bottomBoundarySuppressed = false
        var center = root.contentY + root.height / 2
        var found = -1

        // At the lower bound the viewport center may still be above a short
        // final section. Treat the boundary as an explicit final-section cue.
        if (maximumY > 0 && root.contentY >= maximumY - 0.5 && !root.bottomBoundarySuppressed) {
            for (var last = children.length - 1; last >= 0; last--) {
                if (children[last].visible !== false && children[last].height > 0) {
                    found = last
                    break
                }
            }
        }

        for (var i = 0; i < children.length; i++) {
            if (found >= 0)
                break
            var child = children[i]
            if (child.visible !== false && child.height > 0
                    && center >= child.y && center <= child.y + child.height) {
                found = i
                break
            }
        }
        if (found >= 0 && found !== root.currentIndex)
            root.currentIndex = found
        root._lastContentY = root.contentY
    }

    // Push past the scroll edge on continued wheel input, then settle back.
    function _requestEdgeOvershoot(delta) {
        if (MotionTokens.reducedMotion || scrollAnim.running || root._syncingScroll)
            return
        var maximumY = Math.max(0, root.contentHeight - root.height)
        var proposed = Math.max(-root.overscrollDistance,
                                Math.min(maximumY + root.overscrollDistance,
                                         root.contentY - delta))
        if (edgeBounce.running) {
            var furtherOut = delta > 0 ? proposed < edgeOut.to : proposed > edgeOut.to
            if (!furtherOut)
                return
            edgeBounce.stop()
        }
        edgeOut.from = root.contentY
        edgeOut.to = proposed
        edgeBack.to = Math.max(0, Math.min(maximumY, proposed))
        edgeBounce.start()
    }

    WheelHandler {
        orientation: Qt.Vertical
        target: null
        blocking: false
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: wheel => {
            root._deferredScrollIndex = -1
            root._programmaticTargetIndex = -1
            var scrollingDown = wheel.angleDelta.y < 0 || wheel.pixelDelta.y < 0
            var maximumY = Math.max(0, root.contentHeight - root.height)
            if (scrollingDown && root.bottomBoundarySuppressed
                    && root.contentY >= maximumY - 0.5) {
                root.bottomBoundarySuppressed = false
                var lastIndex = root._lastVisibleSectionIndex()
                if (lastIndex >= 0)
                    root.currentIndex = lastIndex
            }
            var delta = wheel.pixelDelta.y
            if (delta === 0)
                delta = wheel.angleDelta.y / 120 * 40
            if (delta === 0)
                return
            if (!scrollingDown && root.contentY <= 0.5)
                root._requestEdgeOvershoot(delta)
            else if (scrollingDown && root.contentY >= maximumY - 0.5)
                root._requestEdgeOvershoot(delta)
        }
    }

    // Scroll the target section near the viewport center with an eased motion.
    function scrollTo(index) {
        if (index < 0 || index >= column.children.length)
            return
        if (root.entranceBusy) {
            // Layout is still expanding; land the motion once the wave ends,
            // but lock the selection state immediately so nothing overrides it.
            root._deferredScrollIndex = index
            root._programmaticTargetIndex = index
            root.currentIndex = index
            return
        }
        var child = column.children[index]
        if (!child || child.visible === false || child.height <= 0)
            return
        edgeBounce.stop()
        var target = child.y - Math.max(0, (root.height - child.height) / 2)
        target = Math.max(0, Math.min(Math.max(0, root.contentHeight - root.height), target))
        root._syncingScroll = true
        root._programmaticTargetIndex = index
        root.currentIndex = index
        scrollAnim.stop()
        scrollAnim.to = target
        scrollAnim.duration = MotionTokens.reducedMotion ? 0 : 300
        scrollAnim.start()
    }

    Column {
        id: column
        width: root.width
        spacing: 0
    }

    onContentYChanged: root.recomputeCurrent()
    onHeightChanged: root.recomputeCurrent()
    onContentHeightChanged: root.recomputeCurrent()

    // Manual scrolling always wins over a pending wave-time navigation.
    onMovementStarted: {
        root._deferredScrollIndex = -1
        root._programmaticTargetIndex = -1
    }

    NumberAnimation {
        id: scrollAnim
        target: root
        property: "contentY"
        duration: 300
        easing.type: Easing.OutQuint
        onStopped: {
            root._syncingScroll = false
            root.currentIndex = root._programmaticTargetIndex >= 0
                    ? root._programmaticTargetIndex : root.currentIndex
            root._programmaticTargetIndex = -1
            root.recomputeCurrent()
        }
    }

    // Push past the edge, then spring back to the clamped position.
    SequentialAnimation {
        id: edgeBounce
        NumberAnimation {
            id: edgeOut
            target: root
            property: "contentY"
            duration: MotionTokens.reducedMotion ? 0 : 160
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            id: edgeBack
            target: root
            property: "contentY"
            duration: MotionTokens.reducedMotion ? 0 : 260
            easing.type: Easing.InOutCubic
        }
        onFinished: {
            root._lastContentY = root.contentY
            root.recomputeCurrent()
        }
    }
}
