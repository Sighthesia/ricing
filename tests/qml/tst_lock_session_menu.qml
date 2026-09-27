import QtQuick
import QtTest
import "../../modules/lock"
import "../../modules/lock/LockSurfaceLogic.js" as SurfaceLogic

Item {
    id: harness
    width: 520
    height: 420

    QtObject {
        id: fakeService
        property bool running: false
        property string errorText: ""
        property string resultText: ""
        property var calls: []
        property bool unavailable: false
        signal actionFinished(string actionId, bool success, string message)

        function isAvailable(actionId) {
            return !unavailable && ["lock", "logout", "suspend", "reboot", "shutdown"].indexOf(actionId) >= 0
        }

        function execute(actionId) {
            if (running || !isAvailable(actionId))
                return false
            calls = calls.concat([actionId])
            return true
        }
    }

    LockSessionMenu {
        id: menu
        x: 24
        y: 24
        reducedMotion: true
        sessionService: fakeService
    }

    // Rows are nested under the clipped panel host; walk the tree instead of
    // hard-coding child indexes so the color contract stays testable.
    function findRows(item) {
        const found = []
        const kids = item.children || []
        for (let i = 0; i < kids.length; ++i) {
            const child = kids[i]
            if (child.actionId !== undefined && child.labelColor !== undefined)
                found.push(child)
            found.push.apply(found, findRows(child))
        }
        return found
    }

    TestCase {
        name: "LockSessionMenu"
        when: windowShown

        function init() {
            menu.open = false
            menu.pendingAction = ""
            menu.errorText = ""
            menu.statusText = ""
            fakeService.calls = []
            fakeService.running = false
            fakeService.unavailable = false
        }

        function test_startsClosedWithFiveStaticRows() {
            compare(menu.open, false)
            compare(menu.menuItemCount, 5)
        }

        // The whole session surface, rows included, must read one frozen
        // snapshot; otherwise a live palette transition repaints the menu
        // against a panel that no longer moves.
        function test_everyColorRoleComesFromTheLockSnapshot() {
            const theme = {
                lightScheme: true,
                accent: "#ff66aa",
                surface: "#f2f0f5",
                control: "#eeeaf1",
                panel: "#123456",
                trigger: "#654321",
                active: "#abcdef",
                hover: "#fedcba",
                label: "#0a0b0c",
                muted: "#5f5a66",
                rowIcon: "#5f5a66",
                pink: "#ff66aa",
                focus: "#00ff00",
                divider: "#c9c4ce",
                sessionText: "#c2185b",
            }
            menu.lockTheme = theme
            compare(menu.panelColor, "#123456")
            compare(menu.triggerColor, "#654321")
            compare(menu.activeColor, "#abcdef")
            compare(menu.dividerColor, "#c9c4ce")
            compare(menu.sessionTextColor, "#c2185b")

            const rows = harness.findRows(menu)
            compare(rows.length, 5)
            for (let i = 0; i < rows.length; ++i) {
                const row = rows[i]
                compare(row.labelColor, "#0a0b0c", "row label must be frozen")
                compare(row.iconColor, "#5f5a66", "row icon must be frozen")
                compare(row.pinkColor, "#ff66aa", "row accent must be frozen")
                compare(row.accentColor, "#ff66aa", "row bar must be frozen")
                compare(row.hoverColor, "#fedcba", "row hover must be frozen")
                compare(row.activeColor, "#abcdef", "row active must be frozen")
                compare(row.focusColor, "#00ff00", "row focus must be frozen")
            }
            menu.lockTheme = null
        }

        // Translucent hover/active washes are intentional in the lazer theme;
        // rejecting them swapped a real tint for an unrelated surface color.
        function test_snapshotKeepsTranslucentFills() {
            const hover = Qt.rgba(0.11, 0.10, 0.12, 0.078)
            const active = Qt.rgba(0.7, 0.2, 0.4, 0.141)
            const snapshot = SurfaceLogic.lockThemeSnapshot(false, {
                accent: Qt.rgba(1, 0.4, 0.667, 1),
                surface: Qt.rgba(0.1, 0.09, 0.11, 1),
                control: Qt.rgba(0.15, 0.13, 0.18, 1),
                hover: hover,
                active: active,
                label: Qt.rgba(0.9, 0.88, 0.92, 1),
            })
            compare(snapshot.hover, hover)
            compare(snapshot.active, active)
            verify(snapshot.label.hslLightness > 0.5)
        }

        function test_entranceRevealKeepsMenuHiddenAndDisabledUntilWaveTail() {
            menu.open = false
            menu.entranceRevealed = false
            verify(!menu.visible)
            verify(!menu.enabled)

            menu.entranceRevealed = true
            verify(menu.visible)
            verify(menu.enabled)
        }

        function test_triggerOpensAndEscapeCloses() {
            menu.toggleOpen()
            compare(menu.open, true)
            compare(menu.revealProgress, 1)
            verify(menu.handleEscape())
            compare(menu.open, false)
            compare(menu.revealProgress, 0)
        }

        function test_lockExecutesWithoutConfirmation() {
            menu.open = true
            menu.activateAction("lock")
            compare(fakeService.calls, ["lock"])
            compare(menu.pendingAction, "")
            compare(menu.open, false)
        }

        function test_systemActionRequiresSecondActivation() {
            menu.open = true
            menu.activateAction("shutdown")
            compare(fakeService.calls, [])
            compare(menu.pendingAction, "shutdown")
            menu.activateAction("shutdown")
            compare(fakeService.calls, ["shutdown"])
            compare(menu.pendingAction, "")
        }

        function test_unavailableActionDoesNotExecute() {
            menu.open = true
            fakeService.unavailable = true
            menu.activateAction("reboot")
            compare(fakeService.calls, [])
            compare(menu.pendingAction, "")
        }

        function test_escapeCancelsConfirmationBeforeClosing() {
            menu.open = true
            menu.activateAction("logout")
            verify(menu.handleEscape())
            compare(menu.pendingAction, "")
            compare(menu.open, true)
            verify(menu.handleEscape())
            compare(menu.open, false)
        }
    }
}
