import QtQuick
import "../../services" as Services
import "../../services/CapsuleMetrics.js" as CapsuleMetrics
import "." as WorkspaceHint
import "WorkspaceHintStage.js" as Stage
import "WorkspaceHintMotion.js" as Motion

// Self-contained workspace-hint stage: owns the slot stage, the staggered
// reveal progress, the anchor tween, and every `_workspace*` metric the
// capsules read through their `host`. Both the floating-capsule window and the
// island extension panel mount this same view, so the slot/anchor logic lives
// in one place. Capsules reference this view as their `host`.
Item {
    id: stageView

    // --- Inputs ---
    // Live hint snapshot (WindowHintService.activeHint) and reveal gate.
    property var hintData: null
    property bool active: false
    // Drop distance the capsules travel into place during reveal. The floating
    // window drops them from the bar edge; the island panel reveals in place.
    property real stageTargetY: 0
    // Launcher conflict: render only the primary title row, hide the vertical
    // workspace neighbors (the workspace panel yields to the launcher).
    property bool titleRowOnly: false
    // Screen width used to clamp capsule width; caller supplies the live value.
    property int screenWidth: 1
    // Side inset reserved so edge ears remain fully visible.
    property int capsuleEdgeInset: 24
    // Optional host-body sync for island embedding. When a host supplies its
    // live body height and the stage's inset from the body top, capsules near
    // the body's lower edge fade in together with the host's expansion spring
    // so a newly-added bottom capsule never appears before the island bottom
    // reaches it. Floating-capsule mode leaves these at defaults and disables
    // the sync.
    property real hostBodyHeight: -1
    property real hostBodyTopInset: 0

    // --- Exposed geometry ---
    readonly property int stageWidth: _workspaceStageWidth + (_workspaceStagePadding * 2)
    readonly property int stageHeight: _workspaceVisibleStageHeight
    readonly property Item hitRegionItem: stageHitRegion
    // Expose the live capsule items so a host window can build its blur region.
    readonly property var capsuleItems: stageRepeater.count > 0 ? workspaceStage.children : []
    // Y offset of the slot stage within this view, so host-body coverage math
    // can map a capsule's stage-space position into host coordinates.
    readonly property real stageContentY: workspaceStage.y
    // Bottom edge (in view coordinates) of the currently-rendered capsule
    // content, floored at the settled stage height. The island sizes its hint
    // footprint from this live extent so a capsule that enters at the stage's
    // lower edge during a workspace switch is always hosted — the body grows to
    // contain it instead of clipping it until the slots settle.
    readonly property real stageContentBottom: {
        var bottom = _workspaceVisibleStageHeight
        for (var i = 0; i < stageRepeater.count; i++) {
            var item = stageRepeater.itemAt(i)
            if (item && item.visible)
                bottom = Math.max(bottom, workspaceStage.y + item.visibleY + item.height)
        }
        return bottom
    }
    readonly property bool exitComplete: !active
        && _stageTopProgress <= 0.001
        && _stageMiddleProgress <= 0.001
        && _stageBottomProgress <= 0.001

    implicitWidth: stageView.stageWidth
    implicitHeight: _workspaceVisibleStageHeight
    clip: false

    // --- Stage state (migrated from WorkspaceHintWindow) ---
    property var _workspaceStageSlots: Motion.emptyStageSlots(_persistentStageSlotIndices, "workspace-slot")
    property real _animatedWorkspaceAnchor: -1
    property real _workspaceAnchorTarget: -1
    property int _workspaceAnchorDuration: _workspaceAnchorBaseDuration
    property bool _workspaceAnchorAnimationEnabled: true
    property bool _workspaceSettlePending: false
    property bool _stageExiting: false
    property real _stageTopProgress: 0
    property real _stageMiddleProgress: 0
    property real _stageBottomProgress: 0

    property var _renderHint: null
  property var _transitionSourceHint: null

    readonly property var _hintData: stageView.hintData
    readonly property int _activeWorkspacePosition: _hintData ? _hintData.activeWorkspacePosition : -1
    readonly property var _workspaceHintLayout: Stage.workspaceDisplayLayoutForHint(_renderHint || _hintData)
    readonly property int _workspaceVisibleCount: _workspaceHintLayout && _workspaceHintLayout.count !== undefined
        ? _workspaceHintLayout.count
        : 0
    readonly property bool _workspaceHasBefore: !!(_workspaceHintLayout && _workspaceHintLayout.hasBefore)
    readonly property bool _workspaceHasAfter: !!(_workspaceHintLayout && _workspaceHintLayout.hasAfter)
 readonly property var _persistentStageSlotIndices: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
    readonly property real _overflowSlotPosition: 1.18
    readonly property int _workspaceStagePadding: 16
  readonly property int _workspaceCapsuleMaxWidth: Math.max(1, Math.floor(stageView.screenWidth - stageView.capsuleEdgeInset * 2))
  readonly property int _workspaceSideWidth: 96
    // Deterministic primary width from the hint data (character-metric
    // estimate). Same data always yields the same width, so the stage size is
    // stable and available immediately — unlike imperative itemAt() delegate
    // measurement, which resolves asynchronously and produced unstable widths
    // (0 / 746 / 1646 / 2546 for the same workspace). The focused card keeps its
    // full title via the per-card cap; non-focused titles are clamped to fit.
    readonly property int _workspacePrimaryWidth: _workspacePrimaryWidthForHint(_renderHint || _hintData)
    readonly property int _workspaceSideHeight: 28
    readonly property int _workspacePrimaryHeight: 44
    readonly property int _workspaceColumnGap: 8
    readonly property int _workspaceExpandedPrimaryWidth: _workspaceExpandedPrimaryWidthForHint(_renderHint || _hintData)
    readonly property int _workspaceVisibleContentWidthFloor: _workspaceVisibleContentWidthFloorForHint(_renderHint || _hintData)
    readonly property int _workspaceStageWidth: Math.max(
        _workspacePrimaryWidth,
        _workspaceMaxSideWidth,
        _workspaceExpandedPrimaryWidth,
        _workspaceVisibleContentWidthFloor
    )
    readonly property int _workspaceFullStageHeight: _workspaceSideHeight * 2 + _workspacePrimaryHeight + _workspaceColumnGap * 2
    readonly property real _workspaceSingleSideTrim: _workspaceSideHeight + _workspaceColumnGap
    readonly property real _workspaceSingleSideOffset:
        _workspaceVisibleCount <= 1 || (_workspaceHasBefore && _workspaceHasAfter)
            ? 0
            : ((Math.max(0, Math.min(1, _animatedWorkspaceAnchor - (_workspaceVisibleCount - 2)))
                - Math.max(0, Math.min(1, 1 - _animatedWorkspaceAnchor)))
                * _workspaceSingleSideTrim / 2)
    readonly property real _workspaceLeadingTrimTarget:
        _workspaceHasBefore && _workspaceHasAfter
            ? 0
            : (_workspaceHasBefore || _workspaceHasAfter
                ? _workspaceSingleSideTrim / 2
                : _workspaceSingleSideTrim)
    readonly property real _workspaceTrailingTrimTarget: _workspaceLeadingTrimTarget
    property real _workspaceLeadingTrim: _workspaceLeadingTrimTarget
    property real _workspaceTrailingTrim: _workspaceTrailingTrimTarget
    readonly property real _workspaceVisibleStageHeight: _workspaceFullStageHeight - _workspaceLeadingTrim - _workspaceTrailingTrim
    // Capsule reveal drop distance, supplied by the host surface.
    readonly property real _workspaceStageTargetY: stageView.stageTargetY
    // Host-supplied distance from the screen top to the stage target origin.
    readonly property real _workspaceStageScreenY: stageView.stageTargetY
    readonly property int _workspaceAnchorBaseDuration: Math.max(150, Services.Motion.number.surfaceDuration)
    property int _workspaceCapsuleOpacityDuration: Math.max(90, Services.Motion.number.surfaceDuration)
    readonly property int _anchorDurationStep: 24
    readonly property int _anchorMaximumDuration: 240
    readonly property int _workspaceMaxSideWidth: {
      const currentHint = _renderHint || _hintData
        const workspaces = currentHint && currentHint.workspaces ? currentHint.workspaces : []
   let width = _workspaceSideWidth

        for (let index = 0; index < workspaces.length; index++)
          width = Math.max(width, _workspaceSideWidthForAbsoluteIndex(index))

        return width
    }

    function _workspaceMetricsForSlot(slotPosition, absoluteIndex) {
  return Motion.workspaceMetrics(stageView, slotPosition, absoluteIndex)
    }

    function _workspacePrimaryWidthForAbsoluteIndex(absoluteIndex) {
        const currentHint = _renderHint || _hintData
        // Use the measured primary width (same source as the stage container)
        // so the capsule's metrics width matches the stage width. The character
        // estimate from _workspacePrimaryWidthForHint over-estimates badly
        // (clamped to screen width), which overflows the clipped island body.
        // Fall back to the estimate only before measurement is ready.
        const currentWidth = _workspacePrimaryWidth

        if (_workspaceSettlePending && _transitionSourceHint) {
     const previousPosition = _transitionSourceHint.activeWorkspacePosition !== undefined
? _transitionSourceHint.activeWorkspacePosition
       : -1
      const currentPosition = currentHint && currentHint.activeWorkspacePosition !== undefined
 ? currentHint.activeWorkspacePosition
: -1

     if (absoluteIndex === previousPosition && absoluteIndex !== currentPosition)
    return _workspacePrimaryWidthForHint(_transitionSourceHint)
      if (absoluteIndex === currentPosition)
   return currentWidth
        }

        return currentWidth
    }

    function _workspaceIndexForAbsoluteIndex(absoluteIndex) {
        const currentHint = _renderHint || _hintData
        const currentPosition = currentHint && currentHint.activeWorkspacePosition !== undefined
  ? currentHint.activeWorkspacePosition
 : -1
        if (absoluteIndex === currentPosition)
        return currentHint && currentHint.workspaceIndex !== undefined ? currentHint.workspaceIndex : -1

        if (_workspaceSettlePending && _transitionSourceHint) {
     const previousPosition = _transitionSourceHint.activeWorkspacePosition !== undefined
       ? _transitionSourceHint.activeWorkspacePosition
       : -1
    if (absoluteIndex === previousPosition)
   return _transitionSourceHint.workspaceIndex !== undefined ? _transitionSourceHint.workspaceIndex : -1
  }

        const workspaces = currentHint && currentHint.workspaces ? currentHint.workspaces : []
    const summary = absoluteIndex >= 0 && absoluteIndex < workspaces.length ? workspaces[absoluteIndex] : null
        return summary && summary.workspaceIndex !== undefined ? summary.workspaceIndex : -1
    }

    function _workspaceIconCountForAbsoluteIndex(absoluteIndex) {
    const currentHint = _renderHint || _hintData
    const currentPosition = currentHint && currentHint.activeWorkspacePosition !== undefined
            ? currentHint.activeWorkspacePosition
            : -1
   if (absoluteIndex === currentPosition)
       return currentHint && currentHint.windows ? currentHint.windows.length : 0

        if (_workspaceSettlePending && _transitionSourceHint) {
      const previousPosition = _transitionSourceHint.activeWorkspacePosition !== undefined
     ? _transitionSourceHint.activeWorkspacePosition
 : -1
    if (absoluteIndex === previousPosition)
    return _transitionSourceHint.windows ? _transitionSourceHint.windows.length : 0
    }

        const workspaces = currentHint && currentHint.workspaces ? currentHint.workspaces : []
        const summary = absoluteIndex >= 0 && absoluteIndex < workspaces.length ? workspaces[absoluteIndex] : null
        return summary && summary.icons ? summary.icons.length : 0
    }

    function _workspaceSideWidthForAbsoluteIndex(absoluteIndex) {
        const workspaceIndex = _workspaceIndexForAbsoluteIndex(absoluteIndex)
        const labelWidth = workspaceIndex > 0 ? String(workspaceIndex).length * 7.5 : 0
      const iconCount = _workspaceIconCountForAbsoluteIndex(absoluteIndex)
        const iconWidth = iconCount > 0
        ? (iconCount * 18) + Math.max(0, iconCount - 1) * CapsuleMetrics.iconGap
    : 0
    const gap = labelWidth > 0 && iconWidth > 0 ? CapsuleMetrics.inlineGap : 0

return Math.min(
   _workspaceCapsuleMaxWidth,
    Math.max(_workspaceSideWidth, labelWidth + iconWidth + gap + CapsuleMetrics.compactInnerHorizontal)
        )
    }

    function _titleDisplayWidth(title) {
      const text = title || ""
        let width = 0

for (let index = 0; index < text.length; index++) {
            const code = text.charCodeAt(index)
  const ch = text[index]

            if (ch === " ") {
             width += 4.7
            } else if (/[.,:;!'|`]/.test(ch)) {
    width += 4.1
      } else if (/[ilI1\[\]()]/.test(ch)) {
       width += 5.3
         } else if (/[mwMW@#%&]/.test(ch)) {
  width += 9.6
   } else if (/[A-Z0-9]/.test(ch)) {
    width += 8.3
      } else if (code <= 0x7f) {
        width += 7.1
     } else {
        width += 12.8
            }
        }

        return Math.max(24, Math.ceil(width))
    }

    function _workspacePrimaryWidthForHint(hint) {
        const safeHint = hint || {}
        const windows = safeHint.windows || []
   let width = CapsuleMetrics.compactInnerHorizontal

        if (safeHint.workspaceIndex !== undefined && safeHint.workspaceIndex > 0)
    width += _titleDisplayWidth(String(safeHint.workspaceIndex))
    + CapsuleMetrics.compactInnerHorizontal
            + CapsuleMetrics.groupGap

        if (windows.length === 0)
        return 144

    for (let index = 0; index < windows.length; index++) {
            const windowData = windows[index] || {}
    const title = windowData.title || ""
    const titleWidth = _titleDisplayWidth(title)
            const iconWidth = windowData.icon ? 21 : 0
     const cardWidth = Math.max(60, titleWidth + iconWidth + CapsuleMetrics.compactInnerHorizontal)
            width += cardWidth
            if (index < windows.length - 1)
      width += CapsuleMetrics.inlineGap
        }

        width += CapsuleMetrics.compactSidePadding

        return Math.min(_workspaceCapsuleMaxWidth, Math.max(144, width))
    }

    // Expanded primary width computed from the full visible content requirement,
    // mirroring WorkspaceHintCapsule._expandedPrimaryWidth logic but using
    // character-metric estimation. Ensures the stage container is wide enough
    // for the expanded capsule content (full-width window cards + side-wide
    // minimum from non-focused capsules), not just the character estimate alone.
    function _workspaceExpandedPrimaryWidthForHint(hint) {
        const safeHint = hint || {}
        const windows = safeHint.windows || []
        const maxCapsuleWidth = Math.max(_workspacePrimaryHeight, _workspaceCapsuleMaxWidth)

        // Natural primary width using character metrics (same structure as
        // _workspacePrimaryWidthForHint but returns the raw estimate without
        // the final cap — the expanded formula applies its own capping after
        // also considering the workspace-area minimum width from side capsules).
        let naturalWidth = CapsuleMetrics.compactInnerHorizontal

        if (safeHint.workspaceIndex !== undefined && safeHint.workspaceIndex > 0)
            naturalWidth += _titleDisplayWidth(String(safeHint.workspaceIndex))
                + CapsuleMetrics.compactInnerHorizontal
                + CapsuleMetrics.groupGap

        if (windows.length > 0) {
            for (let index = 0; index < windows.length; index++) {
                const windowData = windows[index] || {}
                const title = windowData.title || ""
                const titleWidth = _titleDisplayWidth(title)
                const iconWidth = windowData.icon ? 21 : 0
                const cardWidth = Math.max(60, titleWidth + iconWidth + CapsuleMetrics.compactInnerHorizontal)
                naturalWidth += cardWidth
                if (index < windows.length - 1)
                    naturalWidth += CapsuleMetrics.inlineGap
            }
        } else {
            // No windows: keep at least the workspace label width if present.
            naturalWidth = Math.max(naturalWidth, 144)
        }

        naturalWidth += CapsuleMetrics.compactSidePadding
        naturalWidth = Math.max(144, naturalWidth)

        // Compute the same workspace-area minimum width as the capsule's
        // _workspaceAreaMinWidth so the expanded floor comes from the maximum
        // side capsule width across all workspaces, not just the primary estimate.
        const hasLabel = safeHint.workspaceIndex !== undefined && safeHint.workspaceIndex > 0
        const titleAreaWidth = hasLabel
            ? _titleDisplayWidth(String(safeHint.workspaceIndex)) + CapsuleMetrics.compactInnerHorizontal + CapsuleMetrics.compactSidePadding
            : 0
        const workspaceAreaWidth = _workspaceMaxSideWidth + CapsuleMetrics.groupGap + CapsuleMetrics.compactSidePadding
        const areaMinWidth = Math.max(titleAreaWidth, workspaceAreaWidth)

        return Math.min(maxCapsuleWidth, Math.max(naturalWidth, areaMinWidth))
    }

    // Keep the center dockzone wide enough for the widest visible workspace
    // summary, even when the focused capsule itself narrows.
    function _workspaceVisibleContentWidthFloorForHint(hint) {
        const safeHint = hint || {}
        const workspaces = safeHint.workspaces || []
        let width = _workspaceMaxSideWidth

        for (let index = 0; index < workspaces.length; index++) {
            const summary = workspaces[index] || {}
            const workspaceIndex = summary.workspaceIndex !== undefined ? summary.workspaceIndex : -1
            const labelWidth = workspaceIndex > 0 ? _titleDisplayWidth(String(workspaceIndex)) : 0
            const iconCount = summary.icons ? summary.icons.length : 0
            const iconWidth = iconCount > 0
                ? (iconCount * 18) + Math.max(0, iconCount - 1) * CapsuleMetrics.iconGap
                : 0
            const gap = labelWidth > 0 && iconWidth > 0 ? CapsuleMetrics.inlineGap : 0
            const summaryWidth = Math.min(
                _workspaceCapsuleMaxWidth,
                Math.max(_workspaceSideWidth, labelWidth + iconWidth + gap + CapsuleMetrics.compactInnerHorizontal)
            )

            width = Math.max(width, summaryWidth)
        }

        return width
    }

    function _settleWorkspaceStage(hint) {
        Motion.settleWorkspaceStageSlots(stageView, hint, Stage)
  }

    function _stageRevealForSlot(slotPosition) {
        if (slotPosition <= -0.5)
          return _stageTopProgress
        if (slotPosition < 0.5)
       return _stageMiddleProgress
        return _stageBottomProgress
 }

    function _setStageRevealProgress(top, middle, bottom) {
        _stageTopProgress = top
    _stageMiddleProgress = middle
     _stageBottomProgress = bottom
    }

    // The host-body bottom sync engages only after the reveal cascade settles,
    // so the island's own reveal animation still owns the initial entry feel.
    // During a held-hint workspace switch the cascade is already at 1, so the
    // sync applies and lets new bottom capsules emerge with the island spring.
    readonly property bool _bodySyncReady: _stageTopProgress >= 0.999
        && _stageMiddleProgress >= 0.999
        && _stageBottomProgress >= 0.999

    // Fraction of a capsule (at the given stage-space top and height) that the
    // host body currently covers from its lower edge, 0..1. Capsules below the
    // island's live bottom edge fade proportionally, so they appear exactly as
    // the expansion spring reaches them. No-op (1) for floating hosts.
    function hostBodyCoverageFor(stageY, height) {
        if (root.hostBodyHeight < 0 || !root._bodySyncReady)
            return 1

        var islandTop = root.hostBodyTopInset + root.stageContentY + stageY
        var islandBottom = root.hostBodyHeight
        if (islandTop >= islandBottom)
            return 0

        return Math.max(0, Math.min(1, (islandBottom - Math.max(0, islandTop)) / Math.max(1, height)))
    }

    // Staggered reveal in, staggered reverse out — mirrors the legacy timing.
    onActiveChanged: {
   if (active) {
       _stageExiting = false
       _exitTopTimer.stop()
      _exitMiddleTimer.stop()
            _exitBottomTimer.stop()
 _setStageRevealProgress(0, 0, 0)
            _enterTopTimer.restart()
        _enterMiddleTimer.restart()
        _enterBottomTimer.restart()
     Motion.handleHintChange(stageView, stageView.hintData, _workspaceAnchorSettleTimer, Stage)
     return
        }

_stageExiting = true
_enterTopTimer.stop()
        _enterMiddleTimer.stop()
        _enterBottomTimer.stop()
        _exitBottomTimer.restart()
        _exitMiddleTimer.restart()
        _exitTopTimer.restart()
    }

    onHintDataChanged: {
     if (!active)
          return

        Motion.handleHintChange(stageView, stageView.hintData, _workspaceAnchorSettleTimer, Stage)
    }

    // Stagger the top capsule into view from y = 0.
  Timer {
        id: _enterTopTimer
        interval: 20
  onTriggered: stageView._stageTopProgress = 1
    }

    // Stagger the center capsule into view after the top slot.
    Timer {
        id: _enterMiddleTimer
     interval: 70
        onTriggered: stageView._stageMiddleProgress = 1
  }

    // Stagger the bottom capsule into view last.
    Timer {
        id: _enterBottomTimer
        interval: 100
      onTriggered: stageView._stageBottomProgress = 1
    }

    // Reverse the bottom capsule back toward y = 0 first.
    Timer {
    id: _exitBottomTimer
        interval: 20
        onTriggered: stageView._stageBottomProgress = 0
    }

    // Reverse the center capsule after the bottom slot.
    Timer {
      id: _exitMiddleTimer
 interval: 50
        onTriggered: stageView._stageMiddleProgress = 0
    }

    // Reverse the top capsule last to mirror the old staging.
    Timer {
        id: _exitTopTimer
        interval: 80
        onTriggered: stageView._stageTopProgress = 0
    }

    // Wait for the workspace anchor motion to settle before cleaning stage slots.
    Timer {
        id: _workspaceAnchorSettleTimer
        repeat: false
        onTriggered: {
if (!stageView._workspaceSettlePending)
        return
 if (Math.abs(stageView._animatedWorkspaceAnchor - stageView._workspaceAnchorTarget) > 0.001) {
    interval = 16
        restart()
 return
            }

            stageView._workspaceSettlePending = false
            stageView._settleWorkspaceStage(stageView._renderHint)
        }
    }

    // Keep workspace switching on a smooth anchor tween like DymicShell.
    Behavior on _animatedWorkspaceAnchor {
        enabled: stageView._workspaceAnchorAnimationEnabled

        NumberAnimation {
       duration: stageView._workspaceAnchorDuration
   easing.type: Easing.OutSine
        }
    }

    // Animate the top staged reveal progress.
    Behavior on _stageTopProgress {
        NumberAnimation {
         duration: Services.Motion.number.surfaceDuration
  easing.type: Easing.OutCubic
 }
    }

    // Animate the center staged reveal progress.
    Behavior on _stageMiddleProgress {
     NumberAnimation {
            duration: Services.Motion.number.surfaceDuration
            easing.type: Easing.OutCubic
        }
    }

    // Animate the bottom staged reveal progress.
    Behavior on _stageBottomProgress {
  NumberAnimation {
 duration: Services.Motion.number.surfaceDuration
        easing.type: Easing.OutCubic
        }
    }

    // Animate visible stage trimming as edge neighbors appear and disappear.
    Behavior on _workspaceLeadingTrim {
        NumberAnimation {
            duration: stageView._workspaceCapsuleOpacityDuration
            easing.type: Easing.OutCubic
        }
    }

    // Animate the trailing trim with the same timing as the leading trim.
    Behavior on _workspaceTrailingTrim {
        NumberAnimation {
            duration: stageView._workspaceCapsuleOpacityDuration
            easing.type: Easing.OutCubic
        }
    }

    // Track the visible-capsule bounds so a host window can build its mask.
    Item {
        id: stageHitRegion

        readonly property real _left: {
       var min = workspaceStage.x + workspaceStage.width
            for (var i = 0; i < stageRepeater.count; i++) {
                var item = stageRepeater.itemAt(i)
  if (item && item.visible) min = Math.min(min, workspaceStage.x + item.x)
         }
 return min
     }
        readonly property real _top: {
   var min = stageView.height
    for (var i = 0; i < stageRepeater.count; i++) {
    var item = stageRepeater.itemAt(i)
           if (item && item.visible) min = Math.min(min, workspaceStage.y + item.visibleY)
        }
            return min
        }
        readonly property real _right: {
    var max = workspaceStage.x
  for (var i = 0; i < stageRepeater.count; i++) {
  var item = stageRepeater.itemAt(i)
         if (item && item.visible) max = Math.max(max, workspaceStage.x + item.x + item.width)
   }
      return max
        }
        readonly property real _bottom: {
            var max = workspaceStage.y
    for (var i = 0; i < stageRepeater.count; i++) {
  var item = stageRepeater.itemAt(i)
   if (item && item.visible) max = Math.max(max, workspaceStage.y + item.visibleY + item.height)
    }
      return max
        }

    x: _left < stageView.width ? _left : 0
        y: _top < stageView.height ? _top : 0
        width: Math.max(0, _right - x)
        height: Math.max(0, _bottom - y)
    }

    // Center the slot stage within the view.
    Item {
        id: workspaceStage

        x: stageView._workspaceStagePadding
        y: -stageView._workspaceLeadingTrim + stageView._workspaceSingleSideOffset
   width: stageView._workspaceStageWidth
        height: stageView._workspaceFullStageHeight
        clip: false

        // Render the persistent workspace stage slots.
        Repeater {
   id: stageRepeater

    model: stageView._persistentStageSlotIndices.length

            delegate: WorkspaceHint.WorkspaceHintCapsule {
                required property int index

                readonly property var _slotData:
                    index >= 0 && index < stageView._workspaceStageSlots.length
                        ? stageView._workspaceStageSlots[index]
                        : null
                readonly property var _slotCapsule: _slotData ? _slotData.capsule : null

                // When only the title row is requested (launcher conflict), the
                // vertical neighbors yield: keep only the primary capsule by
                // nulling the others so the capsule's own visibility binding
                // hides them with no extra override.
                readonly property bool _isPrimarySlot: !!(_slotCapsule
                    && (_slotCapsule.isCurrent || _slotCapsule.isTransitionCurrent))

                host: stageView
                capsule: (stageView.titleRowOnly && !_isPrimarySlot) ? null : _slotCapsule
                absoluteIndex: _slotData ? _slotData.absoluteIndex : -1
                slotPosition: Stage.workspaceStageSlotPositionAt(stageView, index)
            }
        }
    }
}
