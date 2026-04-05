import QtQuick
import qs.config

// Reusable animation timeline for SuperIsland state-machine transitions.
Item {
    id: root

    required property Item host
    required property QtObject state
    required property var resetReplaceLayers
    required property var completeWindowHintExit

    visible: false
    width: 0
    height: 0

    property alias pillThrowOutAnim: _pillThrowOutAnim
    property alias pillCatchAnim: _pillCatchAnim
    property alias attachedRevealAnim: _attachedRevealAnim
    property alias attachedCollapseAnim: _attachedCollapseAnim
    property alias replaceAnim: _replaceAnim
    property alias departAnim: _departAnim
    property alias returnAnim: _returnAnim
    property alias hintEnterAnim: _hintEnterAnim
    property alias hintExitAnim: _hintExitAnim
    property alias sharedBackgroundPulseAnim: _sharedBackgroundPulseAnim
    property alias pulseScaleAnim: _pulseScaleAnim

    SequentialAnimation {
        id: _pillThrowOutAnim

        NumberAnimation {
            target: root.state
            property: "_pillThrowOffsetY"
            to: -root.host._pillThrowLift
            duration: root.host._pillThrowLeadDuration
            easing.type: Theme.anim.highlightType
        }

        NumberAnimation {
            target: root.state
            property: "_pillThrowOffsetY"
            to: root.host._pillThrowDrop
            duration: root.host._pillThrowDropDuration
            easing.type: Theme.anim.moveType
        }

        NumberAnimation {
            target: root.state
            property: "_pillThrowOffsetY"
            to: 0
            duration: Theme.anim.moveDuration
            easing.type: Theme.anim.moveType
        }

        onStopped: root.state._pillThrowOffsetY = 0
        onFinished: root.state._pillThrowOffsetY = 0
    }

    SequentialAnimation {
        id: _pillCatchAnim

        NumberAnimation {
            target: root.state
            property: "_pillThrowOffsetY"
            to: -Math.max(3, Math.round(root.host._pillThrowLift * 1.05))
            duration: Math.max(1, Math.round(Theme.anim.highlightDuration * 0.55))
            easing.type: Theme.anim.highlightType
        }

        NumberAnimation {
            target: root.state
            property: "_pillThrowOffsetY"
            to: 0
            duration: Theme.anim.moveDuration
            easing.type: Theme.anim.moveType
        }

        onStopped: root.state._pillThrowOffsetY = 0
        onFinished: root.state._pillThrowOffsetY = 0
    }

    ParallelAnimation {
        id: _attachedRevealAnim

        NumberAnimation {
            target: root.state
            property: "_attachedPanelRevealWidth"
            to: root.host._attachedPanelWidth
            duration: Theme.anim.moveDuration
            easing.type: Theme.anim.moveType
        }

        NumberAnimation {
            target: root.state
            property: "_attachedPanelRevealHeight"
            to: root.host._attachedPanelHeight
            duration: Theme.anim.moveDuration
            easing.type: Theme.anim.moveType
        }

        NumberAnimation {
            target: root.state
            property: "_attachedContentOpacity"
            to: 1
            duration: Theme.anim.highlightDuration
            easing.type: Theme.anim.highlightType
        }

        onFinished: {
            if (!root.host._attachedPanelActive)
                return

            root.state._attachedPanelRevealWidth = root.host._attachedPanelWidth
            root.state._attachedPanelRevealHeight = root.host._attachedPanelHeight
            root.state._attachedContentOpacity = 1
            root.state._attachedRevealUseHandoffCurve = false
            root.state._overlayHintHandoffActive = false
            root.state._overlayHandoffHintEvent = root.host._idleSnapshot()
        }
    }

    ParallelAnimation {
        id: _attachedCollapseAnim

        property real targetWidth: root.host._attachedRevealSeedWidth
        property real targetHeight: root.host._attachedRevealSeedHeight

        NumberAnimation {
            target: root.state
            property: "_attachedPanelRevealWidth"
            to: _attachedCollapseAnim.targetWidth
            duration: Theme.anim.moveDuration
            easing.type: Theme.anim.moveType
        }

        NumberAnimation {
            target: root.state
            property: "_attachedPanelRevealHeight"
            to: _attachedCollapseAnim.targetHeight
            duration: Theme.anim.moveDuration
            easing.type: Theme.anim.moveType
        }

        NumberAnimation {
            target: root.state
            property: "_attachedContentOpacity"
            to: root.state._overlaySessionActive ? 0 : 1
            duration: Theme.anim.highlightDuration
            easing.type: Theme.anim.highlightType
        }

        onFinished: {
            if (root.state._phase === "hint-exit" && !root.state._overlaySessionActive && typeof root.completeWindowHintExit === "function")
                root.completeWindowHintExit()
        }
    }

    ParallelAnimation {
        id: _replaceAnim

        SequentialAnimation {
            PauseAnimation {
                duration: root.host._replaceDelay
            }

            ParallelAnimation {
                NumberAnimation {
                    target: root.state
                    property: "_replaceIncomingY"
                    to: root.host._mainTrackCenterY
                    duration: Theme.anim.moveDuration
                    easing.type: Theme.anim.moveType
                }

                NumberAnimation {
                    target: root.state
                    property: "_replaceIncomingOpacity"
                    to: 1
                    duration: Theme.anim.moveDuration
                    easing.type: Theme.anim.moveType
                }
            }
        }

        NumberAnimation {
            target: root.state
            property: "_replaceOutgoingY"
            to: root.state._replaceOutgoingTargetY
            duration: Theme.anim.moveDuration
            easing.type: Theme.anim.moveType
        }

        NumberAnimation {
            target: root.state
            property: "_replaceOutgoingOpacity"
            to: 0
            duration: Theme.anim.moveDuration
            easing.type: Theme.anim.moveType
        }

        onFinished: {
            if (typeof root.resetReplaceLayers === "function")
                root.resetReplaceLayers()
            root.state._mainTrackY = root.host._mainTrackCenterY
            root.state._mainTrackOpacity = 1
        }
    }

    ParallelAnimation {
        id: _departAnim

        NumberAnimation {
            target: root.state
            property: "_mainTrackY"
            to: root.host._mainTrackCenterY
            duration: Theme.anim.moveDuration
            easing.type: Theme.anim.moveType
        }

        NumberAnimation {
            target: root.state
            property: "_mainTrackScale"
            to: 1
            duration: Theme.anim.moveDuration
            easing.type: Theme.anim.moveType
        }

        NumberAnimation {
            target: root.state
            property: "_mainTrackOpacity"
            to: 1
            duration: Theme.anim.moveDuration
            easing.type: Theme.anim.moveType
        }

        NumberAnimation {
            target: root.state
            property: "_flashTrackY"
            to: root.host._flashStripY
            duration: Theme.anim.moveDuration
            easing.type: Theme.anim.moveType
        }

        NumberAnimation {
            target: root.state
            property: "_flashTrackScale"
            to: root.host._flashScale
            duration: Theme.anim.moveDuration
            easing.type: Theme.anim.moveType
        }

        NumberAnimation {
            target: root.state
            property: "_flashTrackOpacity"
            to: 0.6
            duration: Theme.anim.moveDuration
            easing.type: Theme.anim.moveType
        }

        onFinished: {
            if (root.state._phase === "enter")
                root.state._phase = "hold"
        }
    }

    ParallelAnimation {
        id: _returnAnim

        NumberAnimation {
            target: root.state
            property: "_mainTrackY"
            to: root.host._mainTrackEnterY
            duration: Theme.anim.springDuration
            easing.type: Theme.anim.springType
            easing.overshoot: Theme.anim.springOvershoot
        }

        NumberAnimation {
            target: root.state
            property: "_mainTrackScale"
            to: 0.92
            duration: Theme.anim.springDuration
            easing.type: Theme.anim.springType
            easing.overshoot: Theme.anim.springOvershoot
        }

        NumberAnimation {
            target: root.state
            property: "_mainTrackOpacity"
            to: 0
            duration: Theme.anim.moveDuration
            easing.type: Theme.anim.moveType
        }

        NumberAnimation {
            target: root.state
            property: "_flashTrackY"
            to: root.host._returnTrackCenterY
            duration: Theme.anim.springDuration
            easing.type: Theme.anim.springType
            easing.overshoot: Theme.anim.springOvershoot
        }

        NumberAnimation {
            target: root.state
            property: "_flashTrackScale"
            to: 1
            duration: Theme.anim.springDuration
            easing.type: Theme.anim.springType
            easing.overshoot: Theme.anim.springOvershoot
        }

        NumberAnimation {
            target: root.state
            property: "_flashTrackOpacity"
            to: 1
            duration: Theme.anim.moveDuration
            easing.type: Theme.anim.moveType
        }

        onFinished: {
            const returningEvent = root.host._displayEvent(root.state._flashSourceEvent)
            const returningFromWindowHint = returningEvent.type === "window"
            const handoffY = root.state._flashTrackY
            const handoffScale = root.state._flashTrackScale
            const handoffOpacity = root.state._flashTrackOpacity

            root.state._mainDisplayEvent = returningFromWindowHint
                ? root.host._baselineEvent
                : (returningEvent.type !== "idle" ? returningEvent : root.host._baselineEvent)
            root.state._mainTrackY = returningFromWindowHint ? root.host._mainTrackCenterY : handoffY
            root.state._mainTrackScale = returningFromWindowHint ? 1 : handoffScale
            root.state._mainTrackOpacity = returningFromWindowHint ? 1 : handoffOpacity
            root.state._phase = "idle"
            root.state._flashSourceEvent = root.host._idleSnapshot()
            root.state._flashTrackY = root.host._flashStripY
            root.state._flashTrackScale = root.host._flashScale
            root.state._flashTrackOpacity = 0
        }
    }

    ParallelAnimation {
        id: _hintEnterAnim

        NumberAnimation {
            target: root.state
            property: "_mainTrackY"
            to: root.host._isFullHintEventType(root.state._flashSourceEvent.type)
                ? root.host._mainTrackCenterY
                : root.host._windowHintEntryMeta.mainRole.targetY
            duration: Theme.anim.moveDuration
            easing.type: Theme.anim.moveType
        }

        NumberAnimation {
            target: root.state
            property: "_mainTrackScale"
            to: root.host._isFullHintEventType(root.state._flashSourceEvent.type) ? 1 : root.host._flashScale
            duration: Theme.anim.moveDuration
            easing.type: Theme.anim.moveType
        }

        NumberAnimation {
            target: root.state
            property: "_mainTrackOpacity"
            to: root.host._isFullHintEventType(root.state._flashSourceEvent.type) ? 1 : 0.6
            duration: Theme.anim.moveDuration
            easing.type: Theme.anim.moveType
        }

        NumberAnimation {
            target: root.state
            property: "_flashTrackY"
            to: root.host._windowHintEntryMeta.flashRole.targetY
            duration: Theme.anim.moveDuration
            easing.type: Theme.anim.moveType
        }

        NumberAnimation {
            target: root.state
            property: "_flashTrackScale"
            to: 1
            duration: Theme.anim.moveDuration
            easing.type: Theme.anim.moveType
        }

        NumberAnimation {
            target: root.state
            property: "_flashTrackOpacity"
            to: 1
            duration: Theme.anim.moveDuration
            easing.type: Theme.anim.moveType
        }
    }

    ParallelAnimation {
        id: _hintExitAnim

        NumberAnimation {
            target: root.state
            property: "_mainTrackY"
            to: root.host._mainTrackCenterY
            duration: Theme.anim.highlightDuration
            easing.type: Theme.anim.moveType
        }

        NumberAnimation {
            target: root.state
            property: "_flashTrackY"
            to: root.host._hintTrackY - Theme.barWidget.contentPaddingV * 3
            duration: Theme.anim.highlightDuration
            easing.type: Theme.anim.moveType
        }

        NumberAnimation {
            target: root.state
            property: "_flashTrackScale"
            to: 0.96
            duration: Theme.anim.highlightDuration
            easing.type: Theme.anim.moveType
        }

        NumberAnimation {
            target: root.state
            property: "_flashTrackOpacity"
            to: 0
            duration: Theme.anim.highlightDuration
            easing.type: Theme.anim.moveType
        }

        onFinished: {
            if (root.host._isFullHintEventType(root.state._flashSourceEvent.type))
                return

            if (typeof root.completeWindowHintExit === "function")
                root.completeWindowHintExit()
        }
    }

    SequentialAnimation {
        id: _sharedBackgroundPulseAnim

        NumberAnimation {
            target: root.state
            property: "_sharedBackgroundPulseOpacity"
            from: 0
            to: 0.16
            duration: Theme.anim.highlightDuration
            easing.type: Theme.anim.highlightType
        }

        NumberAnimation {
            target: root.state
            property: "_sharedBackgroundPulseOpacity"
            to: 0
            duration: Theme.anim.moveDuration
            easing.type: Theme.anim.moveType
        }

        onFinished: {
            if (!_pulseScaleAnim.running)
                root.state._pulseOwner = ""
        }
    }

    SequentialAnimation {
        id: _pulseScaleAnim

        NumberAnimation {
            target: root.state
            property: "_pulseScale"
            from: 1
            to: 1.018
            duration: Theme.anim.pulseSpringDuration
            easing.type: Theme.anim.pulseSpringType
            easing.overshoot: Theme.anim.pulseSpringOvershoot
        }

        NumberAnimation {
            target: root.state
            property: "_pulseScale"
            to: 1
            duration: Theme.anim.moveDuration
            easing.type: Theme.anim.moveType
        }

        onFinished: {
            if (!_sharedBackgroundPulseAnim.running)
                root.state._pulseOwner = ""
        }
    }
}
