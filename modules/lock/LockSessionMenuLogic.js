.pragma library

function actions() {
    return [
        { id: "lock", label: "Lock", requiresConfirmation: false, icon: "lock" },
        { id: "logout", label: "Log out", requiresConfirmation: true, icon: "logout" },
        { id: "suspend", label: "Suspend", requiresConfirmation: true, icon: "suspend" },
        { id: "reboot", label: "Reboot", requiresConfirmation: true, icon: "reboot" },
        { id: "shutdown", label: "Shut down", requiresConfirmation: true, icon: "shutdown" }
    ]
}

function toggle(open) {
    return !open
}

function confirmationAction(menuOpen, pendingAction, actionId) {
    if (!menuOpen)
        return "pending"
    if (pendingAction && pendingAction === actionId)
        return "confirm"
    if (pendingAction)
        return "pending"
    var list = actions()
    for (var i = 0; i < list.length; ++i) {
        if (list[i].id === actionId)
            return "select"
    }
    return "pending"
}

function escapeAction(menuOpen, pendingAction) {
    if (pendingAction)
        return "cancel-confirmation"
    if (menuOpen)
        return "close"
    return "none"
}

function canTrigger(actionId, available, running) {
    if (running === true || available !== true)
        return false
    var list = actions()
    for (var i = 0; i < list.length; ++i)
        if (list[i].id === actionId)
            return true
    return false
}
