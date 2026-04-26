.pragma library

function isWindowHintPresentationMode(presentation) {
    return presentation === "window-hint"
        || presentation === "bar-expanded"
        || presentation === "bar-expanded-main"
        || presentation === "bar-expanded-detached"
}

function isBarExpandedCombinedPresentation(presentation) {
    return presentation === "bar-expanded"
}

function isBarExpandedMainPresentation(presentation) {
    return presentation === "bar-expanded-main"
}

function isBarExpandedDetachedPresentation(presentation) {
    return presentation === "bar-expanded-detached"
}

function isDefaultPresentation(presentation) {
    return !isBarExpandedCombinedPresentation(presentation)
        && !isBarExpandedMainPresentation(presentation)
        && !isBarExpandedDetachedPresentation(presentation)
}

function windowHintPresentationKindForEvent(event, useStrip) {
    var presentation = event && event.presentation ? event.presentation : "window-hint"

    if (presentation === "bar-expanded")
        return useStrip ? "bar-expanded-detached" : "bar-expanded-main"

    if (presentation === "bar-expanded-main" || presentation === "bar-expanded-detached")
        return presentation

    return "default"
}

function resolvedDeckHintEvent(event, overlaySessionActive) {
    var nextEvent = event || {}

    if (!overlaySessionActive && nextEvent.presentation === "bar-expanded")
        return Object.assign({}, nextEvent, { presentation: "bar-expanded-detached" })

    return nextEvent
}
