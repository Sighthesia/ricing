import Quickshell
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import qs.config
import qs.services
import "../media" as MediaParts
import "../" as BarParts
import "../" as BarPanels

// Persistent media widget with a transient flash control strip.
Item {
    id: root

    readonly property bool _debugLyricDisplay:
        (Quickshell.env("DYMICSHELL_MEDIA_LYRIC_DEBUG") || "").trim() === "1"
    readonly property bool _enabled: SettingsService.data.mediaControl.enabled
    readonly property bool _showIdle: SettingsService.data.mediaControl.showWhenIdle
    readonly property bool _hoverRevealControls: SettingsService.data.mediaControl.hoverRevealControls
    readonly property bool _showLyrics: SettingsService.data.mediaControl.showLyrics
    readonly property bool _preferLyrics: SettingsService.data.mediaControl.preferLyrics
    readonly property string _compactTextOverflowMode:
        SettingsService.data.mediaControl.compactTextOverflowMode || "elide"
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
    readonly property bool _useMaskedProgress: false
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
    readonly property bool _useLyricsAsPrimaryText:
        root._showLyrics && root._preferLyrics && MediaControlService.hasLyrics && MediaControlService.compactPrimaryLyric !== ""
    readonly property string _displayArtist:
        root._useLyricsAsPrimaryText ? "" : MediaControlService.artist
    readonly property string _displayTitle:
        root._useLyricsAsPrimaryText
            ? MediaControlService.compactPrimaryLyric
            : (MediaControlService.title !== ""
                ? MediaControlService.title
                : (MediaControlService.playerName !== "" ? MediaControlService.playerName : "No Media"))
    readonly property string _displayTextSignature:
        [root._displayArtist, root._displayTitle].join("|")
    readonly property string _mediaIdentitySignature:
        [MediaControlService.artUrl, MediaControlService.artist, MediaControlService.title, MediaControlService.playerName].join("|")
    readonly property string _lyricDisplaySignature: MediaControlService.compactPrimaryLyricKey
    
    function _triggerEventPulse() {
        _pulseAnim.stop()
        _pulseScaleAnim.stop()
        root._pulseOpacity = 0
        root._pulseScale = 1
        _pulseAnim.start()
        _pulseScaleAnim.start()
    }
    readonly property string _contentSignature:
        [
            root._useLyricsAsPrimaryText ? "lyrics" : "media",
            root._mediaIdentitySignature,
            root._useLyricsAsPrimaryText ? root._lyricDisplaySignature : root._displayTextSignature
        ].join("|")
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
    property bool _contentTextOnlySwap: false
    property string _panelState: "closed"
    property real _panelVisibleWidth: 0
    property real _panelVisibleHeight: 0
    property real _panelSurfaceOpacity: 0
    property real _panelSurfaceScale: 0.985
    property real _panelContentOpacity: 0
    property real _panelThrowOffsetY: 0
    property var _currentContent: ({ title: "", artist: "", artUrl: "" })
    property var _outgoingContent: ({ title: "", artist: "", artUrl: "" })
    property var _incomingContent: ({ title: "", artist: "", artUrl: "" })

    readonly property bool _flashRenderVisible: root.flashVisible || root._flashHold
    readonly property real _flashStageClipHeight: _flashStageClip.height
    readonly property bool _seekPreviewActive: _seekArea.pressed && root._seekPreviewProgress >= 0
    readonly property real _displayProgress:
        root._seekPreviewActive ? root._seekPreviewProgress : MediaControlService.progress
    readonly property real _panelPillWidth:
        Math.max(
            Theme.barWidget.mediaCompactMinWidth,
            root.width > 0 ? root.width : Theme.barWidget.mediaCompactMinWidth
        )
    readonly property real _panelPillHeight: root._pillH
    readonly property real _panelWidth: Theme.barWidget.mediaPanelWidth + ThemeCards.panelPadding * 2
    readonly property real _panelHeight: _panelContent.implicitHeight + ThemeCards.panelPadding * 2
    readonly property real _panelShellY: _pillClip.y
    readonly property real _panelDetachedY:
        root._panelShellY + root._panelPillHeight + root._panelInwardCornerDepth
    readonly property real _panelRevealLift: Math.max(8, Theme.barWidget.contentPaddingV * 4)
    readonly property real _panelAttachmentOverlap: 1
    readonly property real _panelShellRadius: ThemeCards.shellRadius
    readonly property real _panelInwardCornerRadius: _panelShellRadius
    readonly property real _panelInwardCornerDepth:
        Math.max(18, root._panelInwardCornerRadius + (root._panelInwardCornerRadius - 18) * 0.3)
    readonly property real _panelBridgeOutset: 0
    readonly property real _panelWindowHeight: Math.max(_panelPillHeight, _panelDetachedY + _panelHeight)
    readonly property real _panelShellHeight:
        Math.max(0, (_panelHost.y + root._panelVisibleHeight) - _panelShellY)
    readonly property real _panelReservedExtension:
        root._panelState === "closed"
            ? 0
            : Math.max(0, Math.ceil(root._panelDetachedY + root._panelHeight))
    readonly property real _panelShellBlend:
        root._panelState === "closed"
            ? 0
            : Math.max(
                0,
                Math.min(
                    1,
                    root._panelState === "closing"
                        ? root._panelRevealProgress
                        : Math.max(root._panelRevealProgress, root._panelSurfaceOpacity)
                )
            )
    readonly property real _panelWidthRevealProgress:
        root._panelWidth > root._panelPillWidth
            ? Math.max(0, Math.min(1, (root._panelVisibleWidth - root._panelPillWidth) / (root._panelWidth - root._panelPillWidth)))
            : 1
    readonly property real _panelHeightRevealProgress:
        root._panelHeight > 0
            ? Math.max(0, Math.min(1, root._panelVisibleHeight / root._panelHeight))
            : 1
    readonly property real _panelRevealProgress:
        root._panelState === "closed"
            ? 0
            : Math.min(root._panelWidthRevealProgress, root._panelHeightRevealProgress)
    readonly property real _panelRevealYOffset: (1 - root._panelRevealProgress) * root._panelRevealLift
    readonly property bool _panelCollapseTailHidden:
        root._panelState === "closing"
            && (root._panelRevealProgress <= 0.2
                || root._panelVisibleHeight <= Math.max(8, root._panelAttachmentOverlap + 6))

    BarPanels.AttachedExpansionMotion {
        id: _panelMotion

        motionTarget: root
        throwOffsetProperty: "_panelThrowOffsetY"
        revealWidthProperty: "_panelVisibleWidth"
        revealHeightProperty: "_panelVisibleHeight"
        contentOpacityProperty: "_panelContentOpacity"
        throwLift: Math.max(8, Theme.barWidget.contentPaddingV * 4)
        throwDrop: Math.max(3, Math.round(root._panelRevealLift * 0.55))
        throwCatchLift: Math.max(3, Math.round(root._panelRevealLift * 1.05))
        revealWidthTarget: root._panelWidth
        revealHeightTarget: root._panelHeight
        collapseWidthTarget: root._panelPillWidth
        collapseHeightTarget: 0
        revealContentOpacityTarget: 1
        collapseContentOpacityTarget: 1
        throwLeadDuration: Math.max(1, Math.round(Theme.anim.springDuration / 6))
        throwDropDuration: Math.max(1, Math.round(Theme.anim.springDuration / 2))

        onRevealFinished: {
            if (root._panelState === "opening")
                root._panelState = "open"
        }

        onCollapseFinished: {
            if (root._panelState !== "closing")
                return

            root._panelState = "closed"
            root._resetPanelCollapsedSeed()
        }
    }

    implicitWidth: root._active ? _pillClip.implicitWidth : 0
    implicitHeight: root._active ? (_pillH + Theme.iconPadding) : 0

    // Flash extension binding.
    Binding {
        target: BarLayoutService
        property: "mediaControlFlashExtension"
        value: root._flashRenderVisible ? (root._flashGap + root._flashRowH) : 0
        restoreMode: Binding.RestoreBindingOrValue
    }

    function _resetPanelCollapsedSeed() {
        root._panelVisibleWidth = root._panelPillWidth
        root._panelVisibleHeight = 0
        root._panelSurfaceOpacity = 0
        root._panelSurfaceScale = 0.985
        root._panelContentOpacity = 0
        root._panelThrowOffsetY = 0
    }

    function _syncPanelExtensionReservation() {
        if (root._panelReservedExtension > 0)
            BarLayoutService.setTransientExtension("mediaControlPanelExtension", root._panelReservedExtension)
        else
            BarLayoutService.clearTransientExtension("mediaControlPanelExtension")
    }

    function _openPanel() {
        _panelMotion.catchAnim.stop()
        _panelMotion.collapseAnim.stop()
        _panelSurfaceOpenAnim.stop()
        _panelSurfaceCloseAnim.stop()
        _panelEnterDelay.stop()

        if (root._panelState === "closed")
            root._resetPanelCollapsedSeed()

        root._panelState = "opening"
        _panelSurfaceCloseAnim.stop()
        _panelSurfaceOpenAnim.restart()
        _panelMotion.throwOutAnim.restart()
        _panelMotion.revealAnim.restart()
        _panelEnterDelay.restart()
    }

    function _closePanel() {
        _panelMotion.throwOutAnim.stop()
        _panelMotion.revealAnim.stop()
        _panelSurfaceOpenAnim.stop()
        _panelSurfaceCloseAnim.stop()
        _panelEnterDelay.stop()

        if (_panelContent && _panelContent.runExitAnimation)
            _panelContent.runExitAnimation()

        if (root._panelState === "closed" || root._panelState === "closing")
            return

        root._panelState = "closing"
        _panelMotion.catchAnim.restart()
        _panelMotion.collapseAnim.restart()
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
        if (root._active) {
            if (MediaControlService.panelOpen)
                root._openPanel()
            else
                root._resetPanelCollapsedSeed()
            return
        }

        _hoverRetainRelease.stop()
        root._hoverRetainActive = false
        root._closePanel()
    }

    Component.onCompleted: {
        root._startContentSwap()
        root._syncPanelExtensionReservation()

        if (root._active && MediaControlService.panelOpen)
            root._openPanel()
        else
            root._resetPanelCollapsedSeed()
    }

    Component.onDestruction: BarLayoutService.clearTransientExtension("mediaControlPanelExtension")

    on_PanelReservedExtensionChanged: root._syncPanelExtensionReservation()

    Connections {
        target: MediaControlService

        function onPanelOpenChanged() {
            if (!root._active)
                return

            if (MediaControlService.panelOpen)
                root._openPanel()
            else
                root._closePanel()
        }
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

    Timer {
        id: _panelEnterDelay
        interval: Math.max(Theme.staggerDelay * 4, Math.round(Theme.anim.moveDuration / 2))
        repeat: false
        onTriggered: _panelContent.runEnterAnimation()
    }

    ParallelAnimation {
        id: _panelSurfaceOpenAnim

        PropertyAnimation {
            target: root
            property: "_panelSurfaceOpacity"
            to: 1
            duration: Theme.anim.highlightDuration
            easing.type: Theme.anim.highlightType
        }

        PropertyAnimation {
            target: root
            property: "_panelSurfaceScale"
            to: 1
            duration: Theme.anim.springDuration
            easing.type: Theme.anim.springType
            easing.overshoot: Theme.anim.springOvershoot
        }
    }

    ParallelAnimation {
        id: _panelSurfaceCloseAnim

        PropertyAnimation {
            target: root
            property: "_panelSurfaceOpacity"
            to: 0
            duration: Theme.anim.highlightDuration
            easing.type: Theme.anim.highlightType
        }

        PropertyAnimation {
            target: root
            property: "_panelSurfaceScale"
            to: 0.985
            duration: Theme.anim.springDuration
            easing.type: Theme.anim.moveType
        }
    }


    function _clampSeekProgress(xPosition) {
        if (_pillBackground.width <= 0)
            return 0

        return Math.max(0, Math.min(1, xPosition / _pillBackground.width))
    }

    function _snapshotContent() {
        return {
            title: root._displayTitle,
            artist: root._displayArtist,
            artUrl: MediaControlService.artUrl,
            mode: root._useLyricsAsPrimaryText ? "lyrics" : "media",
            mediaSignature: root._mediaIdentitySignature,
            textSignature: root._useLyricsAsPrimaryText ? root._lyricDisplaySignature : root._displayTextSignature
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
        const currentContent = carryIncomingLayer ? root._incomingContent : root._currentContent
        const textChanged = !root._contentInitialized || nextContent.textSignature !== (currentContent.textSignature || "")
        const lyricOnlyUpdate = root._contentInitialized
            && nextContent.mode === "lyrics"
            && currentContent.mode === "lyrics"
            && nextContent.mediaSignature === currentContent.mediaSignature
            && textChanged

        if (!root._contentInitialized) {
            root._currentContent = nextContent
            root._outgoingContent = nextContent
            root._incomingContent = nextContent
            root._contentSwapProgress = 1
            root._outgoingContentStartOpacity = 1
            root._outgoingContentStartY = 0
            root._contentTextOnlySwap = false
            root._contentInitialized = true

            if (root._debugLyricDisplay) {
                console.log("[DymicShell:MediaWidgetSwap:init]", JSON.stringify({
                    contentSignature: root._contentSignature,
                    lyricDisplaySignature: root._lyricDisplaySignature,
                    displayTitle: root._displayTitle,
                    useLyricsAsPrimaryText: root._useLyricsAsPrimaryText
                }))
            }

            return
        }

        if (!textChanged) {
            if (root._debugLyricDisplay) {
                console.log("[DymicShell:MediaWidgetSwap:skip]", JSON.stringify({
                    reason: "text-unchanged",
                    contentSignature: root._contentSignature,
                    currentTextSignature: currentContent.textSignature || "",
                    nextTextSignature: nextContent.textSignature || "",
                    lyricDisplaySignature: root._lyricDisplaySignature
                }))
            }

            _contentSwapAnim.stop()
            root._currentContent = nextContent
            root._outgoingContent = nextContent
            root._incomingContent = nextContent
            root._contentSwapProgress = 1
            root._outgoingContentStartOpacity = 1
            root._outgoingContentStartY = 0
            root._contentTextOnlySwap = false
            root._contentSwapActive = false
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
        root._contentTextOnlySwap = lyricOnlyUpdate
        root._contentSwapActive = true

        if (root._debugLyricDisplay) {
            console.log("[DymicShell:MediaWidgetSwap:start]", JSON.stringify({
                contentSignature: root._contentSignature,
                currentTextSignature: currentContent.textSignature || "",
                nextTextSignature: nextContent.textSignature || "",
                lyricDisplaySignature: root._lyricDisplaySignature,
                displayTitle: root._displayTitle,
                displayArtist: root._displayArtist,
                textChanged: textChanged,
                lyricOnlyUpdate: lyricOnlyUpdate,
                carryIncomingLayer: carryIncomingLayer
            }))
        }

        _contentSwapAnim.start()
    }

    on_ContentSignatureChanged: root._startContentSwap()

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
        onFinished: {
            // root._contentSwapActive = false
            // root._contentTextOnlySwap = false
        }
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
            root._flashRenderVisible ? _flashStageClip.implicitWidth : 0
        )
        implicitHeight: root._flashRenderVisible
            ? (root._pillH + root._flashGap + root._flashRowH)
            : root._pillH
        scale: root._pulseScale
        transformOrigin: Item.Center
        clip: false

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

        // Throw layer keeps the exported widget geometry stable while the visible
        // media surface and attached shell move together.
        Item {
            id: _pillThrowLayer
            x: 0
            y: root._panelThrowOffsetY
            width: parent.width
            height: parent.height

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
                color: Qt.rgba(
                    Colors.background.r,
                    Colors.background.g,
                    Colors.background.b,
                    Math.max(0, 1 - root._panelShellBlend)
                )
                border.color: Colors.border
                border.width: root._panelShellBlend > 0.05 ? 0 : 1

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
                visible: root._useMaskedProgress
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
                visible: root._useMaskedProgress
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
                visible: root._useMaskedProgress && Theme.graphicalEffectsEnabled
                source: _sharedProgressSource
                maskSource: _sharedProgressMask
            }

            // Shared progress fallback.
            MediaParts.MediaProgressStrip {
                z: 1
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: root._flashProgressInset
                anchors.rightMargin: root._flashProgressInset
                y: root._sharedProgressY
                visible: !root._useMaskedProgress || !Theme.graphicalEffectsEnabled
                progress: root._displayProgress
                expanded: root.flashVisible
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
                opacity: Theme.barWidget.mediaSurfaceOverlayOpacity * (1 - root._panelShellBlend)
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
                visible: !Theme.powerSaveEnabled
                bars: MediaControlService.visualizerHealthy ? MediaControlService.visualizerBars : []
                barOpacity: Theme.barWidget.mediaVisualizerBarOpacity * 1.1 * (1 - root._panelShellBlend * 0.75)
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
                hovered: !root._panelShellBlend && _mainArea.containsMouse
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
                    textOnlySwap: root._contentSwapActive && root._contentTextOnlySwap
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
                    textOverflowMode: root._compactTextOverflowMode
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
                    _mainRipple.triggerRipple(mouse.x, mouse.y)
                    MediaControlService.togglePanel()
                }
            }
        }
        }

    }

    BarPanels.AttachedExpansionShell {
        id: _panelShellHost

        anchorItem: _pillClip
        active: root._panelState !== "closed"
        collapseTailHidden: root._panelCollapseTailHidden
        visibleWidth: root._panelVisibleWidth
        shellHeight: root._panelShellHeight
        shellY: root._panelShellY
        surfaceOpacity: root._panelSurfaceOpacity
        surfaceScale: root._panelSurfaceScale
        throwOffsetY: root._panelThrowOffsetY
        pillWidth: root._panelPillWidth
        pillHeight: root._panelPillHeight
        panelY: _panelHost.y
        attachmentOverlap: root._panelAttachmentOverlap
        shellRadius: root._panelShellRadius
        bridgeOutset: root._panelBridgeOutset
        inwardCornerRadius: root._panelInwardCornerRadius
        pulseOpacity: 0
        surfaceFillOpacity: 1
    }

    BarPanels.AttachedExpansionPanelHost {
        id: _panelHost

        anchorItem: _pillClip
        active: root._panelState !== "closed"
        collapseTailHidden: root._panelCollapseTailHidden
        expanded: root._panelState !== "closed"
        visibleWidth: root._panelVisibleWidth
        visibleHeight: root._panelVisibleHeight
        detachedY: root._panelDetachedY
        attachmentOverlap: root._panelAttachmentOverlap
        revealLift: root._panelRevealLift
        revealYOffset: root._panelRevealYOffset
        surfaceOpacity: root._panelSurfaceOpacity
        surfaceScale: root._panelSurfaceScale
        throwOffsetY: root._panelThrowOffsetY
        contentOpacity: root._panelContentOpacity

        // Inset the media body so the attached shell keeps readable chrome.
        MediaParts.MediaPanelContent {
            id: _panelContent
            anchors.fill: parent
            anchors.margins: ThemeCards.panelPadding
            embedded: true
        }
    }
}
