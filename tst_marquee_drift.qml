import QtQuick
import "./modules/bar"

// Regression harness for the active-window/media marquee. Each scenario gets
// a fresh MarqueeLabel so phases cannot pollute each other's state.
//
// Scenarios:
//  1..4 — after switches/interrupts/morphs/churn, label.x must stay inside
//         [-(overflow), 0]; drifting past -(overflow) means the text fully
//         exits the left viewport (the reported bug).
//  5    — pacing: a huge title must finish its full out-and-back cycle
//         quickly; an unclamped linear pace once crawled left for ~40s,
//         reading as the title drifting away and never coming back.
//
// Run from repo root: qs -p tst_marquee_drift.qml
Item {
    id: root

    property int _failures: 0
    property int _checks: 0

    readonly property int sampleMs: 150
    readonly property int maxCycleMs: 24000

    property var _label: null
    property real _elapsed: 0
    property int _phaseMs: 0
    property string _phase: ""
    property real _minX: 0
    property real _maxD: 0
    property bool _deepSeen: false
    property bool _ghostSeen: false
    property int _maxGhostCount: 0

    function check(labelText, actual, expected) {
        root._checks += 1
        if (actual === expected) {
            console.log("PASS:", labelText)
            return
        }
        root._failures += 1
        console.log("FAIL:", labelText, "expected", JSON.stringify(expected),
                    "got", JSON.stringify(actual))
    }

    function overflowDistance() {
        return Math.max(0, _label.label.width - _label.slot.width)
    }

    function beginSampling(phase, ms) {
        root._phase = phase
        root._phaseMs = ms
        root._elapsed = 0
        root._minX = 0
        root._maxD = 0
        sampler.restart()
    }

    function finishPhase() {
        sampler.stop()
        var d = root.overflowDistance()
        var boundD = Math.max(d, root._maxD)
        console.log("[", root._phase, "] minX:", root._minX.toFixed(1),
                    "bound:", (-(boundD + 4)).toFixed(1))
        root.check(root._phase + ": label.x never exits left viewport",
                   root._minX >= -(boundD + 4), true)
        if (root._phase === "deep-exit-ghost")
            root.check("deep-exit-ghost: old characters remain visible to fall",
                       root._ghostSeen, true)
        if (root._phase === "rapid-interrupt")
            root.check("rapid-interrupt: only one ghost generation remains",
                       root._maxGhostCount <= root._label.transitionMaxChars, true)
        _label.destroy()
        _label = null
        Qt.callLater(root._phases.shift())
    }

    function makeLabel() {
        var comp = Qt.createComponent("modules/bar/MarqueeLabel.qml")
        root._label = comp.createObject(root, {
            maxWidth: 200,
            textColor: "white",
            pixelSize: 12,
            bold: true
        })
        return root._label
    }

    Timer {
        id: sampler

        interval: root.sampleMs
        repeat: true
        running: false
        onTriggered: {
            root._elapsed += root.sampleMs
            if (root._phase === "rapid-interrupt") {
                var ghosts = root._label.overlay.children
                var activeGhosts = 0
                for (var ghostIndex = 0; ghostIndex < ghosts.length; ghostIndex++) {
                    if (ghosts[ghostIndex].visible && ghosts[ghostIndex].opacity > 0)
                        activeGhosts++
                }
                if (activeGhosts > root._maxGhostCount)
                    root._maxGhostCount = activeGhosts
            }
            // Give entrance choreography time to hand back to the real label.
            if (root._elapsed < 1200)
                return
            var x = root._label.label.x
            var d = root.overflowDistance()
            // Bound against the widest overflow seen in this phase: a phase
            // that ends on short text has d==0 and any negative x would be
            // a trivial false positive.
            if (d > root._maxD)
                root._maxD = d
            if (x < root._minX)
                root._minX = x
            if (root._phase === "pacing-full-cycle") {
                if (!root._deepSeen && d > 0 && x <= -(d * 0.5))
                    root._deepSeen = true
                var cycleDone = root._deepSeen && x >= -(d * 0.02)
                if (cycleDone || root.elapsedSinceMark() > root.maxCycleMs) {
                    console.log("[pacing] full cycle took",
                                Math.round(root.elapsedSinceMark()), "ms — cap",
                                root.maxCycleMs,
                                cycleDone ? "(completed)" : "(TIMED OUT)")
                    root.check("pacing-full-cycle: out-and-back completes in time",
                               cycleDone, true)
                    sampler.stop()
                    cycleClock.stop()
                    root._label.destroy()
                    root._label = null
                    Qt.callLater(root._phases.shift())
                    return
                }
            }
            if (root._phase === "deep-exit-ghost") {
                var kids = root._label.overlay.children
                for (var k = 0; k < kids.length; k++) {
                    if (kids[k].text && kids[k].text.length === 1
                            && kids[k].x < root._label.slot.width
                            && kids[k].x + kids[k].width > 0) {
                        root._ghostSeen = true
                        break
                    }
                }
            }
            if (root._elapsed >= root._phaseMs)
                root.finishPhase()
        }
    }

    // Cycle clock for the pacing scenario, independent of the handback gate.
    property real _cycleElapsed: 0
    function elapsedSinceMark() { return root._cycleElapsed }

    Timer {
        id: cycleClock

        interval: 100
        repeat: true
        running: false
        onTriggered: root._cycleElapsed += 100
    }

    property var _phases: []

    Component.onCompleted: Qt.callLater(function () {
        root._phases = [
            // 1 — steady marquee after a switch into a long title.
            function () {
                var m = root.makeLabel()
                m.text = "short"
                var long_ = "Neovim — ~/.config/quickshell/afloat/modules/bar/widgets/ActiveWindow.qml"
                m.text = long_
                m.transitionFrom("short", long_)
                root.beginSampling("steady-after-switch", 8000)
            },
            // 2 — alt-tab round trip: leave while scrolled deep, come back.
            function () {
                var m = root.makeLabel()
                m.text = "Neovim — ~/.config/quickshell/afloat/modules/bar/widgets/ActiveWindow.qml"
                var t = Qt.createQmlObject("import QtQuick; Timer { }", root)
                t.interval = 2500
                var n = 0
                t.triggered.connect(function () {
                    n += 1
                    if (n === 1) {
                        m.text = "short"
                        m.transitionFrom(m.label.text, "short")
                    } else if (n === 2) {
                        m.text = "Neovim — ~/.config/quickshell/afloat/modules/bar/widgets/ActiveWindow.qml"
                        m.transitionFrom("short", m.text)
                        t.stop()
                    }
                })
                t.start()
                root.beginSampling("deep-switch-roundtrip", 9000)
            },
            // 3 — interrupt an in-flight sweep with another long title.
            function () {
                var m = root.makeLabel()
                var firstTitle = "Neovim — ~/.config/quickshell/afloat/modules/bar/widgets/ActiveWindow.qml"
                var secondTitle = firstTitle + " [one]"
                var oldTitle = firstTitle + " [old]"
                m.text = firstTitle
                m.transitionFrom(oldTitle, firstTitle)
                var t = Qt.createQmlObject("import QtQuick; Timer { }", root)
                t.interval = 300
                t.triggered.connect(function () {
                    t.stop()
                    m.text = secondTitle
                    m.transitionFrom(firstTitle, secondTitle)
                })
                t.start()
                root.beginSampling("rapid-interrupt", 9000)
            },
            // 4 — high-frequency title churn (~60Hz), like a browser tab.
            function () {
                var m = root.makeLabel()
                m.text = "build 0% — long churned title that overflows the cap"
                var t = Qt.createQmlObject("import QtQuick; Timer { repeat: true }", root)
                var n = 0
                t.interval = 16
                t.triggered.connect(function () {
                    n += 1
                    if (n > 120) { t.stop(); return }
                    var next = "build " + n + "% — long churned title that overflows the cap"
                    m.text = next
                    if (n % 6 === 1)
                        m.transitionFrom(m.label.text, next)
                })
                t.start()
                root.beginSampling("title-churn", 9000)
            },
            // 5 — a deeply scrolled old title must still leave visible ghosts.
            function () {
                var m = root.makeLabel()
                var oldTitle = "old-title-"
                for (var i = 0; i < 20; i++)
                    oldTitle += "segment-" + i + "-"
                m.text = oldTitle
                var t = Qt.createQmlObject("import QtQuick; Timer { }", root)
                t.interval = 9000
                t.triggered.connect(function () {
                    t.stop()
                    m.text = "new-title"
                    m.transitionFrom(oldTitle, "new-title")
                    root._ghostSeen = false
                })
                t.start()
                root.beginSampling("deep-exit-ghost", 12000)
            },
            // 6 — pacing: huge title must complete its cycle inside the cap.
            function () {
                var m = root.makeLabel()
                var huge = ""
                for (var i = 0; i < 200; i++)
                    huge += "word "
                m.text = huge
                root._deepSeen = false
                root._cycleElapsed = 0
                cycleClock.start()
                root.beginSampling("pacing-full-cycle", 120000)
            },
            function () {
                console.log("Totals:", root._checks - root._failures, "passed,",
                            root._failures, "failed")
                Qt.quit(root._failures === 0 ? 0 : 1)
            },
        ]
        Qt.callLater(root._phases.shift())
    })
}
