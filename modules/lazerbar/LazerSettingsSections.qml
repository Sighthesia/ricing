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
    property bool _ignoreScrollStopped: false
    property bool _ignoreWheelStopped: false
    property int _wheelAnimationPhase: 0
    property real _wheelTargetY: 0
    property real _wheelReturnTarget: 0
    readonly property real overscrollDistance: 88
    readonly property bool wheelAnimationActive: _wheelAnimationPhase !== 0
    readonly property bool wheelOverscrolling: contentY < 0 || contentY > Math.max(0, contentHeight - height)
    readonly property int sectionCount: column.children.length
    readonly property int totalVisibleResultCount: _sumVisible()

    // Sections are injected and stacked vertically in one column.
    default property alias sections: column.data

    contentWidth: width
    contentHeight: _totalContentHeight()
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    property bool _syncingScroll: false

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

    function _interruptProgrammaticScroll() {
        if (!scrollAnim.running && root._programmaticTargetIndex < 0)
            return
        root._ignoreScrollStopped = true
        scrollAnim.stop()
        root._ignoreScrollStopped = false
        root._syncingScroll = false
        root._programmaticTargetIndex = -1
    }

    function _stopWheelAnimation() {
        wheelSettleTimer.stop()
        wheelFrameTimer.stop()
        if (!wheelReturn.running && root._wheelAnimationPhase === 0)
            return
        root._ignoreWheelStopped = true
        wheelReturn.stop()
        root._wheelAnimationPhase = 0
        root._ignoreWheelStopped = false
    }

    function _animateWheelTo(target, returnTarget) {
        var wasReturning = root._wheelAnimationPhase === 2
        root._wheelAnimationPhase = 1
        root._wheelTargetY = target
        root._wheelReturnTarget = returnTarget
        if (Math.abs(target - returnTarget) > 0.5)
            wheelSettleTimer.restart()
        else
            wheelSettleTimer.stop()
        if (wasReturning) {
            root._ignoreWheelStopped = true
            wheelReturn.stop()
            root._ignoreWheelStopped = false
        }
        wheelFrameTimer.start()
    }

    function resetScrollState() {
        root._ignoreScrollStopped = true
        scrollAnim.stop()
        root._ignoreScrollStopped = false
        root._stopWheelAnimation()
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

    onSearchQueryChanged: syncSections()
    onCurrentIndexChanged: syncSections()

    function recomputeCurrent() {
        if (root._syncingScroll)
            return
        if (root._wheelAnimationPhase !== 0)
            return
        if (root.dropdownOpen)
            return
        if (root._programmaticTargetIndex >= 0)
            return
        var children = column.children
        var maximumY = Math.max(0, root.contentHeight - root.height)
        var movedDown = root.contentY > root._lastContentY + 0.5
        if (root.bottomBoundarySuppressed && root.contentY < maximumY - 0.5)
            root.bottomBoundarySuppressed = false
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
            if (root.bottomBoundarySuppressed && root.contentY >= maximumY - 0.5
                    && i === root._lastVisibleSectionIndex())
                continue
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

    WheelHandler {
        orientation: Qt.Vertical
        target: null
        blocking: true
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: wheel => {
            root._interruptProgrammaticScroll()
            var scrollingDown = wheel.angleDelta.y < 0 || wheel.pixelDelta.y < 0
            var maximumY = Math.max(0, root.contentHeight - root.height)
            var delta = wheel.pixelDelta.y
            if (delta === 0)
                delta = wheel.angleDelta.y / 120 * 40
            if (delta === 0)
                return
            var baseY = root._wheelAnimationPhase === 1 ? root._wheelTargetY : root.contentY
            var requestedY = baseY - delta
            var nextContentY = Math.max(-root.overscrollDistance,
                                        Math.min(maximumY + root.overscrollDistance, requestedY))
            var returnTarget = Math.max(0, Math.min(maximumY, nextContentY))
            if (scrollingDown && root.bottomBoundarySuppressed
                    && (root.contentY >= maximumY - 0.5 || nextContentY > maximumY)) {
                root.bottomBoundarySuppressed = false
                var lastIndex = root._lastVisibleSectionIndex()
                if (lastIndex >= 0)
                    root.currentIndex = lastIndex
            }
            root._animateWheelTo(nextContentY, returnTarget)
        }
    }

    // Scroll the target section near the viewport center with an eased motion.
    function scrollTo(index) {
        var children = column.children
        if (index < 0 || index >= children.length)
            return
        var child = children[index]
        if (!child || child.visible === false || child.height <= 0)
            return
        root._stopWheelAnimation()
        root.contentY = Math.max(0, Math.min(Math.max(0, root.contentHeight - root.height), root.contentY))
        var target = child.y - Math.max(0, (root.height - child.height) / 2)
        var maximumY = Math.max(0, root.contentHeight - root.height)
        target = Math.max(0, Math.min(maximumY, target))
        var lastIndex = root._lastVisibleSectionIndex()
        if (target >= maximumY - 0.5 && index !== lastIndex)
            root.bottomBoundarySuppressed = true
        else if (index === lastIndex)
            root.bottomBoundarySuppressed = false
        root._ignoreScrollStopped = true
        scrollAnim.stop()
        root._ignoreScrollStopped = false
        root._syncingScroll = true
        root._programmaticTargetIndex = index
        root.currentIndex = index
        scrollAnim.to = target
        scrollAnim.duration = MotionTokens.reducedMotion ? 0 : 300
        scrollAnim.start()
    }

    Column {
        id: column
        width: root.width
        spacing: 4
    }

    onContentYChanged: root.recomputeCurrent()
    onHeightChanged: root.recomputeCurrent()
    onContentHeightChanged: root.recomputeCurrent()

    NumberAnimation {
        id: scrollAnim
        target: root
        property: "contentY"
        duration: 300
        easing.type: Easing.InOutCubic
        onStopped: {
            if (root._ignoreScrollStopped)
                return
            root._syncingScroll = false
            root.currentIndex = root._programmaticTargetIndex >= 0
                    ? root._programmaticTargetIndex : root.currentIndex
            root._programmaticTargetIndex = -1
            root.recomputeCurrent()
        }
    }

    NumberAnimation {
        id: wheelReturn
        target: root
        property: "contentY"
        easing.type: Easing.InOutCubic
        onStopped: {
            if (root._ignoreWheelStopped || root._wheelAnimationPhase !== 2)
                return
            root._wheelAnimationPhase = 0
            root.contentY = root._wheelReturnTarget
            root._lastContentY = root.contentY
            root.recomputeCurrent()
        }
    }

    // Retarget the current position every frame without restarting an animation.
    Timer {
        id: wheelFrameTimer
        interval: 16
        repeat: true
        onTriggered: {
            if (root._wheelAnimationPhase !== 1)
                return
            var distance = root._wheelTargetY - root.contentY
            if (Math.abs(distance) < 0.5) {
                root.contentY = root._wheelTargetY
                stop()
                if (Math.abs(root._wheelTargetY - root._wheelReturnTarget) > 0.5)
                    wheelSettleTimer.restart()
                else {
                    root._wheelAnimationPhase = 0
                    root._lastContentY = root.contentY
                    root.recomputeCurrent()
                }
                return
            }
            var follow = MotionTokens.reducedMotion ? 1 : 0.32
            root.contentY += distance * follow
        }
    }

    // Hold the edge position briefly so closely spaced wheel ticks stay one motion.
    Timer {
        id: wheelSettleTimer
        interval: MotionTokens.reducedMotion ? 0 : 120
        repeat: false
        onTriggered: {
            if (root._wheelAnimationPhase !== 1)
                return
            root._ignoreWheelStopped = true
            wheelFrameTimer.stop()
            root._ignoreWheelStopped = false
            root._wheelAnimationPhase = 2
            wheelReturn.from = root.contentY
            wheelReturn.to = root._wheelReturnTarget
            wheelReturn.duration = MotionTokens.reducedMotion ? 0 : 340
            wheelReturn.start()
        }
    }
}
