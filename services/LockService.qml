pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import "./" as Services
import "lock/LockLogic.js" as Logic

// Session lock state owner: password buffer, PAM verification, and the lock
// trigger surface (IPC). The WlSessionLock window itself lives in the visual
// module; it mirrors `locked` and plays the exit animation before calling
// finishUnlock(), because dropping the lock before the animation ends makes
// the compositor show an uninteractive fallback screen.
Singleton {
    id: root

    // True while the session is locked; every per-screen surface exists.
    property bool locked: false
    // Shared password buffer so all lock surfaces stay in sync.
    property string buffer: ""
    // True between a submit and the PAM completion.
    property bool unlockInProgress: false
    // Last failure feedback state: none | failed | maxTries | error.
    property string failureState: "none"

    // Emitted on PAM success; the surface plays its exit animation and must
    // call finishUnlock() when done. Never set locked=false directly.
    signal unlockRequested()
    signal failed()

    // TEMPORARY testing failsafe: release the lock 10s after activation so a
    // bug can never strand the session behind an ununlockable screen. It
    // rides the normal unlockRequested path (animated exit). Remove once the
    // lock screen is proven stable.
    readonly property bool failsafeEnabled: true
    readonly property int failsafeDelayMs: 10000

    onLockedChanged: {
        if (locked && failsafeEnabled)
            failsafeTimer.restart()
        else
            failsafeTimer.stop()
    }

    Timer {
        id: failsafeTimer
        interval: root.failsafeDelayMs
        running: false
        repeat: false
        onTriggered: {
            if (!root.locked)
                return
            console.warn("LockService: failsafe fired, releasing lock after", root.failsafeDelayMs, "ms")
            root.unlockInProgress = false
            root.unlockRequested()
        }
    }

    function lock() {
        if (!locked)
            locked = true
    }

    // Route one key event through the pure buffer contracts. Surfaces with a
    // native text field do not need this; keyboard-only surfaces forward here.
    function handleKey(keyCode, text, hasControlModifier) {
        var out = Logic.applyKey(buffer, keyCode, text, hasControlModifier)
        if (out.action === "submit") {
            tryUnlock()
            return
        }
        if (out.action !== "changed")
            return
        setBuffer(out.buffer)
    }

    function setBuffer(next) {
        if (next === buffer)
            return
        buffer = String(next == null ? "" : next)
        if (buffer.length > 0 && failureState !== "none" && failureState !== "maxTries")
            failureState = "none"
    }

    function clearBuffer() {
        setBuffer("")
    }

    function tryUnlock() {
        if (!Logic.canAttemptSubmit(buffer, unlockInProgress))
            return
        unlockInProgress = true
        pam.start()
    }

    // Called by the surface after the unlock exit animation finishes.
    function finishUnlock() {
        unlockInProgress = false
        buffer = ""
        failureState = "none"
        locked = false
    }

    PamContext {
        id: pam
        config: "passwd"
        configDirectory: Quickshell.shellDir + "/assets/pam.d"

        onResponseRequiredChanged: {
            if (responseRequired)
                respond(root.buffer)
        }

        onCompleted: result => {
            root.unlockInProgress = false
            var state = Logic.outcomeState(result, PamResult.Success,
                PamResult.MaxTries, PamResult.Error)
            if (state === "success") {
                root.unlockRequested()
                return
            }
            root.buffer = ""
            root.failureState = state
            root.failed()
        }
    }

    // IPC entry for scripts/afloat-ipc and niri keybind spawns.
    IpcHandler {
        target: "lock"
        function activate() { root.lock() }
        function isLocked() { return root.locked }
    }
}
