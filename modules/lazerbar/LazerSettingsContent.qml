import QtQuick
import QtQuick.Effects
import "LazerSettingsLogic.js" as Logic

// Own the settings content chrome: search, category title, viewport, footer,
// plus the top-level tooltip and dropdown overlay layers for row controls.
Item {
    id: root

    property string title: ""
    property string searchQuery: ""
    property bool interactive: true
    property bool contentReady: false
    property bool expanded: true
    property int visibleResultCount: 0
    property real backgroundExtend: 170
    property Item currentPage: null
    property bool dropdownOpen: false
    readonly property bool emptyStateVisible:
        Logic.normalizeSearchQuery(searchQuery).length > 0 && visibleResultCount === 0
    readonly property bool canScrollDown: currentPage && currentPage.contentHeight - currentPage.contentY - viewport.height > 8
    readonly property bool dropdownVisible: dropdownOpen

    // Active tooltip request state, owned by this content instance only. The
    // bridge transports requests; per-screen ownership stays here.
    property var activeTooltipSource: null
    property string activeTooltipText: ""
    property int activeTooltipPriority: 0
    property bool tooltipVisible: false
    property var _tooltipSourceRect: ({ x: 0, y: 0, width: 0, height: 0 })
    property var _tooltipBoundsRect: ({ x: 0, y: 0, width: 0, height: 0 })

    signal searchQueryEdited(string query)
    property alias searchEditor: searchEditor
    property alias searchSurfaceItem: searchSurface
    property alias tooltipItem: tooltip
    property alias tooltipTextItem: tooltipText
    property alias tooltipPlacementSide: tooltip.placementSide

    // Keep the persistent category pages mounted inside the clipped viewport.
    default property alias viewportChildren: viewport.data

    // Mirror externally cleared queries without fighting the active editor.
    onSearchQueryChanged: {
        if (searchEditor.text !== root.searchQuery)
            searchEditor.text = root.searchQuery
        root.closeDropdownMenu()
        root.hideTooltip()
    }

    onCurrentPageChanged: {
        root.closeDropdownMenu()
        root.hideTooltip()
    }

    onInteractiveChanged: {
        if (!root.interactive) {
            root.closeDropdownMenu()
            root.hideTooltip()
        }
    }

    onContentReadyChanged: {
        if (!root.contentReady)
            root.closeActiveTooltip()
    }

    // Re-evaluate tooltip placement whenever the content viewport geometry
    // changes (e.g. sidebar collapse on a narrow panel).
    onWidthChanged: root.repositionTooltip()
    onHeightChanged: root.repositionTooltip()

    function focusSearch() {
        if (root.interactive && root.contentReady)
            searchEditor.forceActiveFocus()
    }

    // Extend the content background leftward so the slide never reveals gaps.
    Rectangle {
        x: -root.backgroundExtend
        width: root.width + root.backgroundExtend
        height: root.height
        color: LazerTheme.settingsPanel
        Behavior on x { enabled: !MotionTokens.reducedMotion; NumberAnimation { duration: MotionTokens.settingsSidebarCollapse; easing.type: Easing.OutQuint } }
        Behavior on width { enabled: !MotionTokens.reducedMotion; NumberAnimation { duration: MotionTokens.settingsSidebarCollapse; easing.type: Easing.OutQuint } }
    }

    // Present the category title below the search field as the sole page heading.
    Item {
        id: header
        x: 0
        y: searchArea.height
        width: root.width
        height: 48

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            text: root.title
            color: LazerTheme.textPrimary
            font.pixelSize: 18
            font.weight: Font.DemiBold
        }

    }

    // Keep the borderless search field at the top of the content surface.
    Item {
        id: searchArea
        x: 0
        y: 0
        width: root.width
        height: 52

        Rectangle {
            id: searchSurface
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            anchors.topMargin: 2
            anchors.bottomMargin: 2
            radius: 6
            color: LazerTheme.settingsSearchSurface
            border.width: 0
            border.color: "transparent"
            Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
        }

        Image {
            id: searchIcon
            anchors.right: searchSurface.right
            anchors.rightMargin: 14
            anchors.verticalCenter: searchSurface.verticalCenter
            width: 15
            height: 15
            source: "icons/search.svg"
            fillMode: Image.PreserveAspectFit
            visible: searchEditor.text.length === 0
            Behavior on opacity { NumberAnimation { duration: MotionTokens.fast } }
        }
        MultiEffect {
            anchors.fill: searchIcon
            source: searchIcon
            visible: searchIcon.visible
            colorization: 1
            colorizationColor: LazerTheme.textMuted
        }

        TextInput {
            id: searchEditor
            anchors.left: searchSurface.left
            anchors.leftMargin: 12
            anchors.right: searchSurface.right
            anchors.rightMargin: 38
            anchors.verticalCenter: searchSurface.verticalCenter
            clip: true
            enabled: root.interactive && root.contentReady
            color: LazerTheme.textPrimary
            selectionColor: LazerTheme.settingsAccent
            font.pixelSize: 13
            activeFocusOnTab: root.interactive && root.contentReady
            onTextEdited: root.searchQueryEdited(searchEditor.text)
        }

        Text {
            anchors.left: searchEditor.left
            anchors.verticalCenter: searchEditor.verticalCenter
            visible: !searchEditor.text && !searchEditor.activeFocus
            text: "输入以搜索"
            color: LazerTheme.textMuted
            font.pixelSize: 13
        }

        // Clear the query in place without leaving the search field.
        Item {
            id: searchClearButton
            anchors.right: searchSurface.right
            anchors.rightMargin: 8
            anchors.verticalCenter: searchSurface.verticalCenter
            width: 24
            height: 24
            visible: searchEditor.text.length > 0
            enabled: root.interactive && root.contentReady
            activeFocusOnTab: false

            scale: clearPress.pressed ? MotionTokens.pressScale : 1
            Behavior on scale { enabled: !MotionTokens.reducedMotion; NumberAnimation { duration: MotionTokens.fast } }

            Rectangle {
                anchors.fill: parent
                radius: 12
                color: clearHover.hovered ? LazerTheme.settingsRowHover : "transparent"
                Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
            }
            Image {
                id: clearIcon
                anchors.centerIn: parent
                width: 12
                height: 12
                source: "icons/close.svg"
                fillMode: Image.PreserveAspectFit
            }
            MultiEffect {
                anchors.fill: clearIcon
                source: clearIcon
                visible: clearIcon.visible
                colorization: 1
                colorizationColor: clearHover.hovered ? LazerTheme.textPrimary : LazerTheme.textMuted
                Behavior on colorizationColor { ColorAnimation { duration: MotionTokens.fast } }
            }
            HoverHandler { id: clearHover; enabled: searchClearButton.enabled && searchClearButton.visible }
            TapHandler {
                id: clearPress
                enabled: searchClearButton.enabled && searchClearButton.visible
                onTapped: {
                    searchEditor.text = ""
                    root.searchQueryEdited("")
                    searchEditor.forceActiveFocus()
                }
            }
        }

        HoverHandler { id: searchHover; enabled: root.interactive }
        TapHandler { enabled: root.interactive; onTapped: searchEditor.forceActiveFocus() }
    }

    // Scroll the mounted category pages between the search field and footer.
    Item {
        id: viewport
        x: 0
        y: header.y + header.height
        width: root.width
        height: Math.max(0, root.height - searchArea.height - header.height - footer.height)
        clip: true
    }

    // Reveal a scroll shadow once the current page can scroll further down.
    Rectangle {
        id: scrollShadow
        anchors.left: viewport.left
        anchors.right: viewport.right
        anchors.bottom: viewport.bottom
        height: 22
        opacity: root.canScrollDown ? 1 : 0
        gradient: Gradient {
            GradientStop { position: 0; color: "#00000000" }
            GradientStop { position: 1; color: "#55000000" }
        }
        Behavior on opacity { NumberAnimation { duration: MotionTokens.medium; easing.type: Easing.OutQuint } }
    }

    // Present a clear message when the current category has no matches.
    Item {
        id: emptyState
        anchors.fill: viewport
        visible: root.emptyStateVisible

        Column {
            anchors.centerIn: parent
            spacing: 4

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "没有匹配的设置"
                color: LazerTheme.textPrimary
                font.pixelSize: 15
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "尝试其他关键词"
                color: LazerTheme.textMuted
                font.pixelSize: 12
            }
        }
    }

    // Close the content with static info and the keyboard hint.
    Item {
        id: footer
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 44
    }

    // Present the hover/focus description or slider value near its source.
    // Size is driven by the Text's own measurement: the Text provides its
    // natural width, is clamped to a target wrap width, then its wrapped
    // implicit height decides the surface height. The Rectangle only paints
    // the already-measured surface and never contributes an implicit size.
    Item {
        id: tooltip
        z: 20
        visible: false
        opacity: 0
        readonly property real hPadding: 6
        readonly property real vPadding: 6
        readonly property real sideMargin: 10
        readonly property real minSurfaceWidth: 24
        readonly property real gap: 6
        readonly property real availableSurfaceWidth:
            Logic.tooltipAvailableSurfaceWidth(viewport.width, sideMargin, hPadding)
        readonly property real surfaceWidth:
            Logic.tooltipSurfaceWidth(tooltipText.implicitWidth, LazerTheme.tooltipMaxWidth,
                                      availableSurfaceWidth, hPadding, minSurfaceWidth)
        readonly property real textWidth: Math.max(0, surfaceWidth - 2 * hPadding)
        readonly property real surfaceHeight: tooltipText.implicitHeight + 2 * vPadding
        readonly property var placement:
            root.tooltipVisible
                ? Logic.tooltipPlacement(root._tooltipSourceRect, width, height,
                                         root._tooltipBoundsRect, gap)
                : ({ x: 0, y: 0, side: "below" })
        readonly property string placementSide: placement.side
        readonly property real targetX: placement.x
        readonly property real targetY: placement.y
        width: surfaceWidth
        height: surfaceHeight
        x: targetX
        y: targetY

        Rectangle {
            id: tooltipSurface
            anchors.fill: parent
            radius: 6
            color: LazerTheme.tooltipBackground
            border.width: 1
            border.color: LazerTheme.tooltipBorder
        }

        Text {
            id: tooltipText
            x: tooltip.hPadding
            y: tooltip.vPadding
            width: tooltip.textWidth
            text: root.activeTooltipText
            color: LazerTheme.textPrimary
            font.pixelSize: 12
            wrapMode: Text.WordWrap
        }

        // Fade the surface in/out; geometry updates never lag behind opacity.
        NumberAnimation {
            id: tooltipOpacityAnimation
            target: tooltip
            property: "opacity"
            onFinished: {
                if (!root.tooltipVisible)
                    tooltip.visible = false
            }
        }
    }

    // Own the real dropdown menu and its outside-click catcher on a top layer.
    // The layer visibility follows the content state (not the child menu's
    // visible, which would create a circular binding that resets the menu).
    Item {
        id: dropdownLayer
        z: 30
        anchors.fill: parent
        visible: root.dropdownOpen

        // Close the menu when the pointer lands outside it.
        Item {
            id: menuCatcher
            anchors.fill: parent
            TapHandler {
                enabled: dropdownMenu.visible
                onTapped: eventPoint => root.handleDropdownTap(eventPoint.position)
            }
        }

        SettingsDropdownMenu {
            id: dropdownMenu
            z: 1
            onItemSelected: value => root.selectDropdownValue(value)
            onClosed: root.onMenuClosed()
        }
    }

    function hideTooltip() {
        root.closeActiveTooltip()
    }

    // Map the source rect into this content's local coordinate domain. Never
    // mix screen coordinates with local ones.
    function mappedSourceRect(source) {
        var pos = source.mapToItem(root, 0, 0)
        var x = isFinite(Number(pos.x)) ? Number(pos.x) : 0
        var y = isFinite(Number(pos.y)) ? Number(pos.y) : 0
        var w = isFinite(Number(source.width)) ? Math.max(0, Number(source.width)) : 0
        var h = isFinite(Number(source.height)) ? Math.max(0, Number(source.height)) : 0
        return { x: x, y: y, width: w, height: h }
    }

    // Keep every tooltip inside the page viewport so it never covers the
    // header, search field, or footer.
    function tooltipBoundsRect() {
        return {
            x: viewport.x + tooltip.sideMargin,
            y: viewport.y,
            width: Math.max(0, viewport.width - 2 * tooltip.sideMargin),
            height: viewport.height,
        }
    }

    function tooltipSourceVisible(source) {
        var cursor = source
        while (cursor) {
            if (cursor.visible === false)
                return false
            cursor = cursor.parent
        }
        return true
    }

    // Recompute the cached source/bounds rects and enforce the visibility
    // contract: a source that fully leaves the viewport closes the tooltip.
    function repositionTooltip() {
        if (!root.tooltipVisible || !root.activeTooltipSource)
            return
        root._tooltipSourceRect = root.mappedSourceRect(root.activeTooltipSource)
        root._tooltipBoundsRect = root.tooltipBoundsRect()
        if (!root.tooltipSourceVisible(root.activeTooltipSource)
                || !Logic.rectsIntersect(root._tooltipSourceRect, root._tooltipBoundsRect)) {
            root.closeActiveTooltip()
            return
        }
        // Placement recomputes through the declarative binding on the new rects.
    }

    function setActiveTooltip(text, source, priority) {
        var sameSource = root.tooltipVisible && root.activeTooltipSource === source
        root.activeTooltipSource = source
        root.activeTooltipText = text
        root.activeTooltipPriority = priority
        root.tooltipVisible = true
        root.repositionTooltip()
        if (root.tooltipVisible && !sameSource)
            root.showTooltipSurface()
    }

    function showTooltipSurface() {
        tooltipOpacityAnimation.stop()
        if (!tooltip.visible) {
            tooltip.opacity = 0
            tooltip.visible = true
        }
        if (MotionTokens.reducedMotion) {
            tooltip.opacity = 1
        } else {
            tooltipOpacityAnimation.duration = MotionTokens.tooltipIn
            tooltipOpacityAnimation.to = 1
            tooltipOpacityAnimation.start()
        }
    }

    function closeActiveTooltip() {
        if (!root.tooltipVisible)
            return
        root.tooltipVisible = false
        tooltipOpacityAnimation.stop()
        if (MotionTokens.reducedMotion || !tooltip.visible) {
            tooltip.visible = false
            tooltip.opacity = 0
        } else {
            tooltipOpacityAnimation.duration = MotionTokens.tooltipOut
            tooltipOpacityAnimation.to = 0
            tooltipOpacityAnimation.start()
        }
        root.activeTooltipSource = null
        root.activeTooltipText = ""
        root.activeTooltipPriority = 0
    }

    // Accept requests only for sources mounted under this content; external
    // screen requests are ignored without disturbing the local tooltip.
    function handleTooltipRequest(text, source, priority) {
        if (!root.ownsOverlaySource(source))
            return
        if (!root.interactive || !root.contentReady) {
            if (root.activeTooltipSource === source)
                root.closeActiveTooltip()
            return
        }
        var p = priority === undefined ? 1 : Number(priority)
        if (!isFinite(p) || p < 1)
            p = 1
        // Keep the current owner stable. Equal-priority hover/focus requests
        // remain registered for deterministic fallback instead of stealing it.
        if (root.activeTooltipSource && root.activeTooltipSource !== source
                && p <= root.activeTooltipPriority) {
            return
        }
        root.setActiveTooltip(text, source, p)
    }

    function handleTooltipDismiss(source) {
        if (source === null) {
            root.closeActiveTooltip()
            return
        }
        if (!root.ownsOverlaySource(source))
            return
        if (root.activeTooltipSource === source)
            root.applyBridgeFallback()
    }

    // After a dismiss, fall back to the best request still owned by this
    // content instead of leaving a stale or empty surface.
    function applyBridgeFallback() {
        var best = root.ownedBestTooltipRequest()
        if (best && best.text && root.interactive && root.contentReady)
            root.setActiveTooltip(best.text, best.source, best.priority)
        else
            root.closeActiveTooltip()
    }

    function ownedBestTooltipRequest() {
        var requests = SettingsOverlayBridge.allTooltipRequests()
        var best = null
        for (var i = 0; i < requests.length; i++) {
            var req = requests[i]
            if (!req.text || !req.source || !root.ownsOverlaySource(req.source))
                continue
            if (!best || req.priority > best.priority)
                best = req
        }
        return best
    }

    // Accept overlay requests only from controls mounted under this screen's content.
    function ownsOverlaySource(source) {
        var cursor = source
        while (cursor) {
            if (cursor === root)
                return true
            cursor = cursor.parent
        }
        return false
    }

    function closeDropdownMenu() {
        root.dropdownOpen = false
        if (dropdownMenu.choiceItem)
            dropdownMenu.choiceItem.closeMenu()
        else
            dropdownMenu.close()
    }

    function handleDropdownTap(position) {
        var choice = dropdownMenu.choiceItem
        if (choice) {
            var header = choice.headerItem || choice
            var origin = header.mapToItem(root, 0, 0)
            if (position.x >= origin.x && position.x <= origin.x + header.width
                    && position.y >= origin.y && position.y <= origin.y + header.height) {
                choice.closeMenu()
                return
            }
        }
        root.closeDropdownMenu()
    }

    function selectDropdownValue(value) {
        var choice = dropdownMenu.choiceItem
        if (!choice)
            return
        choice.selectValue(value)
        dropdownMenu.close()
    }

    function onMenuClosed() {
        root.dropdownOpen = false
        if (dropdownMenu.choiceItem) {
            dropdownMenu.choiceItem.menuOpen = false
            dropdownMenu.choiceItem.focusHeader()
            dropdownMenu.choiceItem = null
        }
    }

    function showDropdownFor(choiceItem) {
        if (!root.interactive || !root.contentReady || !root.ownsOverlaySource(choiceItem)) {
            hideTooltip()
            return
        }
        hideTooltip()
        if (dropdownMenu.choiceItem && dropdownMenu.choiceItem !== choiceItem) {
            dropdownMenu.choiceItem.menuOpen = false
            dropdownMenu.choiceItem = null
        }
        dropdownMenu.choiceItem = choiceItem
        dropdownMenu.model = choiceItem.model
        dropdownMenu.currentValue = choiceItem.currentValue
        var header = choiceItem.headerItem || choiceItem
        var pos = header.mapToItem(root, 0, 0)
        var menuHeight = Math.min(LazerTheme.dropdownMaxHeight, choiceItem.model.length * 30 + 8)
        dropdownMenu.x = Logic.clamp(pos.x, 0, Math.max(0, root.width - header.width))
        dropdownMenu.width = header.width
        dropdownMenu.y = pos.y + header.height
        dropdownMenu.height = menuHeight
        dropdownMenu.open()
        root.dropdownOpen = true
        dropdownMenu.forceActiveFocus()
    }

    // Follow the active source's own geometry and visibility changes. The
    // connection retargets automatically whenever the active source changes.
    // The source is also revalidated on every parent/viewport geometry update,
    // so detached or stale sources cannot keep a visible tooltip alive.
    Connections {
        id: tooltipSourceConnections
        target: root.activeTooltipSource
        function onXChanged() { root.repositionTooltip() }
        function onYChanged() { root.repositionTooltip() }
        function onWidthChanged() { root.repositionTooltip() }
        function onHeightChanged() { root.repositionTooltip() }
        function onVisibleChanged() { root.repositionTooltip() }
        function onParentChanged() { root.repositionTooltip() }
    }

    // Removing a source from a dynamic page does not necessarily emit a
    // geometry or visibility notification on the source itself. Its former
    // parent does emit childrenChanged, which gives the active request a
    // deterministic lifecycle check without relying on a stale QObject.
    Connections {
        target: root.activeTooltipSource ? root.activeTooltipSource.parent : null
        function onChildrenChanged() { root.repositionTooltip() }
    }

    // A parent transform or layout change can move a source without changing
    // the source's own x/y. Track the current page and the clipping viewport
    // in the same local coordinate domain used by mappedSourceRect().
    Connections {
        target: viewport
        function onXChanged() { root.repositionTooltip() }
        function onYChanged() { root.repositionTooltip() }
        function onWidthChanged() { root.repositionTooltip() }
        function onHeightChanged() { root.repositionTooltip() }
        function onVisibleChanged() { root.repositionTooltip() }
    }

    // Reposition (and possibly close) while the page scrolls; the source's own
    // y does not change, so this connection owns scroll following.
    Connections {
        target: root.currentPage
        function onXChanged() { root.repositionTooltip() }
        function onYChanged() { root.repositionTooltip() }
        function onWidthChanged() { root.repositionTooltip() }
        function onHeightChanged() { root.repositionTooltip() }
        function onVisibleChanged() { root.repositionTooltip() }
        function onContentHeightChanged() { root.repositionTooltip() }
        function onContentYChanged() {
            root.closeDropdownMenu()
            root.repositionTooltip()
        }
    }

    Connections {
        target: SettingsOverlayBridge
        function onTooltipRequested(text, source, priority) { root.handleTooltipRequest(text, source, priority) }
        function onTooltipDismissed(source) { root.handleTooltipDismiss(source) }
        function onDropdownRequested(choiceItem) { root.showDropdownFor(choiceItem) }
        function onDropdownDismissed(choiceItem) {
            if (dropdownMenu.visible && dropdownMenu.choiceItem === choiceItem)
                dropdownMenu.close()
        }
    }
}
