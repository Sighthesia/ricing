.pragma library

var actionIds = ["lock", "logout", "suspend", "reboot", "shutdown"]

function isKnownAction(actionId) {
    return actionIds.indexOf(actionId) >= 0
}

function commandFor(actionId, sessionId) {
    if (actionId === "logout")
        return sessionId ? ["loginctl", "terminate-session", sessionId] : []
    if (actionId === "suspend")
        return ["systemctl", "suspend"]
    if (actionId === "reboot")
        return ["systemctl", "reboot"]
    if (actionId === "shutdown")
        return ["systemctl", "poweroff"]
    return []
}

function isAvailable(actionId, sessionId) {
    return isKnownAction(actionId) && (actionId !== "logout" || !!sessionId)
}

function canStart(running, actionId, sessionId) {
    return running !== true && isAvailable(actionId, sessionId)
}
