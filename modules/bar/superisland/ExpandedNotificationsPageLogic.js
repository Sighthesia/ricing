.pragma library

function visibleCardDelegates(listView, count) {
    var delegates = []

    for (var index = 0; index < count; index++) {
        var delegate = listView.itemAtIndex(index)
        if (delegate)
            delegates.push(delegate)
    }

    return delegates
}

function syncStaggerItems(pageStagger, listShell, includeShell) {
    pageStagger.clear()

    if (includeShell !== false)
        pageStagger.registerItem(listShell, 0, 1)
}

function runCardEnter(delegates, emptyStateVisible, runEmptyEnterFn) {
    for (var index = 0; index < delegates.length; index++) {
        var delegate = delegates[index]
        if (!delegate || typeof delegate.queueManagedEnter !== "function")
            continue

        delegate.queueManagedEnter(index, delegates.length)
    }

    if (emptyStateVisible)
        runEmptyEnterFn()
}

function exitWindow(total, maxExitSlots, exitStep) {
    var cappedTotal = Math.max(0, Math.min(total, maxExitSlots))
    return Math.max(0, cappedTotal - 1) * exitStep
}

function compressedExitDelay(rank, total, maxExitSlots, exitStep) {
    if (total <= 1)
        return 0

    var window = exitWindow(total, maxExitSlots, exitStep)
    return Math.round(window * (rank / Math.max(1, total - 1)))
}

function runCardExit(delegates, emptyStateVisible, maxExitSlots, exitStep, runEmptyExitFn) {
    for (var index = 0; index < delegates.length; index++) {
        var delegate = delegates[index]
        if (!delegate || typeof delegate.runExit !== "function")
            continue

        delegate.exitDelay = compressedExitDelay(index, delegates.length, maxExitSlots, exitStep)
        delegate.runExit()
    }

    if (emptyStateVisible)
        runEmptyExitFn()
}

function relativeTime(timestamp, nowMs) {
    var diff = nowMs - Number(timestamp || 0)

    if (diff < 60000)
        return "刚刚"

    if (diff < 3600000)
        return Math.floor(diff / 60000) + " 分钟前"

    if (diff < 86400000)
        return Math.floor(diff / 3600000) + " 小时前"

    return Math.floor(diff / 86400000) + " 天前"
}
