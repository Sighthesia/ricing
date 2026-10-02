import QtQuick
import Quickshell
import "./services" as Services
import "./modules/bar" as Bar
import "./modules/lazerbar" as LazerBar

// Instantiation-cost probe for the subtrees TopBar builds but never shows.
//
// The load-cost probe measured the widgets the bar actually paints: ~14ms warm,
// ~300ms cold, same object graph either way. That gap is one-time per-type work —
// Qt building the type, creating the objects, resolving the first font, standing
// up shader-backed effects, rasterizing SVG icons.
//
// The bar audit turned up a second and larger consumer of that same one-time
// work. BarPopupHost and LazerSettingsOverlay construct their entire content
// tree at startup behind `visible: false`, which does NOT gate construction in
// QML — only `Loader.active` does. Per screen that is a popup body carrying a
// 42-cell calendar grid and six rolling-digit clocks, plus a settings panel of 35
// rows that each carry an Image and a MultiEffect.
//
// Each tree is built twice through one Loader. The first build pays compile plus
// instantiate; the second pays instantiate alone. That difference is the part
// that could be moved off the startup path.
//
// Offscreen-safe: every target is a plain Item, so nothing here opens a window.
// The PanelWindow wrappers around them cannot be built headless, which is
// precisely why this measures the contents — it separates the cost of the
// content tree from the cost of the surface.
//
// Run from the repo root:
//   qs -p tst_invisible_subtree_cost.qml
Item {
    id: root
    width: 320
    height: 48

    property int failures: 0
    property int checks: 0
    property bool finished: false

    function check(label, condition, detail) {
        root.checks++
        if (condition) {
            console.log("PASS:", label)
            return
        }
        root.failures++
        console.log("FAIL:", label, detail !== undefined ? "| " + detail : "")
    }

    // Plain Items only. Paths resolve against this file, so they are the same
    // files the shell loads. A PanelWindow-backed target cannot load headless
    // and is reported as such rather than silently counted as zero.
    readonly property var targets: [
        { name: "popup/BarPopupIdentity", path: "./modules/bar/BarPopupIdentity.qml" },
        { name: "popup/BarPopupActions", path: "./modules/bar/BarPopupActions.qml" },
        { name: "popup/BarContextPopupActions", path: "./modules/bar/BarContextPopupActions.qml" },
        { name: "settings/LazerSettingsPanel", path: "./modules/lazerbar/LazerSettingsPanel.qml" },
        { name: "settings/LazerSettingsSidebar", path: "./modules/lazerbar/LazerSettingsSidebar.qml" },
        { name: "settings/LazerSettingsContent", path: "./modules/lazerbar/LazerSettingsContent.qml" },
        { name: "settings/LazerSettingsRow", path: "./modules/lazerbar/LazerSettingsRow.qml" },
        { name: "widgets/ClockPopupContent", path: "./modules/bar/widgets/ClockPopupContent.qml" },
        { name: "bar/MarqueeLabel", path: "./modules/bar/MarqueeLabel.qml" },
        { name: "bar/BarIcon", path: "./modules/bar/BarIcon.qml" },
    ]

    property var rows: []
    property int index: 0
    property bool warmPass: false
    property double startedAt: 0
    property bool armed: false

    // Parked off-screen and never shown: this measures construction, not
    // painting. `active` is the gate under test, so it is driven explicitly.
    Loader {
        id: probe
        x: -100000
        active: false
        source: ""

        onLoaded: {
            if (!root.armed)
                return
            root.armed = false
            root.finishBuild(Date.now() - root.startedAt, false)
        }

        // A component that cannot be built headless lands here instead, and is
        // recorded as "did not load" rather than as a zero cost.
        onStatusChanged: {
            if (!root.armed)
                return
            if (status === Loader.Error) {
                root.armed = false
                root.finishBuild(0, true)
            }
        }
    }

    function finishBuild(cost, failed) {
        const target = targets[index]
        if (!root.warmPass) {
            root.rows.push({ name: target.name, cold: cost, warm: 0, failed: failed })
        } else if (index < root.rows.length) {
            root.rows[index].warm = cost
            root.rows[index].warmFailed = failed
        }
        // Tear down before moving on, so nothing stays resident and the next
        // build starts from an empty tree.
        probe.active = false
        probe.source = ""
        root.index++
        Qt.callLater(root.next)
    }

    function next() {
        if (root.index >= targets.length) {
            if (!root.warmPass) {
                root.warmPass = true
                root.index = 0
                Qt.callLater(root.next)
            } else {
                root.report()
            }
            return
        }
        probe.source = targets[index].path
        root.startedAt = Date.now()
        root.armed = true
        probe.active = true
    }

    function report() {
        const sorted = root.rows.slice().sort(function(a, b) { return b.cold - a.cold })
        console.log("[subtree] instantiation cost, cold (compile+build) vs warm (rebuild) in ms:")
        let coldTotal = 0
        let warmTotal = 0
        let coldLoaded = 0
        for (let i = 0; i < sorted.length; i++) {
            if (!sorted[i].failed) {
                coldTotal += sorted[i].cold
                warmTotal += sorted[i].warm
                coldLoaded++
            }
            console.log("[subtree]   " + String(sorted[i].cold).padStart(5) + " cold  "
                + String(sorted[i].warm).padStart(4) + " warm  " + sorted[i].name
                + ((sorted[i].failed || sorted[i].warmFailed) ? "  (did not load headless)" : ""))
        }
        console.log("[subtree] total cold " + coldTotal + " ms, warm " + warmTotal
            + " ms over " + coldLoaded + " loadable targets")
        console.log("[subtree] the cold column is per screen, multiplied by screen count")

        root.check("every target was attempted twice",
                   root.rows.length === targets.length,
                   root.rows.length + "/" + targets.length)
        const loaded = root.rows.filter(function(r) { return !r.failed && !r.warmFailed })
        root.check("at least half the targets load headless",
                   loaded.length * 2 >= targets.length,
                   "loaded=" + loaded.length + "/" + targets.length)
        // The story this probe exists to test: a rebuild must not cost more than
        // the first build. If it did, the one-time framing would be wrong and
        // every decision made from it would need revisiting.
        root.check("warm rebuild never exceeds cold build",
                   loaded.every(function(r) { return r.warm <= r.cold + 5 }),
                   JSON.stringify(loaded.filter(function(r) { return r.warm > r.cold + 5 })))
        root.finish()
    }

    function finish() {
        if (root.finished)
            return
        root.finished = true
        giveUp.stop()
        console.log("Totals: " + (root.failures === 0
            ? root.checks + " passed, 0 failed"
            : root.failures + " failed"))
        Qt.quit()
    }

    Timer {
        id: giveUp
        interval: 120000
        repeat: false
        onTriggered: {
            console.log("FAIL: subtree probe did not finish | warmPass=" + root.warmPass
                + " index=" + root.index + " rows=" + root.rows.length)
            root.failures++
            root.finish()
        }
    }

    Component.onCompleted: {
        giveUp.restart()
        Qt.callLater(root.next)
    }
}