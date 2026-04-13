.pragma library

function lerp(from, to, progress) {
    return from + (to - from) * progress
}

function mixColor(from, to, progress) {
    return Qt.rgba(
        lerp(from.r, to.r, progress),
        lerp(from.g, to.g, progress),
        lerp(from.b, to.b, progress),
        lerp(from.a, to.a, progress)
    )
}

function workspaceLabel(index) {
    if (index <= 0)
        return ""

    return "WS " + index
}

function cloneWindowData(windowData) {
    return {
        windowId: windowData ? (windowData.windowId || "") : "",
        title: windowData ? (windowData.title || "") : "",
        icon: windowData ? (windowData.icon || "") : "",
        isFocused: windowData ? !!windowData.isFocused : false
    }
}

function cloneWorkspaceSummary(summary) {
    return {
        workspaceId: summary ? (summary.workspaceId || "") : "",
        workspaceIndex: summary ? (summary.workspaceIndex || -1) : -1,
        icons: summary && summary.icons ? summary.icons.slice() : []
    }
}

function cloneHint(hint) {
    if (!hint)
        return null

    return {
        visible: hint.visible === true,
        workspaceId: hint.workspaceId || "",
        workspaceIndex: hint.workspaceIndex !== undefined ? hint.workspaceIndex : -1,
        activeWorkspacePosition: hint.activeWorkspacePosition !== undefined ? hint.activeWorkspacePosition : -1,
        currentWindowId: hint.currentWindowId || "",
        currentWindowTitle: hint.currentWindowTitle || "",
        currentWindowIcon: hint.currentWindowIcon || "",
        currentIndex: hint.currentIndex !== undefined ? hint.currentIndex : -1,
        windows: hint.windows ? hint.windows.slice() : [],
        workspaces: hint.workspaces ? hint.workspaces.map(function(workspace) { return cloneWorkspaceSummary(workspace) }) : [],
        previousWindow: cloneWindowData(hint.previousWindow),
        nextWindow: cloneWindowData(hint.nextWindow),
        previousWorkspace: cloneWorkspaceSummary(hint.previousWorkspace),
        nextWorkspace: cloneWorkspaceSummary(hint.nextWorkspace)
    }
}

function cloneWorkspaceCapsule(capsule) {
    if (!capsule)
        return null

    return {
        key: capsule.key || "",
        label: capsule.label || "",
        icons: (capsule.icons || []).slice(),
        workspaceIndex: capsule.workspaceIndex !== undefined ? capsule.workspaceIndex : -1,
        visible: capsule.visible !== false
    }
}

function cloneTitleCapsule(capsule) {
    if (!capsule)
        return null

    return {
        key: capsule.key || "",
        title: capsule.title || "",
        icon: capsule.icon || "",
        visible: capsule.visible !== false
    }
}

function emptyStageSlots(slotIndices, prefix) {
    var slots = []

    for (var index = 0; index < slotIndices.length; index++) {
        slots.push({
            slotId: prefix + "-" + index,
            absoluteIndex: -1,
            workspaceIndex: -1,
            capsule: null
        })
    }

    return slots
}

function cloneStageSlot(slot, cloneCapsuleFn, slotId) {
    return {
        slotId: slot ? (slot.slotId || slotId) : slotId,
        absoluteIndex: slot && slot.absoluteIndex !== undefined ? slot.absoluteIndex : -1,
        workspaceIndex: slot && slot.workspaceIndex !== undefined ? slot.workspaceIndex : -1,
        capsule: cloneCapsuleFn(slot ? slot.capsule : null)
    }
}

function stageSlotsFrom(slotIndices, currentSlots, cloneCapsuleFn, prefix) {
    var slots = []

    for (var index = 0; index < slotIndices.length; index++) {
        var slotId = prefix + "-" + index
        var currentSlot = currentSlots && index < currentSlots.length ? currentSlots[index] : null
        slots.push(cloneStageSlot(currentSlot, cloneCapsuleFn, slotId))
    }

    return slots
}

function slotsForEntries(slotIndices, currentSlots, entries, cloneCapsuleFn, prefix, preserveUnassigned) {
    var current = stageSlotsFrom(slotIndices, currentSlots, cloneCapsuleFn, prefix)
    var slots = emptyStageSlots(slotIndices, prefix)
    var assignedSlots = ({})

    for (var entryIndex = 0; entryIndex < Math.min(slots.length, entries.length); entryIndex++) {
        var entry = entries[entryIndex]
        var slotIndex = -1

        for (var i = 0; i < current.length; i++) {
            if (assignedSlots[i])
                continue
            if (current[i].absoluteIndex !== entry.absoluteIndex)
                continue

            slotIndex = i
            break
        }

        if (slotIndex < 0) {
            for (var j = 0; j < current.length; j++) {
                if (assignedSlots[j])
                    continue
                if (current[j].absoluteIndex >= 0
                    && (!current[j].capsule || current[j].capsule.visible !== false))
                    continue

                slotIndex = j
                break
            }
        }

        if (slotIndex < 0) {
            for (var k = 0; k < current.length; k++) {
                if (assignedSlots[k])
                    continue

                slotIndex = k
                break
            }
        }

        if (slotIndex < 0)
            break

        assignedSlots[slotIndex] = true
        slots[slotIndex] = {
            slotId: current[slotIndex].slotId,
            absoluteIndex: entry.absoluteIndex,
            workspaceIndex: entry.capsule && entry.capsule.workspaceIndex !== undefined
                ? entry.capsule.workspaceIndex
                : entry.absoluteIndex,
            capsule: cloneCapsuleFn(entry.capsule)
        }
    }

    if (preserveUnassigned) {
        for (var n = 0; n < current.length; n++) {
            if (assignedSlots[n])
                continue
            if (current[n].absoluteIndex < 0 || !current[n].capsule)
                continue
            if (current[n].capsule.visible === false)
                continue

            slots[n] = cloneStageSlot(current[n], cloneCapsuleFn, current[n].slotId)
        }
    }

    return slots
}
