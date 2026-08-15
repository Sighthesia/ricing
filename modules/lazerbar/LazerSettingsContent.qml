import QtQuick
import QtQuick.Effects
import "LazerSettingsLogic.js" as Logic

// Own the settings content chrome: header, outlined search, viewport, footer,
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

    signal searchQueryEdited(string query)
    signal expandToggleRequested()
    signal closeRequested()
    property alias closeButton: closeButton
    property alias searchEditor: searchEditor

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

    // Present the expandable header with title, collapse chevron, and close.
    Item {
        id: header
        x: 0
        y: 0
        width: root.width
        height: 56

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            text: root.title
            color: LazerTheme.textPrimary
            font.pixelSize: 22
            font.weight: Font.DemiBold
        }

        // Keep the close affordance fixed-size and independent of page layout.
        Item {
            id: closeButton
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            width: 32
            height: 32
            enabled: root.interactive
            activeFocusOnTab: root.interactive
            Accessible.role: Accessible.Button
            Accessible.name: "关闭"

            scale: closePress.pressed ? MotionTokens.pressScale : 1
            Behavior on scale { enabled: !MotionTokens.reducedMotion; NumberAnimation { duration: MotionTokens.fast } }

            Rectangle {
                anchors.fill: parent
                radius: 16
                color: closeHover.hovered || closeButton.activeFocus ? LazerTheme.settingsRowHover : "transparent"
                border.width: closeButton.activeFocus ? 1 : 0
                border.color: LazerTheme.focusRing
                Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
            }
            Image {
                id: closeIcon
                anchors.centerIn: parent
                width: 16
                height: 16
                source: "icons/close.svg"
                fillMode: Image.PreserveAspectFit
            }
            MultiEffect {
                anchors.fill: closeIcon
                source: closeIcon
                visible: closeIcon.visible
                colorization: 1
                colorizationColor: closeHover.hovered || closeButton.activeFocus ? LazerTheme.textPrimary : LazerTheme.textMuted
                Behavior on colorizationColor { ColorAnimation { duration: MotionTokens.fast } }
            }
            HoverHandler { id: closeHover; enabled: closeButton.enabled }
            TapHandler {
                id: closePress
                enabled: closeButton.enabled
                onTapped: { closeButton.forceActiveFocus(); root.closeRequested() }
            }
            Keys.onPressed: event => {
                if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) && closeButton.enabled) {
                    root.closeRequested()
                    event.accepted = true
                }
            }
        }

        // Let the header chevron toggle the same 70/170px sidebar expansion.
        Item {
            id: expandToggle
            anchors.right: closeButton.left
            anchors.rightMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            width: 32
            height: 32
            enabled: root.interactive
            activeFocusOnTab: root.interactive
            Accessible.role: Accessible.Button
            Accessible.name: root.expanded ? "收起设置面板" : "展开设置面板"

            scale: expandPress.pressed ? MotionTokens.pressScale : 1
            Behavior on scale { enabled: !MotionTokens.reducedMotion; NumberAnimation { duration: MotionTokens.fast } }

            Rectangle {
                anchors.fill: parent
                radius: 16
                color: expandHover.hovered || expandToggle.activeFocus ? LazerTheme.settingsRowHover : "transparent"
                border.width: expandToggle.activeFocus ? 1 : 0
                border.color: LazerTheme.focusRing
                Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
            }
            Image {
                id: expandIcon
                anchors.centerIn: parent
                width: 16
                height: 16
                source: root.expanded ? "icons/chevron-left.svg" : "icons/chevron-right.svg"
                fillMode: Image.PreserveAspectFit
            }
            MultiEffect {
                anchors.fill: expandIcon
                source: expandIcon
                visible: expandIcon.visible
                colorization: 1
                colorizationColor: expandHover.hovered || expandToggle.activeFocus ? LazerTheme.textPrimary : LazerTheme.textMuted
                Behavior on colorizationColor { ColorAnimation { duration: MotionTokens.fast } }
            }
            HoverHandler { id: expandHover; enabled: expandToggle.enabled }
            TapHandler {
                id: expandPress
                enabled: expandToggle.enabled
                onTapped: { expandToggle.forceActiveFocus(); root.expandToggleRequested() }
            }
            Keys.onPressed: event => {
                if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) && expandToggle.enabled) {
                    root.expandToggleRequested()
                    event.accepted = true
                }
            }
        }
    }

    // Keep the outlined search field fixed between the header and the pages.
    Item {
        id: searchArea
        x: 0
        y: header.height
        width: root.width
        height: 44

        Rectangle {
            id: searchSurface
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            anchors.topMargin: 2
            anchors.bottomMargin: 2
            radius: LazerTheme.settingsControlRadius
            color: "transparent"
            border.width: searchEditor.activeFocus ? 2 : 1
            border.color: searchEditor.activeFocus ? LazerTheme.focusRing : (searchHover.hovered ? "#66FFFFFF" : "#33FFFFFF")
            Behavior on border.width { NumberAnimation { duration: MotionTokens.fast } }
            Behavior on border.color { ColorAnimation { duration: MotionTokens.fast } }
        }

        Image {
            id: searchIcon
            anchors.left: searchSurface.left
            anchors.leftMargin: 14
            anchors.verticalCenter: searchSurface.verticalCenter
            width: 15
            height: 15
            source: "icons/search.svg"
            fillMode: Image.PreserveAspectFit
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
            anchors.leftMargin: 34
            anchors.right: searchClearButton.left
            anchors.rightMargin: 6
            anchors.verticalCenter: searchSurface.verticalCenter
            clip: true
            enabled: root.interactive && root.contentReady
            color: LazerTheme.textPrimary
            selectionColor: LazerTheme.osuPink
            font.pixelSize: 13
            activeFocusOnTab: root.interactive && root.contentReady
            onTextEdited: root.searchQueryEdited(searchEditor.text)
        }

        Text {
            anchors.left: searchEditor.left
            anchors.verticalCenter: searchEditor.verticalCenter
            visible: !searchEditor.text && !searchEditor.activeFocus
            text: "搜索设置…"
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
        y: header.height + searchArea.height
        width: root.width
        height: Math.max(0, root.height - header.height - searchArea.height - footer.height)
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

        Rectangle {
            anchors.fill: parent
            color: LazerTheme.settingsRail
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            text: "Afloat 设置"
            color: LazerTheme.textPrimary
            font.pixelSize: 13
            font.weight: Font.DemiBold
        }
        Text {
            anchors.left: parent.left
            anchors.leftMargin: 96
            anchors.verticalCenter: parent.verticalCenter
            text: "v0.1.0 · Esc 关闭"
            color: LazerTheme.textMuted
            font.pixelSize: 11
        }
    }

    // Present the hover/focus description or slider value above its source.
    Item {
        id: tooltip
        z: 20
        visible: false
        property string tooltipText: ""
        width: Math.min(LazerTheme.tooltipMaxWidth, Math.max(24, tooltipSurface.implicitWidth + 20))
        height: tooltipSurface.implicitHeight + 12
        opacity: visible ? 1 : 0

        Rectangle {
            id: tooltipSurface
            anchors.fill: parent
            radius: 6
            color: LazerTheme.tooltipBackground
            border.width: 1
            border.color: LazerTheme.tooltipBorder

            Text {
                anchors.fill: parent
                anchors.margins: 6
                text: tooltip.tooltipText
                color: LazerTheme.textPrimary
                font.pixelSize: 12
                wrapMode: Text.WordWrap
                verticalAlignment: Text.AlignVCenter
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
                onTapped: root.closeDropdownMenu()
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
        tooltip.visible = false
    }

    function showTooltipAt(text, source) {
        if (!root.interactive || !root.contentReady || !root.ownsOverlaySource(source) || !text) {
            hideTooltip()
            return
        }
        tooltip.tooltipText = text
        var pos = source.mapToItem(root, 0, 0)
        if (!isFinite(Number(pos.x)) || !isFinite(Number(pos.y)))
            pos = { x: 0, y: 0 }
        tooltip.x = Logic.clamp(pos.x, 0, Math.max(0, root.width - tooltip.width))
        var aboveY = pos.y - tooltip.height - 6
        if (aboveY >= viewport.y)
            tooltip.y = aboveY
        else
            tooltip.y = Math.min(pos.y + (source.height > 0 ? source.height : 20) + 6, Math.max(viewport.y, root.height - tooltip.height))
        tooltip.visible = true
    }

    function refreshTooltipFromBridge() {
        var current = SettingsOverlayBridge.currentTooltip()
        if (current && current.text && root.ownsOverlaySource(current.source))
            showTooltipAt(current.text, current.source)
        else
            hideTooltip()
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
        var placement = Logic.dropdownPlacement(pos.y, pos.y + header.height, menuHeight,
                                                viewport.y, viewport.y + viewport.height,
                                                LazerTheme.dropdownMaxHeight)
        dropdownMenu.x = Logic.clamp(pos.x, 0, Math.max(0, root.width - header.width))
        dropdownMenu.width = header.width
        dropdownMenu.y = placement.y
        dropdownMenu.height = placement.height
        dropdownMenu.open()
        root.dropdownOpen = true
        dropdownMenu.forceActiveFocus()
    }

    // Close stale dropdowns and tooltips when the page scrolls out from under them.
    Connections {
        target: root.currentPage
        function onContentYChanged() {
            root.closeDropdownMenu()
            root.hideTooltip()
        }
    }

    Connections {
        target: SettingsOverlayBridge
        function onTooltipRequested(text, source, priority) { root.refreshTooltipFromBridge() }
        function onTooltipDismissed(source) { root.refreshTooltipFromBridge() }
        function onDropdownRequested(choiceItem) { root.showDropdownFor(choiceItem) }
        function onDropdownDismissed(choiceItem) {
            if (dropdownMenu.visible && dropdownMenu.choiceItem === choiceItem)
                dropdownMenu.close()
        }
    }
}
