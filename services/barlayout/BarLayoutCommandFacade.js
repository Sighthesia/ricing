.pragma library

.import "BarLayoutGeometryStateFacade.js" as GeometryStateFacadeUtils
.import "BarLayoutIdentity.js" as IdentityUtils
.import "BarLayoutMutations.js" as MutationUtils
.import "BarLayoutPersistenceOrchestration.js" as PersistenceOrchestrationUtils

function serializeLayout(layoutModel) {
    return IdentityUtils.serializeLayout(layoutModel)
}

function instanceKeyAt(layoutModel, modelIndex) {
    return IdentityUtils.instanceKeyAt(layoutModel, modelIndex)
}

function createInstanceKey(root, widgetId) {
    var result = IdentityUtils.createInstanceKey(root._nextInstanceSerialByWidget, widgetId)
    root._nextInstanceSerialByWidget = result.nextSerialByWidget
    return result.instanceKey
}

function ensureLayoutInstanceKeys(root, layoutModel) {
    root._nextInstanceSerialByWidget = IdentityUtils.ensureLayoutInstanceKeys(
        layoutModel,
        root._nextInstanceSerialByWidget
    )
}

function applyJson(root, layoutModel, defaultLayout, json) {
    return MutationUtils.applyJson(layoutModel, json, {
        resetLayout: function() {
            resetLayout(root, layoutModel, defaultLayout)
        },
        resetArrivalState: function() {
            GeometryStateFacadeUtils.resetArrivalState(root)
        },
        ensureLayoutInstanceKeys: function() {
            ensureLayoutInstanceKeys(root, layoutModel)
        },
        recomputeGeometryContracts: root._recomputeGeometryContracts,
        layoutChanged: root.layoutChanged,
        logError: function(error) {
            console.log("BarLayoutService: failed to parse layout JSON:", error)
        }
    })
}

function saveLayout(layoutModel, persistStore, fileWriter) {
    return PersistenceOrchestrationUtils.saveLayout(layoutModel, persistStore, fileWriter)
}

function moveWidget(root, layoutModel, persistStore, fileWriter, instanceKey, toSection, toAlignment, toOrder) {
    return MutationUtils.moveWidget(layoutModel, instanceKey, toSection, toAlignment, toOrder, {
        recomputeGeometryContracts: root._recomputeGeometryContracts,
        layoutChanged: root.layoutChanged,
        saveLayout: function() {
            saveLayout(layoutModel, persistStore, fileWriter)
        }
    })
}

function resetLayout(root, layoutModel, defaultLayout) {
    return MutationUtils.resetLayout(layoutModel, defaultLayout, {
        resetArrivalState: function() {
            GeometryStateFacadeUtils.resetArrivalState(root)
        },
        ensureLayoutInstanceKeys: function() {
            ensureLayoutInstanceKeys(root, layoutModel)
        },
        recomputeGeometryContracts: root._recomputeGeometryContracts,
        layoutChanged: root.layoutChanged
    })
}

function addWidget(root, layoutModel, persistStore, fileWriter, widgetId, section) {
    return MutationUtils.addWidget(layoutModel, widgetId, section, {
        settingsMode: root.settingsMode,
        sectionSlots: root.sectionSlots,
        arrivalState: GeometryStateFacadeUtils.arrivalState(root)
    }, {
        createInstanceKey: function(targetWidgetId) {
            return createInstanceKey(root, targetWidgetId)
        },
        recomputeGeometryContracts: root._recomputeGeometryContracts,
        applyArrivalState: function(nextState) {
            GeometryStateFacadeUtils.applyArrivalState(root, nextState)
        },
        layoutChanged: root.layoutChanged,
        saveLayout: function() {
            saveLayout(layoutModel, persistStore, fileWriter)
        }
    })
}

function removeWidget(root, layoutModel, persistStore, fileWriter, instanceKey) {
    return MutationUtils.removeWidget(layoutModel, instanceKey, root.activeWidgetInstanceKey, {
        clearArrivalGeometry: root.clearArrivalGeometry,
        closeWidgetSettings: root.closeWidgetSettings,
        recomputeGeometryContracts: root._recomputeGeometryContracts,
        layoutChanged: root.layoutChanged,
        saveLayout: function() {
            saveLayout(layoutModel, persistStore, fileWriter)
        }
    })
}
