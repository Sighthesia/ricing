import Quickshell
import QtQuick

// Minimal root harness loader for isolating side effects from top-level module imports.
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
        if (_harnessName === "")
            throw new Error("Set DYMICSHELL_TEST_HARNESS to a tests/qml harness base name.")
    }
}
