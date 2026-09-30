.pragma library

// The permanent power row on the lock surface. The buttons are glyph-only, so
// the label stays the spoken/accessible name and the status-line copy. Lock is
// absent because the surface is already locked, and reboot is not part of the
// row; SessionService still knows both ids, so neither capability is removed
// from the service.
function actions() {
    return [
        { id: "suspend", label: "Suspend", requiresConfirmation: true, icon: "suspend" },
        { id: "shutdown", label: "Shut down", requiresConfirmation: true, icon: "power" },
        { id: "logout", label: "Log out", requiresConfirmation: true, icon: "logout" }
    ]
}

function actionFor(actionId) {
    var list = actions()
    for (var i = 0; i < list.length; ++i) {
        if (list[i].id === actionId)
            return list[i]
    }
    return null
}

function labelFor(actionId) {
    var action = actionFor(actionId)
    return action ? action.label : ""
}

// Every row action is destructive, so the first activation only arms a
// confirmation and the second one runs. A different action while one is armed
// stays pending instead of silently switching the target.
function confirmationAction(pendingAction, actionId) {
    if (pendingAction)
        return pendingAction === actionId ? "confirm" : "pending"
    return actionFor(actionId) ? "select" : "pending"
}

// Escape only cancels an armed confirmation; there is no panel left to close.
function escapeAction(pendingAction) {
    return pendingAction ? "cancel-confirmation" : "none"
}

function canTrigger(actionId, available, running) {
    if (running === true || available !== true)
        return false
    return actionFor(actionId) !== null
}

// One status line explains the row: a failure first, then the armed
// confirmation, then whatever the service reported last.
function statusMessage(pendingAction, errorText, resultText) {
    if (errorText)
        return String(errorText)
    if (pendingAction) {
        var action = actionFor(pendingAction)
        return action ? "Confirm " + action.label + "?" : "Select again to confirm"
    }
    return String(resultText || "")
}
