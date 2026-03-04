import QtQuick
import qs.config

// Settings panel with a persistent search bar at the top, left sidebar, and
// right page content. Typing in the search bar propagates the query to the
// active page, which hides non-matching items in-place (VSCode-style filtering)
// and auto-expands groups that contain matches.
Item {
    id: root

    property string currentPage: "appearance"
    property string pendingSection: ""

    // Public API consumed by SettingsPanelWindow's click-to-deselect backdrop.
    function clearAllHighlights() {
        if (loader.item && loader.item.clearAllHighlights)
            loader.item.clearAllHighlights()
    }
    function dismissSearch() {
        searchField.focus = false
    }

    // ── Stagger enter/exit animation API ──────────────────────────────
    // Called by SettingsPanelWindow when AnimatedPanelBase emits
    // panelOpening / panelClosing.  Resets items to invisible state,
    // then launches staggered timers for each structural block.
    function runEnterAnimation() {
        _resetStaggerItems()
        _sbEnterTimer.interval = 80;  _sbEnterTimer.restart()
        sidebar.runEnterAnimation()
        _ciEnterTimer.interval = 160; _ciEnterTimer.restart()
    }

    function runExitAnimation() {
        _sbEnterTimer.stop(); _sbExitTimer.interval = 0; _sbExitTimer.restart()
        sidebar.runExitAnimation()
        _ciEnterTimer.stop(); _ciExitTimer.interval = 0; _ciExitTimer.restart()
    }

    function _resetStaggerItems() {
        // Snap to invisible/offset state before starting a new enter cycle.
        _sbEnterTimer.stop();  _sbExitTimer.stop()
        _sbOpacityEnter.stop(); _sbOffsetEnter.stop()
        _sbOpacityExit.stop();  _sbOffsetExit.stop()
        searchBar.opacity  = 0.0; searchBar._offsetY  = 20.0
        _ciEnterTimer.stop();  _ciExitTimer.stop()
        _ciOpacityEnter.stop(); _ciOffsetEnter.stop()
        _ciOpacityExit.stop();  _ciOffsetExit.stop()
        contentItem.opacity = 0.0; contentItem._offsetY = 20.0
    }

    // searchBar stagger timers & animations
    Timer { id: _sbEnterTimer; repeat: false; onTriggered: { _sbOpacityEnter.restart(); _sbOffsetEnter.restart() } }
    Timer { id: _sbExitTimer;  repeat: false; onTriggered: { _sbOpacityExit.restart();  _sbOffsetExit.restart()  } }
    PropertyAnimation { id: _sbOpacityEnter; target: searchBar; property: "opacity";  to: 1.0;  duration: 280; easing.type: Easing.OutCubic }
    PropertyAnimation { id: _sbOffsetEnter;  target: searchBar; property: "_offsetY"; to: 0.0;  duration: 280; easing.type: Easing.OutCubic }
    PropertyAnimation { id: _sbOpacityExit;  target: searchBar; property: "opacity";  to: 0.0;  duration: 100; easing.type: Easing.InCubic }
    PropertyAnimation { id: _sbOffsetExit;   target: searchBar; property: "_offsetY"; to: 10.0; duration: 100; easing.type: Easing.InCubic }

    // contentItem stagger timers & animations
    Timer { id: _ciEnterTimer; repeat: false; onTriggered: { _ciOpacityEnter.restart(); _ciOffsetEnter.restart() } }
    Timer { id: _ciExitTimer;  repeat: false; onTriggered: { _ciOpacityExit.restart();  _ciOffsetExit.restart()  } }
    PropertyAnimation { id: _ciOpacityEnter; target: contentItem; property: "opacity";  to: 1.0;  duration: 280; easing.type: Easing.OutCubic }
    PropertyAnimation { id: _ciOffsetEnter;  target: contentItem; property: "_offsetY"; to: 0.0;  duration: 280; easing.type: Easing.OutCubic }
    PropertyAnimation { id: _ciOpacityExit;  target: contentItem; property: "opacity";  to: 0.0;  duration: 100; easing.type: Easing.InCubic }
    PropertyAnimation { id: _ciOffsetExit;   target: contentItem; property: "_offsetY"; to: 10.0; duration: 100; easing.type: Easing.InCubic }

    implicitWidth: Math.max(searchBar.implicitWidth, mainRow.implicitWidth)
    implicitHeight: searchBar.height + 6 + mainRow.implicitHeight
    clip: true

    // ── Search bar ──────────────────────────────────────────────────
    Item {
        id: searchBar
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: Theme.barHeight
        implicitWidth: 360
        // Stagger animation state — initial: invisible, offset 20px down
        opacity: 0.0
        property real _offsetY: 20.0
        transform: Translate { y: searchBar._offsetY }

        Rectangle {
            anchors.fill: parent
            radius: Theme.cornerRadius - 2
            color: Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 0.5)
            border.color: searchField.activeFocus ? Colors.highlight : Colors.border
            border.width: 1
            Behavior on border.color { ColorAnimation { duration: Theme.anim.highlightDuration } }
        }

        Text {
            id: searchIcon
            anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
            text: "\uf002"
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSizeSmall
            color: Colors.textMuted
        }

        TextInput {
            id: searchField
            anchors { left: searchIcon.right; leftMargin: 8; right: clearBtn.left; rightMargin: 4; verticalCenter: parent.verticalCenter }
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            color: Colors.text
            selectionColor: Qt.rgba(Colors.highlight.r, Colors.highlight.g, Colors.highlight.b, 0.35)
            HoverHandler { cursorShape: Qt.IBeamCursor }
        }

        Text {
            visible: searchField.text === "" && !searchField.activeFocus
            anchors { left: searchField.left; verticalCenter: parent.verticalCenter }
            text: "搜索设置..."
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            color: Colors.textMuted
        }

        Text {
            id: clearBtn
            visible: searchField.text !== ""
            anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
            text: "\uf00d"
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSizeSmall
            color: Colors.textMuted
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: searchField.clear() }
        }
    }

    // ── Main content (sidebar + page loader) ────────────────────────
    Item {
        id: mainRow
        anchors { top: searchBar.bottom; topMargin: 6; left: parent.left; right: parent.right; bottom: parent.bottom }
        implicitWidth: sidebar.implicitWidth + contentItem.implicitWidth + 8
        implicitHeight: Math.max(sidebar.implicitHeight, contentItem.implicitHeight)

        SettingsSidebar {
            id: sidebar
            anchors { top: parent.top; left: parent.left; bottom: parent.bottom }
            currentPage: root.currentPage
            onPageSelected: (page) => root.currentPage = page
            onSectionRequested: (page, sectionId) => {
                if (root.currentPage !== page) {
                    root.currentPage = page
                    root.pendingSection = sectionId
                } else if (loader.item && loader.item.scrollToSection) {
                    loader.item.scrollToSection(sectionId)
                }
            }
        }

        Item {
            id: contentItem
            anchors { top: parent.top; left: sidebar.right; right: parent.right; bottom: parent.bottom; leftMargin: 8 }
            implicitWidth: loader.implicitWidth
            implicitHeight: loader.implicitHeight
            // Stagger animation state — initial: invisible, offset 20px down
            opacity: 0.0
            property real _offsetY: 20.0
            transform: Translate { y: contentItem._offsetY }

            Loader {
                id: loader
                anchors.fill: parent
                source: {
                    switch (root.currentPage) {
                        case "appearance": return "AppearancePage.qml"
                        case "about":      return "AboutPage.qml"
                        default:           return "AppearancePage.qml"
                    }
                }
                onLoaded: {
                    if (loader.item && loader.item.hasOwnProperty("searchQuery"))
                        loader.item.searchQuery = Qt.binding(function() { return searchField.text })
                    if (root.pendingSection !== "")
                        scrollDelay.restart()
                }
            }
        }
    }

    Timer {
        id: scrollDelay
        interval: 60
        onTriggered: {
            if (root.pendingSection !== "" && loader.item && loader.item.scrollToSection) {
                loader.item.scrollToSection(root.pendingSection)
                root.pendingSection = ""
            }
        }
    }

}



