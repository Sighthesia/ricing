import QtQuick
import "tests/qml/launcher" as Harnesses

// Root-level loader keeps the repository root as the Quickshell config root.
Item {
    id: root

    Harnesses.ClipboardRefreshHarness {
        anchors.fill: parent
    }
}