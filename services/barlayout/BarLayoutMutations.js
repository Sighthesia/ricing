.pragma library

.import "BarLayoutLayoutModel.js" as LayoutModelUtils
.import "BarLayoutPersistence.js" as PersistenceUtils
.import "BarLayoutArrivalSession.js" as ArrivalSessionUtils

function loadFromPersistOrDisk(persistLayoutJson, applyJsonFn, startDiskReadFn) {
    return PersistenceUtils.loadFromPersistOrDisk(persistLayoutJson, applyJsonFn, startDiskReadFn)
}

function replaceLayout(layoutModel, entries, ensureLayoutInstanceKeysFn) {
    layoutModel.clear()

    for (var i = 0; i < entries.length; i++)
        layoutModel.append(entries[i])

    ensureLayoutInstanceKeysFn()
}

function applyJson(layoutModel, json, handlers) {
    return PersistenceUtils.applyLayoutJson(
        json,
        layoutModel.count,
        handlers.resetLayout,
        function(entries) {
            handlers.resetArrivalState()
            replaceLayout(layoutModel, entries, handlers.ensureLayoutInstanceKeys)
        },
        function() {
            handlers.recomputeGeometryContracts()
            handlers.layoutChanged()
        },
        function(error) {
            if (typeof handlers.logError === "function")
                handlers.logError(error)
        }
    )
}

function saveLayout(layoutModel, persistStore, fileWriter) {
    return PersistenceUtils.saveLayoutJson(layoutModel, persistStore, fileWriter)
}

function moveWidget(layoutModel, instanceKey, toSection, toAlignment, toOrder, handlers) {
    var result = LayoutModelUtils.moveWidget(layoutModel, instanceKey, toSection, toAlignment, toOrder)
    if (!result.changed)
        return false

    handlers.recomputeGeometryContracts()
    handlers.layoutChanged()
    handlers.saveLayout()
    return true
}

function isSamePlacement(layoutModel, instanceKey, sectionName, order, alignment) {
    var modelIndex = LayoutModelUtils.layoutIndexForInstanceKey(layoutModel, instanceKey)
    if (modelIndex < 0)
        return false

    var item = layoutModel.get(modelIndex)
    return item.section === sectionName && item.order === order && item.alignment === alignment
}

function resetLayout(layoutModel, defaultLayout, handlers) {
    handlers.resetArrivalState()
    replaceLayout(layoutModel, defaultLayout, handlers.ensureLayoutInstanceKeys)
    handlers.recomputeGeometryContracts()
    handlers.layoutChanged()
}

function addWidget(layoutModel, widgetId, section, options, handlers) {
    var maxOrder = LayoutModelUtils.maxOrderForSection(layoutModel, section)
    var instanceKey = handlers.createInstanceKey(widgetId)

    layoutModel.append({
        id: widgetId,
        section: section,
        alignment: "left",
        order: maxOrder + 1,
        enabled: true,
        instanceKey: instanceKey
    })

    handlers.recomputeGeometryContracts()

    if (options.settingsMode) {
        var addResult = ArrivalSessionUtils.addOverlayArrivalForWidget(
            options.arrivalState,
            options.sectionSlots(section),
            instanceKey,
            widgetId,
            section
        )

        if (addResult.changed)
            handlers.applyArrivalState(addResult.state)
    }

    handlers.layoutChanged()
    handlers.saveLayout()
    return instanceKey
}

function removeWidget(layoutModel, instanceKey, activeWidgetInstanceKey, handlers) {
    var modelIndex = LayoutModelUtils.layoutIndexForInstanceKey(layoutModel, instanceKey)
    if (modelIndex < 0)
        return { removed: false }

    handlers.clearArrivalGeometry(instanceKey)
    layoutModel.remove(modelIndex)

    if (activeWidgetInstanceKey === instanceKey)
        handlers.closeWidgetSettings()

    handlers.recomputeGeometryContracts()
    handlers.layoutChanged()
    handlers.saveLayout()
    return { removed: true }
}
