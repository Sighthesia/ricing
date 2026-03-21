import QtQuick
import QtQuick.Layouts
import "../../../modules/bar/settings" as SettingsParts

Item {
    id: root
    width: 320
    height: 320

    function assertTrue(condition, message) {
        if (!condition)
            throw new Error(message)
    }

    ColumnLayout {
        id: groupHost
        width: 296

        Rectangle {
            id: groupTopSibling
            Layout.fillWidth: true
            implicitHeight: 16
        }

        SettingsParts.ExpandableGroup {
            id: group
            Layout.fillWidth: true
            title: "Harness Group"
            expanded: false

            Rectangle {
                id: dynamicRect
                implicitWidth: 296
                implicitHeight: 32
            }

            Rectangle {
                implicitWidth: 296
                implicitHeight: 24
            }
        }

        Rectangle {
            id: groupBottomSibling
            Layout.fillWidth: true
            implicitHeight: 16
        }
    }

    Timer {
        id: settlePoll
        interval: 16
        repeat: true
        property var onStable: null

        onTriggered: {
            if (groupBottomSibling.y > groupTopSibling.y) {
                stop()
                if (onStable)
                    onStable()
            }
        }
    }

    Component.onCompleted: {
        const initialBottomY = groupBottomSibling.y
        group.expanded = true

        settlePoll.onStable = function() {
            root.assertTrue(groupBottomSibling.y > initialBottomY,
                "expanded group should push the lower sibling through layout reflow")
            root.assertTrue(typeof group.animatedExtent === "number",
                "ExpandableGroup should expose the layout-native adopted-axis extent")
            root.assertTrue(typeof group.running === "boolean",
                "ExpandableGroup should expose the layout-native running state")
            Qt.quit()
        }
        settlePoll.start()
    }
}
