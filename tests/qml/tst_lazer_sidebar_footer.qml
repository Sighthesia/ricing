import QtQuick
import QtTest
import "../../modules/lazerbar" as Lazer

// The navigation rail splits its entries by KIND: primary entries filter what
// the mounted page shows, a `footer` entry is an action that leaves the page.
// They share one rail and one accent indicator, so the split has to hold in the
// geometry too - a footer row must not be laid out in the primary column, and
// the indicator must not jump up into it.
Item {
    id: testRoot
    width: 800
    height: 600

    Lazer.FullscreenSidebar {
        id: sidebar
        anchors.left: parent.left
        anchors.top: parent.top
        width: 176
        height: 560
        entries: [
            { id: "apps", label: "Apps", icon: "icons/apps.svg" },
            { id: "clipboard", label: "Clipboard", icon: "icons/clipboard.svg" },
            { id: "shortcuts", label: "Shortcuts", icon: "icons/keyboard.svg" },
            { id: "control-center", label: "Control Center",
              icon: "icons/control-center.svg", section: "footer" }
        ]
    }

    TestCase {
        id: testCase
        name: "SidebarFooterBand"
        when: windowShown
        width: 800
        height: 600

        // --- partitioning ---

        function test_theEntriesSplitIntoPrimaryAndFooterBands() {
            compare(sidebar.primaryEntries.length, 3)
            compare(sidebar.footerEntries.length, 1)
            verify(sidebar.hasFooter)

            compare(sidebar.primaryEntries[0].id, "apps")
            compare(sidebar.primaryEntries[2].id, "shortcuts")
            compare(sidebar.footerEntries[0].id, "control-center")
        }

        // A rail with no footer entry must report none, and must not leave an
        // empty band reserving space above the collapse toggle.
        function test_aRailWithNoFooterDeclaresNone() {
            sidebar.entries = [
                { id: "apps", label: "Apps", icon: "icons/apps.svg" },
                { id: "clipboard", label: "Clipboard", icon: "icons/clipboard.svg" }
            ]

            compare(sidebar.footerEntries.length, 0)
            verify(!sidebar.hasFooter)
            compare(sidebar.selectedFooterIndex(), -1)
        }

        // --- the indicator picks the band that owns the selection ---

        function test_theIndicatorIndexesEachBandIndependently() {
            sidebar.selected = "shortcuts"
            compare(sidebar.selectedIndex(), 2)
            compare(sidebar.selectedFooterIndex(), -1)

            // The footer id must NOT resolve to primary row 3: the primary column
            // only has three rows, so an indicator placed there would land on no
            // item at all - which is the bug this band split exists to prevent.
            sidebar.selected = "control-center"
            compare(sidebar.selectedIndex(), -1)
            compare(sidebar.selectedFooterIndex(), 0)
            verify(sidebar.anySelected)

            sidebar.selected = "apps"
            compare(sidebar.selectedIndex(), 0)
            compare(sidebar.selectedFooterIndex(), -1)
        }

        function test_nothingSelectedHidesTheIndicatorInBothBands() {
            sidebar.selected = "control-center"
            verify(sidebar.anySelected)

            sidebar.selected = "not-an-entry"
            compare(sidebar.selectedIndex(), -1)
            compare(sidebar.selectedFooterIndex(), -1)
            verify(!sidebar.anySelected)
            verify(!sidebar.selectionIndicatorItem.visible)
        }

        // --- geometry: the bands must not overlap ---

        function test_theFooterBandSitsAboveTheCollapseToggleAndBelowTheModes() {
            var primaryY = sidebar.selectionIndicatorItem.y
            sidebar.selected = "apps"
            primaryY = sidebar.selectionIndicatorItem.y
            sidebar.selected = "control-center"

            // The footer band is anchored to the collapse toggle, so its y is
            // settled geometry rather than a row number, and a TestCase function
            // does not run the event loop: read it only once the anchor has laid
            // out. Without this the first read can return the pre-layout value
            // and the band looks like it overlaps the collapse toggle.
            tryVerify(function() {
                return sidebar.selectionIndicatorItem.y
                        + sidebar.selectionIndicatorItem.height < sidebar.height - 40
            }, 500)

            var footerY = sidebar.selectionIndicatorItem.y

            verify(footerY > primaryY,
                   "a footer selection must place the indicator BELOW the primary rows")

            // The primary band starts at railTop; the footer band must be pushed
            // down far enough that even the LAST primary row sits above it.
            var lastPrimaryCenter = sidebar.railTop
                    + 2 * (sidebar.itemHeight + sidebar.itemSpacing)
                    + sidebar.itemHeight / 2
            verify(footerY + sidebar.selectionIndicatorItem.height / 2 > lastPrimaryCenter,
                   "the footer indicator must not overlap the last primary row")
        }

        function init() {
            Lazer.MotionTokens.reducedMotionOverride = true
            sidebar.entries = [
                { id: "apps", label: "Apps", icon: "icons/apps.svg" },
                { id: "clipboard", label: "Clipboard", icon: "icons/clipboard.svg" },
                { id: "shortcuts", label: "Shortcuts", icon: "icons/keyboard.svg" },
                { id: "control-center", label: "Control Center",
                  icon: "icons/control-center.svg", section: "footer" }
            ]
            sidebar.expanded = true
            sidebar.selected = "apps"
            wait(0)
        }

        function cleanup() {
            Lazer.MotionTokens.reducedMotionOverride = false
        }
    }
}
