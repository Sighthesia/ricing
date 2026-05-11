var SECTION_ORDER = ["left", "center", "right"]
var PLACEHOLDER_WIDGET_ID = "placeholder"
var LEGACY_WIDGET_IDS = {
    "dynamic-island-dock-zone": PLACEHOLDER_WIDGET_ID,
    "DynamicIslandDockZone": PLACEHOLDER_WIDGET_ID,
}

var DEFAULT_WIDGET_SOURCE_BY_ID = {
    "placeholder": "../../modules/bar/widgets/Placeholder.qml",
}

function normalizeWidgetId(widgetId, widgetSource) {
    if (typeof widgetId === "string" && LEGACY_WIDGET_IDS[widgetId]) {
        return LEGACY_WIDGET_IDS[widgetId]
    }

    if (typeof widgetSource === "string" && widgetSource.indexOf("DynamicIslandDockZone") !== -1) {
        return PLACEHOLDER_WIDGET_ID
    }

    if (typeof widgetId === "string" && widgetId) {
        return widgetId
    }

    return PLACEHOLDER_WIDGET_ID
}

function normalizeWidgetSource(widgetSource, widgetId) {
    if (typeof widgetSource === "string" && widgetSource && widgetSource.indexOf("DynamicIslandDockZone") === -1) {
        return widgetSource
    }

    return defaultWidgetSource(widgetId)
}

function normalizeWidgetInstanceKey(widgetEntry, widgetId, orderIndex) {
    var existingInstanceKey = typeof widgetEntry.instanceKey === "string" && widgetEntry.instanceKey
        ? widgetEntry.instanceKey
        : ""

    if (existingInstanceKey) {
        var instanceParts = existingInstanceKey.split(":")
        var instanceSuffix = instanceParts[instanceParts.length - 1]
        var parsedIndex = parseInt(instanceSuffix, 10)
        var normalizedIndex = !isNaN(parsedIndex) ? parsedIndex : orderIndex

        if (existingInstanceKey.indexOf("DynamicIslandDockZone") === -1 && instanceParts[0] === widgetId) {
            return existingInstanceKey
        }

        return widgetId + ":" + normalizedIndex
    }

    return widgetId + ":" + orderIndex
}

var AVAILABLE_WIDGETS = [
    {
        id: PLACEHOLDER_WIDGET_ID,
        label: "Placeholder",
        description: "Managed center placeholder widget.",
        section: "center",
        source: "../../modules/bar/widgets/Placeholder.qml",
    },
]

var DEFAULT_LAYOUT_MODEL = {
    version: 1,
    widgets: [
        {
            id: PLACEHOLDER_WIDGET_ID,
            instanceKey: "placeholder:0",
            section: "center",
            order: 0,
            enabled: true,
            source: "../../modules/bar/widgets/Placeholder.qml",
        },
    ],
}

function cloneLayoutModel(layoutModel) {
    return JSON.parse(JSON.stringify(layoutModel))
}

function defaultWidgetSource(widgetId) {
    var normalizedWidgetId = normalizeWidgetId(widgetId)
    return DEFAULT_WIDGET_SOURCE_BY_ID[normalizedWidgetId] || ""
}

function defaultLayoutModel() {
    return cloneLayoutModel(DEFAULT_LAYOUT_MODEL)
}

function availableWidgets() {
    return cloneLayoutModel(AVAILABLE_WIDGETS)
}

function availableWidget(widgetId) {
    var normalizedWidgetId = normalizeWidgetId(widgetId)

    for (var index = 0; index < AVAILABLE_WIDGETS.length; index += 1) {
        if (AVAILABLE_WIDGETS[index].id === normalizedWidgetId) {
            return AVAILABLE_WIDGETS[index]
        }
    }

    return null
}

function nextWidgetInstanceIndex(layoutModel, widgetId) {
    var normalizedLayoutModel = normalizeLayoutModel(layoutModel)
    var highestIndex = -1
    var normalizedWidgetId = normalizeWidgetId(widgetId)

    for (var index = 0; index < normalizedLayoutModel.widgets.length; index += 1) {
        var widgetEntry = normalizedLayoutModel.widgets[index]
        if (normalizeWidgetId(widgetEntry.id, widgetEntry.source) !== normalizedWidgetId) {
            continue
        }

        var instanceParts = String(widgetEntry.instanceKey || "").split(":")
        var parsedIndex = parseInt(instanceParts[instanceParts.length - 1], 10)
        if (!isNaN(parsedIndex) && parsedIndex > highestIndex) {
            highestIndex = parsedIndex
        }
    }

    return highestIndex + 1
}

function createWidgetEntry(widgetId, sectionName, layoutModel) {
    var normalizedWidgetId = normalizeWidgetId(widgetId)
    var widgetDefinition = availableWidget(normalizedWidgetId)
    if (!widgetDefinition) {
        return null
    }

    var normalizedSection = typeof sectionName === "string" && SECTION_ORDER.indexOf(sectionName) !== -1
        ? sectionName
        : widgetDefinition.section
    var nextIndex = nextWidgetInstanceIndex(layoutModel, normalizedWidgetId)

    return {
        id: widgetDefinition.id,
        instanceKey: widgetDefinition.id + ":" + nextIndex,
        section: normalizedSection,
        order: nextIndex,
        enabled: true,
        source: widgetDefinition.source,
    }
}

function addWidgetToSection(layoutModel, widgetId, sectionName) {
    var normalizedLayoutModel = normalizeLayoutModel(layoutModel)
    var widgetEntry = createWidgetEntry(widgetId, sectionName, normalizedLayoutModel)

    if (!widgetEntry) {
        return normalizedLayoutModel
    }

    var nextLayoutModel = cloneLayoutModel(normalizedLayoutModel)
    nextLayoutModel.widgets.push(widgetEntry)
    return normalizeLayoutModel(nextLayoutModel)
}

function normalizeWidgetEntry(widgetEntry, sectionName, orderIndex) {
    if (!widgetEntry || typeof widgetEntry !== "object") {
        return null
    }

    var id = normalizeWidgetId(widgetEntry.id, widgetEntry.source)
    var instanceKey = normalizeWidgetInstanceKey(widgetEntry, id, orderIndex)
    var source = normalizeWidgetSource(widgetEntry.source, id)

    return {
        id: id,
        instanceKey: instanceKey,
        section: typeof widgetEntry.section === "string" && SECTION_ORDER.indexOf(widgetEntry.section) !== -1
            ? widgetEntry.section
            : sectionName,
        order: typeof widgetEntry.order === "number" && isFinite(widgetEntry.order)
            ? widgetEntry.order
            : orderIndex,
        enabled: widgetEntry.enabled !== false,
        source: source,
    }
}

function normalizeWidgets(widgets, sectionName) {
    var normalized = []

    if (!widgets || !widgets.length) {
        return normalized
    }

    for (var index = 0; index < widgets.length; index += 1) {
        var entry = normalizeWidgetEntry(widgets[index], sectionName, index)
        if (entry) {
            normalized.push(entry)
        }
    }

    normalized.sort(function (leftWidget, rightWidget) {
        if (leftWidget.order !== rightWidget.order) {
            return leftWidget.order - rightWidget.order
        }

        if (leftWidget.instanceKey < rightWidget.instanceKey) {
            return -1
        }
        if (leftWidget.instanceKey > rightWidget.instanceKey) {
            return 1
        }

        return 0
    })

    return normalized
}

function normalizeLayoutModel(layoutModel) {
    if (!layoutModel || typeof layoutModel !== "object") {
        return defaultLayoutModel()
    }

    if (layoutModel.widgets && layoutModel.widgets.length) {
        return {
            version: 1,
            widgets: normalizeWidgets(layoutModel.widgets, "center"),
        }
    }

    if (layoutModel.widgets) {
        return {
            version: 1,
            widgets: [],
        }
    }

    var widgets = []
    for (var sectionIndex = 0; sectionIndex < SECTION_ORDER.length; sectionIndex += 1) {
        var sectionName = SECTION_ORDER[sectionIndex]
        var sectionWidgets = layoutModel[sectionName] || []
        var normalizedSectionWidgets = normalizeWidgets(sectionWidgets, sectionName)

        for (var widgetIndex = 0; widgetIndex < normalizedSectionWidgets.length; widgetIndex += 1) {
            widgets.push(normalizedSectionWidgets[widgetIndex])
        }
    }

    if (!widgets.length) {
        return defaultLayoutModel()
    }

    return {
        version: 1,
        widgets: widgets,
    }
}

function sectionWidgets(layoutModel, sectionName) {
    var normalizedLayoutModel = normalizeLayoutModel(layoutModel)

    return normalizedLayoutModel.widgets.filter(function (widgetEntry) {
        return widgetEntry.enabled && widgetEntry.section === sectionName
    })
}
