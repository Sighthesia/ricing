import Quickshell
import QtQuick
import qs.config
import qs.services
import "modules/bar" as BarParts
import "modules/bar/settings" as SettingsParts

// Smoke harness for shared settings primitives and navigation structure.
ShellRoot {
    id: root

    Item {
        id: anchorHost
        width: 320
        height: 48
        visible: false
    }

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

    BarParts.SettingsPanelWindow {
        id: settingsPanelWindow
    }

    BarParts.WidgetPickerWindow {
        id: widgetPickerWindow
    }

    BarParts.BarContextMenu {
        id: contextMenu
        anchorTarget: anchorHost
    }

    BarParts.BarWidgetWrapper {
        id: widgetWrapper
        visible: false
        widgetId: "clock"
        instanceKey: "clock_0"

        Rectangle {
            width: 24
            height: 24
        }
    }

    Component.onCompleted: {
        root._assert(typeof BarLayoutService.widgetSettingsAutoEnteredLayout === "boolean",
            "BarLayoutService should track whether widget settings auto-entered layout mode")
        root._assert(typeof BarLayoutService.suppressWidgetPrimaryActions === "boolean",
            "BarLayoutService should expose widget primary-action suppression state")
        root._assert(contextMenu._widgetActionCount === 1,
            "BarContextMenu should expose only one widget-specific action")
        root._assert(typeof widgetWrapper._primaryActionsSuppressed === "boolean",
            "BarWidgetWrapper should expose whether widget primary actions are suppressed")
        root._assert(aboutPage._showsNotificationDiagnostics === true,
            "AboutPage should surface notification diagnostics")
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
        root._assert(settingsPanelWindow._usesCenteredPlacement === true,
            "SettingsPanelWindow should use centered placement below the bar")
        root._assert(widgetPickerWindow._usesCenteredPlacement === true,
            "WidgetPickerWindow should use centered placement below the bar")
        root._assert(settingsPanelWindow._closeButton !== undefined && settingsPanelWindow._closeButton !== null,
            "SettingsPanelWindow should expose an explicit close affordance")
        root._assert(widgetPickerWindow._closeButton !== undefined && widgetPickerWindow._closeButton !== null,
            "WidgetPickerWindow should expose an explicit close affordance")

        console.log("SettingsStructure smoke test passed")
        Qt.callLater(Qt.quit)
    }
}
