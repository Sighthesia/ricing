var SECTION_ORDER = ["left", "center", "right"]

var DEFAULT_WIDGET_SOURCE_BY_ID = {
    "dynamic-island-dock-zone": "../../modules/background/DynamicIslandDockZone.qml",
}

var DEFAULT_LAYOUT_MODEL = {
    version: 1,
    widgets: [
        {
            id: "dynamic-island-dock-zone",
            instanceKey: "dynamic-island-dock-zone:0",
            section: "center",
            order: 0,
            enabled: true,
            source: "../../modules/background/DynamicIslandDockZone.qml",
        },
    ],
}

function cloneLayoutModel(layoutModel) {
    return JSON.parse(JSON.stringify(layoutModel))
}

function defaultWidgetSource(widgetId) {
    return DEFAULT_WIDGET_SOURCE_BY_ID[widgetId] || ""
}

function defaultLayoutModel() {
    return cloneLayoutModel(DEFAULT_LAYOUT_MODEL)
}

function normalizeWidgetEntry(widgetEntry, sectionName, orderIndex) {
    if (!widgetEntry || typeof widgetEntry !== "object") {
        return null
    }

    var id = typeof widgetEntry.id === "string" && widgetEntry.id ? widgetEntry.id : "widget"
    var instanceKey = typeof widgetEntry.instanceKey === "string" && widgetEntry.instanceKey
        ? widgetEntry.instanceKey
        : id + ":" + orderIndex
    var source = typeof widgetEntry.source === "string" && widgetEntry.source
        ? widgetEntry.source
        : defaultWidgetSource(id)

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

    normalized.sort(function(leftWidget, rightWidget) {
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

    return normalizedLayoutModel.widgets.filter(function(widgetEntry) {
        return widgetEntry.enabled && widgetEntry.section === sectionName
    })
}
