import QtQuick
import QtTest
import "../../modules/lock"
import "../../modules/lock/LockSurfaceLogic.js" as SurfaceLogic

Item {
    id: harness
    width: 520
    height: 420

    // Records what the row hands back to the lock surface's keyboard owner.
    property int keyboardReleases: 0
    property var forwardedKeys: []

    QtObject {
        id: fakeService
        property bool running: false
        property string errorText: ""
        property string resultText: ""
        property var calls: []
        property bool unavailable: false
        signal actionFinished(string actionId, bool success, string message)

        function isAvailable(actionId) {
            return !unavailable
                    && ["lock", "logout", "suspend", "reboot", "shutdown"].indexOf(actionId) >= 0
        }

        function execute(actionId) {
            if (running || !isAvailable(actionId))
                return false
            calls = calls.concat([actionId])
            return true
        }
    }

    LockActionBar {
        id: bar
        x: 24
        y: 200
        reducedMotion: true
        sessionService: fakeService
    }

    Connections {
        target: bar
        function onKeyboardReleased() { harness.keyboardReleases += 1 }
        function onKeyForwarded(key, text) {
            harness.forwardedKeys = harness.forwardedKeys.concat([key + ":" + text])
        }
    }

    // The row is not a list, so walk the tree instead of hard-coding child
    // indexes; that keeps the geometry and color contracts testable.
    function findButtons(item) {
        const found = []
        const kids = item.children || []
        for (let i = 0; i < kids.length; ++i) {
            const child = kids[i]
            if (child.actionId !== undefined && child.markColor !== undefined)
                found.push(child)
            found.push.apply(found, findButtons(child))
        }
        return found
    }

    function buttonFor(actionId) {
        const buttons = findButtons(bar)
        for (let i = 0; i < buttons.length; ++i) {
            if (buttons[i].actionId === actionId)
                return buttons[i]
        }
        return null
    }

    function findByName(item, name) {
        const kids = item.children || []
        for (let i = 0; i < kids.length; ++i) {
            if (kids[i].objectName === name)
                return kids[i]
            const found = findByName(kids[i], name)
            if (found)
                return found
        }
        return null
    }

    TestCase {
        name: "LockActionBar"
        when: windowShown

        function init() {
            bar.entranceRevealed = true
            bar.pendingAction = ""
            bar.errorText = ""
            bar.statusText = ""
            bar.lockTheme = null
            fakeService.calls = []
            fakeService.running = false
            fakeService.unavailable = false
            harness.keyboardReleases = 0
            harness.forwardedKeys = []
        }

        function test_rowIsThreeButtonsAtTheLockEntrySize() {
            const buttons = findButtons(bar)
            compare(buttons.length, 3)
            compare(buttons.map(function(b) { return b.actionId }),
                    ["suspend", "shutdown", "logout"])
            // 68x48 is the centered lock control's collapsed footprint.
            compare(bar.buttonWidth, 68)
            compare(bar.buttonHeight, 48)
            compare(bar.implicitWidth, 3 * 68 + 2 * 10)
            for (let i = 0; i < buttons.length; ++i) {
                compare(buttons[i].width, 68)
                compare(buttons[i].height, 48)
            }
        }

        // The buttons are glyph-only, so the armed state has to be carried by
        // tone and the status line instead of a caption swap.
        function test_armedActionIsMarkedByToneAndTheStatusLine() {
            const shutdown = buttonFor("shutdown")
            compare(shutdown.confirmationPending, false)
            bar.activateAction("shutdown")
            compare(shutdown.confirmationPending, true)
            compare(shutdown.markColor, bar.pinkColor)
            compare(bar.statusMessage, "Confirm Shut down?")
            // Only the armed button turns; its neighbours stay neutral.
            compare(buttonFor("suspend").confirmationPending, false)
            compare(buttonFor("suspend").markColor, buttonFor("logout").markColor)
        }

        // The whole row, buttons included, must read one frozen snapshot;
        // otherwise a live palette transition repaints it against a surface
        // that no longer moves.
        function test_everyColorRoleComesFromTheLockSnapshot() {
            const theme = {
                lightScheme: true,
                accent: "#ff66aa",
                surface: "#f2f0f5",
                control: "#654321",
                panel: "#123456",
                trigger: "#654321",
                active: "#abcdef",
                hover: "#fedcba",
                label: "#0a0b0c",
                muted: "#5f5a66",
                pink: "#ff66aa",
                focus: "#00ff00",
                divider: "#c9c4ce",
                sessionText: "#c2185b",
            }
            bar.lockTheme = theme
            compare(bar.controlColor, "#654321")
            compare(bar.hoverColor, "#fedcba")
            compare(bar.activeColor, "#abcdef")
            compare(bar.dividerColor, "#c9c4ce")
            compare(bar.textColor, "#c2185b")

            const buttons = findButtons(bar)
            for (let i = 0; i < buttons.length; ++i) {
                const button = buttons[i]
                compare(button.controlColor, "#654321", "button surface must be frozen")
                compare(button.hoverColor, "#fedcba", "button hover must be frozen")
                compare(button.activeColor, "#abcdef", "button active must be frozen")
                compare(button.dividerColor, "#c9c4ce", "button border must be frozen")
                compare(button.focusColor, "#00ff00", "button focus must be frozen")
                compare(button.pinkColor, "#ff66aa", "button confirm tone must be frozen")
                compare(button.labelColor, "#0a0b0c", "button label must be frozen")
                compare(button.accentColor, "#ff66aa", "button indicator must be frozen")
            }
            bar.lockTheme = null
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

        function test_entranceRevealKeepsRowHiddenAndDisabledUntilWaveTail() {
            bar.entranceRevealed = false
            verify(!bar.visible)
            verify(!bar.enabled)

            bar.entranceRevealed = true
            verify(bar.visible)
            verify(bar.enabled)
        }

        function test_powerActionArmsThenExecutes() {
            bar.activateAction("shutdown")
            compare(fakeService.calls, [])
            compare(bar.pendingAction, "shutdown")
            compare(bar.statusMessage, "Confirm Shut down?")

            bar.activateAction("shutdown")
            compare(fakeService.calls, ["shutdown"])
            compare(bar.pendingAction, "")
        }

        function test_otherActionDoesNotStealAnArmedConfirmation() {
            bar.activateAction("suspend")
            bar.activateAction("logout")
            compare(fakeService.calls, [])
            compare(bar.pendingAction, "suspend")
        }

        function test_unavailableActionDoesNotExecute() {
            fakeService.unavailable = true
            bar.activateAction("logout")
            compare(fakeService.calls, [])
            compare(bar.pendingAction, "")
            compare(buttonFor("logout").opacity < 1, true, "unavailable action dims")
        }

        function test_runningServiceDisablesEveryButton() {
            fakeService.running = true
            const buttons = findButtons(bar)
            for (let i = 0; i < buttons.length; ++i) {
                verify(!buttons[i].interactive, buttons[i].actionId + " must be inert")
                verify(!buttons[i].activeFocusOnTab, "no button may steal Tab focus")
            }
            bar.activateAction("suspend")
            compare(fakeService.calls, [])
        }

        function test_escapeCancelsTheArmedConfirmation() {
            bar.activateAction("logout")
            verify(bar.handleEscape())
            compare(bar.pendingAction, "")
            compare(bar.statusMessage, "")
            // Nothing left to cancel: the key falls through to the auth owner.
            verify(!bar.handleEscape())
        }

        function test_finishedFailureSurfacesTheServiceMessage() {
            bar.activateAction("shutdown")
            fakeService.actionFinished("shutdown", false, "Session action failed")
            compare(bar.pendingAction, "")
            compare(bar.errorText, "Session action failed")
            compare(bar.statusMessage, "Session action failed")

            fakeService.actionFinished("shutdown", true, "shutdown requested")
            compare(bar.errorText, "")
            compare(bar.statusMessage, "shutdown requested")
        }

        // A Tab-focused power button must never become a second keyboard owner:
        // it forwards what it does not own and returns the keyboard otherwise.
        function test_buttonForwardsUnownedKeysAndHandsTheKeyboardBack() {
            const suspend = buttonFor("suspend")
            verify(suspend.handleKey(Qt.Key_A, "a"))
            compare(harness.forwardedKeys, [Qt.Key_A + ":a"])

            verify(suspend.handleKey(Qt.Key_Return, ""))
            compare(bar.pendingAction, "suspend")
            verify(suspend.handleKey(Qt.Key_Escape, ""))
            compare(bar.pendingAction, "")
            compare(harness.keyboardReleases, 0, "a cancelled confirmation is consumed")

            verify(suspend.handleKey(Qt.Key_Escape, ""))
            compare(harness.keyboardReleases, 1, "an idle Escape returns the keyboard")
        }

        // With the names gone, the row's whole identity is the lock entry's
        // own box: 68x48 with a centered 22px glyph.
        function test_glyphsAreTheCenteredLockGlyphBox() {
            const buttons = findButtons(bar)
            for (let i = 0; i < buttons.length; ++i) {
                const glyph = findByName(buttons[i], "actionGlyph")
                compare(glyph.width, 22, buttons[i].actionId + " glyph size")
                compare(glyph.height, 22, buttons[i].actionId + " glyph size")
                compare(glyph.x, (buttons[i].width - 22) / 2,
                        buttons[i].actionId + " glyph must be centered")
                compare(glyph.y, (buttons[i].height - 22) / 2,
                        buttons[i].actionId + " glyph must be centered")
            }
        }

        // The lock entry is the password field's own control, so no button may
        // force focus on hover and strand the next typed character.
        function test_buttonsStayTabReachableWithoutForcingFocus() {
            const suspend = buttonFor("suspend")
            verify(suspend.activeFocusOnTab)
            verify(!suspend.activeFocus)
            verify(!suspend.focus)
        }
    }
}
