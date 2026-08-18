pragma Singleton
import QtQuick

// Route settings dropdown requests to the LazerSettingsContent overlay owner
// without threading signals through every category page.
QtObject {
    signal dropdownRequested(var choiceItem)
    signal dropdownDismissed(var choiceItem)

    function showDropdown(choiceItem) {
        dropdownRequested(choiceItem)
    }

    function hideDropdown(choiceItem) {
        dropdownDismissed(choiceItem)
    }
}
