import QtQuick
import "../lazerbar"

// Compact context actions for the bar's second popup layer.
Item {
    id: root

    property string widgetId: ""
    property string instanceKey: ""
    property string section: "center"
    property bool hasSettings: false
    property bool layoutMode: false
    property var availableWidgets: []
    property string actionKind: "context"
    property bool widgetsExpanded: false
    property var payload: null
    signal actionRequested(string action)

    implicitWidth: 260
    implicitHeight: root.visible ? actionColumn.implicitHeight + 16 : 0
    visible: root.actionKind === "context"
    // Empty-area menus carry no widget identity; widget rows need one.
    readonly property bool hasWidgetTarget: root.instanceKey !== ""

    function invoke(action) {
        var callbacks = root.payload || ({})
        var callback = callbacks[action]
        if (typeof callback === "function")
            callback(root.instanceKey, root.widgetId, root.section)
        root.actionRequested(action)
    }

    // Add a catalog widget into the menu's own section.
    function addWidgetById(widgetId) {
        var callbacks = root.payload || ({})
        var callback = callbacks["addWidget"]
        if (typeof callback === "function")
            callback(String(widgetId || ""), root.section)
        root.actionRequested("addWidget")
    }

    function toggleWidgetsExpanded() {
        widgetsExpanded = !widgetsExpanded
    }

    onInstanceKeyChanged: widgetsExpanded = false

    // Render each context command as a compact settings-style row.
    Column {
        id: actionColumn
        anchors.fill: parent
        anchors.margins: 8
        spacing: 2

        // Layout-mode entry stays on top so it is reachable from any target.
        Item {
            width: actionColumn.width
            height: 32

            Rectangle {
                anchors.fill: parent
                radius: 6
                color: layoutHover.hovered ? LazerTheme.settingsCardHover : LazerTheme.settingsCard
                Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
            }

            Text {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 44
                verticalAlignment: Text.AlignVCenter
                text: root.layoutMode ? "Exit layout mode" : "Enter layout mode"
                color: LazerTheme.textPrimary
                font.pixelSize: 13
                elide: Text.ElideRight
            }

            Text {
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                text: root.layoutMode ? "On" : "Off"
                color: LazerTheme.textMuted
                font.pixelSize: 11
            }

            HoverHandler { id: layoutHover; blocking: false }
            TapHandler {
                gesturePolicy: TapHandler.ReleaseWithinBounds
                onTapped: root.invoke("toggleLayoutMode")
            }
        }

        Repeater {
            model: root.hasWidgetTarget ? [
                { action: "moveLeft", label: "Move left" },
                { action: "moveRight", label: "Move right" },
                { action: "moveToSection", label: "Move to section" },
                { action: "openSettings", label: "Widget settings", available: root.hasSettings },
                { action: "remove", label: "Remove widget" },
            ] : []

            delegate: Item {
                required property var modelData
                width: actionColumn.width
                height: modelData.available === false ? 0 : 32
                visible: height > 0

                Rectangle {
                    anchors.fill: parent
                    radius: 6
                    color: actionHover.hovered ? LazerTheme.settingsCardHover : LazerTheme.settingsCard
                    Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
                }

                Text {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    verticalAlignment: Text.AlignVCenter
                    text: modelData.label
                    color: LazerTheme.textPrimary
                    font.pixelSize: 13
                }

                HoverHandler { id: actionHover; blocking: false }
                TapHandler {
                    gesturePolicy: TapHandler.ReleaseWithinBounds
                    onTapped: root.invoke(modelData.action)
                }
            }
        }

        // Expandable widget catalog for the current section.
        Item {
            width: actionColumn.width
            height: 32

            Rectangle {
                anchors.fill: parent
                radius: 6
                color: catalogHover.hovered ? LazerTheme.settingsCardHover : LazerTheme.settingsCard
                Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
            }

            Text {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 28
                verticalAlignment: Text.AlignVCenter
                text: "Add widgets"
                color: LazerTheme.textPrimary
                font.pixelSize: 13
                elide: Text.ElideRight
            }

            Text {
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                text: root.widgetsExpanded ? "▾" : "▸"
                color: LazerTheme.textMuted
                font.pixelSize: 13
            }

            HoverHandler { id: catalogHover; blocking: false }
            TapHandler {
                gesturePolicy: TapHandler.ReleaseWithinBounds
                onTapped: root.toggleWidgetsExpanded()
            }
        }

        // Clipped catalog list grows the popup height when expanded.
        Item {
            id: catalogHost
            width: actionColumn.width
            implicitHeight: root.widgetsExpanded ? catalogColumn.implicitHeight : 0
            height: implicitHeight
            clip: true
            opacity: root.widgetsExpanded ? 1 : 0
            visible: opacity > 0.01 || root.widgetsExpanded
            Behavior on implicitHeight { NumberAnimation { duration: MotionTokens.slow; easing.type: Easing.InOutQuad } }
            Behavior on opacity { NumberAnimation { duration: MotionTokens.fast } }

            Column {
                id: catalogColumn
                width: parent.width
                spacing: 2

                Repeater {
                    model: root.availableWidgets || []

                    delegate: Item {
                        required property var modelData
                        required property int index
                        width: catalogColumn.width
                        height: 44

                        Rectangle {
                            anchors.fill: parent
                            radius: 6
                            color: widgetHover.hovered ? LazerTheme.settingsCardHover : LazerTheme.settingsCard
                            Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
                        }

                        Column {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 30
                            anchors.topMargin: 5
                            anchors.bottomMargin: 5
                            spacing: 1

                            Text {
                                width: parent.width
                                text: String(modelData.label || modelData.id || "Widget")
                                color: LazerTheme.textPrimary
                                font.pixelSize: 13
                                elide: Text.ElideRight
                                maximumLineCount: 1
                            }

                            Text {
                                width: parent.width
                                text: String(modelData.description || modelData.section || "")
                                color: LazerTheme.textMuted
                                font.pixelSize: 10
                                elide: Text.ElideRight
                                maximumLineCount: 1
                                visible: text !== ""
                            }
                        }

                        Text {
                            anchors.right: parent.right
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            text: "+"
                            color: LazerTheme.textMuted
                            font.pixelSize: 16
                        }

                        HoverHandler { id: widgetHover; blocking: false }
                        TapHandler {
                            gesturePolicy: TapHandler.ReleaseWithinBounds
                            onTapped: root.addWidgetById(modelData.id)
                        }
                    }
                }
            }
        }

        // Dismiss row stays last so catalog growth pushes content, not the exit.
        Item {
            width: actionColumn.width
            height: 32

            Rectangle {
                anchors.fill: parent
                radius: 6
                color: closeHover.hovered ? LazerTheme.settingsCardHover : LazerTheme.settingsCard
                Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
            }

            Text {
                anchors.fill: parent
                anchors.leftMargin: 10
                verticalAlignment: Text.AlignVCenter
                text: "Close"
                color: LazerTheme.textPrimary
                font.pixelSize: 13
            }

            HoverHandler { id: closeHover; blocking: false }
            TapHandler {
                gesturePolicy: TapHandler.ReleaseWithinBounds
                onTapped: root.invoke("close")
            }
        }
    }
}
