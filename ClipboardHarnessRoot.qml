import QtQuick
import "tests/qml/clipboard" as Harnesses

// Root-level loader keeps the repository root as the Quickshell config root.
Item {
    id: root

    Harnesses.ClipboardServiceHarness {
        anchors.fill: parent
    }
}