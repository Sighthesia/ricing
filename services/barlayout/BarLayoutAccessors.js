.pragma library

.import "BarLayoutGeometry.js" as GeometryUtils

function sectionGeometry(sectionGeometries, sectionName) {
    if (sectionGeometries[sectionName] !== undefined)
        return sectionGeometries[sectionName]

    return GeometryUtils.emptySectionGeometry(sectionName)
}

function sectionSlots(slotGeometries, sectionName) {
    var slots = slotGeometries[sectionName]
    return Array.isArray(slots) ? slots : []
}

function pickerAnchorGeometry(pickerAnchors, sectionName) {
    if (pickerAnchors[sectionName] !== undefined)
        return pickerAnchors[sectionName]

    return GeometryUtils.emptyPickerAnchor(sectionName)
}

function arrivalGeometry(arrivalGeometries, instanceKey) {
    if (!instanceKey)
        return null

    return arrivalGeometries[instanceKey] !== undefined
        ? arrivalGeometries[instanceKey]
        : null
}

function widgetGeometry(widgetGeometries, instanceKey) {
    if (!instanceKey)
        return null

    return widgetGeometries[instanceKey] !== undefined
        ? widgetGeometries[instanceKey]
        : null
}

function revealLockHolder(arrivalRevealLocks, sectionName) {
    if (!sectionName || arrivalRevealLocks[sectionName] === undefined)
        return ""

    return arrivalRevealLocks[sectionName] || ""
}
