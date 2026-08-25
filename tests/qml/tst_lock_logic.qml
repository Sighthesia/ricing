import QtQuick
import QtTest
import "../../services/lock/LockLogic.js" as Logic

// Verify the pure key classification, buffer edits, and PAM outcome mapping
// without a compositor or PamContext.
//
// NOTE: this environment cannot run `qs -p <file>` configs whose relative .js
// imports get blackholed (quickshell 0.3.1 single-file config limitation), nor
// qmltestrunner (silently exits 1). Until that is resolved, verify via a
// directory-config harness: copy LockLogic.js next to a shell.qml that asserts
// the same contracts and run `qs -p <harness-dir>`.
TestCase {
    name: "LockLogic"

    function test_keyClassification() {
        compare(Logic.keyAction(Logic.keyReturn, false), "submit")
        compare(Logic.keyAction(Logic.keyEnter, true), "submit")
        compare(Logic.keyAction(Logic.keyBackspace, false), "backspace")
        compare(Logic.keyAction(Logic.keyBackspace, true), "clear")
        compare(Logic.keyAction(Qt.Key_A, false), "input")
        compare(Logic.keyAction(Qt.Key_Shift, false), "input")
    }

    function test_bufferEdits() {
        var r = Logic.applyKey("", Qt.Key_A, "a", false)
        compare(r.action, "changed")
        compare(r.buffer, "a")
        r = Logic.applyKey("ab", Qt.Key_A, "c", false)
        compare(r.buffer, "abc")
        // Backspace trims one character and ignores on empty buffer.
        r = Logic.applyKey("ab", Logic.keyBackspace, "", false)
        compare(r.action, "changed")
        compare(r.buffer, "a")
        r = Logic.applyKey("", Logic.keyBackspace, "", false)
        compare(r.action, "ignored")
        compare(r.buffer, "")
        // Ctrl+Backspace wipes the whole buffer.
        r = Logic.applyKey("secret", Logic.keyBackspace, "", true)
        compare(r.action, "changed")
        compare(r.buffer, "")
        // Submit passes the current buffer through untouched.
        r = Logic.applyKey("secret", Logic.keyReturn, "", false)
        compare(r.action, "submit")
        compare(r.buffer, "secret")
    }

    function test_controlCharactersRejected() {
        verify(Logic.applyKey("", Qt.Key_Escape, "\x1b", false).action === "ignored")
        verify(Logic.applyKey("", Qt.Key_Tab, "\t", false).action === "ignored")
        verify(Logic.applyKey("", Qt.Key_Delete, "", false).action === "ignored")
    }

    function test_bufferSizeCap() {
        var full = new Array(Logic.maxBufferSize + 1).join("x")
        compare(full.length, Logic.maxBufferSize)
        verify(Logic.applyKey(full, Qt.Key_A, "y", false).action === "ignored")
        verify(Logic.applyKey(full.slice(0, -1), Qt.Key_A, "y", false).action === "changed")
    }

    function test_submitGate() {
        verify(!Logic.canAttemptSubmit("", false))
        verify(!Logic.canAttemptSubmit("pw", true))
        verify(Logic.canAttemptSubmit("pw", false))
    }

    function test_outcomeMapping() {
        compare(Logic.outcomeState(0, 0, 4, 5), "success")
        compare(Logic.outcomeState(4, 0, 4, 5), "maxTries")
        compare(Logic.outcomeState(5, 0, 4, 5), "error")
        compare(Logic.outcomeState(6, 0, 4, 5), "failed")
        compare(Logic.outcomeState("bad", 0, 4, 5), "failed")
    }
}
