import QtQuick
import "tests/qml/bar" as Harnesses

// Root-level loader keeps the repository root as the Quickshell config root.
Item {
    id: root

    Harnesses.SuperIslandWindowHintHarness {
        anchors.fill: parent
    }
}
