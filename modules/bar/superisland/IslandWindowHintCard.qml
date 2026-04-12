import Quickshell
import QtQuick
import qs.config
import qs.services
import "." as IslandParts
import "./IslandWindowHintCardLogic.js" as HintLogic

// Renders the SuperIsland window hint with slot-driven workspace and title motion.
Item {
    id: root

    required property var event

    readonly property bool _hostKeepsHintVisible: !!(root.event && root.event.type === "window-hint")
    readonly property var _liveHint: WindowHintService.activeHint
    property var _renderHint: null
    readonly property var _hint: root._renderHint || root._liveHint
    readonly property int _padH: Theme.barWidget.contentPaddingH
    readonly property int _padV: Theme.barWidget.contentPaddingV
    readonly property int _rowGap: Math.max(10, Math.round(12 * Theme.uiScale))
    readonly property int _capsuleGap: Math.max(4, Math.round(5 * Theme.uiScale))
    readonly property int _workspaceColumnGap: Math.max(10, Math.round(12 * Theme.uiScale))
    readonly property int _stagePadH: Math.max(14, Math.round(18 * Theme.uiScale))
    readonly property int _stagePadV: Math.max(14, Math.round(18 * Theme.uiScale))
    readonly property int _compactIcon: Math.max(10, Theme.barWidget.compactIconSize - 1)
    readonly property int _primaryIcon: Theme.barWidget.primaryIconSize
    readonly property int _workspaceSideWidth: Math.round(164 * Theme.uiScale)
    readonly property int _workspacePrimaryWidth: Math.round(300 * Theme.uiScale)
    readonly property int _titleSideWidth: Math.round(132 * Theme.uiScale)
    readonly property int _titlePrimaryWidth: Math.round(292 * Theme.uiScale)
    readonly property int _workspaceSideHeight: Math.max(24, Theme.barWidget.pillHeight + Theme.barWidget.contentPaddingV)
    readonly property int _workspacePrimaryHeight: Math.max(54, Theme.barWidget.pillHeight + Theme.barWidget.contentPaddingV * 7)
    readonly property int _titleCapsuleHeight: Math.max(30, Theme.fontSizeBody + Theme.barWidget.badgePaddingV * 6)
    readonly property int _minPreviewWidth: Math.round(320 * Theme.uiScale)
    readonly property int _maxPreviewWidth: Math.round(560 * Theme.uiScale)
    readonly property color _stageFill: Qt.rgba(1, 1, 1, 0.02)
    readonly property color _stageBorder: Qt.rgba(1, 1, 1, 0.035)
    readonly property color _primaryCapsuleFill: Qt.rgba(1, 1, 1, 0.09)
    readonly property color _secondaryCapsuleFill: Qt.rgba(1, 1, 1, 0.04)
    readonly property color _primaryCapsuleBorder: Qt.rgba(1, 1, 1, 0.08)
    readonly property color _secondaryCapsuleBorder: Qt.rgba(1, 1, 1, 0.03)
    readonly property var _slotIndices: [-1, 0, 1]
    readonly property real _overflowSlotPosition: 1.18
    readonly property int _workspaceStageWidth: root._workspacePrimaryWidth
    readonly property int _workspaceStageHeight: root._workspaceSideHeight * 2 + root._workspacePrimaryHeight + root._workspaceColumnGap * 2
    readonly property var _workspaceStageLayout: HintLogic.workspaceStageLayoutForHint(root._hint)
    readonly property bool _workspaceMotionActive:
        root._workspaceSettlePending
        || Math.abs(root._animatedWorkspaceAnchor - root._workspaceAnchorTarget) > 0.001
    readonly property real _workspaceLeadingTrimTarget:
        (root._workspaceMotionActive || root._workspaceStageLayout.hasBefore)
            ? 0
            : root._workspaceSideHeight + root._workspaceColumnGap
    readonly property real _workspaceTrailingTrimTarget:
        (root._workspaceMotionActive || root._workspaceStageLayout.hasAfter)
            ? 0
            : root._workspaceSideHeight + root._workspaceColumnGap
    readonly property real _workspaceVisibleStageHeight: root._workspaceStageHeight - root._workspaceLeadingTrim - root._workspaceTrailingTrim
    readonly property int _titleStageWidth: root._titleSideWidth * 2 + root._titlePrimaryWidth + root._capsuleGap * 2
    readonly property int _titleStageHeight: root._titleCapsuleHeight
    readonly property var _persistentStageSlotIndices: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
    readonly property int _workspaceAnchorBaseDuration: Math.max(150, Math.round(Theme.anim.moveDuration * 1.05))
    readonly property int _titleAnchorBaseDuration: Math.max(140, Theme.anim.moveDuration)
    readonly property int _anchorDurationStep: Math.max(16, Math.round(Theme.anim.moveDuration * 0.1))
    readonly property int _anchorMaximumDuration: Math.max(190, Math.round(Theme.anim.moveDuration * 1.35))
    readonly property int _workspaceFocusLeadDuration: Math.max(70, Math.round(Theme.anim.moveDuration * 0.42))
    readonly property int _workspaceFocusTrailDuration: Math.max(240, Math.round(Theme.anim.moveDuration * 1.45))

    property real _animatedWorkspaceAnchor: -1
    property real _animatedTitleAnchor: -1
    property real _workspaceAnchorTarget: -1
    property real _titleAnchorTarget: -1
    property int _workspaceAnchorDuration: root._workspaceAnchorBaseDuration
    property int _titleAnchorDuration: root._titleAnchorBaseDuration
    property bool _workspaceAnchorAnimationEnabled: true
    property bool _titleAnchorAnimationEnabled: true
    property real _workspaceLeadingTrim: 0
    property real _workspaceTrailingTrim: 0
    property bool _workspaceTrimAnimationEnabled: true
    property bool _workspaceSettlePending: false
    property bool _titleSettlePending: false
    // Inspired by end-4/dots-hyprland ("illogical impulse") workspace indicator motion.
    // Reference: https://github.com/end-4/dots-hyprland/blob/main/dots/.config/quickshell/ii/modules/ii/bar/Workspaces.qml
    property int _workspaceFocusIndex: -1
    property var _workspaceStageSlots: root._emptyStageSlots("workspace-slot")
    property var _titleStageSlots: root._emptyStageSlots("title-slot")

    implicitWidth: Math.min(
        root._maxPreviewWidth,
        Math.max(
            root._minPreviewWidth,
            Math.max(root._workspaceStageWidth, root._titleStageWidth) + root._padH * 2 + root._stagePadH * 2
        )
    )
    implicitHeight: root._workspaceVisibleStageHeight + root._rowGap + root._titleStageHeight + root._padV * 2 + root._stagePadV * 2

    function _lerp(from, to, progress) {
        return HintLogic.lerp(from, to, progress)
    }

    function _mixColor(from, to, progress) {
        return HintLogic.mixColor(from, to, progress)
    }

    function _workspaceLabel(index) {
        return HintLogic.workspaceLabel(index)
    }

    function _cloneHint(hint) {
        return HintLogic.cloneHint(hint)
    }

    function _emptyStageSlots(prefix) {
        return HintLogic.emptyStageSlots(root, prefix)
    }

    function _workspaceStageCapsuleAt(slotIndex) {
        return HintLogic.workspaceStageCapsuleAt(root, slotIndex)
    }

    function _titleStageCapsuleAt(slotIndex) {
        return HintLogic.titleStageCapsuleAt(root, slotIndex)
    }

    function _workspaceStageSlotPositionAt(slotIndex) {
        return HintLogic.workspaceStageSlotPositionAt(root, slotIndex)
    }

    function _titleStageSlotPositionAt(slotIndex) {
        return HintLogic.titleStageSlotPositionAt(root, slotIndex)
    }

    function _refreshStageSlots(hint, includeCurrentAnchor, preserveUnassigned) {
        HintLogic.refreshStageSlots(root, hint, includeCurrentAnchor, preserveUnassigned)
    }

    function _settleWorkspaceStageSlots(hint) {
        HintLogic.settleWorkspaceStageSlots(root, hint)
    }

    function _settleTitleStageSlots(hint) {
        HintLogic.settleTitleStageSlots(root, hint)
    }

    function _retargetHintAnchors(hint, immediate) {
        HintLogic.retargetHintAnchors(root, hint, immediate, _workspaceAnchorSettleTimer, _titleAnchorSettleTimer)
    }

    function _visibleWorkspaceIcons(capsule) {
        return HintLogic.visibleWorkspaceIcons(capsule)
    }

    function _focusedWorkspaceIconIndex(capsule) {
        return HintLogic.focusedWorkspaceIconIndex(capsule)
    }

    function _workspaceMetrics(slotPosition) {
        return HintLogic.workspaceMetrics(root, slotPosition)
    }

    function _titleMetrics(slotPosition) {
        return HintLogic.titleMetrics(root, slotPosition)
    }

    function _handleHintChange() {
        const wasVisible = !!(root._hint && root._hint.visible)
        HintLogic.handleHintChange(root, root._liveHint, _workspaceAnchorSettleTimer, _titleAnchorSettleTimer)
        root._syncWorkspaceStageTrim(!wasVisible || !root._hint || !root._hint.visible)
    }

    function _syncWorkspaceStageTrim(immediate) {
        if (immediate) {
            root._workspaceTrimAnimationEnabled = false
            root._workspaceLeadingTrim = root._workspaceLeadingTrimTarget
            root._workspaceTrailingTrim = root._workspaceTrailingTrimTarget
            root._workspaceTrimAnimationEnabled = true
            return
        }

        root._workspaceLeadingTrim = root._workspaceLeadingTrimTarget
        root._workspaceTrailingTrim = root._workspaceTrailingTrimTarget
    }

    Timer {
        id: _workspaceAnchorSettleTimer

        repeat: false

        onTriggered: {
            if (!root._workspaceSettlePending)
                return

            if (Math.abs(root._animatedWorkspaceAnchor - root._workspaceAnchorTarget) > 0.001) {
                interval = 16
                restart()
                return
            }

            root._workspaceSettlePending = false
            root._settleWorkspaceStageSlots(root._hint)
            root._syncWorkspaceStageTrim(true)
        }
    }

    Timer {
        id: _titleAnchorSettleTimer

        repeat: false

        onTriggered: {
            if (!root._titleSettlePending)
                return

            if (Math.abs(root._animatedTitleAnchor - root._titleAnchorTarget) > 0.001) {
                interval = 16
                restart()
                return
            }

            root._titleSettlePending = false
            root._settleTitleStageSlots(root._hint)
        }
    }

    Connections {
        target: WindowHintService

        function onActiveHintChanged() {
            root._handleHintChange()
        }
    }

    Behavior on _animatedWorkspaceAnchor {
        enabled: root._workspaceAnchorAnimationEnabled

        NumberAnimation {
            id: _workspaceAnchorAnimation

            duration: root._workspaceAnchorDuration
            easing.type: Easing.OutSine
        }
    }

    Behavior on _workspaceLeadingTrim {
        enabled: root._workspaceTrimAnimationEnabled

        NumberAnimation {
            duration: root._workspaceAnchorDuration
            easing.type: Theme.anim.moveType
        }
    }

    Behavior on _workspaceTrailingTrim {
        enabled: root._workspaceTrimAnimationEnabled

        NumberAnimation {
            duration: root._workspaceAnchorDuration
            easing.type: Theme.anim.moveType
        }
    }

    Behavior on _animatedTitleAnchor {
        enabled: root._titleAnchorAnimationEnabled

        NumberAnimation {
            id: _titleAnchorAnimation

            duration: root._titleAnchorDuration
            easing.type: Easing.OutSine
        }
    }

    QtObject {
        id: _workspaceFocusIndexPair

        property int index: root._workspaceFocusIndex
        property real idx1: index
        property real idx2: index
        property int idx1Duration: root._workspaceFocusLeadDuration
        property int idx2Duration: root._workspaceFocusTrailDuration

        Behavior on idx1 {
            NumberAnimation {
                duration: _workspaceFocusIndexPair.idx1Duration
                easing.type: Easing.OutSine
            }
        }

        Behavior on idx2 {
            NumberAnimation {
                duration: _workspaceFocusIndexPair.idx2Duration
                easing.type: Easing.OutSine
            }
        }
    }

    Component.onCompleted: {
        root._renderHint = root._cloneHint(root._liveHint)
        root._refreshStageSlots(root._renderHint, false, false)
        root._retargetHintAnchors(root._renderHint, true)
        root._syncWorkspaceStageTrim(true)
    }

    Item {
        anchors.fill: parent

        Item {
            id: _contentArea

            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                bottom: parent.bottom
            }

            // Main capsule stack.
            Column {
                anchors.centerIn: parent
                width: Math.max(root._workspaceStageWidth, root._titleStageWidth)
                spacing: root._rowGap

                Item {
                    width: parent.width
                    height: root._workspaceVisibleStageHeight

                    Item {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: root._workspaceStageWidth
                        height: root._workspaceStageHeight
                        y: -root._workspaceLeadingTrim
                        clip: true

                        Repeater {
                            model: root._persistentStageSlotIndices

                            delegate: IslandParts.IslandWorkspaceStageCapsule {
                                required property int modelData

                                host: root
                                focusIndexPair: _workspaceFocusIndexPair
                                capsule: root._workspaceStageCapsuleAt(modelData)
                                slotPosition: root._workspaceStageSlotPositionAt(modelData)
                                hiddenForMotion: false
                            }
                        }
                    }
                }

                Item {
                    width: parent.width
                    height: root._titleStageHeight

                    Item {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: root._titleStageWidth
                        height: parent.height
                        clip: true

                        Repeater {
                            model: root._persistentStageSlotIndices

                            delegate: IslandParts.IslandTitleStageCapsule {
                                required property int modelData

                                host: root
                                capsule: root._titleStageCapsuleAt(modelData)
                                slotPosition: root._titleStageSlotPositionAt(modelData)
                                hiddenForMotion: false
                            }
                        }
                    }
                }
            }
        }
    }
}
