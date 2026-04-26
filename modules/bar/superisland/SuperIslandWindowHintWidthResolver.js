.pragma library

function _num(value, fallback) {
    return typeof value === "number" && isFinite(value) ? value : fallback
}

function _itemWidth(item, fallback) {
    return item && typeof item.implicitWidth === "number" ? item.implicitWidth : fallback
}

function _animatedWidth(control, fallback) {
    return control && typeof control.animatedWidth === "number" ? control.animatedWidth : fallback
}

function attachedRevealSeedWidth(root) {
    var collapsedWidthLive = _num(root && root._collapsedWidthLive, 0)
    var overlayWidth = _num(root && root._overlayPillBackgroundWidth, collapsedWidthLive)
    var panelWidth = _num(root && root._attachedPanelWidth, 0)
    var baseSeedWidth = Math.max(overlayWidth, collapsedWidthLive)
    return panelWidth > 0 ? Math.min(baseSeedWidth, panelWidth) : baseSeedWidth
}

function attachedCollapseBaseWidthCandidate(root) {
    return Math.max(_num(root && root._collapsedWidthLive, 0), _itemWidth(root && root._resolverPillClip, 0))
}

function detachedHintWidth(root) {
    var collapsedWidth = _num(root && root._collapsedWidth, 0)
    var measuredWidth = root && root._resolverDetachedHintMeasureLoader && root._resolverDetachedHintMeasureLoader.item
        ? root._resolverDetachedHintMeasureLoader.item.implicitWidth
        : collapsedWidth

    return Math.max(collapsedWidth, _num(measuredWidth, collapsedWidth) + 2)
}

function barExpandedMainHintWidthMeasured(root) {
    var item = root && root._resolverBarExpandedMainMeasureLoader ? root._resolverBarExpandedMainMeasureLoader.item : null
    return _itemWidth(item, 0) + 2
}

function barExpandedDetachedHintWidth(root) {
    var item = root && root._resolverDetachedHintDetachedMeasureLoader ? root._resolverDetachedHintDetachedMeasureLoader.item : null
    return _itemWidth(item, 0) + 2
}

function barExpandedMainHintWidth(root) {
    return Math.max(
        _num(root && root._collapsedWidth, 0),
        _num(root && root._barExpandedDetachedHintWidth, 0),
        _num(root && root._barExpandedMainHintWidthMeasured, 0)
    )
}

function barExpandedTitleWidthClamped(root) {
    var animatedWidth = _animatedWidth(root && root._resolverPillTransitionControl, 0)
    return !!(root && root._barExpandedHintActive)
        && Math.abs(animatedWidth - _num(root && root._attachedPanelBodyWidth, 0)) <= 1.5
}

function barExpandedHostFootprintWidth(root) {
    return Math.max(0, _animatedWidth(root && root._resolverPillTransitionControl, 0))
}

function collapsedWidthLive(root) {
    var barExpandedActive = !!(root && root._barExpandedHintActive)
    var entryBase = _num(root && root._barExpandedEntryBaseWidth, 0)
    var mainWidth = _itemWidth(root && root._resolverMainLoader ? root._resolverMainLoader.item : null, 0)
    var padH = _num(root && root._padH, 0)

    return barExpandedActive && entryBase > 0
        ? entryBase
        : (mainWidth + padH * 2)
}

function collapsedWidth(root) {
    var useBase = !!(root && root._useAttachedCollapseBaseWidth)
    var attachedBase = _num(root && root._attachedCollapseBaseWidth, 0)
    var live = _num(root && root._collapsedWidthLive, 0)
    return useBase && attachedBase > 0 ? attachedBase : live
}

function expandedWidth(root) {
    if (root && root._barExpandedHintActive) {
        return root._phase === "hint-exit"
            ? Math.max(
                _num(root._barExpandedExitBaseWidth, 0) > 0 ? _num(root._barExpandedExitBaseWidth, 0) : _num(root._idleCollapsedWidthLive, 0),
                _num(root._idleCollapsedWidthLive, 0)
            )
            : _num(root._barExpandedMainHintWidth, 0)
    }

    if (root && root._overlaySessionActive)
        return _num(root._overlayExpandedWidth, 0)

    return Math.max(
        _num(root && root._collapsedWidth, 0),
        _itemWidth(root && root._resolverStripLoader ? root._resolverStripLoader.item : null, 0) + _num(root && root._padH, 0) * 2
    )
}
