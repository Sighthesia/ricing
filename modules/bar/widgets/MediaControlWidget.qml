import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import qs.config
import qs.services
import "../media" as MediaParts
import "../" as BarParts

// Persistent media widget with a transient flash control strip.
Item {
    id: root

    readonly property bool _enabled: SettingsService.data.mediaControl.enabled
    readonly property bool _showIdle: SettingsService.data.mediaControl.showWhenIdle
    readonly property bool _hoverRevealControls: SettingsService.data.mediaControl.hoverRevealControls
    readonly property bool _active: root._enabled && (MediaControlService.hasMedia || root._showIdle)
    readonly property int _pillH: Theme.barWidget.pillHeight
    readonly property int _padH: Theme.barWidget.contentPaddingH
    readonly property int _padV: Theme.barWidget.contentPaddingV
    readonly property int _flashGap: Theme.barWidget.stackGap
    readonly property int _flashRowH: Theme.barWidget.pillHeight
    readonly property int _flashEnterDelay: Math.max(1, Math.round(Theme.anim.springDuration / 6))
    readonly property int _flashRestLift: Math.max(1, Theme.barWidget.contentPaddingV)
    readonly property int _contentInsetV: Math.max(1, Theme.barWidget.contentPaddingV - 1)
    readonly property int _contentArtworkSize:
        root._pillH - root._contentInsetV * 2 - Theme.barWidget.mediaProgressThickness
    readonly property int _compactVisualizerLeftInset:
        root._padH + root._contentArtworkSize
    readonly property real _sharedProgressHeight:
        root.flashVisible ? Theme.barWidget.mediaExpandedProgressThickness : Theme.barWidget.mediaProgressThickness
    readonly property real _sharedProgressY:
        root.flashVisible
            ? (root._pillH + (root._flashGap - root._sharedProgressHeight) / 2)
            : (root._pillH - root._sharedProgressHeight)
    readonly property real _sharedProgressMaskY: root.flashVisible ? root._sharedProgressY : 0
    readonly property real _sharedProgressMaskHeight:
        root.flashVisible ? root._sharedProgressHeight : root._pillH
    readonly property real _flashProgressInset: root._padH * root._flashStageProgress
    readonly property real _flashProgressWidth:
        root.flashVisible
            ? Math.max(0, _pillBackground.width - root._flashProgressInset * 2)
            : _pillBackground.width
    readonly property real _transientAccentBaseOpacity:
        Colors.highlightAlpha * Theme.barWidget.mediaTransientAccentOpacityMultiplier
    readonly property bool _hoverFlashRequested:
        root._active
            && root._hoverRevealControls
            && (root._hoverFlashOverride || (!root._hoverHandlerIgnored && _hoverHandler.hovered))
    readonly property bool _hoverFlashActive:
        root._active && root._hoverRevealControls && (root._hoverFlashRequested || root._hoverRetainActive)
    readonly property bool flashVisible:
        root._active && (MediaControlService.announcementState !== "idle" || root._hoverFlashActive)
    readonly property string _displayTitle:
        MediaControlService.title !== ""
            ? MediaControlService.title
            : (MediaControlService.playerName !== "" ? MediaControlService.playerName : "No Media")
    
    function _triggerEventPulse() {
        _pulseAnim.stop()
        _pulseScaleAnim.stop()
        root._pulseOpacity = 0
        root._pulseScale = 1
        _pulseAnim.start()
        _pulseScaleAnim.start()
    }
    readonly property string _contentSignature:
        [MediaControlService.artUrl, MediaControlService.artist, root._displayTitle].join("|")
    readonly property int _contentSwapOffset:
        Math.max(2, Theme.barWidget.contentPaddingV * 2)
    readonly property real _flashStageVisibleOffset: Math.max(1, Math.round(Theme.uiScale))
    readonly property real _flashStageFullHeight: root._pillH + root._flashGap + root._flashRowH
    property real _pulseOpacity: 0
    property real _pulseScale: 1
    property real _flashStageProgress: 0
    property real _contentSwapProgress: 1
    property real _outgoingContentStartOpacity: 1
    property real _outgoingContentStartY: 0
    property real _seekPreviewProgress: -1
    property bool _flashHold: false
    property bool _hoverFlashOverride: false
    property bool _hoverRetainActive: false
    property bool _hoverHandlerIgnored: false
    property bool _contentInitialized: false
    property bool _contentSwapActive: false
    property var _currentContent: ({ title: "", artist: "", artUrl: "" })
    property var _outgoingContent: ({ title: "", artist: "", artUrl: "" })
    property var _incomingContent: ({ title: "", artist: "", artUrl: "" })

    readonly property bool _flashRenderVisible: root.flashVisible || root._flashHold
    readonly property real _flashStageClipHeight: _flashStageClip.height
    readonly property bool _seekPreviewActive: _seekArea.pressed && root._seekPreviewProgress >= 0
    readonly property real _displayProgress:
        root._seekPreviewActive ? root._seekPreviewProgress : MediaControlService.progress

    implicitWidth: root._active ? _pillClip.implicitWidth : 0
    implicitHeight: root._active ? (_pillH + Theme.iconPadding) : 0

    // Flash extension binding.
    Binding {
        target: BarLayoutService
        property: "mediaControlFlashExtension"
        value: root._flashRenderVisible ? (root._flashGap + root._flashRowH) : 0
        restoreMode: Binding.RestoreBindingOrValue
    }

    onFlashVisibleChanged: {
        if (!root.flashVisible) {
            _flashStageIn.stop()
            _flashStageOut.start()
            _flashCollapseRelease.restart()
        } else {
            _flashCollapseRelease.stop()
            root._flashHold = true
            _flashStageOut.stop()
            _flashStageIn.start()
        }

        if (root.flashVisible) {
            root._triggerEventPulse()
        } else {
            _pulseScaleAnim.stop()
            root._pulseScale = 1
            _pulseScaleAnim.start()
        }
    }

    on_HoverFlashRequestedChanged: {
        if (!root._hoverRevealControls || !root._active) {
            _hoverRetainRelease.stop()
            root._hoverRetainActive = false
            return
        }

        if (root._hoverFlashRequested) {
            _hoverRetainRelease.stop()
            root._hoverRetainActive = true
            return
        }

        if (root._hoverRetainActive)
            _hoverRetainRelease.restart()
    }

    on_ActiveChanged: {
        if (root._active)
            return

        _hoverRetainRelease.stop()
        root._hoverRetainActive = false
    }

    // Collapse hold timer.
    Timer {
        id: _flashCollapseRelease
        interval: Theme.anim.springDuration + root._flashEnterDelay
        repeat: false
        onTriggered: root._flashHold = false
    }

    // Hover retain timer.
    Timer {
        id: _hoverRetainRelease
        interval: SettingsService.data.mediaControl.announcementDuration
        repeat: false
        onTriggered: root._hoverRetainActive = false
    }

    function _findBarContent() {
        let candidate = root.parent
        while (candidate && !candidate.hitTestSection)
            candidate = candidate.parent
        return candidate
    }

    function _clampSeekProgress(xPosition) {
        if (_pillBackground.width <= 0)
            return 0

        return Math.max(0, Math.min(1, xPosition / _pillBackground.width))
    }

    function _snapshotContent() {
        return {
            title: root._displayTitle,
            artist: MediaControlService.artist,
            artUrl: MediaControlService.artUrl
        }
    }

    function _incomingSwapProgress(progressValue) {
        return Math.max(0, Math.min(1,
            (progressValue - Theme.barWidget.mediaContentSwapIncomingStart)
            / Theme.barWidget.mediaContentSwapIncomingRange))
    }

    readonly property real _incomingContentOpacity:
        root._contentSwapActive ? root._incomingSwapProgress(root._contentSwapProgress) : 0
    readonly property real _incomingContentY:
        root._contentSwapActive
            ? ((root._incomingContentOpacity - 1) * root._contentSwapOffset)
            : 0

    function _startContentSwap() {
        const nextContent = root._snapshotContent()
        const carryIncomingLayer = root._contentSwapActive
        const outgoingContent = carryIncomingLayer ? root._incomingContent : root._currentContent

        if (!root._contentInitialized) {
            root._currentContent = nextContent
            root._outgoingContent = nextContent
            root._incomingContent = nextContent
            root._contentSwapProgress = 1
            root._outgoingContentStartOpacity = 1
            root._outgoingContentStartY = 0
            root._contentInitialized = true
            return
        }

        _contentSwapAnim.stop()
        root._outgoingContent = outgoingContent
        root._incomingContent = nextContent
        root._currentContent = nextContent
        root._outgoingContentStartOpacity = carryIncomingLayer
            ? root._incomingSwapProgress(root._contentSwapProgress)
            : 1
        root._outgoingContentStartY = carryIncomingLayer
            ? ((root._incomingSwapProgress(root._contentSwapProgress) - 1) * root._contentSwapOffset)
            : 0
        root._contentSwapProgress = 0
        root._contentSwapActive = true
        _contentSwapAnim.start()
    }

    on_ContentSignatureChanged: root._startContentSwap()

    Component.onCompleted: root._startContentSwap()

    Connections {
        target: MediaControlService
        function onEventRevisionChanged() {
            if (!root._active)
                return

            if (!SettingsService.data.mediaControl.announcementEnabled || root.flashVisible)
                root._triggerEventPulse()
        }
    }
    // Background pulse animation.
    ParallelAnimation {
        id: _pulseAnim

        SequentialAnimation {
            NumberAnimation {
                target: root
                property: "_pulseOpacity"
                from: 0
                to: Colors.highlightAlpha + Theme.barWidget.mediaFlashScaleRange
                duration: Theme.anim.highlightDuration
                easing.type: Theme.anim.highlightType
            }
            NumberAnimation {
                target: root
                property: "_pulseOpacity"
                to: 0
                duration: Theme.anim.moveDuration
                easing.type: Theme.anim.moveType
            }
        }
    }

    // Flash stage-in animation.
    SequentialAnimation {
        id: _flashStageIn

        PauseAnimation {
            duration: root._flashEnterDelay
        }

        NumberAnimation {
            target: root
            property: "_flashStageProgress"
            to: 1
            duration: Theme.anim.springDuration
            easing.type: Theme.anim.springType
            easing.overshoot: Theme.anim.springOvershoot
        }
    }

    // Flash stage-out animation.
    NumberAnimation {
        id: _flashStageOut
        target: root
        property: "_flashStageProgress"
        to: 0
        duration: Theme.anim.springDuration
        easing.type: Theme.anim.springType
        easing.overshoot: Theme.anim.springOvershoot
    }

    // Center rebound animation.
    SequentialAnimation {
        id: _pulseScaleAnim

        NumberAnimation {
            target: root
            property: "_pulseScale"
            from: 1
            to: 1.018
            duration: Theme.anim.pulseSpringDuration
            easing.type: Theme.anim.pulseSpringType
            easing.overshoot: Theme.anim.pulseSpringOvershoot
        }

        NumberAnimation {
            target: root
            property: "_pulseScale"
            to: 1
            duration: Theme.anim.moveDuration
            easing.type: Theme.anim.moveType
        }
    }

    // Content swap animation.
    NumberAnimation {
        id: _contentSwapAnim
        target: root
        property: "_contentSwapProgress"
        to: 1
        duration: Theme.anim.moveDuration
        easing.type: Theme.anim.moveType
        onFinished: root._contentSwapActive = false
    }

    // Pulse backdrop.
    Rectangle {
        id: _pulseBackdrop
        anchors.fill: _pillClip
        radius: root._pillH / 2
        color: Colors.highlight
        opacity: root._pulseOpacity * 0.5
        visible: false
    }

    // Pill clip shell.
    Item {
        id: _pillClip
        visible: root._active
        anchors.top: parent.top
        anchors.topMargin: Theme.iconPadding
        anchors.horizontalCenter: parent.horizontalCenter
        implicitWidth: Math.max(
            _contentStage.implicitWidth + root._padH * 2,
            _flashStageClip.implicitWidth
        )
        implicitHeight: root._flashRenderVisible
            ? (root._pillH + root._flashGap + root._flashRowH)
            : root._pillH
        scale: root._pulseScale
        transformOrigin: Item.Center
        clip: true

        HoverHandler {
            id: _hoverHandler
        }

        Behavior on implicitWidth {
            NumberAnimation {
                duration: Theme.anim.springDuration
                easing.type: Theme.anim.springType
                easing.overshoot: Theme.anim.springOvershoot
            }
        }

        // Pill background.
        Rectangle {
            id: _pillBackground
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: root.flashVisible
                ? (root._pillH + root._flashGap + root._flashRowH)
                : root._pillH
            radius: root._pillH / 2
            color: Colors.background
            border.color: Colors.border
            border.width: 1

            Behavior on height {
                NumberAnimation {
                    duration: Theme.anim.springDuration
                    easing.type: Theme.anim.springType
                    easing.overshoot: Theme.anim.springOvershoot
                }
            }
        }

        // Base highlight layer.
        Rectangle {
            anchors.fill: _pillBackground
            radius: _pillBackground.radius
            color: Colors.highlight
            opacity: 0
        }

        // Transient accent layer.
        Rectangle {
            z: 1
            anchors.fill: _pillBackground
            radius: _pillBackground.radius
            color: Colors.highlight
            opacity: root._flashRenderVisible ? Math.min(1, root._transientAccentBaseOpacity + root._pulseOpacity) : 0
        }

        // Flash stage clip.
        MediaParts.MediaFlashStage {
            id: _flashStageClip
            anchors.left: _pillBackground.left
            anchors.right: _pillBackground.right
            anchors.top: _pillBackground.top
            height: Math.min(
                _pillBackground.height,
                root._pillH + (root._flashGap + root._flashRowH) * root._flashStageProgress
            )
            active: root._active
            stageProgress: root._flashStageProgress
            pillWidth: _pillBackground.width
            pillHeight: root._pillH
            padH: root._padH
            gap: root._flashGap
            rowHeight: root._flashRowH
            restLift: root._flashRestLift
            visibleOffset: root._flashStageVisibleOffset
            leadingLabel: MediaControlService.positionLabel
            durationLabel: MediaControlService.durationLabel
            playbackState: MediaControlService.playbackState
            canGoPrevious: MediaControlService.canGoPrevious
            canTogglePlayback: MediaControlService.canTogglePlayback
            canGoNext: MediaControlService.canGoNext
            secondaryButtonSize: Theme.barWidget.mediaFlashCompactSecondaryButtonSize
            primaryButtonSize: Theme.barWidget.mediaFlashCompactPrimaryButtonSize
            secondaryIconSize: Theme.barWidget.mediaFlashCompactSecondaryIconSize
            primaryIconSize: Theme.barWidget.mediaFlashCompactPrimaryIconSize
            onPreviousRequested: MediaControlService.previous()
            onPlayPauseRequested: MediaControlService.playPause()
            onNextRequested: MediaControlService.next()
        }

        // Shared progress mask.
        Item {
            id: _sharedProgressMask
            anchors.fill: parent
            layer.enabled: true
            opacity: 0

            // Shared progress mask shape.
            Rectangle {
                x: root._flashProgressInset
                y: root._sharedProgressMaskY
                width: root._flashProgressWidth
                height: root._sharedProgressMaskHeight
                radius: root.flashVisible ? (root._sharedProgressHeight / 2) : (root._pillH / 2)
                color: "white"

                Behavior on y {
                    NumberAnimation {
                        duration: Theme.anim.springDuration
                        easing.type: Theme.anim.springType
                        easing.overshoot: Theme.anim.springOvershoot
                    }
                }

                Behavior on height {
                    NumberAnimation {
                        duration: Theme.anim.springDuration
                        easing.type: Theme.anim.springType
                        easing.overshoot: Theme.anim.springOvershoot
                    }
                }

                Behavior on radius {
                    NumberAnimation {
                        duration: Theme.anim.springDuration
                        easing.type: Theme.anim.springType
                        easing.overshoot: Theme.anim.springOvershoot
                    }
                }
            }
        }

        // Shared progress source.
        Item {
            id: _sharedProgressSource
            anchors.fill: parent
            opacity: 0

            // Shared progress strip.
            MediaParts.MediaProgressStrip {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: root._flashProgressInset
                anchors.rightMargin: root._flashProgressInset
                y: root._sharedProgressY
                progress: root._displayProgress
                expanded: root.flashVisible

                Behavior on y {
                    NumberAnimation {
                        duration: Theme.anim.springDuration
                        easing.type: Theme.anim.springType
                        easing.overshoot: Theme.anim.springOvershoot
                    }
                }
            }
        }

        // Shared progress masked output.
        OpacityMask {
            z: 1
            anchors.fill: parent
            source: _sharedProgressSource
            maskSource: _sharedProgressMask
        }

        // Seek hit target.
        MouseArea {
            id: _seekArea
            z: 2
            x: root._flashProgressInset
            y: root._sharedProgressY
            width: root._flashProgressWidth
            height: root._sharedProgressHeight
            enabled: root._flashRenderVisible && MediaControlService.canSeek
            hoverEnabled: enabled
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onPressed: mouse => {
                root._seekPreviewProgress = root._clampSeekProgress(mouse.x)
            }
            onPositionChanged: mouse => {
                if (!pressed)
                    return

                root._seekPreviewProgress = root._clampSeekProgress(mouse.x)
            }
            onReleased: mouse => {
                root._seekPreviewProgress = root._clampSeekProgress(mouse.x)
                MediaControlService.seekToProgress(root._seekPreviewProgress)
                root._seekPreviewProgress = -1
            }
            onCanceled: root._seekPreviewProgress = -1

            Behavior on y {
                NumberAnimation {
                    duration: Theme.anim.springDuration
                    easing.type: Theme.anim.springType
                    easing.overshoot: Theme.anim.springOvershoot
                }
            }

            Behavior on height {
                NumberAnimation {
                    duration: Theme.anim.springDuration
                    easing.type: Theme.anim.springType
                    easing.overshoot: Theme.anim.springOvershoot
                }
            }
        }

        // Surface shell.
        Item {
            id: _surface
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: root._pillH
            clip: true

            // Surface overlay.
            Rectangle {
                anchors.fill: parent
                radius: root._pillH / 2
                color: Colors.background
                opacity: Theme.barWidget.mediaSurfaceOverlayOpacity
            }

            // Surface visualizer.
            MediaParts.MediaVisualizerBackground {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.leftMargin: root._compactVisualizerLeftInset
                anchors.rightMargin: root._padH
                anchors.topMargin: root._contentInsetV
                anchors.bottomMargin: Theme.barWidget.mediaProgressThickness
                bars: MediaControlService.visualizerHealthy ? MediaControlService.visualizerBars : []
                barOpacity: Theme.barWidget.mediaVisualizerBarOpacity * 1.1
            }

            // Surface accent layer.
            Rectangle {
                anchors.fill: parent
                radius: root._pillH / 2
                color: Colors.highlight
                opacity: 0
            }

            // Surface hover highlight.
            BarParts.HoverRevealHighlight {
                anchors.fill: parent
                hovered: _mainArea.containsMouse
                radius: root._pillH / 2
            }

            // Content stage.
            Item {
                id: _contentStage
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: root._padH
                anchors.rightMargin: root._padH
                implicitWidth: _contentLayers.implicitWidth
                implicitHeight: _contentLayers.implicitHeight

                // Swappable content layers.
                MediaParts.MediaCompactContentStack {
                    id: _contentLayers
                    anchors.left: parent.left
                    anchors.right: parent.right
                    swapActive: root._contentSwapActive
                    outgoingOpacity: root._contentSwapActive
                        ? (root._outgoingContentStartOpacity * (1 - root._contentSwapProgress))
                        : 0
                    outgoingY: root._contentSwapActive
                        ? (root._outgoingContentStartY
                            + (root._contentSwapOffset - root._outgoingContentStartY) * root._contentSwapProgress)
                        : 0
                    incomingOpacity: root._incomingContentOpacity
                    incomingY: root._incomingContentY
                    currentContent: root._currentContent
                    outgoingContent: root._outgoingContent
                    incomingContent: root._incomingContent
                    artworkSize: root._contentArtworkSize
                    textMaxWidth: Theme.barWidget.mediaCompactMaxTitleWidth
                }
            }

            // Main ripple layer.
            BarParts.ClickRipple {
                id: _mainRipple
                anchors.fill: parent
            }

            // Main hit target.
            MouseArea {
                id: _mainArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: (mouse) => {
                    let barContent = root._findBarContent()
                    if (barContent) {
                        let centerPoint = root.mapToItem(barContent, root.width / 2, 0)
                        BarLayoutService.mediaControlPanelX = centerPoint.x
                    }
                    _mainRipple.triggerRipple(mouse.x, mouse.y)
                    MediaControlService.togglePanel()
                }
            }
        }

    }
}
