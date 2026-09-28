// MANUAL PROBE — do not run this in automation and do not run it without
// asking. With AFLOAT_LOCK_SELFTEST=1 it mounts Lock for real, grabs the
// session lock and blacks out the screen for selfTestDelayMs (5s), so the user
// is locked out of their own desktop until they authenticate. Without that env
// var it arms nothing and exits immediately. It is deliberately NOT named
// tst_*.qml, so scripts/run-tests.sh never picks it up.
import QtQuick
import Quickshell
import "modules/lock" as LockModule
import "modules/lazerbar" as Lazer
import "services" as Services

ShellRoot {
    Component.onCompleted: {
        Quickshell.watchFiles = false
        Lazer.LazerTheme.settingsService = Services.SettingsService
        Lazer.LazerTheme.colorService = Services.Color
        if (!lock.selfTestEnabled)
            exitTimer.start()
    }

    LockModule.Lock {
        id: lock
        selfTestDelayMs: 5000
        onSelfTestFinished: exitTimer.start()
    }

    Timer {
        id: exitTimer
        interval: 100
        repeat: false
        onTriggered: {
            if (!lock.locked && !lock.preparing)
                Qt.quit()
        }
    }
}
