.pragma library

.import "BarLayoutArrival.js" as ArrivalUtils

function resetState() {
    return {
        arrivalGeometries: ({}),
        arrivalRevealLocks: ({})
    }
}

function clear(state, instanceKey) {
    var result = ArrivalUtils.clearArrivalGeometry(
        state.arrivalGeometries,
        state.arrivalRevealLocks,
        instanceKey
    )

    return {
        changed: result.changed,
        state: {
            arrivalGeometries: result.arrivalGeometries,
            arrivalRevealLocks: result.arrivalRevealLocks
        }
    }
}

function _tryRelease(sectionName, state, sectionSlotsFn) {
    var slots = sectionSlotsFn(sectionName)
    var result = ArrivalUtils.tryReleaseArrivalForSection(
        sectionName,
        state.arrivalRevealLocks,
        slots,
        state.arrivalGeometries
    )

    return {
        released: result.released,
        state: {
            arrivalGeometries: result.arrivalGeometries,
            arrivalRevealLocks: result.arrivalRevealLocks
        }
    }
}

function requestReveal(state, instanceKey, sectionSlotsFn) {
    var requestResult = ArrivalUtils.requestArrivalReveal(state.arrivalGeometries, instanceKey)
    if (!requestResult.changed)
        return { changed: false, state: state }

    var nextState = {
        arrivalGeometries: requestResult.arrivalGeometries,
        arrivalRevealLocks: state.arrivalRevealLocks
    }

    var releaseResult = _tryRelease(requestResult.sectionName, nextState, sectionSlotsFn)
    return {
        changed: true,
        state: releaseResult.state,
        released: releaseResult.released
    }
}

function finishReveal(state, instanceKey, sectionSlotsFn) {
    var finishResult = ArrivalUtils.finishArrivalReveal(state.arrivalRevealLocks, instanceKey)
    if (!finishResult.changed)
        return { changed: false, state: state }

    var cleared = ArrivalUtils.clearArrivalGeometry(
        state.arrivalGeometries,
        finishResult.arrivalRevealLocks,
        instanceKey
    )
    var nextState = {
        arrivalGeometries: cleared.arrivalGeometries,
        arrivalRevealLocks: cleared.arrivalRevealLocks
    }
    var releaseResult = _tryRelease(finishResult.sectionName, nextState, sectionSlotsFn)

    return {
        changed: true,
        state: releaseResult.state,
        released: releaseResult.released
    }
}

function addOverlayArrivalForWidget(state, slots, instanceKey, widgetId, sectionName) {
    var slot = ArrivalUtils.slotForInstanceKey(slots, instanceKey)
    if (!slot)
        return { changed: false, state: state }

    var nextArrivalGeometries = Object.assign({}, state.arrivalGeometries)
    nextArrivalGeometries[instanceKey] = ArrivalUtils.arrivalGeometryForSlot(
        instanceKey,
        widgetId,
        sectionName,
        slot,
        "overlay",
        false
    )

    return {
        changed: true,
        state: {
            arrivalGeometries: nextArrivalGeometries,
            arrivalRevealLocks: state.arrivalRevealLocks
        }
    }
}
