import QtQuick
import QtQuick.Effects
import "LazerSettingsLogic.js" as Logic

// Own the settings content chrome: search, category title, viewport, footer,
// and the top-level dropdown overlay layer for choice controls.
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

    function _rect(item) {
        if (!item)
            return { "x": 0, "y": 0, "width": 0, "height": 0 }
        var pos = item.mapToItem(root, 0, 0)
        return { "x": Number(pos.x), "y": Number(pos.y),
            "width": Math.max(0, Number(item.width)), "height": Math.max(0, Number(item.height)) }
    }

    function _sceneRect(item) {
        if (!item)
            return { "x": 0, "y": 0, "width": 0, "height": 0 }
        var pos = item.mapToItem(null, 0, 0)
        return { "x": Number(pos.x), "y": Number(pos.y),
            "width": Math.max(0, Number(item.width)), "height": Math.max(0, Number(item.height)) }
    }

    function _point(point) {
        return point ? { "x": Number(point.x), "y": Number(point.y) } : null
    }

    function _surfaceSnapshot(item) {
        if (!item)
            return null
        return {
            "rect": _rect(item), "sceneRect": _sceneRect(item),
            "visible": item.visible, "enabled": item.enabled,
            "opacity": Number(item.opacity), "z": Number(item.z),
            "borderWidth": item.border !== undefined && item.border
                ? Number(item.border.width) : null,
        }
    }

    function _controlSurface(control) {
        if (!control)
            return null
        if (control.surfaceItem !== undefined)
            return control.surfaceItem
        if (control.headerItem !== undefined)
            return control.headerItem
        if (control.fieldSurfaceItem !== undefined)
            return control.fieldSurfaceItem
        if (control.trackItem !== undefined)
            return control.trackItem
        if (control.nubItem !== undefined)
            return control.nubItem
        return null
    }

    function _rowSnapshot(row, index) {
        var control = row.controlItem
        return {
            "role": "row-" + index, "rect": _rect(row), "sceneRect": _sceneRect(row),
            "visible": row.visible, "enabled": row.enabled, "opacity": Number(row.opacity),
            "z": Number(row.z), "hover": row.rowHovered === true,
            "hoverScenePoint": row.rowHovered === true ? _point(row.debugHoverScenePoint) : null,
            "focus": row.activeFocus === true || (control && control.activeFocus === true),
            "rowHighlighted": row.rowHighlighted === true,
            "rowHoverBlocking": row.rowHoverBlocking === true,
            "cardSurface": _surfaceSnapshot(row.cardItem),
            "cardHighlight": _surfaceSnapshot(row.cardHighlightItem),
            "cardBorderWidth": Number(row.cardItem ? row.cardItem.border.width : 0),
            "control": control ? {
                "role": String(row.rowPresentation || "standard"), "rect": _rect(control),
                "sceneRect": _sceneRect(control),
                "surface": _surfaceSnapshot(_controlSurface(control)),
                "visible": control.visible, "enabled": control.enabled,
                "opacity": Number(control.opacity), "z": Number(control.z),
                "focus": control.activeFocus === true,
                "effectiveEnabled": control.effectiveEnabled !== undefined
                    ? control.effectiveEnabled === true : control.enabled === true,
                "focusVisible": control.focusVisible !== undefined
                    ? control.focusVisible === true : control.activeFocus === true,
                "activeFocusOnTab": control.activeFocusOnTab === true,
                "focusRing": {
                    "activeFocus": control.activeFocus === true,
                    "focusVisible": control.focusVisible !== undefined
                        ? control.focusVisible === true : control.activeFocus === true,
                    "surfaceBorderWidth": _controlSurface(control)
                        && _controlSurface(control).border !== undefined
                        && _controlSurface(control).border
                        ? Number(_controlSurface(control).border.width) : null,
                },
            } : null,
        }
    }

    function _pageSnapshot(page) {
        if (!page)
            return null
        return {
            "visible": page.visible, "enabled": page.enabled,
            "opacity": Number(page.opacity), "z": Number(page.z),
            "rect": _rect(page), "contentY": Number(page.contentY),
            "contentHeight": Number(page.contentHeight),
        }
    }

    function _findRows(item, result) {
        if (!item)
            return
        if (item.labelText !== undefined && item.controlItem !== undefined)
            result.push(item)
        var children = item.children || []
        for (var i = 0; i < children.length; i++)
            _findRows(children[i], result)
    }

    function debugSnapshot() {
        var rows = []
        _findRows(currentPage, rows)
        var rowSnapshots = []
        for (var i = 0; i < rows.length; i++)
            rowSnapshots.push(_rowSnapshot(rows[i], i))
        return {
            "rect": _rect(root), "viewport": {
                "rect": _rect(viewport), "sceneRect": _sceneRect(viewport),
                "visible": viewport.visible, "enabled": viewport.enabled,
                "opacity": Number(viewport.opacity), "z": Number(viewport.z),
                "clip": viewport.clip,
            },
            "page": currentPage ? { "rect": _rect(currentPage), "contentY": Number(currentPage.contentY), "contentHeight": Number(currentPage.contentHeight), "visible": currentPage.visible, "enabled": currentPage.enabled, "opacity": Number(currentPage.opacity), "z": Number(currentPage.z) } : null,
            "pages": {
                "appearance": _pageSnapshot(root.parent && root.parent.appearancePage),
                "bar": _pageSnapshot(root.parent && root.parent.barPage),
                "notifications": _pageSnapshot(root.parent && root.parent.notificationPage),
            },
            "selectedPageScroll": currentPage ? { "contentY": Number(currentPage.contentY), "contentHeight": Number(currentPage.contentHeight) } : null,
            "search": { "visible": searchArea.visible, "enabled": searchEditor.enabled, "focus": searchEditor.activeFocus },
            "dropdown": { "open": root.dropdownOpen }, "rows": rowSnapshots,
        }
    }

    signal searchQueryEdited(string query)
    property alias searchEditor: searchEditor
    property alias searchSurfaceItem: searchSurface
    property alias viewportItem: viewport
    property alias scrollShadowItem: scrollShadow
    property alias emptyStateItem: emptyState
    property alias dropdownLayerItem: dropdownLayer
    property alias menuCatcherItem: menuCatcher

    // Keep the persistent category pages mounted inside the clipped viewport.
    default property alias viewportChildren: viewport.data

    // Mirror externally cleared queries without fighting the active editor.
    onSearchQueryChanged: {
        if (searchEditor.text !== root.searchQuery)
            searchEditor.text = root.searchQuery
        root.closeDropdownMenu()
    }

    onCurrentPageChanged: {
        root.closeDropdownMenu()
    }

    onInteractiveChanged: {
        if (!root.interactive) {
            root.closeDropdownMenu()
        }
    }

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

        HoverHandler { id: searchHover; enabled: root.interactive; blocking: false }
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
    // Use visible (not opacity) so the item is fully removed from the scene
    // graph when hidden, preventing it from intercepting hover events on the
    // settings rows beneath it.
    Rectangle {
        id: scrollShadow
        enabled: false
        anchors.left: viewport.left
        anchors.right: viewport.right
        anchors.bottom: viewport.bottom
        height: 22
        visible: root.canScrollDown
        gradient: Gradient {
            GradientStop { position: 0; color: "#00000000" }
            GradientStop { position: 1; color: "#55000000" }
        }
    }

    // Present a clear message when the current category has no matches.
    Item {
        id: emptyState
        enabled: false
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
            enabled: root.dropdownOpen
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
            return
        }
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

    // Close dropdowns when the active page scrolls.
    Connections {
        target: root.currentPage
        function onContentYChanged() {
            root.closeDropdownMenu()
        }
    }

    Connections {
        target: SettingsOverlayBridge
        function onDropdownRequested(choiceItem) { root.showDropdownFor(choiceItem) }
        function onDropdownDismissed(choiceItem) {
            if (dropdownMenu.visible && dropdownMenu.choiceItem === choiceItem)
                dropdownMenu.close()
        }
    }
}
