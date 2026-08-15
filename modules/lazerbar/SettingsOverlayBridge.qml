pragma Singleton
import QtQuick

// Route settings control overlay requests (tooltips, dropdown menus) from
// rows and controls up to the LazerSettingsContent overlay owner without
// threading signals through every category page.
QtObject {
    signal tooltipRequested(string text, var sourceItem, int priority)
    signal tooltipDismissed(var sourceItem)
    signal dropdownRequested(var choiceItem)
    signal dropdownDismissed(var choiceItem)

    // Keep one active tooltip per source so hover/focus changes do not flicker.
    property var _tooltipRequests: []

    function showTooltip(text, sourceItem, priority) {
        var p = priority === undefined ? 1 : Number(priority)
        if (!isFinite(p) || p < 1)
            p = 1
        removeTooltipSource(sourceItem)
        _tooltipRequests.push({ text: text, source: sourceItem, priority: p })
        tooltipRequested(text, sourceItem, p)
    }

    function hideTooltip(sourceItem) {
        removeTooltipSource(sourceItem)
        tooltipDismissed(sourceItem)
    }

    function removeTooltipSource(sourceItem) {
        for (var i = _tooltipRequests.length - 1; i >= 0; i--) {
            if (_tooltipRequests[i].source === sourceItem)
                _tooltipRequests.splice(i, 1)
        }
    }

    function currentTooltip() {
        if (_tooltipRequests.length === 0)
            return null
        var best = _tooltipRequests[0]
        for (var i = 1; i < _tooltipRequests.length; i++) {
            if (_tooltipRequests[i].priority >= best.priority)
                best = _tooltipRequests[i]
        }
        return best
    }

    function clearTooltips() {
        _tooltipRequests = []
        tooltipDismissed(null)
    }

    function showDropdown(choiceItem) {
        dropdownRequested(choiceItem)
    }

    function hideDropdown(choiceItem) {
        dropdownDismissed(choiceItem)
    }
}
