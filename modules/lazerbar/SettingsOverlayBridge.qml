pragma Singleton
import QtQuick

// Route settings dropdown requests to the LazerSettingsContent overlay owner
// without threading signals through every category page.
QtObject {
    signal dropdownRequested(var choiceItem)
    signal dropdownDismissed(var choiceItem)

    // Open intent from anywhere outside the overlay owner (bar gear button,
    // IPC); the owning window listens and routes through its coordinator.
    signal openRequested()

    function showDropdown(choiceItem) {
        dropdownRequested(choiceItem)
    }

    function hideDropdown(choiceItem) {
        dropdownDismissed(choiceItem)
    }

    function requestOpen() {
        openRequested()
    }
}
