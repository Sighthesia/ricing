import QtQuick
import Quickshell
import "./services" as Services

// Behavioural checks for the clipboard list announcement, run from the repo
// root so ./services resolves inside the config folder:
//   qs -p tst_clipboard_list_announce.qml
//
// The history is polled every few seconds, and the launcher re-pulls the whole
// history whenever a poll announces itself. Announcing every poll meant a full
// re-stream of ~750 rows every five seconds for as long as the launcher sat
// open, on the frames the user is looking at, for a set that had not changed.
//
// This drives the real service singleton and finishes in milliseconds, before
// the first poll can fire: it overwrites the published rows rather than waiting
// for cliphist. Measured against the real database with
// harness_clipboard_cost.qml, which is where the end-to-end count comes from.
Item {
    id: root

    property int _failures: 0
    property int _checks: 0

    function check(label, actual, expected) {
        root._checks += 1
        if (actual === expected) {
            console.log("PASS:", label)
            return
        }
        root._failures += 1
        console.log("FAIL:", label, "expected", JSON.stringify(expected),
                    "got", JSON.stringify(actual))
    }

    function rows(ids) {
        var out = []
        for (var i = 0; i < ids.length; i++)
            out.push({ id: ids[i], preview: "text " + i })
        return out
    }

    function service() { return Services.ClipboardService }

    function run() {
        var service = root.service()

        // Nothing published yet: the first set has to announce, or the launcher's
        // very first load would wait for a completion that never came.
        service.items = root.rows(["3", "2", "1"])
        root.check("a fresh set announces", service.announceListIfChanged(), true)

        // The poll that matters: the same set again, five seconds later.
        service.items = root.rows(["3", "2", "1"])
        root.check("an unchanged poll stays quiet",
                service.announceListIfChanged(), false)
        root.check("and it is recorded as unchanged",
                service._listUnchangedSinceLastPublish, true)

        // A copy prepends an entry and drops the oldest: the length is
        // unchanged, so only the ids themselves give it away.
        service.items = root.rows(["4", "3", "2"])
        root.check("a copy at the same length announces",
                service.announceListIfChanged(), true)

        service.items = root.rows(["4", "3", "2"])
        root.check("and it is news exactly once",
                service.announceListIfChanged(), false)

        // Rank order is the launcher's whole ordering, so a reorder matters.
        service.items = root.rows(["1", "2", "3"])
        root.check("a reordered set announces", service.announceListIfChanged(), true)

        service.items = root.rows(["3", "2", "1"])
        root.check("a trimmed set announces", service.announceListIfChanged(), true)

        service.items = []
        root.check("an empty set is never silently swallowed",
                service.announceListIfChanged(), true)

        console.log("Totals:", root._checks - root._failures, "passed,",
                    root._failures, "failed")
        Qt.quit()
    }

    Component.onCompleted: Qt.callLater(root.run)
}
