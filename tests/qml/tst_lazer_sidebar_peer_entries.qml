import QtQuick
import QtTest
import "../../modules/lazerbar" as Lazer

// The navigation rail is ONE flat column of peer entries. Three of them filter
// what the launcher page shows; the fourth swaps that page's content area to the
// control center. Nothing in the rail distinguishes them, and that is the point:
// a second band would have been a second layout for a difference the content
// area already shows on its own.
//
// So these assertions are as much about what is GONE as what is there. A rail
// that grew a footer band again would still lay four rows out correctly in some
// configurations, which is exactly why the mechanism has to be named as absent.
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
              icon: "icons/control-center.svg" }
        ]
    }

    TestCase {
        id: testCase
        name: "SidebarPeerEntries"
        when: windowShown
        width: 800
        height: 600

        // --- one list, four rows, no partition ---

        // The fourth entry is an ordinary member of the list. The earlier
        // footer-band mechanism marked it `section: "footer"` and moved it into a
        // second band anchored above the collapse toggle, so both facts are
        // asserted absent here: the marker, and the band properties that read it.
        function test_theControlCenterIsAPeerEntryInOneList() {
            compare(sidebar.entries.length, 4)
            compare(sidebar.entries[3].id, "control-center")
            compare(sidebar.entries[3].label, "Control Center")

            var controlCenter = sidebar.entries[3]
            verify(controlCenter.section === undefined,
                   "no entry may carry a section marker: the rail has one list")
            // The mechanism itself is gone, not merely unused. These four are the
            // partition API; a rail that kept them would be one refactor away
            // from being partitioned again, with nothing failing in between.
            verify(sidebar.primaryEntries === undefined,
                   "the primary/footer split must not survive as dead API")
            verify(sidebar.footerEntries === undefined)
            verify(sidebar.hasFooter === undefined)
            verify(sidebar.selectedFooterIndex === undefined)
        }

        // Row arithmetic covers every entry, including the fourth. Before the
        // split, a selected footer entry resolved to -1 in the primary column, so
        // the accent strip had nowhere to go; here it must land on row 3 like any
        // other selection.
        function test_theIndicatorIndexesEveryEntryIncludingTheFourth() {
            for (var row = 0; row < sidebar.entries.length; row++) {
                sidebar.selected = sidebar.entries[row].id
                compare(sidebar.selectedIndex(), row,
                    sidebar.entries[row].id + " must index as row " + row)
                verify(sidebar.selectionIndicatorItem.visible,
                    sidebar.entries[row].id + " must show the accent strip")
            }
        }

        // The strip is placed by ONE formula over the one list, so a selection
        // four rows down cannot land somewhere the list has no row. Asserted
        // against the rail's own published geometry rather than a copied literal.
        function test_theFourthEntryPlacesTheIndicatorOnItsOwnRow() {
            for (var row = 0; row < sidebar.entries.length; row++) {
                sidebar.selected = sidebar.entries[row].id
                var expectedCenter = sidebar.railTop
                        + row * (sidebar.itemHeight + sidebar.itemSpacing)
                        + sidebar.itemHeight / 2
                compare(sidebar.selectionIndicatorItem.y
                        + sidebar.selectionIndicatorItem.height / 2, expectedCenter,
                    "row " + row + " must centre the strip on its own band")
            }
        }

        // Rows advance downward for every entry: the fourth is the last row, so
        // its strip must sit below the third's and stay clear of the collapse
        // toggle. This is the concrete form of "one list, top to bottom".
        function test_rowsRunTopToBottomIntoTheLastEntry() {
            sidebar.selected = "shortcuts"
            var thirdY = sidebar.selectionIndicatorItem.y
            sidebar.selected = "control-center"
            var fourthY = sidebar.selectionIndicatorItem.y

            verify(fourthY > thirdY,
                "the fourth entry must sit below the third, not in a band elsewhere")
            tryVerify(function() {
                return fourthY + sidebar.selectionIndicatorItem.height
                        < sidebar.height - 40
            }, 500, "the last row must stay clear of the collapse toggle")
        }

        function test_nothingSelectedHidesTheIndicator() {
            sidebar.selected = "control-center"
            verify(sidebar.selectionIndicatorItem.visible)

            sidebar.selected = "not-an-entry"
            compare(sidebar.selectedIndex(), -1)
            verify(!sidebar.selectionIndicatorItem.visible)
        }

        function init() {
            Lazer.MotionTokens.reducedMotionOverride = true
            sidebar.entries = [
                { id: "apps", label: "Apps", icon: "icons/apps.svg" },
                { id: "clipboard", label: "Clipboard", icon: "icons/clipboard.svg" },
                { id: "shortcuts", label: "Shortcuts", icon: "icons/keyboard.svg" },
                { id: "control-center", label: "Control Center",
                  icon: "icons/control-center.svg" }
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