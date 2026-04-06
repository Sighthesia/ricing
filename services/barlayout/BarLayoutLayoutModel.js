.pragma library

function parseInstanceSerial(widgetId, instanceKey) {
    if (!widgetId || !instanceKey)
        return -1

    var prefix = widgetId + "_"
    if (!instanceKey.startsWith(prefix))
        return -1

    var serial = Number(instanceKey.slice(prefix.length))
    if (!Number.isInteger(serial) || serial < 0)
        return -1

    return serial
}

function createInstanceKey(nextSerialByWidget, widgetId) {
    var nextSerials = Object.assign({}, nextSerialByWidget)
    var serial = nextSerials[widgetId] || 0

    nextSerials[widgetId] = serial + 1

    return {
        instanceKey: widgetId + "_" + serial,
        nextSerialByWidget: nextSerials
    }
}

function instanceKeyAt(layoutModel, modelIndex) {
    if (modelIndex < 0 || modelIndex >= layoutModel.count)
        return ""

    var targetId = layoutModel.get(modelIndex).id
    var n = 0
    for (var i = 0; i < modelIndex; i++) {
        if (layoutModel.get(i).id === targetId)
            n++
    }

    var storedKey = layoutModel.get(modelIndex).instanceKey
    if (storedKey)
        return storedKey

    return targetId + "_" + n
}

function ensureLayoutInstanceKeys(layoutModel, nextSerialByWidget) {
    var nextSerials = Object.assign({}, nextSerialByWidget)

    for (var i = 0; i < layoutModel.count; i++) {
        var item = layoutModel.get(i)
        var serial = parseInstanceSerial(item.id, item.instanceKey)

        if (serial < 0)
            continue

        nextSerials[item.id] = Math.max(nextSerials[item.id] || 0, serial + 1)
    }

    for (var j = 0; j < layoutModel.count; j++) {
        var entry = layoutModel.get(j)
        if (parseInstanceSerial(entry.id, entry.instanceKey) >= 0)
            continue

        var nextSerial = nextSerials[entry.id] || 0
        layoutModel.setProperty(j, "instanceKey", entry.id + "_" + nextSerial)
        nextSerials[entry.id] = nextSerial + 1
    }

    return nextSerials
}

function serializeLayoutItem(item) {
    return {
        id: item.id,
        section: item.section,
        alignment: item.alignment,
        order: item.order,
        enabled: item.enabled,
        instanceKey: item.instanceKey || ""
    }
}

function serializeLayoutModel(layoutModel) {
    var arr = []

    for (var i = 0; i < layoutModel.count; i++)
        arr.push(serializeLayoutItem(layoutModel.get(i)))

    return JSON.stringify(arr)
}

function layoutIndexForInstanceKey(layoutModel, instanceKey) {
    if (!instanceKey)
        return -1

    for (var i = 0; i < layoutModel.count; i++) {
        if (instanceKeyAt(layoutModel, i) === instanceKey)
            return i
    }

    return -1
}

function moveWidget(layoutModel, instanceKey, toSection, toAlignment, toOrder) {
    var currentSection = ""
    var currentOrder = -1

    for (var i = 0; i < layoutModel.count; i++) {
        var item = layoutModel.get(i)
        if (instanceKeyAt(layoutModel, i) === instanceKey) {
            currentSection = item.section
            currentOrder = item.order
            break
        }
    }

    if (currentOrder >= 0 && currentSection === toSection && currentOrder === toOrder)
        return { changed: false }

    var others = []
    var movingIdx = -1
    for (var j = 0; j < layoutModel.count; j++) {
        var entry = layoutModel.get(j)
        if (instanceKeyAt(layoutModel, j) === instanceKey) {
            movingIdx = j
            continue
        }

        if (entry.section === toSection)
            others.push({ modelIndex: j, order: entry.order })
    }

    if (movingIdx < 0)
        return { changed: false }

    others.sort(function(a, b) { return a.order - b.order })

    var insertAt = Math.min(toOrder, others.length)
    others.splice(insertAt, 0, { modelIndex: movingIdx, order: -1 })

    for (var k = 0; k < others.length; k++) {
        var modelIndex = others[k].modelIndex
        layoutModel.setProperty(modelIndex, "order", k)

        if (modelIndex === movingIdx) {
            layoutModel.setProperty(modelIndex, "section", toSection)
            layoutModel.setProperty(modelIndex, "alignment", toAlignment)
        }
    }

    return {
        changed: true,
        movingIndex: movingIdx
    }
}

function maxOrderForSection(layoutModel, sectionName) {
    var maxOrder = -1

    for (var i = 0; i < layoutModel.count; i++) {
        var item = layoutModel.get(i)
        if (item.section === sectionName && item.order > maxOrder)
            maxOrder = item.order
    }

    return maxOrder
}
