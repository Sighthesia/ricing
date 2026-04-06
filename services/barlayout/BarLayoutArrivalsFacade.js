.pragma library

.import "BarLayoutArrivalSession.js" as ArrivalSessionUtils

function resetArrivalState(applyArrivalStateFn) {
    applyArrivalStateFn(ArrivalSessionUtils.resetState())
}

function clearArrivalGeometry(arrivalState, instanceKey, applyArrivalStateFn) {
    var result = ArrivalSessionUtils.clear(arrivalState, instanceKey)
    if (!result.changed)
        return false

    applyArrivalStateFn(result.state)
    return true
}

function completeArrivalGeometry(arrivalState, instanceKey, applyArrivalStateFn) {
    return clearArrivalGeometry(arrivalState, instanceKey, applyArrivalStateFn)
}

function requestArrivalReveal(arrivalState, instanceKey, sectionSlotsFn, applyArrivalStateFn) {
    var result = ArrivalSessionUtils.requestReveal(arrivalState, instanceKey, sectionSlotsFn)
    if (!result.changed)
        return false

    applyArrivalStateFn(result.state)
    return true
}

function finishArrivalReveal(arrivalState, instanceKey, sectionSlotsFn, applyArrivalStateFn) {
    var result = ArrivalSessionUtils.finishReveal(arrivalState, instanceKey, sectionSlotsFn)
    if (!result.changed)
        return false

    applyArrivalStateFn(result.state)
    return true
}
