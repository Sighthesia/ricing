import QtQuick
import qs.config

// Hosts the divider and transient transport controls below the compact media pill.
Item {
    id: root

    property bool active: false
    property real stageProgress: 0
    property real pillWidth: 0
    property int pillHeight: Theme.barWidget.pillHeight
    property int padH: Theme.barWidget.contentPaddingH
    property int gap: Theme.barWidget.stackGap
    property int rowHeight: Theme.barWidget.pillHeight
    property int restLift: Math.max(1, Theme.barWidget.contentPaddingV)
    property real visibleOffset: Math.max(1, Math.round(Theme.uiScale))
    property string leadingLabel: ""
    property string durationLabel: ""
    property string playbackState: "stopped"
    property bool canGoPrevious: false
    property bool canTogglePlayback: false
    property bool canGoNext: false
    property int secondaryButtonSize: Theme.barWidget.mediaFlashCompactSecondaryButtonSize
    property int primaryButtonSize: Theme.barWidget.mediaFlashCompactPrimaryButtonSize
    property int secondaryIconSize: Theme.barWidget.mediaFlashCompactSecondaryIconSize
    property int primaryIconSize: Theme.barWidget.mediaFlashCompactPrimaryIconSize

    signal previousRequested
    signal playPauseRequested
    signal nextRequested

    readonly property real _controlsWidth: Math.max(0, root.pillWidth - root.padH * 2)

    implicitWidth: _controls.implicitWidth + root.padH * 2
    implicitHeight: root.pillHeight + root.gap + root.rowHeight

    clip: true

    Item {
        anchors.left: parent.left
        anchors.right: parent.right
        y: root.pillHeight
        height: root.gap

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.max(0, root.pillWidth - root.padH * 2)
            height: 1
            radius: height / 2
            color: Colors.border
            opacity: 0.35 * root.stageProgress
        }
    }

    Item {
        anchors.left: parent.left
        anchors.right: parent.right
        y: root.pillHeight + root.gap
        height: root.rowHeight

        MediaFlashControls {
            id: _controls
            visible: root.active
            width: root._controlsWidth
            anchors.horizontalCenter: parent.horizontalCenter
            y: (parent.height - implicitHeight) / 2
                - root.restLift
                + (root.restLift + root.visibleOffset) * root.stageProgress
            opacity: root.stageProgress
            scale: Theme.barWidget.mediaFlashMinScale
                + Theme.barWidget.mediaFlashScaleRange * root.stageProgress
            leadingLabel: root.leadingLabel
            durationLabel: root.durationLabel
            playbackState: root.playbackState
            canGoPrevious: root.canGoPrevious
            canTogglePlayback: root.canTogglePlayback
            canGoNext: root.canGoNext
            showProgress: false
            secondaryButtonSize: root.secondaryButtonSize
            primaryButtonSize: root.primaryButtonSize
            secondaryIconSize: root.secondaryIconSize
            primaryIconSize: root.primaryIconSize
            onPreviousRequested: root.previousRequested()
            onPlayPauseRequested: root.playPauseRequested()
            onNextRequested: root.nextRequested()
        }
    }
}
