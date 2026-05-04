import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import "../media" as MediaParts

// Renders the steady idle clock pill content for SuperIsland.
// Inspired by: Quickshell DynamicIsland ClockContent.qml
// /home/Sighthesia/0_Files/Producing/Software/Quickshell/quickshell/Modules/DynamicIsland/ClockContent/ClockContent.qml
Item {
    id: root

    required property date currentTime
    required property bool hasPendingEvents
    property int cardHeight: Theme.barWidget.pillHeight
    property bool showMedia: SettingsService.data.superIsland.showMedia !== false

    readonly property string _dayText: Qt.formatDate(root.currentTime, "M月d日")
    readonly property string _hourText: Qt.formatDateTime(root.currentTime, "hh")
    readonly property string _minuteText: Qt.formatDateTime(root.currentTime, "mm")
    readonly property int _hourTens: Number(root._hourText.charAt(0) || "0")
    readonly property int _hourOnes: Number(root._hourText.charAt(1) || "0")
    readonly property int _minuteTens: Number(root._minuteText.charAt(0) || "0")
    readonly property int _minuteOnes: Number(root._minuteText.charAt(1) || "0")
    readonly property int _digitHeight: Math.max(20, Math.round(Theme.fontSizeBody * 1.15))
    readonly property string _displayTitle: MediaControlService.title !== ""
        ? MediaControlService.title
        : (MediaControlService.playerName !== "" ? MediaControlService.playerName : "Media")
    readonly property string _displayArtist: MediaControlService.artist !== ""
        ? MediaControlService.artist
        : MediaControlService.playbackState
    readonly property string _artUrl: MediaControlService.artUrl || ""
    readonly property bool _hasMediaDisplayData:
        MediaControlService.hasPlayer
            || MediaControlService.title !== ""
            || MediaControlService.artist !== ""
            || MediaControlService.artUrl !== ""
            || MediaControlService.playerName !== ""
    readonly property bool _showMediaContent: root.showMedia && root._hasMediaDisplayData
    readonly property int _artworkSize: Theme.barWidget.pillHeight - Theme.barWidget.contentPaddingV * 2

    implicitWidth: _contentRow.implicitWidth
    implicitHeight: root.cardHeight

    // Centered idle clock and media row.
    RowLayout {
        id: _contentRow

        anchors.centerIn: parent
        spacing: root._showMediaContent ? Theme.barWidget.iconLabelSpacing : 0

        // Clock cluster.
        RowLayout {
            spacing: ThemeSuperIsland.idleClockClockClusterSpacing

            // Month-day label.
            Text {
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeSmall
                font.bold: true
                text: root._dayText
                color: Colors.textMuted
            }

            // Divider between date and time.
            Rectangle {
                implicitWidth: 1
                implicitHeight: Theme.fontSizeBody
                radius: width / 2
                color: Colors.border
                opacity: 0.65
                Layout.alignment: Qt.AlignVCenter
            }

            // Animated time group.
            RowLayout {
                spacing: ThemeSuperIsland.idleClockDigitGroupSpacing
                Layout.alignment: Qt.AlignVCenter

                // Hour digits.
                RowLayout {
                    spacing: ThemeSuperIsland.idleClockDigitSpacing
                    Layout.alignment: Qt.AlignVCenter

                    // Hour tens digit.
                    RollingDigit {
                        targetDigit: root._hourTens
                        digitColor: Colors.textMuted
                    }

                    // Hour ones digit.
                    RollingDigit {
                        targetDigit: root._hourOnes
                        digitColor: Colors.text
                    }
                }

                // Colon separator.
                ColumnLayout {
                    spacing: ThemeSuperIsland.idleClockColonColumnSpacing
                    Layout.alignment: Qt.AlignVCenter

                    // Upper colon dot.
                    Rectangle {
                        implicitWidth: ThemeSuperIsland.idleClockColonDotSize
                        implicitHeight: ThemeSuperIsland.idleClockColonDotSize
                        radius: width / 2
                        color: Colors.text
                        opacity: 0.8
                        Layout.alignment: Qt.AlignHCenter
                    }

                    // Lower colon dot.
                    Rectangle {
                        implicitWidth: ThemeSuperIsland.idleClockColonDotSize
                        implicitHeight: ThemeSuperIsland.idleClockColonDotSize
                        radius: width / 2
                        color: Colors.text
                        opacity: 0.8
                        Layout.alignment: Qt.AlignHCenter
                    }
                }

                // Minute digits.
                RowLayout {
                    spacing: -1
                    Layout.alignment: Qt.AlignVCenter

                    // Minute tens digit.
                    RollingDigit {
                        targetDigit: root._minuteTens
                        digitColor: Colors.textMuted
                    }

                    // Minute ones digit.
                    RollingDigit {
                        targetDigit: root._minuteOnes
                        digitColor: Colors.text
                    }
                }
            }

            // Pending-event indicator.
            Rectangle {
                visible: root.hasPendingEvents
                implicitWidth: Theme.barWidget.indicatorDotSize
                implicitHeight: Theme.barWidget.indicatorDotSize
                radius: width / 2
                color: Colors.highlight
                opacity: Colors.highlightAlpha + 0.2
                Layout.alignment: Qt.AlignVCenter
            }
        }

        // Persistent media content stays on the clock host.
        MediaParts.MediaCompactContent {
            visible: root._showMediaContent
            title: root._displayTitle
            artist: root._displayArtist
            artUrl: root._artUrl
            fallbackIcon: "audio-x-generic-symbolic"
            artworkSize: root._artworkSize
            textMaxWidth: Theme.barWidget.mediaCompactMaxTitleWidth
            textOverflowMode: SettingsService.data.mediaControl.compactTextOverflowMode || "elide"
            showArtwork: true
            showText: true
            Layout.alignment: Qt.AlignVCenter
        }
    }

    // Rolling digit strip used for the time flip effect.
    component RollingDigit : Item {
        id: digitContainer

        property int targetDigit: 0
        property color digitColor: Colors.text

        width: digitText.implicitWidth
        height: root._digitHeight
        clip: true

        // Vertical digit stack.
        Text {
            id: digitText

            text: "0\n1\n2\n3\n4\n5\n6\n7\n8\n9"
            color: digitContainer.digitColor
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSizeBody
            font.bold: true
            lineHeight: digitContainer.height
            lineHeightMode: Text.FixedHeight
            y: -digitContainer.targetDigit * digitContainer.height

            Behavior on y {
                SpringAnimation {
                    spring: 3.5
                    damping: 0.75
                    mass: 1.0
                }
            }
        }
    }
}
