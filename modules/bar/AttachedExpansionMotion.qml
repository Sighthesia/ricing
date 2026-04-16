import QtQuick
import qs.config

// Shared throw/catch motion contract for attached expansion surfaces.
Item {
    id: root

    required property QtObject motionTarget
    required property string throwOffsetProperty
    required property string revealWidthProperty
    required property string revealHeightProperty
    property bool useSurfaceOpacity: true
    property bool useSurfaceScale: true
    required property string contentOpacityProperty
    required property real throwLift
    required property real throwDrop
    required property real throwCatchLift
    required property real revealWidthTarget
    required property real revealHeightTarget
    required property real collapseWidthTarget
    required property real collapseHeightTarget
    property real targetWidth: NaN
    property real targetHeight: NaN
    required property real revealContentOpacityTarget
    required property real collapseContentOpacityTarget
    required property int throwLeadDuration
    required property int throwDropDuration

    visible: false
    width: 0
    height: 0

    property alias throwOutAnim: _throwOutAnim
    property alias catchAnim: _catchAnim
    property alias revealAnim: _revealAnim
    property alias collapseAnim: _collapseAnim

    signal throwOutFinished()
    signal throwOutStopped()
    signal catchFinished()
    signal catchStopped()
    signal revealFinished()
    signal collapseFinished()

    function resetThrowOffset() {
        if (root.motionTarget)
            root.motionTarget[root.throwOffsetProperty] = 0
    }

    function resolvedCollapseWidthTarget() {
        return Number.isFinite(root.targetWidth) ? root.targetWidth : root.collapseWidthTarget
    }

    function resolvedCollapseHeightTarget() {
        return Number.isFinite(root.targetHeight) ? root.targetHeight : root.collapseHeightTarget
    }

    function resetCollapseTargets() {
        root.targetWidth = NaN
        root.targetHeight = NaN
    }

    SequentialAnimation {
        id: _throwOutAnim

        NumberAnimation {
            target: root.motionTarget
            property: root.throwOffsetProperty
            to: -root.throwLift
            duration: root.throwLeadDuration
            easing.type: Theme.anim.highlightType
        }

        NumberAnimation {
            target: root.motionTarget
            property: root.throwOffsetProperty
            to: root.throwDrop
            duration: root.throwDropDuration
            easing.type: Theme.anim.moveType
        }

        NumberAnimation {
            target: root.motionTarget
            property: root.throwOffsetProperty
            to: 0
            duration: Theme.anim.moveDuration
            easing.type: Theme.anim.moveType
        }

        onStopped: {
            root.resetThrowOffset()
            root.throwOutStopped()
        }

        onFinished: {
            root.resetThrowOffset()
            root.throwOutFinished()
        }
    }

    SequentialAnimation {
        id: _catchAnim

        NumberAnimation {
            target: root.motionTarget
            property: root.throwOffsetProperty
            to: -root.throwCatchLift
            duration: Math.max(1, Math.round(Theme.anim.highlightDuration * 0.55))
            easing.type: Theme.anim.highlightType
        }

        NumberAnimation {
            target: root.motionTarget
            property: root.throwOffsetProperty
            to: 0
            duration: Theme.anim.moveDuration
            easing.type: Theme.anim.moveType
        }

        onStopped: {
            root.resetThrowOffset()
            root.catchStopped()
        }

        onFinished: {
            root.resetThrowOffset()
            root.catchFinished()
        }
    }

    ParallelAnimation {
        id: _revealAnim

        NumberAnimation {
            target: root.motionTarget
            property: root.revealWidthProperty
            to: root.revealWidthTarget
            duration: Theme.anim.moveDuration
            easing.type: Theme.anim.moveType
        }

        NumberAnimation {
            target: root.motionTarget
            property: root.revealHeightProperty
            to: root.revealHeightTarget
            duration: Theme.anim.moveDuration
            easing.type: Theme.anim.moveType
        }

        NumberAnimation {
            target: root.motionTarget
            property: root.contentOpacityProperty
            to: root.revealContentOpacityTarget
            duration: Theme.anim.highlightDuration
            easing.type: Theme.anim.highlightType
        }

        onFinished: root.revealFinished()
    }

    ParallelAnimation {
        id: _collapseAnim

        NumberAnimation {
            target: root.motionTarget
            property: root.revealWidthProperty
            to: root.resolvedCollapseWidthTarget()
            duration: Theme.anim.moveDuration
            easing.type: Theme.anim.moveType
        }

        NumberAnimation {
            target: root.motionTarget
            property: root.revealHeightProperty
            to: root.resolvedCollapseHeightTarget()
            duration: Theme.anim.moveDuration
            easing.type: Theme.anim.moveType
        }

        NumberAnimation {
            target: root.motionTarget
            property: root.contentOpacityProperty
            to: root.collapseContentOpacityTarget
            duration: Math.max(1, Math.round(Theme.anim.highlightDuration * 0.72))
            easing.type: Theme.anim.highlightType
        }

        onStopped: root.resetCollapseTargets()
        onFinished: {
            root.resetCollapseTargets()
            root.collapseFinished()
        }
    }
}
