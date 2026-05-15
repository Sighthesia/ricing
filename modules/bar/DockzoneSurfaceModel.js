// Pure derivation helper for dockzone surface state.
// No lifecycle, no mutable state — only normalization and geometry derivation.

// Motion baselines for the hidden state — owner animates between these and attached.
var _hiddenScale = 0.95;
var _hiddenOffsetY = -4;

/**
 * Build a contract-shaped model from semantic inputs.
 *
 * @param {Object} inputs
 * @param {string} inputs.section - Semantic section: "left" | "center" | "right"
 * @param {string} inputs.surfaceState - Structural mode: "attached" | "floating" | "hidden" | "entering" | "exiting"
 * @param {number} inputs.surfaceHeight - Resolved bar height for this surface
 * @param {number} inputs.contentWidth - Measured content row width
 * @param {number} inputs.contentHeight - Measured content row height
 * @param {number} [inputs.visibilityProgress] - Owner-supplied canonical visibility driver (0..1)
 * @param {number} [inputs.stateTransitionProgress] - Owner-supplied canonical transition driver (0..1)
 * @param {number} [inputs.detachProgress] - Owner-supplied ear detach driver (0..1)
 * @param {number} [inputs.morphProgress] - Owner-supplied morph driver (0..1)
 * @returns {Object} Contract-shaped model object
 */
function buildModel(inputs) {
    var section = inputs.section || "center";
    var surfaceState = inputs.surfaceState || "attached";
    var surfaceHeight = inputs.surfaceHeight || 0;
    var contentWidth = inputs.contentWidth || 0;
    var contentHeight = inputs.contentHeight || 0;
    var isCenter = section === "center";
    var isLeft = section === "left";
    var isRight = section === "right";

    // Owner-supplied canonical progress drivers — fall back to state-derived
    // defaults when the owner has not yet wired real animated values.
    var visibilityProgress = inputs.visibilityProgress !== undefined
        ? inputs.visibilityProgress
        : _visibilityForState(surfaceState);
    var stateTransitionProgress = inputs.stateTransitionProgress !== undefined
        ? inputs.stateTransitionProgress
        : 0;
    var detachProgress = inputs.detachProgress !== undefined ? inputs.detachProgress : 0;
    var morphProgress = inputs.morphProgress !== undefined ? inputs.morphProgress : 0;

    // Geometry baselines — match current BarDockZoneBackground defaults.
    var earRadius = 24;
    var bodyRadius = 14;
    var horizontalPadding = 18;
    var verticalPadding = 8;
    var bottomEarEnvelope = isCenter ? 0 : earRadius;

    var hasContent = contentWidth > 0 && contentHeight > 0 && surfaceHeight > 0;
    var bodyWidth = hasContent ? Math.max(contentWidth + horizontalPadding * 2, 0) : 0;
    var totalHeight = hasContent ? Math.max(contentHeight + verticalPadding * 2, surfaceHeight) : 0;
    var bodyHeight = hasContent ? totalHeight : 0;
    var bodyX = isLeft ? 0 : earRadius;
    var bodyY = 0;
    var containerWidth = hasContent ? bodyWidth + (isCenter ? earRadius * 2 : earRadius) : 0;
    var containerHeight = hasContent ? totalHeight + bottomEarEnvelope : 0;

    var floatingBlend = surfaceState === "floating" ? Math.max(detachProgress, morphProgress) : 0;

    // Derive global motion from visibility and floating semantics — body and ears stay continuous.
    var opacity = visibilityProgress;
    var scale = _hiddenScale + (1 - _hiddenScale) * visibilityProgress + floatingBlend * 0.02;
    var translateX = floatingBlend * 1.5;
    var translateY = _hiddenOffsetY * (1 - visibilityProgress) - floatingBlend * 1.5;

    return {
        identity: {
            id: section + "-surface",
            section: section
        },
        state: {
            surfaceState: surfaceState,
            visibilityProgress: visibilityProgress,
            stateTransitionProgress: stateTransitionProgress,
            morphProgress: morphProgress,
            detachProgress: detachProgress
        },
        geometry: {
            visibleBodyWidth: bodyWidth,
            visibleBodyHeight: bodyHeight,
            containerWidth: containerWidth,
            containerHeight: containerHeight,
            bottomEarEnvelope: bottomEarEnvelope,
            bodyRadius: bodyRadius,
            earRadius: earRadius
        },
        globalMotion: {
            translateX: translateX,
            translateY: translateY,
            scale: scale,
            opacity: opacity,
            colorProgress: floatingBlend
        },
        leftEar: {
            presence: 1 - floatingBlend * 0.05,
            morphProgress: morphProgress,
            detachProgress: detachProgress,
            offsetX: floatingBlend * -0.5,
            offsetY: floatingBlend * -1
        },
        rightEar: {
            presence: 1 - floatingBlend * 0.05,
            morphProgress: morphProgress,
            detachProgress: detachProgress,
            offsetX: floatingBlend * 0.5,
            offsetY: floatingBlend * -1
        },
        contentRegion: {
            x: bodyX + horizontalPadding,
            y: bodyY + verticalPadding,
            width: bodyWidth - horizontalPadding * 2,
            height: bodyHeight - verticalPadding * 2
        }
    };
}

/**
 * Derive renderer-facing geometry helpers from a contract model.
 *
 * @param {Object} model - Contract-shaped model from buildModel()
 * @returns {Object} Renderer metrics: positions, sizes, ear flags, style constants
 */
function deriveRendererMetrics(model) {
    var g = model.geometry;
    var section = model.identity.section;

    var hasLeftTopEar = section === "center" || section === "right";
    var hasTopRightEar = section === "center" || section === "left";
    var hasBottomLeftEar = section === "left";
    var hasBottomRightEar = section === "right";
    var bottomEarY = g.visibleBodyHeight;
    var bodyX = hasLeftTopEar ? g.earRadius : 0;
    // Left bottom ear attaches at the body's inner edge (earRadius from left).
    var bottomLeftEarX = hasBottomLeftEar ? g.earRadius : 0;
    // Right bottom ear attaches at the body's right edge.
    var bottomRightEarX = hasBottomRightEar ? bodyX + g.visibleBodyWidth - g.earRadius : 0;

    return {
        bodyX: hasLeftTopEar ? g.earRadius : 0,
        bodyY: 0,
        bodyWidth: g.visibleBodyWidth,
        bodyHeight: g.visibleBodyHeight,
        containerWidth: g.containerWidth,
        containerHeight: g.containerHeight,
        hasLeftTopEar: hasLeftTopEar,
        hasTopRightEar: hasTopRightEar,
        hasBottomLeftEar: hasBottomLeftEar,
        hasBottomRightEar: hasBottomRightEar,
        bottomEarY: bottomEarY,
        bottomLeftEarX: bottomLeftEarX,
        bottomRightEarX: bottomRightEarX,
        bodyRadius: g.bodyRadius,
        earRadius: g.earRadius
    };
}

function _visibilityForState(state) {
    if (state === "hidden" || state === "exiting")
        return 0;
    return 1;
}
