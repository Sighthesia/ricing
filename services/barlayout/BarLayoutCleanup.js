.pragma library

function layoutInstanceKeySet(layoutModel, instanceKeyAtFn) {
    var instanceKeys = ({})

    for (var i = 0; i < layoutModel.count; i++) {
        var instanceKey = instanceKeyAtFn(i)
        if (!instanceKey)
            continue

        instanceKeys[instanceKey] = true
    }

    return instanceKeys
}

function cleanupStaleGeometryState(
    activeInstanceKeys,
    widgetMeasuredWidths,
    widgetMeasurementMetadata,
    arrivalGeometries,
    arrivalRevealLocks,
    draggedInstanceKey
) {
    var staleGeometryEntries = []

    for (var instanceKey in widgetMeasuredWidths) {
        if (activeInstanceKeys[instanceKey])
            continue

        staleGeometryEntries.push(instanceKey)
    }

    for (var metadataInstanceKey in widgetMeasurementMetadata) {
        if (activeInstanceKeys[metadataInstanceKey] || staleGeometryEntries.indexOf(metadataInstanceKey) >= 0)
            continue

        staleGeometryEntries.push(metadataInstanceKey)
    }

    if (staleGeometryEntries.length <= 0) {
        return {
            changed: false,
            widgetMeasuredWidths: widgetMeasuredWidths,
            widgetMeasurementMetadata: widgetMeasurementMetadata,
            arrivalGeometries: arrivalGeometries,
            arrivalRevealLocks: arrivalRevealLocks,
            clearDragState: !!(draggedInstanceKey && !activeInstanceKeys[draggedInstanceKey])
        }
    }

    var nextMeasuredWidths = Object.assign({}, widgetMeasuredWidths)
    var nextMeasurementMetadata = Object.assign({}, widgetMeasurementMetadata)
    var nextArrivalGeometries = Object.assign({}, arrivalGeometries)
    var nextArrivalRevealLocks = Object.assign({}, arrivalRevealLocks)

    for (var i = 0; i < staleGeometryEntries.length; i++) {
        var staleKey = staleGeometryEntries[i]
        delete nextMeasuredWidths[staleKey]
        delete nextMeasurementMetadata[staleKey]
        delete nextArrivalGeometries[staleKey]

        for (var sectionName in nextArrivalRevealLocks) {
            if (nextArrivalRevealLocks[sectionName] === staleKey)
                delete nextArrivalRevealLocks[sectionName]
        }
    }

    return {
        changed: true,
        widgetMeasuredWidths: nextMeasuredWidths,
        widgetMeasurementMetadata: nextMeasurementMetadata,
        arrivalGeometries: nextArrivalGeometries,
        arrivalRevealLocks: nextArrivalRevealLocks,
        clearDragState: !!(draggedInstanceKey && !activeInstanceKeys[draggedInstanceKey])
    }
}
