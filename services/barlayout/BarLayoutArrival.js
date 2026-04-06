.pragma library

function slotForInstanceKey(slots, instanceKey) {
    if (!Array.isArray(slots) || !instanceKey)
        return null

    for (var i = 0; i < slots.length; i++) {
        if (slots[i].instanceKey === instanceKey)
            return slots[i]
    }

    return null
}

function arrivalGeometryForSlot(instanceKey, widgetId, sectionName, slot, phase, readyForDelegate) {
    if (!slot)
        return null

    return {
        active: true,
        instanceKey: instanceKey,
        widgetId: widgetId,
        section: sectionName,
        barLeft: slot.left,
        barWidth: slot.width,
        barRight: slot.right,
        barCenterX: slot.centerX,
        phase: phase,
        readyForDelegate: readyForDelegate === true
    }
}

function syncArrivalGeometriesWithSlots(arrivalGeometries, slotGeometries) {
    var nextArrivalGeometries = Object.assign({}, arrivalGeometries)

    for (var instanceKey in nextArrivalGeometries) {
        var snapshot = nextArrivalGeometries[instanceKey]
        if (!snapshot || snapshot.active !== true || !snapshot.section)
            continue

        var slot = slotForInstanceKey(slotGeometries[snapshot.section], instanceKey)
        if (!slot)
            continue

        nextArrivalGeometries[instanceKey] = Object.assign({}, snapshot, {
            barLeft: slot.left,
            barWidth: slot.width,
            barRight: slot.right,
            barCenterX: slot.centerX
        })
    }

    return nextArrivalGeometries
}

function clearArrivalGeometry(arrivalGeometries, arrivalRevealLocks, instanceKey) {
    if (!instanceKey || arrivalGeometries[instanceKey] === undefined) {
        return {
            changed: false,
            arrivalGeometries: arrivalGeometries,
            arrivalRevealLocks: arrivalRevealLocks
        }
    }

    var nextArrivalGeometries = Object.assign({}, arrivalGeometries)
    var nextArrivalRevealLocks = Object.assign({}, arrivalRevealLocks)
    delete nextArrivalGeometries[instanceKey]

    for (var sectionName in nextArrivalRevealLocks) {
        if (nextArrivalRevealLocks[sectionName] === instanceKey)
            delete nextArrivalRevealLocks[sectionName]
    }

    return {
        changed: true,
        arrivalGeometries: nextArrivalGeometries,
        arrivalRevealLocks: nextArrivalRevealLocks
    }
}

function requestArrivalReveal(arrivalGeometries, instanceKey) {
    var snapshot = instanceKey ? arrivalGeometries[instanceKey] : null
    if (!snapshot || snapshot.active !== true) {
        return {
            changed: false,
            sectionName: "",
            arrivalGeometries: arrivalGeometries
        }
    }

    var nextArrivalGeometries = Object.assign({}, arrivalGeometries)
    nextArrivalGeometries[instanceKey] = Object.assign({}, snapshot, {
        readyForDelegate: true
    })

    return {
        changed: true,
        sectionName: snapshot.section || "",
        arrivalGeometries: nextArrivalGeometries
    }
}

function finishArrivalReveal(arrivalRevealLocks, instanceKey) {
    if (!instanceKey) {
        return {
            changed: false,
            sectionName: "",
            arrivalRevealLocks: arrivalRevealLocks
        }
    }

    var releaseSection = ""
    for (var sectionName in arrivalRevealLocks) {
        if (arrivalRevealLocks[sectionName] === instanceKey) {
            releaseSection = sectionName
            break
        }
    }

    if (!releaseSection) {
        return {
            changed: false,
            sectionName: "",
            arrivalRevealLocks: arrivalRevealLocks
        }
    }

    var nextArrivalRevealLocks = Object.assign({}, arrivalRevealLocks)
    delete nextArrivalRevealLocks[releaseSection]

    return {
        changed: true,
        sectionName: releaseSection,
        arrivalRevealLocks: nextArrivalRevealLocks
    }
}

function tryReleaseArrivalForSection(sectionName, arrivalRevealLocks, slots, arrivalGeometries) {
    if (!sectionName || arrivalRevealLocks[sectionName]) {
        return {
            released: false,
            arrivalGeometries: arrivalGeometries,
            arrivalRevealLocks: arrivalRevealLocks
        }
    }

    for (var i = 0; i < slots.length; i++) {
        var snapshot = arrivalGeometries[slots[i].instanceKey]
        if (!snapshot || snapshot.active !== true)
            continue

        if (snapshot.readyForDelegate !== true) {
            return {
                released: false,
                arrivalGeometries: arrivalGeometries,
                arrivalRevealLocks: arrivalRevealLocks
            }
        }

        var releasedInstanceKey = snapshot.instanceKey
        var nextArrivalGeometries = Object.assign({}, arrivalGeometries)
        var nextArrivalRevealLocks = Object.assign({}, arrivalRevealLocks)

        nextArrivalGeometries[releasedInstanceKey] = Object.assign({}, snapshot, {
            phase: "delegate",
            delegateReleased: true
        })
        nextArrivalRevealLocks[sectionName] = releasedInstanceKey

        return {
            released: true,
            arrivalGeometries: nextArrivalGeometries,
            arrivalRevealLocks: nextArrivalRevealLocks
        }
    }

    return {
        released: false,
        arrivalGeometries: arrivalGeometries,
        arrivalRevealLocks: arrivalRevealLocks
    }
}
