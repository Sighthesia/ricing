.pragma library

function openWidgetSettingsState(settingsMode, instanceKey, widgetCenterX) {
    return {
        shouldAutoEnterLayout: !settingsMode,
        activeWidgetInstanceKey: instanceKey,
        widgetSettingsX: widgetCenterX,
        widgetSettingsPanelOpen: true,
        widgetSettingsAutoEnteredLayout: !settingsMode
    }
}

function clearWidgetSettingsSessionState() {
    return {
        widgetSettingsPanelOpen: false,
        activeWidgetInstanceKey: "",
        widgetSettingsAutoEnteredLayout: false
    }
}

function closeWidgetSettingsState(widgetSettingsAutoEnteredLayout) {
    return {
        clearSession: true,
        shouldExitLayout: widgetSettingsAutoEnteredLayout === true
    }
}

function toggleWidgetPickerState(widgetPickerOpen, widgetPickerTargetSection, sectionName) {
    if (!sectionName) {
        return {
            changed: false,
            widgetPickerOpen: widgetPickerOpen,
            widgetPickerTargetSection: widgetPickerTargetSection
        }
    }

    if (widgetPickerOpen && widgetPickerTargetSection === sectionName) {
        return {
            changed: true,
            widgetPickerOpen: false,
            widgetPickerTargetSection: widgetPickerTargetSection
        }
    }

    return {
        changed: true,
        widgetPickerOpen: true,
        widgetPickerTargetSection: sectionName
    }
}
