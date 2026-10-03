import QtQuick
import Quickshell
import "./services" as Services

// Whole-repo QML compile guard.
//
// Why this exists: a `readonly property alias` whose target id moved inside a
// `Loader`'s `Component` compiled fine in every test that did not load the file,
// and took the entire shell down at startup with "Invalid alias reference.
// Unable to find id ..." — a compile error that only appears once something
// actually instantiates that file. Nothing in the suite caught it, because the
// one harness that loads the bar popup host is window-only.
//
// Qt.createComponent compiles and links a file without instantiating it, so this
// catches exactly that class of defect: missing ids, aliases that lost their
// target, unresolved types, syntax errors. It deliberately does NOT instantiate,
// so a PanelWindow file compiles fine here even with no compositor - which is
// what makes the whole repo checkable in one headless run.
//
// Run from the repo root:
//   qs -p tst_qml_compiles.qml
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

    // Every QML file the shell loads at runtime, plus the entrypoint. Kept as an
    // explicit list rather than a filesystem walk so a file that stops being part
    // of the shell has to be removed deliberately instead of silently dropping
    // out of coverage - and so the walk cannot be defeated by .gitignore rules.
    readonly property var sources: [
        "shell.qml",
        // bar
        "modules/bar/BarContent.qml",
        "modules/bar/BarIcon.qml",
        "modules/bar/BarPill.qml",
        "modules/bar/BarPopupHost.qml",
        "modules/bar/BarPopupActions.qml",
        "modules/bar/BarPopupIdentity.qml",
        "modules/bar/BarContextPopupActions.qml",
        "modules/bar/BarWindowHintContent.qml",
        "modules/bar/BarWindowHintStrip.qml",
        "modules/bar/BarWindowHintLabel.qml",
        "modules/bar/BarWindowHintEmpty.qml",
        "modules/bar/MarqueeLabel.qml",
        "modules/bar/TopBar.qml",
        // bar widgets
        "modules/bar/widgets/ActiveWindow.qml",
        "modules/bar/widgets/Battery.qml",
        "modules/bar/widgets/Bluetooth.qml",
        "modules/bar/widgets/Brightness.qml",
        "modules/bar/widgets/Clock.qml",
        "modules/bar/widgets/ClockPopupContent.qml",
        "modules/bar/widgets/LauncherButton.qml",
        "modules/bar/widgets/Media.qml",
        "modules/bar/widgets/Network.qml",
        "modules/bar/widgets/Notifications.qml",
        "modules/bar/widgets/RollingClockTime.qml",
        "modules/bar/widgets/RollingDigit.qml",
        "modules/bar/widgets/SettingsButton.qml",
        "modules/bar/widgets/Tray.qml",
        "modules/bar/widgets/Volume.qml",
        "modules/bar/widgets/Workspaces.qml",
        // lazerbar surfaces
        "modules/lazerbar/LauncherSurface.qml",
        "modules/lazerbar/WaveSurfaceHost.qml",
        "modules/lazerbar/WaveRevealLayers.qml",
        "modules/lazerbar/LauncherPage.qml",
        "modules/lazerbar/FullscreenWave.qml",
        "modules/lazerbar/FullscreenHeader.qml",
        "modules/lazerbar/FullscreenSidebar.qml",
        "modules/lazerbar/LazerSettingsOverlay.qml",
        "modules/lazerbar/LazerSettingsPanel.qml",
        "modules/lazerbar/LazerSettingsSidebar.qml",
        "modules/lazerbar/LazerSettingsContent.qml",
        "modules/lazerbar/LazerSettingsSections.qml",
        "modules/lazerbar/LazerSettingsRow.qml",
        "modules/lazerbar/NotificationHost.qml",
        "modules/lazerbar/OverviewBackgroundWindow.qml",
        "modules/lazerbar/ScreenRoundedCorners.qml",
        "modules/lazerbar/RippleGlow.qml",
        "modules/lazerbar/WallpaperBackground.qml",
        "modules/lazerbar/WallpaperReveal.qml",
        // lock
        "modules/lock/Lock.qml",
        "modules/lock/LockSurface.qml",
    ]

    property int index: 0
    property var broken: []
    property var panelOnly: []

    // A PanelWindow-rooted file cannot have its root type registered without a
    // compositor, so its body is never compiled here and this guard cannot see
    // inside it. That hole is real and not hypothetical: an alias that lost its
    // target id inside a Loader's Component broke the entire shell at startup,
    // and neither this guard, nor qmllint, nor any headless test saw it. The
    // files below are the ones it applies to, listed so the gap stays visible;
    // they are covered by the window-only harnesses (tst_bar_popup_host,
    // tst_wallpaper_startup_slots, ...) under `run-tests.sh -g`. Keep this list
    // in step when a surface is added or removed - the test fails if the
    // observed set stops matching, so the coverage cannot quietly change.
    readonly property var expectedPanelOnly: [
        "shell.qml",
        "modules/bar/BarPopupHost.qml",
        "modules/bar/TopBar.qml",
        "modules/lazerbar/NotificationHost.qml",
        "modules/lazerbar/OverviewBackgroundWindow.qml",
        "modules/lazerbar/ScreenRoundedCorners.qml",
        "modules/lazerbar/WallpaperBackground.qml",
    ]

    function classify(error) {
        // The same signal scripts/run-tests.sh uses to mark a harness
        // window-only. Any other failure is a real defect.
        if (error.indexOf("No PanelWindow backend loaded") >= 0
                || error.indexOf("No PopupWindow backend loaded") >= 0)
            return "panelOnly"
        return "broken"
    }

    function compileNext() {
        if (index >= sources.length) {
            report()
            return
        }
        const path = sources[index]
        let error = ""
        try {
            // Compiled against this file's imports, so the singleton types and
            // module types resolve exactly as they do in the shell.
            const component = Qt.createComponent(Qt.resolvedUrl("./" + path), root)
            if (component.status === Component.Error)
                error = String(component.errorString()).trim()
        } catch (e) {
            error = String(e)
        }
        if (error !== "") {
            if (classify(error) === "broken")
                root.broken.push({ path: path, error: error })
            else
                root.panelOnly.push(path)
        }
        index++
        // One turn apart: compiling a file also compiles its imports, and a
        // same-turn neighbour would be charged for work this one already did.
        Qt.callLater(compileNext)
    }

    function report() {
        for (let i = 0; i < root.broken.length; i++) {
            console.log("[compile-guard] BROKEN " + root.broken[i].path + "\n"
                + root.broken[i].error)
        }
        console.log("[compile-guard] compiled cleanly: "
            + (sources.length - root.broken.length - root.panelOnly.length)
            + "/" + sources.length)
        console.log("[compile-guard] NOT checkable headless (PanelWindow root): "
            + root.panelOnly.join(", "))

        root.check("every headlessly-compilable file compiles",
                   root.broken.length === 0,
                   root.broken.map(function(b) { return b.path }).join(", "))
        root.check("the PanelWindow-rooted set has not drifted",
                   JSON.stringify(root.panelOnly.slice().sort())
                   === JSON.stringify(root.expectedPanelOnly.slice().sort()),
                   "observed: " + JSON.stringify(root.panelOnly.slice().sort()))
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
            console.log("FAIL: compile guard did not finish | index=" + root.index)
            root.failures++
            root.finish()
        }
    }

    Component.onCompleted: {
        giveUp.restart()
        Qt.callLater(root.compileNext)
    }
}