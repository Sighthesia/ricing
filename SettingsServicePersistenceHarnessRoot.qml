import QtQuick
import "tests/qml/settings" as Harnesses

// Root-level loader keeps the repository root as the Quickshell config root.
Item {
    id: root

    Harnesses.SettingsServicePersistenceHarness {
        anchors.fill: parent
    }
}
