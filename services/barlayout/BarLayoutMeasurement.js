.pragma library

function setWidgetMeasuredWidth(widgetMeasuredWidths, widgetMeasurementMetadata, instanceKey, width, options) {
    if (!instanceKey) {
        return {
            accepted: false,
            requestClear: false,
            changed: false,
            widthChanged: false,
            widgetMeasuredWidths: widgetMeasuredWidths,
            widgetMeasurementMetadata: widgetMeasurementMetadata
        }
    }

    var nextWidth = Math.max(0, Number(width) || 0)
    var updateOptions = options || {}
    var source = updateOptions.source || "external"
    var reporterId = updateOptions.reporterId || ""
    var preserveExternalSnapshot = source === "runtime" && updateOptions.preserveExternalSnapshot === true

    if (nextWidth <= 0) {
        return {
            accepted: true,
            requestClear: true,
            clearOptions: {
                reporterId: reporterId
            },
            changed: false,
            widthChanged: false,
            widgetMeasuredWidths: widgetMeasuredWidths,
            widgetMeasurementMetadata: widgetMeasurementMetadata
        }
    }

    var currentWidth = typeof widgetMeasuredWidths[instanceKey] === "number" ? widgetMeasuredWidths[instanceKey] : 0
    var currentMetadata = widgetMeasurementMetadata[instanceKey] || null
    var currentSource = currentMetadata && currentMetadata.source ? currentMetadata.source : "external"
    var currentReporterId = currentMetadata && currentMetadata.reporterId ? currentMetadata.reporterId : ""

    if (preserveExternalSnapshot && currentWidth > 0 && currentSource !== "runtime") {
        return {
            accepted: false,
            requestClear: false,
            changed: false,
            widthChanged: false,
            widgetMeasuredWidths: widgetMeasuredWidths,
            widgetMeasurementMetadata: widgetMeasurementMetadata
        }
    }

    var nextMeasuredWidths = Object.assign({}, widgetMeasuredWidths)
    var nextMeasurementMetadata = Object.assign({}, widgetMeasurementMetadata)
    var widthChanged = nextMeasuredWidths[instanceKey] !== nextWidth
    var metadataChanged = currentSource !== source || currentReporterId !== reporterId

    if (!widthChanged && !metadataChanged) {
        return {
            accepted: true,
            requestClear: false,
            changed: false,
            widthChanged: false,
            widgetMeasuredWidths: widgetMeasuredWidths,
            widgetMeasurementMetadata: widgetMeasurementMetadata
        }
    }

    nextMeasuredWidths[instanceKey] = nextWidth
    nextMeasurementMetadata[instanceKey] = {
        source: source,
        reporterId: reporterId
    }

    return {
        accepted: true,
        requestClear: false,
        changed: true,
        widthChanged: widthChanged,
        widgetMeasuredWidths: nextMeasuredWidths,
        widgetMeasurementMetadata: nextMeasurementMetadata
    }
}

function clearWidgetMeasuredWidth(widgetMeasuredWidths, widgetMeasurementMetadata, instanceKey, options) {
    var clearOptions = options || {}
    var reporterId = clearOptions.reporterId || ""
    var hasMeasuredWidth = widgetMeasuredWidths[instanceKey] !== undefined
    var hasMeasurementMetadata = widgetMeasurementMetadata[instanceKey] !== undefined

    if (!instanceKey || (!hasMeasuredWidth && !hasMeasurementMetadata)) {
        return {
            accepted: false,
            changed: false,
            hadMeasuredWidth: false,
            widgetMeasuredWidths: widgetMeasuredWidths,
            widgetMeasurementMetadata: widgetMeasurementMetadata
        }
    }

    var currentMetadata = widgetMeasurementMetadata[instanceKey] || null
    var currentSource = currentMetadata && currentMetadata.source ? currentMetadata.source : "external"
    var currentReporterId = currentMetadata && currentMetadata.reporterId ? currentMetadata.reporterId : ""

    if (reporterId) {
        if (currentSource !== "runtime") {
            return {
                accepted: false,
                changed: false,
                hadMeasuredWidth: false,
                widgetMeasuredWidths: widgetMeasuredWidths,
                widgetMeasurementMetadata: widgetMeasurementMetadata
            }
        }

        if (currentReporterId && currentReporterId !== reporterId) {
            return {
                accepted: false,
                changed: false,
                hadMeasuredWidth: false,
                widgetMeasuredWidths: widgetMeasuredWidths,
                widgetMeasurementMetadata: widgetMeasurementMetadata
            }
        }
    }

    var nextMeasuredWidths = Object.assign({}, widgetMeasuredWidths)
    var nextMeasurementMetadata = Object.assign({}, widgetMeasurementMetadata)

    delete nextMeasuredWidths[instanceKey]
    delete nextMeasurementMetadata[instanceKey]

    return {
        accepted: true,
        changed: true,
        hadMeasuredWidth: hasMeasuredWidth,
        widgetMeasuredWidths: nextMeasuredWidths,
        widgetMeasurementMetadata: nextMeasurementMetadata
    }
}

function measuredWidthForInstance(widgetMeasuredWidths, instanceKey) {
    if (!instanceKey)
        return 0

    var measuredWidth = widgetMeasuredWidths[instanceKey]
    return typeof measuredWidth === "number" ? measuredWidth : 0
}
