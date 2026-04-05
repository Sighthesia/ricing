import QtQuick

// Appearance settings page that composes wallpaper, color, font, bar,
// animation, and behavior groups.
Item {
    id: root

    // Propagated from SettingsPanelContent. When non-empty, highlight matching items
    // in place and force-expand groups that contain matches.
    property string searchQuery: ""

    // Public stagger API — called by SettingsPanelContent when the panel opens/closes.
    function runEnterAnimation() {
        groupWallpaper.runEnter()
        groupColors.runEnter()
        groupFont.runEnter()
        groupBar.runEnter()
        groupAnimation.runEnter()
        groupBehavior.runEnter()
    }
    function runExitAnimation() {
        groupWallpaper.runExit()
        groupColors.runExit()
        groupFont.runExit()
        groupBar.runExit()
        groupAnimation.runExit()
        groupBehavior.runExit()
    }

    implicitWidth: parent ? parent.width : 340
    implicitHeight: Math.min(pageFlickable.contentHeight + 8, 480)

    // Auto-clear highlights 3 seconds after a scroll-to-section jump.
    // Gives the user enough time to see which group was highlighted without
    // requiring an explicit click to dismiss.
    Timer {
        id: highlightClearTimer
        interval: 3000
        onTriggered: root.clearAllHighlights()
    }

    // Scroll to a named section, expand it if collapsed, and show a persistent
    // highlight on the group header. Cleared by clearAllHighlights().
    function scrollToSection(sectionId) {
        var map = {
            "wallpaper": groupWallpaper,
            "colors":    groupColors,
            "font":      groupFont,
            "bar":       groupBar,
            "animation": groupAnimation,
            "behavior":  groupBehavior
        }
        var group = map[sectionId]
        if (!group) return
        group.expanded = true
        pageFlickable.contentY = Math.max(0, group.y - 4)
        // Clear any previously highlighted group first
        clearAllHighlights()
        group.highlighted = true
        group.flash()
        highlightClearTimer.restart()
    }

    // Remove persistent highlights from all groups.
    // Called when the user clicks on blank space in the panel.
    function clearAllHighlights() {
        groupWallpaper.highlighted = false
        groupColors.highlighted = false
        groupFont.highlighted = false
        groupBar.highlighted = false
        groupAnimation.highlighted = false
        groupBehavior.highlighted = false
    }

    Flickable {
        id: pageFlickable
        anchors.fill: parent
        contentWidth: width
        contentHeight: pageCol.implicitHeight
        clip: true
        boundsMovement: Flickable.StopAtBounds

        Column {
            id: pageCol
            width: pageFlickable.width
            spacing: 4

            Item { width: 1; height: 4 }

            AppearanceWallpaperGroup {
                id: groupWallpaper
                searchQuery: root.searchQuery
            }

            AppearanceColorsGroup {
                id: groupColors
                searchQuery: root.searchQuery
            }

            AppearanceFontGroup {
                id: groupFont
                searchQuery: root.searchQuery
            }

            AppearanceBarGroup {
                id: groupBar
                searchQuery: root.searchQuery
            }

            AppearanceAnimationGroup {
                id: groupAnimation
                searchQuery: root.searchQuery
            }

            AppearanceBehaviorGroup {
                id: groupBehavior
                searchQuery: root.searchQuery
            }

            Item { width: 1; height: 8 }
        }
    }

    // When this page is created while the settings panel is already open,
    // SettingsPanelContent does not emit a fresh panelOpening signal. Trigger one
    // enter cycle on creation so staggered groups do not remain at opacity 0.
    Component.onCompleted: Qt.callLater(runEnterAnimation)
}
