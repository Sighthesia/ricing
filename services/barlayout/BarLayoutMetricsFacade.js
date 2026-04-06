.pragma library

.import "BarLayoutStateSync.js" as StateSyncUtils
.import "BarLayoutMeasurement.js" as MeasurementUtils

function setBarMetrics(currentWidth, currentPadding, contentWidth, padding, applyMetricsFn, recomputeGeometryContractsFn) {
    var result = StateSyncUtils.setBarMetrics(currentWidth, currentPadding, contentWidth, padding)

    if (!result.changed)
        return false

    applyMetricsFn(result.barContentWidth, result.barContentPadding)
    recomputeGeometryContractsFn()
    return true
}

function setTransientExtension(transientExtensions, ownerKey, height, applyTransientExtensionsFn) {
    var result = StateSyncUtils.setTransientExtension(transientExtensions, ownerKey, height)
    if (!result.accepted)
        return false

    if (!result.changed)
        return true

    applyTransientExtensionsFn(result.transientExtensions)
    return true
}

function maxTransientExtension(transientExtensions) {
    return StateSyncUtils.maxTransientExtension(transientExtensions)
}

function clearTransientExtension(transientExtensions, ownerKey, applyTransientExtensionsFn) {
    var result = StateSyncUtils.clearTransientExtension(transientExtensions, ownerKey)
    if (!result.accepted)
        return false

    applyTransientExtensionsFn(result.transientExtensions)
    return true
}

function setWidgetMeasuredWidth(widgetMeasuredWidths, widgetMeasurementMetadata, instanceKey, width, options, handlers) {
    var result = MeasurementUtils.setWidgetMeasuredWidth(
        widgetMeasuredWidths,
        widgetMeasurementMetadata,
        instanceKey,
        width,
        options
    )

    if (!result.accepted)
        return false

    if (result.requestClear)
        return handlers.clearWidgetMeasuredWidth(instanceKey, result.clearOptions)

    if (!result.changed)
        return true

    handlers.applyMeasurementState(result.widgetMeasuredWidths, result.widgetMeasurementMetadata)

    if (result.widthChanged)
        handlers.recomputeGeometryContracts()

    return true
}

function clearWidgetMeasuredWidth(widgetMeasuredWidths, widgetMeasurementMetadata, instanceKey, options, handlers) {
    var result = MeasurementUtils.clearWidgetMeasuredWidth(
        widgetMeasuredWidths,
        widgetMeasurementMetadata,
        instanceKey,
        options
    )

    if (!result.accepted)
        return false

    handlers.applyMeasurementState(result.widgetMeasuredWidths, result.widgetMeasurementMetadata)

    if (result.hadMeasuredWidth)
        handlers.recomputeGeometryContracts()

    return true
}

function measuredWidthForInstance(widgetMeasuredWidths, instanceKey) {
    return MeasurementUtils.measuredWidthForInstance(widgetMeasuredWidths, instanceKey)
}
