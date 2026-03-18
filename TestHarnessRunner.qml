import Quickshell
import QtQuick
import qs.config
import qs.services
import qs.modules.bar
import qs.modules.launcher
import qs.modules.notifications
import qs.modules.background

// Repository-root harness loader so smoke tests resolve qs.* imports the same
// way the real shell does.
ShellRoot {
    id: root

    readonly property string _harnessName: Quickshell.env("DYMICSHELL_TEST_HARNESS")
    readonly property string _harnessPath: _harnessName === ""
        ? ""
        : (Quickshell.shellDir + "/tests/qml/" + _harnessName + ".qml")

    Loader {
        id: harnessLoader
        active: root._harnessPath !== ""
        source: root._harnessPath
    }

    Component.onCompleted: {
        if (_harnessName === "") {
            throw new Error("Set DYMICSHELL_TEST_HARNESS to a tests/qml harness base name.")
        }
    }
}
