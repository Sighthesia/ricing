.pragma library

.import "BarLayoutLayoutModel.js" as LayoutModelUtils

function applyLayoutJson(json, currentCount, resetLayoutFn, onApplyEntriesFn, onSuccessFn, onErrorFn) {
    try {
        var arr = JSON.parse(json)
        if (!Array.isArray(arr) || arr.length === 0) {
            resetLayoutFn()
            return { applied: false, reset: true }
        }

        onApplyEntriesFn(arr)
        onSuccessFn()
        return { applied: true, reset: false }
    } catch (e) {
        if (typeof onErrorFn === "function")
            onErrorFn(e)

        resetLayoutFn()
        return {
            applied: false,
            reset: true,
            error: e
        }
    }
}

function saveLayoutJson(layoutModel, persistStore, fileWriter) {
    var json = LayoutModelUtils.serializeLayoutModel(layoutModel)
    persistStore.layoutJson = json
    fileWriter.running = false
    fileWriter.running = true
    fileWriter.write(json + "\n")
    return json
}

function loadFromPersistOrDisk(persistLayoutJson, applyJsonFn, startDiskReadFn) {
    if (persistLayoutJson !== "") {
        applyJsonFn(persistLayoutJson)
        return true
    }

    startDiskReadFn()
    return false
}
