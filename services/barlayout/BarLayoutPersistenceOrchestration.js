.pragma library

.import "BarLayoutPersistence.js" as PersistenceUtils

function runStartupLoad(root, persistStore, fileReader) {
    PersistenceUtils.loadFromPersistOrDisk(
        persistStore.layoutJson,
        root.applyJson,
        function() {
            fileReader.running = true
        }
    )

    root._recomputeGeometryContracts()
}

function applyDiskLayoutChunk(root, data) {
    var trimmed = (data || "").trim()
    if (trimmed !== "")
        root.applyJson(trimmed)
}

function finishDiskRead(root, running) {
    if (!running && root.layoutModel.count === 0)
        root.resetLayout()
}

function saveLayout(layoutModel, persistStore, fileWriter) {
    var json = PersistenceUtils.serializeLayoutJson(layoutModel)
    PersistenceUtils.persistLayoutJson(persistStore, json)
    PersistenceUtils.writeLayoutJson(fileWriter, json)
    return json
}
