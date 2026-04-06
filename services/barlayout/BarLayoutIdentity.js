.pragma library

.import "BarLayoutLayoutModel.js" as LayoutModelUtils

function createInstanceKey(nextSerialByWidget, widgetId) {
    return LayoutModelUtils.createInstanceKey(nextSerialByWidget, widgetId)
}

function ensureLayoutInstanceKeys(layoutModel, nextSerialByWidget) {
    return LayoutModelUtils.ensureLayoutInstanceKeys(layoutModel, nextSerialByWidget)
}

function instanceKeyAt(layoutModel, modelIndex) {
    return LayoutModelUtils.instanceKeyAt(layoutModel, modelIndex)
}

function serializeLayout(layoutModel) {
    return LayoutModelUtils.serializeLayoutModel(layoutModel)
}
