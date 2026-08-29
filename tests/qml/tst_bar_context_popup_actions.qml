import QtQuick
import QtTest
import "../../modules/bar" as Bar

// Verify context actions remain payload-driven and service-independent.
Item {
    id: root
    width: 320
    height: 280

    property var calls: []
    property var callbacks: ({
        moveLeft: function() { calls.push("moveLeft") },
        moveRight: function() { calls.push("moveRight") },
        moveToSection: function() { calls.push("moveToSection") },
        openSettings: function() { calls.push("openSettings") },
        remove: function() { calls.push("remove") },
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
        payload: root.callbacks
    }

    TestCase {
        name: "BarContextPopupActions"

        function init() { root.calls = [] }

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

        function findSettingsRow() {
            for (var i = 0; i < actions.children.length; ++i) {
                var column = actions.children[i]
                if (!column.children)
                    continue
                for (var j = 0; j < column.children.length; ++j) {
                    if (column.children[j].children && column.children[j].children.length > 0
                            && String(column.children[j].children[1].text || "") === "Widget settings")
                        return column.children[j]
                }
            }
            return null
        }
    }
}
