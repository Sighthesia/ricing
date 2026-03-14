import Quickshell
import QtQuick
import qs.config
import "modules/bar/settings" as SettingsParts

// Smoke harness for shared settings primitives and navigation structure.
ShellRoot {
    id: root

    function _assert(condition, message) {
        if (!condition)
            throw new Error(message)
    }

    SettingsParts.ToggleSection {
        id: toggleSection
        visible: false
        label: "Toggle"
    }

    SettingsParts.ExpandableGroup {
        id: expandableGroup
        visible: false
        title: "Group"

        Text {
            text: "Body"
        }
    }

    SettingsParts.FontPickerSection {
        id: fontPicker
        visible: false
        label: "Font"
        value: Theme.fontFamily
    }

    SettingsParts.BehaviorSection {
        id: behaviorSection
        visible: false
    }

    SettingsParts.AppearancePage {
        id: appearancePage
        visible: false
    }

    SettingsParts.AboutPage {
        id: aboutPage
        visible: false
    }

    SettingsParts.SettingsSidebar {
        id: sidebar
        visible: false
    }

    Component.onCompleted: {
        root._assert(toggleSection.implicitHeight > 0,
            "ToggleSection should expose a positive implicit height")
        root._assert(expandableGroup.implicitHeight >= Theme.settingsGroupHeaderHeight,
            "ExpandableGroup should include at least its header height")
        root._assert(fontPicker.implicitHeight >= Theme.settingsRowHeight,
            "FontPickerSection should expose a collapsed row height")
        root._assert(behaviorSection.implicitHeight > 0,
            "BehaviorSection should render a positive implicit height")
        root._assert(appearancePage.implicitHeight > 0,
            "AppearancePage should render a positive implicit height")
        root._assert(aboutPage.implicitHeight > 0,
            "AboutPage should render a positive implicit height")
        root._assert(sidebar.implicitHeight > 0,
            "SettingsSidebar should render a positive implicit height")
        root._assert(typeof sidebar.runEnterAnimation === "function",
            "SettingsSidebar should expose runEnterAnimation()")
        root._assert(typeof aboutPage.runEnterAnimation === "function",
            "AboutPage should expose runEnterAnimation()")

        console.log("SettingsStructure smoke test passed")
        Qt.callLater(Qt.quit)
    }
}
