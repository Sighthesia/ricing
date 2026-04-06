.pragma library

.import "BarLayoutSession.js" as SessionUtils

function _applyWidgetSettingsState(root, nextState) {
    root.activeWidgetInstanceKey = nextState.activeWidgetInstanceKey
    root.widgetSettingsX = nextState.widgetSettingsX
    root.widgetSettingsPanelOpen = nextState.widgetSettingsPanelOpen
    root.widgetSettingsAutoEnteredLayout = nextState.widgetSettingsAutoEnteredLayout
}

function openWidgetSettings(root, instanceKey, widgetCenterX) {
    var nextState = SessionUtils.openWidgetSettingsState(root.settingsMode, instanceKey, widgetCenterX)

    if (nextState.shouldAutoEnterLayout)
        root.activePanel = "layout"

    _applyWidgetSettingsState(root, nextState)
}

function clearWidgetSettings(root) {
    _applyWidgetSettingsState(root, SessionUtils.clearWidgetSettingsSessionState())
}

function closeWidgetSettings(root) {
    var nextState = SessionUtils.closeWidgetSettingsState(root.widgetSettingsAutoEnteredLayout)

    if (nextState.clearSession)
        clearWidgetSettings(root)

    if (nextState.shouldExitLayout)
        root.activePanel = "none"
}

function openWidgetPickerForSection(root, sectionName) {
    if (!sectionName)
        return false

    root.widgetPickerTargetSection = sectionName
    root.widgetPickerOpen = true
    return true
}

function toggleWidgetPickerForSection(root, sectionName) {
    var nextState = SessionUtils.toggleWidgetPickerState(
        root.widgetPickerOpen,
        root.widgetPickerTargetSection,
        sectionName
    )

    if (!nextState.changed)
        return false

    root.widgetPickerOpen = nextState.widgetPickerOpen
    root.widgetPickerTargetSection = nextState.widgetPickerTargetSection
    return true
}
