import QtQuick
import QtTest
import "../../modules/bar" as Bar

// Verify context actions remain payload-driven and service-independent.
Item {
    id: root
    width: 320
    height: 280

    property var calls: []
    property var addCalls: []
    property var callbacks: ({
        moveLeft: function() { calls.push("moveLeft") },
        moveRight: function() { calls.push("moveRight") },
        moveToSection: function() { calls.push("moveToSection") },
        openSettings: function() { calls.push("openSettings") },
        remove: function() { calls.push("remove") },
        openShellSettings: function() { calls.push("openShellSettings") },
        toggleLayoutMode: function() { calls.push("toggleLayoutMode") },
        addWidget: function(widgetId, section) { addCalls.push(widgetId + "@" + section) },
        close: function() { calls.push("close") },
    })

    Bar.BarContextPopupActions {
        id: actions
        width: 260
        height: 240
        widgetId: "volume"
        instanceKey: "volume:0"
        section: "right"
        hasSettings: true
        layoutMode: false
        availableWidgets: [
            { id: "clock", label: "Clock", description: "Compact date and time display.", section: "right" },
            { id: "tray", label: "System Tray", description: "System tray icons.", section: "right" },
        ]
        payload: root.callbacks
    }

    TestCase {
        name: "BarContextPopupActions"

        function init() {
            root.calls = []
            root.addCalls = []
            actions.layoutMode = false
            actions.instanceKey = "volume:0"
            actions.widgetId = "volume"
            actions.hasSettings = true
            actions.widgetsExpanded = false
        }

        function test_actionsInvokePayloadOnce() {
            actions.invoke("moveLeft")
            actions.invoke("moveToSection")
            actions.invoke("openSettings")
            actions.invoke("remove")
            compare(root.calls.join(","), "moveLeft,moveToSection,openSettings,remove")
        }

        function test_settingsActionCanBeHidden() {
            actions.hasSettings = false
            verify(!findSettingsRow().visible)
        }

        function test_layoutModeToggleInvokesPayload() {
            actions.invoke("toggleLayoutMode")
            compare(root.calls.join(","), "toggleLayoutMode")
        }

        function test_shellSettingsInvokesPayload() {
            actions.invoke("openShellSettings")
            compare(root.calls.join(","), "openShellSettings")
            verify(findWidgetRow("Shell settings") !== null)
        }

        function test_addWidgetByIdPassesSection() {
            actions.addWidgetById("clock")
            compare(root.addCalls.join(","), "clock@right")
        }

        function test_emptyTargetHidesWidgetRows() {
            actions.instanceKey = ""
            actions.widgetId = ""
            verify(!findWidgetRow("Remove widget"))
            verify(findLayoutRow() !== null)
        }

        function test_widgetsExpandedDefaultsToClosed() {
            verify(actions.widgetsExpanded === false)
            actions.toggleWidgetsExpanded()
            verify(actions.widgetsExpanded === true)
        }

        function findRowByLabel(label) {
            for (var i = 0; i < actions.children.length; ++i) {
                var column = actions.children[i]
                if (!column.children)
                    continue
                for (var j = 0; j < column.children.length; ++j) {
                    var candidate = column.children[j]
                    if (!candidate || !candidate.children)
                        continue
                    for (var k = 0; k < candidate.children.length; ++k) {
                        var textItem = candidate.children[k]
                        if (textItem && String(textItem.text || "") === label)
                            return candidate
                    }
                    if (candidate.children.length > 1
                            && String(candidate.children[1].text || "") === label)
                        return candidate
                }
            }
            return null
        }

        function findSettingsRow() {
            return findRowByLabel("Widget settings")
        }

        function findWidgetRow(label) {
            return findRowByLabel(label)
        }

        function findLayoutRow() {
            var entered = findRowByLabel("Enter layout mode")
            if (entered)
                return entered
            return findRowByLabel("Exit layout mode")
        }
    }
}
