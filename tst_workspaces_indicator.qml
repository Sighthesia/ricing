import QtQuick
import "./services" as Services
import "./modules/lazerbar" as Lazer

// Regression harness for the workspace overview: feeds fake Niri windows
// through the real NiriService model path, mounts the real Workspaces widget,
// and verifies app icons render, the focused icon stays bright, the single
// indicator tracks workspace/app switches, and rapid content bursts never
// lose icon delegates (delegate-churn-icon-storm).
Item {
    id: root

    property int failures: 0
    property int phase: 0
    property int ticks: 0
    property var wsInstance: null
    property var wsComponent: null
    property int swapsBeforeChurn: -1
    property int churnLeft: 0
    property int burstLeft: 0
    property bool burstToggle: false
    // Real workspace ids (or faked when no compositor): squares come from
    // NiriService.workspaces; fake 900-ids are fed through updateWindows and
    // re-fed if a live compositor event clobbers the scenario mid-run.
    property string wsA: ""
    property string wsB: ""
    property string wantedFocus: "901"

    function log(line) {
        console.log(line)
    }

    function check(label, cond, extra) {
        if (cond) {
            root.log("PASS: " + label)
            return true
        }
        root.failures++
        root.log("FAIL: " + label + (extra !== undefined ? " | " + extra : ""))
        return false
    }

    function collect(item, pred, out) {
        if (!item)
            return out
        var kids = []
        try {
            kids = item.children || []
        } catch (e) {
            return out
        }
        for (var i = 0; i < kids.length; i++) {
            var c = kids[i]
            if (!c)
                continue
            var hit = false
            try {
                hit = pred(c)
            } catch (e2) {
                hit = false
            }
            if (hit)
                out.push(c)
            root.collect(c, pred, out)
        }
        return out
    }

    function squares() {
        if (!root.wsInstance)
            return []
        return root.collect(root.wsInstance, function (c) {
            return typeof c.wsId === "string"
        }, [])
    }

    function squareById(id) {
        var all = root.squares()
        for (var i = 0; i < all.length; i++)
            if (all[i].wsId === String(id))
                return all[i]
        return null
    }

    function iconsOf(square) {
        if (!square)
            return []
        return root.collect(square, function (c) {
            return c.winId !== undefined && c.appId !== undefined
        }, [])
    }

    function iconByWinId(square, winId) {
        var icons = root.iconsOf(square)
        for (var i = 0; i < icons.length; i++)
            if (String(icons[i].winId) === String(winId))
                return icons[i]
        return null
    }

    function iconImage(icon) {
        if (!icon)
            return null
        var kids = []
        try {
            kids = icon.children || []
        } catch (e) {
            return null
        }
        for (var i = 0; i < kids.length; i++) {
            var c = kids[i]
            if (!c)
                continue
            var hasSource = false
            try {
                hasSource = c.source !== undefined
            } catch (e2) {
                hasSource = false
            }
            if (hasSource)
                return c
        }
        return null
    }

    function iconOpacity(square, winId) {
        var img = root.iconImage(root.iconByWinId(square, winId))
        if (!img)
            return -1
        return img.opacity
    }

    function indicator() {
        if (!root.wsInstance)
            return null
        var kids = []
        try {
            kids = root.wsInstance.children || []
        } catch (e) {
            return null
        }
        for (var i = 0; i < kids.length; i++) {
            var c = kids[i]
            if (!c)
                continue
            var isRow = false
            try {
                isRow = c.spacing !== undefined
            } catch (e2) {
                isRow = false
            }
            if (!isRow)
                return c
        }
        return null
    }

    function indicatorCenterX() {
        var bar = root.indicator()
        if (!bar)
            return NaN
        return bar.x + bar.width / 2
    }

    function expectedCenterXFor(winId) {
        var all = root.squares()
        for (var i = 0; i < all.length; i++) {
            try {
                var cx = all[i].iconCenterXInRoot(winId)
                if (isFinite(cx))
                    return cx
            } catch (e) {
            }
        }
        return NaN
    }

    function feedInitial() {
        // Discover squares from the live model; fall back to a fake pair
        // when no compositor is present (no event stream to fight there).
        var ids = []
        var model = Services.NiriService.workspaces
        for (var i = 0; i < model.count; i++) {
            try {
                ids.push(String(model.get(i).wsId))
            } catch (e) {
            }
        }
        if (ids.length < 2) {
            Services.NiriService.updateWorkspaces({ workspaces: [
                { id: 1, idx: 1, is_active: true, name: "1" },
                { id: 2, idx: 2, is_active: false, name: "2" }
            ] })
            ids = ["1", "2"]
        }
        root.wsA = ids[0]
        root.wsB = ids[1]
        root.wantedFocus = "901"
        root.inject()
    }

    // Drive the FULL production path (NiriService model -> refreshWindowMap
    // -> surgical ListModel sync): fake 900-ids on the real workspace ids.
    // In-process only; the live shell runs in its own process.
    function niriRow(winId, appId, wsId, focused) {
        return { id: Number(winId), title: "t" + winId, app_id: appId,
                 is_focused: focused === String(winId), workspace_id: Number(wsId) }
    }

    function feedRows(rows) {
        Services.NiriService.updateWindows({ WindowsChanged: { windows: rows } })
    }

    function standardRows() {
        return [
            root.niriRow(901, "firefox", root.wsA, root.wantedFocus),
            root.niriRow(902, "kitty", root.wsA, root.wantedFocus),
            root.niriRow(903, "code", root.wsB, root.wantedFocus)
        ]
    }

    function inject() {
        if (root.wsA === "")
            return
        root.feedRows(root.standardRows())
    }

    // A live event may still rewrite the service model between ticks; restore
    // the scenario instead of stalling until the deadline.
    function ensureState() {
        if (!root.wsInstance || root.wsA === "")
            return false
        var a = root.squareById(root.wsA)
        var b = root.squareById(root.wsB)
        if (!a || !b)
            return false
        if (root.iconByWinId(a, 901) === null
                || root.iconByWinId(a, 902) === null
                || root.iconByWinId(b, 903) === null
                || root.wsInstance.focusedWinId !== root.wantedFocus) {
            root.inject()
            return false
        }
        return true
    }

    function mount() {
        root.wsComponent = Qt.createComponent("modules/bar/widgets/Workspaces.qml")
        if (root.wsComponent.status !== Component.Ready) {
            root.check("workspaces component loads", false, String(root.wsComponent.errorString()))
            root.finish()
            return
        }
        root.wsInstance = root.wsComponent.createObject(root, {})
        root.check("workspaces instance created", !!root.wsInstance)
    }

    function finish() {
        root.log("Totals: " + (root.failures === 0 ? "all passed" : root.failures + " failed"))
        // The local Quickshell host exposes Qt.quit() without an exit code.
        Qt.quit()
    }

    Timer {
        id: pump
        interval: 60
        repeat: true
        running: true
        onTriggered: root.tick()
    }

    function tick() {
        root.ticks++
        if (root.ticks > 250) {
            root.check("harness completes before deadline (phase " + root.phase + ")", false)
            root.finish()
            return
        }
        switch (root.phase) {
        case 0:
            root.mount()
            if (!root.wsInstance)
                return
            root.feedInitial()
            root.phase = 1
            break
        case 1: {
            // Wait for delegates: both squares present with their icons.
            if (!root.ensureState())
                return
            root.phase = 2
            break
        }
        case 2: {
            // Initial state: focus 901 -> icon bright, others dim, indicator on 901.
            if (!root.ensureState())
                return
            var a1 = root.squareById(root.wsA)
            var o901 = root.iconOpacity(a1, 901)
            var o902 = root.iconOpacity(a1, 902)
            if (o901 < 0 || o902 < 0)
                return
            // Opacity animates (100ms); wait for it to settle before judging.
            if (Math.abs(o901 - 1) >= 0.03 || Math.abs(o902 - 0.55) >= 0.1)
                return
            root.check("focused icon 901 bright", Math.abs(o901 - 1) < 0.03, "opacity=" + o901)
            root.check("unfocused icon 902 dim", Math.abs(o902 - 0.55) < 0.05, "opacity=" + o902)
            var bar = root.indicator()
            root.check("single indicator exists", !!bar)
            if (!bar)
                return
            var expectedW = Lazer.LazerTheme.barWidgetHeight - 16
            root.check("indicator reuses volume bar width", Math.abs(bar.width - expectedW) < 1,
                       "width=" + bar.width + " expected=" + expectedW)
            root.check("indicator keeps workspace green", String(bar.color) === String(Lazer.LazerTheme.osuGreen),
                       "color=" + bar.color)
            if (!root.wsInstance.indicatorVisible)
                return
            var target = root.expectedCenterXFor(901)
            if (!isFinite(target))
                return
            var dx = Math.abs(root.indicatorCenterX() - target)
            if (dx >= 3)
                return
            root.check("indicator settled under focused app 901", true)
            root.swapsBeforeChurn = root.wsInstance.mapSwaps
            root.wantedFocus = "902"
            Services.NiriService.setFocusedWindow(902)
            root.phase = 3
            break
        }
        case 3: {
            // App switch within workspace A: highlight + indicator follow to 902.
            if (!root.ensureState())
                return
            var b1 = root.squareById(root.wsA)
            var p902 = root.iconOpacity(b1, 902)
            var p901 = root.iconOpacity(b1, 901)
            if (p902 < 0 || p901 < 0)
                return
            if (Math.abs(p902 - 1) >= 0.01 || Math.abs(p901 - 0.55) >= 0.05)
                return
            var t2 = root.expectedCenterXFor(902)
            if (!isFinite(t2))
                return
            if (Math.abs(root.indicatorCenterX() - t2) >= 3)
                return
            root.check("app switch moves highlight 901->902", true)
            root.check("app switch moves indicator to 902", true)
            root.wantedFocus = "903"
            Services.NiriService.setFocusedWindow(903)
            root.phase = 4
            break
        }
        case 4: {
            // Cross-workspace app switch: highlight + indicator follow to ws B.
            if (!root.ensureState())
                return
            var c2 = root.squareById(root.wsB)
            var c1 = root.squareById(root.wsA)
            var q903 = root.iconOpacity(c2, 903)
            var q902 = root.iconOpacity(c1, 902)
            if (q903 < 0 || q902 < 0)
                return
            if (Math.abs(q903 - 1) >= 0.01)
                return
            var t3 = root.expectedCenterXFor(903)
            if (!isFinite(t3))
                return
            if (Math.abs(root.indicatorCenterX() - t3) >= 3)
                return
            root.check("cross-workspace switch highlights 903", true)
            root.check("cross-workspace switch moves indicator to ws2", true)
            root.check("indicator still visible after switches", !!root.wsInstance.indicatorVisible)
            root.churnLeft = 8
            root.phase = 5
            break
        }
        case 5: {
            // Focus-only churn must not destroy delegates or lose highlight.
            if (root.churnLeft > 0) {
                root.wantedFocus = root.churnLeft % 2 === 0 ? "901" : "902"
                Services.NiriService.setFocusedWindow(Number(root.wantedFocus))
                root.churnLeft--
                return
            }
            root.wantedFocus = "901"
            Services.NiriService.setFocusedWindow(901)
            root.phase = 6
            break
        }
        case 6: {
            if (!root.ensureState())
                return
            var d1 = root.squareById(root.wsA)
            var d2 = root.squareById(root.wsB)
            if (!d1 || !d2)
                return
            if (root.iconsOf(d1).length < 2 || root.iconsOf(d2).length < 1)
                return
            var r901 = root.iconOpacity(d1, 901)
            if (r901 < 0)
                return
            // Opacity animates; wait for it to settle before judging.
            if (Math.abs(r901 - 1) >= 0.05)
                return
            root.check("churn keeps icon delegates alive", true)
            root.check("churn preserves highlight on 901", true)
            root.check("churn causes no map rebuild",
                       root.wsInstance.mapSwaps === root.swapsBeforeChurn,
                       "swaps=" + root.wsInstance.mapSwaps + " before=" + root.swapsBeforeChurn)
            root.check("indicator visible after churn", !!root.wsInstance.indicatorVisible)
            var t1 = root.expectedCenterXFor(901)
            if (!isFinite(t1))
                return
            root.check("indicator back on 901 after churn",
                       Math.abs(root.indicatorCenterX() - t1) < 3,
                       "dx=" + Math.abs(root.indicatorCenterX() - t1))
            // Hand control back to the live service path: a real refresh must
            // still leave the truly focused window bright with a visible bar.
            root.wsInstance.refreshWindowMap()
            root.phase = 7
            break
        }
        case 7: {
            var liveFocus = ""
            try {
                liveFocus = String(root.wsInstance.focusedWinId || "")
            } catch (e6) {
            }
            if (liveFocus === "") {
                root.check("live refresh exposes a focused window", false, "no focused window")
                root.finish()
                return
            }
            var lf = root.expectedCenterXFor(liveFocus)
            if (!isFinite(lf))
                return
            if (Math.abs(root.indicatorCenterX() - lf) >= 3)
                return
            var found = false
            var allSq = root.squares()
            for (var si = 0; si < allSq.length && !found; si++) {
                var op = root.iconOpacity(allSq[si], liveFocus)
                if (op >= 0)
                    found = Math.abs(op - 1) < 0.01
            }
            root.check("live refresh keeps focused icon bright", found, "focus=" + liveFocus)
            root.check("live refresh keeps indicator visible",
                       !!root.wsInstance.indicatorVisible)
            root.check("live refresh parks indicator on focused app", true)
            // Burst stress: rapid wholesale content swaps (open/close/reorder
            // bursts from the event stream) must not lose icon delegates.
            root.burstLeft = 12
            root.burstToggle = false
            root.phase = 8
            break
        }
        case 8: {
            if (root.burstLeft > 0) {
                root.burstToggle = !root.burstToggle
                if (root.burstToggle) {
                    root.wantedFocus = "904"
                    root.feedRows([
                        root.niriRow(902, "kitty", root.wsA, root.wantedFocus),
                        root.niriRow(906, "vlc", root.wsA, root.wantedFocus),
                        root.niriRow(904, "gimp", root.wsB, root.wantedFocus),
                        root.niriRow(903, "code", root.wsB, root.wantedFocus)
                    ])
                } else {
                    root.wantedFocus = "901"
                    root.feedRows(root.standardRows())
                }
                root.burstLeft--
                return
            }
            // Settle on map A and demand exact delegate contents.
            root.wantedFocus = "901"
            Services.NiriService.setFocusedWindow(901)
            if (!root.ensureState())
                return
            var e1 = root.squareById(root.wsA)
            var e2 = root.squareById(root.wsB)
            if (root.iconsOf(e1).length !== 2 || root.iconsOf(e2).length !== 1)
                return
            var eb901 = root.iconOpacity(e1, 901)
            if (Math.abs(eb901 - 1) >= 0.05)
                return
            var tb = root.expectedCenterXFor(901)
            if (!isFinite(tb) || Math.abs(root.indicatorCenterX() - tb) >= 3)
                return
            root.check("burst keeps exact icon set", true)
            root.check("burst preserves highlight", true)
            root.check("burst keeps indicator parked", true)
            root.check("burst keeps indicator visible", !!root.wsInstance.indicatorVisible)
            root.finish()
            break
        }
        }
    }
}
