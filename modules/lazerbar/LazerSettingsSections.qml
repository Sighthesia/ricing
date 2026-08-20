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
    readonly property int sectionCount: column.children.length
    readonly property int totalVisibleResultCount: _sumVisible()

    // Sections are injected and stacked vertically in one column.
    default property alias sections: column.data

    contentWidth: width
    contentHeight: _totalContentHeight()
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    flickDeceleration: 2000

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

    function resetScrollState() {
        root._ignoreScrollStopped = true
        scrollAnim.stop()
        root._ignoreScrollStopped = false
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
            var nextContentY = Math.max(0, Math.min(maximumY, root.contentY - delta))
            if (nextContentY !== root.contentY)
                root.contentY = nextContentY
            if (scrollingDown && root.bottomBoundarySuppressed
                    && root.contentY >= maximumY - 0.5) {
                root.bottomBoundarySuppressed = false
                var lastIndex = root._lastVisibleSectionIndex()
                if (lastIndex >= 0)
                    root.currentIndex = lastIndex
            }
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
        easing.type: Easing.OutQuint
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
}
