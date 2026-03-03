import QtQuick
import qs.config
import qs.services

Item {
    id: settingsToggle

    implicitWidth: Theme.barHeight - Theme.barPadding
    implicitHeight: Theme.barHeight - Theme.barPadding

    // Background rectangle: reveals on hover and settings mode
    Rectangle {
        id: bg
        anchors.fill: parent
        radius: Theme.cornerRadius
        color: Colors.highlight
        opacity: BarLayoutService.settingsMode
            ? Colors.highlightAlpha
            : (hoverArea.containsMouse ? 0.08 : 0)

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.anim.highlightDuration
                easing.type: BarLayoutService.settingsMode
                    ? Easing.OutExpo
                    : Easing.InExpo
            }
        }
    }

    // Gear icon
    Text {
        id: icon
        anchors.centerIn: parent
        text: "\uf013"  // Nerd Font gear icon
        font.family: Theme.fontMono
        font.pixelSize: Theme.fontSizeIcon
        color: Colors.text

        rotation: BarLayoutService.settingsMode ? 45 : 0

        Behavior on rotation {
            NumberAnimation {
                duration: BarLayoutService.settingsMode
                    ? Theme.anim.enterDuration : Theme.anim.exitDuration
                easing.type: BarLayoutService.settingsMode
                    ? Easing.OutElastic
                    : Easing.InExpo
                easing.amplitude: BarLayoutService.settingsMode
                    ? Theme.anim.enterAmplitude : 1.0
                easing.period: BarLayoutService.settingsMode
                    ? Theme.anim.enterPeriod : 0.3
            }
        }
    }

    // Click handler
    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            BarLayoutService.settingsMode = !BarLayoutService.settingsMode;
        }
    }

    // Periodic pulse in settings mode (every 3s)
    Timer {
        id: pulseTimer
        interval: Theme.pulseInterval
        repeat: true
        running: BarLayoutService.settingsMode

        onTriggered: {
            // Walk up to BarWidgetWrapper parent and call pulse()
            if (settingsToggle.parent && settingsToggle.parent.pulse) {
                settingsToggle.parent.pulse(1);
            }
        }
    }

    // Global Esc to exit settings mode
    Shortcut {
        sequence: "Escape"
        enabled: BarLayoutService.settingsMode
        onActivated: {
            BarLayoutService.settingsMode = false;
        }
    }
}
