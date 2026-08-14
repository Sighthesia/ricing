import QtQuick
import Quickshell
import Quickshell.Wayland

// Create one background and three focused interaction zones per screen.
Variants {
    id: root
    property string username: "Sighthesia"
    property url avatarSource
    model: Quickshell.screens

    // Own the persistent surfaces for one compositor screen.
    Scope {
        id: screenScope
        required property var modelData
        readonly property int sidePadding: 12
        readonly property int safetyGap: 16
        readonly property int utilityBudget: Math.max(LazerTheme.targetSize,
            modelData.width - leftWindow.implicitWidth - statusWindow.implicitWidth
            - sidePadding * 2 - safetyGap * 2)

        BarBackground { targetScreen: screenScope.modelData }

        // Host system and mode controls at the left edge.
        PanelWindow {
            id: leftWindow
            screen: screenScope.modelData
            color: LazerTheme.bgDark
            implicitWidth: leftContent.implicitWidth + screenScope.sidePadding * 2
            implicitHeight: LazerTheme.barHeight
            exclusiveZone: 0
            anchors { top: true; left: true }
            LeftZone { id: leftContent; anchors.centerIn: parent }
        }

        // Host utilities against the status zone without a full-width hit area.
        PanelWindow {
            id: utilityWindow
            screen: screenScope.modelData
            color: LazerTheme.bgDark
            implicitWidth: utilityContent.implicitWidth + screenScope.sidePadding * 2
            implicitHeight: LazerTheme.barHeight
            exclusiveZone: 0
            anchors { top: true; right: true }
            margins.right: statusWindow.implicitWidth + screenScope.safetyGap
            UtilityZone {
                id: utilityContent
                anchors.centerIn: parent
                availableWidth: screenScope.utilityBudget - screenScope.sidePadding * 2
            }
        }

        // Host profile and system status at the right edge.
        PanelWindow {
            id: statusWindow
            screen: screenScope.modelData
            color: LazerTheme.bgDark
            implicitWidth: statusContent.implicitWidth + screenScope.sidePadding * 2
            implicitHeight: LazerTheme.barHeight
            exclusiveZone: 0
            anchors { top: true; right: true }
            StatusZone {
                id: statusContent
                anchors.centerIn: parent
                username: root.username
                avatarSource: root.avatarSource
            }
        }
    }
}
