.pragma library

.import "IslandWindowHintClone.js" as CloneUtils
.import "IslandWindowHintStage.js" as StageUtils
.import "IslandWindowHintMotion.js" as MotionUtils

// Facade over split window-hint helpers.

function _cloneApi() {
    return {
        lerp: CloneUtils.lerp,
        mixColor: CloneUtils.mixColor,
        workspaceLabel: CloneUtils.workspaceLabel,
        cloneHint: CloneUtils.cloneHint,
        cloneWorkspaceCapsule: CloneUtils.cloneWorkspaceCapsule,
        cloneTitleCapsule: CloneUtils.cloneTitleCapsule,
        emptyStageSlots: CloneUtils.emptyStageSlots,
        slotsForEntries: CloneUtils.slotsForEntries
    }
}

function _stageApi(workspaceLabelFn) {
    return {
        workspaceAnchorForHint: StageUtils.workspaceAnchorForHint,
        titleAnchorForHint: StageUtils.titleAnchorForHint,
        workspaceCapsuleForAbsolute: function(absoluteIndex, hint, transitionAnchor) {
            return StageUtils.workspaceCapsuleForAbsolute(absoluteIndex, hint, workspaceLabelFn, transitionAnchor)
        },
        titleCapsuleForAbsolute: StageUtils.titleCapsuleForAbsolute,
        workspaceStageCapsulesForHint: StageUtils.workspaceStageCapsulesForHint,
        titleStageCapsulesForHint: StageUtils.titleStageCapsulesForHint,
        workspaceStageCapsuleAt: StageUtils.workspaceStageCapsuleAt,
        workspaceStageAbsoluteIndexAt: StageUtils.workspaceStageAbsoluteIndexAt,
        titleStageCapsuleAt: StageUtils.titleStageCapsuleAt,
        workspaceStageSlotPositionAt: StageUtils.workspaceStageSlotPositionAt,
        titleStageSlotPositionAt: StageUtils.titleStageSlotPositionAt
    }
}

function lerp(from, to, progress) {
    return CloneUtils.lerp(from, to, progress)
}

function mixColor(from, to, progress) {
    return CloneUtils.mixColor(from, to, progress)
}

function workspaceLabel(index) {
    return CloneUtils.workspaceLabel(index)
}

function cloneHint(hint) {
    return CloneUtils.cloneHint(hint)
}

function emptyStageSlots(host, prefix) {
    return CloneUtils.emptyStageSlots(host._persistentStageSlotIndices, prefix)
}

function workspaceStageCapsuleAt(host, slotIndex) {
    return StageUtils.workspaceStageCapsuleAt(host, slotIndex)
}

function workspaceStageAbsoluteIndexAt(host, slotIndex) {
    return StageUtils.workspaceStageAbsoluteIndexAt(host, slotIndex)
}

function titleStageCapsuleAt(host, slotIndex) {
    return StageUtils.titleStageCapsuleAt(host, slotIndex)
}

function workspaceStageSlotPositionAt(host, slotIndex) {
    return StageUtils.workspaceStageSlotPositionAt(host, slotIndex)
}

function workspaceStageLayoutForHint(hint) {
    return StageUtils.workspaceStageLayoutForHint(hint)
}

function visibleWorkspaceCountForHint(hint) {
    return StageUtils.visibleWorkspaceCountForHint(hint)
}

function visibleWorkspaceAbsoluteBoundsForHint(hint) {
    return StageUtils.visibleWorkspaceAbsoluteBoundsForHint(hint)
}

function visibleWorkspaceStageSlotCount(host) {
    return StageUtils.visibleWorkspaceStageSlotCount(host)
}

function visibleWorkspaceStageSlotBounds(host) {
    return StageUtils.visibleWorkspaceStageSlotBounds(host)
}

function titleStageSlotPositionAt(host, slotIndex) {
    return StageUtils.titleStageSlotPositionAt(host, slotIndex)
}

function refreshStageSlots(host, hint, includeCurrentAnchor, preserveUnassigned) {
    var cloneApi = _cloneApi()
    var stageApi = _stageApi(cloneApi.workspaceLabel)
    MotionUtils.refreshStageSlots(host, hint, includeCurrentAnchor, preserveUnassigned, stageApi, cloneApi)
}

function settleWorkspaceStageSlots(host, hint) {
    var cloneApi = _cloneApi()
    var stageApi = _stageApi(cloneApi.workspaceLabel)
    MotionUtils.settleWorkspaceStageSlots(host, hint, stageApi, cloneApi)
}

function retireWorkspaceStageSlots(host, hint) {
    var cloneApi = _cloneApi()
    var stageApi = _stageApi(cloneApi.workspaceLabel)
    return MotionUtils.retireWorkspaceStageSlots(host, hint, stageApi, cloneApi)
}

function cleanupWorkspaceStageSlots(host, hint) {
    var cloneApi = _cloneApi()
    var stageApi = _stageApi(cloneApi.workspaceLabel)
    MotionUtils.cleanupWorkspaceStageSlots(host, hint, stageApi, cloneApi)
}

function settleTitleStageSlots(host, hint) {
    var cloneApi = _cloneApi()
    var stageApi = _stageApi(cloneApi.workspaceLabel)
    MotionUtils.settleTitleStageSlots(host, hint, stageApi, cloneApi)
}

function retargetHintAnchors(host, hint, immediate, workspaceAnimation, titleAnimation) {
    var cloneApi = _cloneApi()
    var stageApi = _stageApi(cloneApi.workspaceLabel)
    MotionUtils.retargetHintAnchors(host, hint, immediate, workspaceAnimation, titleAnimation, stageApi)
}

function visibleWorkspaceIcons(capsule) {
    var icons = capsule && capsule.icons ? capsule.icons : []
    return icons
}

function focusedWorkspaceIconIndex(capsule) {
    var icons = capsule && capsule.icons ? capsule.icons : []

    for (var index = 0; index < icons.length; index++) {
        if (icons[index] && icons[index].isFocused)
            return index
    }

    return -1
}

function workspaceMetrics(host, slotPosition, absoluteIndex) {
    return MotionUtils.workspaceMetrics(host, slotPosition, absoluteIndex, CloneUtils.lerp)
}

function workspaceBottomInset(host) {
    return MotionUtils.workspaceBottomInset(host, CloneUtils.lerp)
}

function titleMetrics(host, slotPosition) {
    return MotionUtils.titleMetrics(host, slotPosition, CloneUtils.lerp)
}

function handleHintChange(host, liveHint, workspaceAnimation, titleAnimation) {
    var cloneApi = _cloneApi()
    var stageApi = _stageApi(cloneApi.workspaceLabel)
    MotionUtils.handleHintChange(host, liveHint, workspaceAnimation, titleAnimation, cloneApi, stageApi, MotionUtils)
}
