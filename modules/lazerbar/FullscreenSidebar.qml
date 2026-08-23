import QtQuick

// Keep page-local navigation as a settings-panel rail: darker rail surface,
// rounded hover swap, accent pill for the active entry, and the shared
// click-flash contract on activation.
Rectangle {
    id: root
    property var entries: []
    property string selected: ""
    property real railWidth: 220
    signal selectedChangedByUser(string value)

    width: railWidth
    color: LazerTheme.settingsRail

    ListView {
        anchors.fill: parent
        anchors.topMargin: 12
        anchors.bottomMargin: 12
        model: root.entries
        spacing: 2
        clip: true

        delegate: Item {
            id: navItem
            required property var modelData
            width: ListView.view.width
            height: 46

            // Hover highlight uses the settings row surface with detail rounding.
            Rectangle {
                anchors.fill: parent
                anchors.margins: 2
                radius: 10
                color: itemHover.hovered ? LazerTheme.settingsRowHover : "transparent"
                Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
            }

            // Confirm activation with the shared click-flash contract.
            Rectangle {
                id: flashOverlay
                z: 1
                anchors.fill: parent
                anchors.margins: 2
                radius: 10
                color: LazerTheme.textPrimary
                opacity: 0
                enabled: false
            }

            Text {
                anchors.left: parent.left; anchors.leftMargin: 24
                anchors.verticalCenter: parent.verticalCenter
                text: navItem.modelData.label
                color: root.selected === navItem.modelData.id
                       ? LazerTheme.textPrimary : LazerTheme.settingsNavInactive
                font.pixelSize: 14
                Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
            }

            // Accent pill marks the selected entry, matching settings navigation.
            Rectangle {
                x: 6
                anchors.verticalCenter: parent.verticalCenter
                width: 4
                height: root.selected === navItem.modelData.id ? 24 : 0
                radius: 2
                color: LazerTheme.settingsAccent
                Behavior on height {
                    enabled: !MotionTokens.reducedMotion
                    NumberAnimation { duration: MotionTokens.fast; easing.type: Easing.OutQuint }
                }
            }

            HoverHandler { id: itemHover }
            TapHandler { id: itemTap; onTapped: navItem.activate() }

            function activate() {
                root.selectedChangedByUser(navItem.modelData.id)
                if (!MotionTokens.reducedMotion)
                    flashAnimation.restart()
            }

            NumberAnimation {
                id: flashAnimation
                target: flashOverlay
                property: "opacity"
                from: MotionTokens.clickFlashOpacity
                to: 0
                duration: MotionTokens.clickFlashDuration
                easing.type: MotionTokens.clickFlashEasing
            }
        }
    }
}
