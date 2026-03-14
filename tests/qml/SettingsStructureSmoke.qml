import Quickshell
import Quickshell.Wayland
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

    function _findFirstStaggerItem(node) {
        if (!node)
            return null

        if (typeof node.runEnter === "function"
                && typeof node.runExit === "function"
                && node.hasOwnProperty("delay")) {
            return node
        }

        let itemChildren = node.children || []
        for (let i = 0; i < itemChildren.length; i++) {
            let match = root._findFirstStaggerItem(itemChildren[i])
            if (match)
                return match
        }

        if (node.contentItem) {
            let contentChildren = node.contentItem.children || []
            for (let j = 0; j < contentChildren.length; j++) {
                let contentMatch = root._findFirstStaggerItem(contentChildren[j])
                if (contentMatch)
                    return contentMatch
            }
        }

        return null
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

    BarParts.AnimatedPanelBase {
        id: animatedPanelBase
        visible: false
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
        root._assert(animatedPanelBase.exclusionMode === ExclusionMode.Ignore,
            "AnimatedPanelBase should ignore compositor exclusion by default")
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

        let appearanceEntryItem = root._findFirstStaggerItem(appearancePage)
        root._assert(appearanceEntryItem !== null,
            "AppearancePage should contain at least one staggered content item")

        appearanceEntryCheck.restart()
    }

    Timer {
        id: appearanceEntryCheck
        interval: 500
        repeat: false
        onTriggered: {
            let appearanceEntryItem = root._findFirstStaggerItem(appearancePage)
            root._assert(appearanceEntryItem.opacity > 0,
                "AppearancePage should auto-run its initial enter animation when instantiated")
            console.log("SettingsStructure smoke test passed")
            Qt.callLater(Qt.quit)
        }
    }
}
