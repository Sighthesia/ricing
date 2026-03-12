import Quickshell
import QtQuick
import QtQuick.Layouts
import qs.config
import "../" as BarComponents

// Interactive flash-row controls used by the compact widget and announcement strip.
Item {
    id: root

    property real progress: 0
    property string leadingLabel: ""
    property string durationLabel: ""
    property string playbackState: "stopped"
    property bool canGoPrevious: false
    property bool canTogglePlayback: false
    property bool canGoNext: false
    property bool showProgress: true
    property int topPadding: 0
    property int bottomPadding: 0
    property int secondaryButtonSize: -1
    property int primaryButtonSize: -1
    property int secondaryIconSize: -1
    property int primaryIconSize: -1

    signal previousRequested
    signal playPauseRequested
    signal nextRequested

    implicitWidth: _row.implicitWidth
    implicitHeight: _row.implicitHeight + root.topPadding + root.bottomPadding

    // Flash control button.
    component IconButton: Item {
        id: button

        required property string iconName
        required property bool enabled
        property bool primary: false
        readonly property int _iconSize: button.primary
            ? (root.primaryIconSize > 0 ? root.primaryIconSize : Theme.barWidget.primaryIconSize)
            : (root.secondaryIconSize > 0 ? root.secondaryIconSize : Theme.barWidget.compactIconSize)
        signal triggered

        implicitWidth: button.primary
            ? (root.primaryButtonSize > 0 ? root.primaryButtonSize : Theme.barWidget.mediaFlashPrimaryButtonSize)
            : (root.secondaryButtonSize > 0 ? root.secondaryButtonSize : Theme.barWidget.mediaFlashSecondaryButtonSize)
        implicitHeight: implicitWidth
        opacity: button.enabled ? 1 : Theme.barWidget.mediaFlashDisabledButtonOpacity

        // Button background.
        Rectangle {
            anchors.fill: parent
            radius: Math.round(height * Theme.barWidget.mediaFlashButtonRadiusRatio)
            color: button.primary
                ? Colors.highlight
                : Qt.rgba(1, 1, 1, Theme.barWidget.mediaFlashSecondarySurfaceOpacity)
            border.color: Colors.border
            border.width: 1
        }

        // Button hover layer.
        BarComponents.HoverRevealHighlight {
            anchors.fill: parent
            hovered: _area.containsMouse
            radius: Math.round(height * Theme.barWidget.mediaFlashButtonRadiusRatio)
            adaptiveContrast: true
            surfaceColor: button.primary
                ? Colors.highlight
                : Qt.rgba(1, 1, 1, Theme.barWidget.mediaFlashSecondarySurfaceOpacity)
            highlightColor: Colors.highlight
            highlightOpacity: button.primary
                ? Theme.barWidget.mediaFlashPrimaryHighlightOpacity
                : Theme.barWidget.mediaFlashSecondaryHighlightOpacity
        }

        // Button icon.
        Image {
            anchors.centerIn: parent
            source: Quickshell.iconPath(button.iconName, "audio-x-generic")
            sourceSize.width: button._iconSize
            sourceSize.height: button._iconSize
            width: sourceSize.width
            height: sourceSize.height
            opacity: button.enabled
                ? (button.primary ? 1 : Theme.barWidget.mediaFlashSecondaryIconOpacity)
                : Theme.barWidget.mediaFlashDisabledIconOpacity
        }

        // Button ripple layer.
        BarComponents.ClickRipple {
            id: _ripple
            anchors.fill: parent
            radius: Math.round(height * Theme.barWidget.mediaFlashButtonRadiusRatio)
            rippleColor: button.primary ? Colors.background : Colors.highlight
            rippleOpacity: button.primary
                ? Theme.barWidget.mediaFlashPrimaryRippleOpacity
                : Theme.barWidget.mediaFlashSecondaryRippleOpacity
        }

        // Button hit target.
        MouseArea {
            id: _area
            anchors.fill: parent
            enabled: button.enabled
            hoverEnabled: true
            cursorShape: button.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: (mouse) => {
                _ripple.triggerRipple(mouse.x, mouse.y)
                button.triggered()
            }
        }
    }

    // Flash transport row.
    RowLayout {
        id: _row
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: root.topPadding
        spacing: Theme.barWidget.mediaFlashControlGap

        // Leading time label.
        Text {
            visible: root.leadingLabel !== ""
            text: root.leadingLabel
            color: Colors.textMuted
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSizeSmall
            Layout.alignment: Qt.AlignVCenter
            Layout.minimumWidth: implicitWidth
            opacity: Theme.barWidget.mediaFlashLabelOpacity
        }

        // Inline progress strip.
        MediaProgressStrip {
            visible: root.showProgress
            progress: root.progress
            Layout.fillWidth: true
            Layout.minimumWidth: Theme.barWidget.mediaFlashProgressMinWidth
            Layout.alignment: Qt.AlignVCenter
        }

        // Leading spacer.
        Item {
            visible: !root.showProgress
            Layout.fillWidth: true
        }

        // Button cluster.
        RowLayout {
            spacing: Theme.barWidget.mediaFlashClusterGap

            // Previous button.
            IconButton {
                iconName: "media-skip-backward"
                enabled: root.canGoPrevious
                Layout.alignment: Qt.AlignVCenter
                onTriggered: root.previousRequested()
            }

            // Play-pause button.
            IconButton {
                iconName: root.playbackState === "playing"
                    ? "media-playback-pause"
                    : "media-playback-start"
                enabled: root.canTogglePlayback
                primary: true
                Layout.alignment: Qt.AlignVCenter
                onTriggered: root.playPauseRequested()
            }

            // Next button.
            IconButton {
                iconName: "media-skip-forward"
                enabled: root.canGoNext
                Layout.alignment: Qt.AlignVCenter
                onTriggered: root.nextRequested()
            }
        }

        // Trailing spacer.
        Item {
            visible: !root.showProgress
            Layout.fillWidth: true
        }

        // Trailing time label.
        Text {
            text: root.durationLabel
            color: Colors.textMuted
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSizeSmall
            Layout.alignment: Qt.AlignVCenter
            Layout.minimumWidth: implicitWidth
            horizontalAlignment: Text.AlignRight
            opacity: Theme.barWidget.mediaFlashLabelOpacity
        }
    }
}