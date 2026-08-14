import QtQuick
import QtTest
import "../../modules/lazerbar" as Lazer

// Verify popup lifecycle, origin, clamping, and modal timing contracts.
Item {
    width: 800
    height: 600
    Item { id: opener; width: 32; height: 32; focus: true }
    Lazer.DropdownMenu { id: dropdown; model: [{ label: "One" }, { label: "Two" }] }
    Lazer.ContextMenu { id: contextMenu; model: [{ label: "One" }] }
    Lazer.ModalOverlay { id: modal; anchors.fill: parent }

    TestCase {
        name: "LazerPopups"
        when: windowShown

        function init() {
            dropdown.phase = "closed"; dropdown.progress = 0
            contextMenu.phase = "closed"; contextMenu.progress = 0
            modal.phase = "closed"; modal.progress = 0
        }

        function test_dropdownLifecycle() {
            compare(dropdown.openFromScale, 0.98)
            compare(dropdown.openFromY, -4)
            compare(dropdown.openDuration, 160)
            compare(dropdown.closeDuration, 100)
            dropdown.openAt(opener, 800)
            compare(dropdown.phase, "opening")
            tryCompare(dropdown, "phase", "open", 250)
            dropdown.closeAndRestoreFocus()
            compare(dropdown.interactive, false)
            tryCompare(dropdown, "phase", "closed", 180)
        }

        function test_contextClamp() {
            contextMenu.openAtPoint(Qt.point(790, 590), Qt.rect(0, 0, 800, 600))
            verify(contextMenu.popupX + contextMenu.implicitWidth <= 800)
            verify(contextMenu.popupY + contextMenu.implicitHeight <= 600)
            compare(contextMenu.originName, "topRight")
        }

        function test_modalTimingAndBlocking() {
            compare(modal.backdropTargetOpacity, 0.55)
            compare(modal.backdropEnterDuration, 120)
            compare(modal.panelEnterDuration, 240)
            compare(modal.panelExitDuration, 160)
            compare(modal.backdropExitDuration, 100)
            modal.openFrom(opener)
            tryCompare(modal, "phase", "open", 340)
            modal.closeAndRestoreFocus()
            compare(modal.interactive, false)
            tryCompare(modal, "phase", "closed", 240)
        }
    }
}
