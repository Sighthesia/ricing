import QtQuick
import "LazerSettingsLogic.js" as Logic

// Own the settings content chrome: header, search, viewport, footer, empty state.
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
    readonly property bool emptyStateVisible:
        Logic.normalizeSearchQuery(searchQuery).length > 0 && visibleResultCount === 0
    readonly property bool canScrollDown: currentPage && currentPage.contentHeight - currentPage.contentY - viewport.height > 8

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

            Rectangle {
                anchors.fill: parent
                radius: 16
                color: closeHover.hovered || closeButton.activeFocus ? LazerTheme.settingsRowHover : "transparent"
                border.width: closeButton.activeFocus ? 1 : 0
                border.color: LazerTheme.focusRing
            }
            Text { anchors.centerIn: parent; text: "×"; color: LazerTheme.textPrimary; font.pixelSize: 22 }
            HoverHandler { id: closeHover; enabled: closeButton.enabled }
            TapHandler {
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

            Rectangle {
                anchors.fill: parent
                radius: 16
                color: expandHover.hovered || expandToggle.activeFocus ? LazerTheme.settingsRowHover : "transparent"
                border.width: expandToggle.activeFocus ? 1 : 0
                border.color: LazerTheme.focusRing
            }
            Text {
                anchors.centerIn: parent
                text: root.expanded ? "«" : "»"
                color: LazerTheme.textMuted
                font.pixelSize: 16
            }
            HoverHandler { id: expandHover; enabled: expandToggle.enabled }
            TapHandler {
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

    // Keep the search field fixed between the header and the scrolling sections.
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
            radius: 10
            color: searchHover.hovered || searchEditor.activeFocus ? LazerTheme.settingsRowHover : LazerTheme.settingsRow
            border.width: searchEditor.activeFocus ? 2 : 1
            border.color: searchEditor.activeFocus ? LazerTheme.focusRing : LazerTheme.settingsPanelBorder
            Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
            Behavior on border.width { NumberAnimation { duration: MotionTokens.fast } }
        }

        Text {
            anchors.left: searchSurface.left
            anchors.leftMargin: 14
            anchors.verticalCenter: searchSurface.verticalCenter
            text: "⌕"
            color: LazerTheme.textMuted
            font.pixelSize: 18
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

            Text {
                anchors.centerIn: parent
                text: "×"
                color: LazerTheme.textMuted
                font.pixelSize: 16
            }
            TapHandler {
                enabled: searchClearButton.enabled && searchClearButton.visible
                onTapped: {
                    searchEditor.text = ""
                    root.searchQueryEdited("")
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
}
