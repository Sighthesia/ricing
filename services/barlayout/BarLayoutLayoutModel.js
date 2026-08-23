var SECTION_ORDER = ["left", "center", "right"]
var LEGACY_WIDGET_IDS = {
    "dynamic-island-dock-zone": "clock",
    "DynamicIslandDockZone": "clock",
    "placeholder": "clock",
    "widget-picker-button": "clock",
}

var DEFAULT_WIDGET_SOURCE_BY_ID = {
    "clock": "../../modules/bar/widgets/Clock.qml",
    "tray": "../../modules/bar/widgets/Tray.qml",
    "active-window": "../../modules/bar/widgets/ActiveWindow.qml",
    "workspaces": "../../modules/bar/widgets/Workspaces.qml",
    "battery": "../../modules/bar/widgets/Battery.qml",
    "brightness": "../../modules/bar/widgets/Brightness.qml",
    "system-monitor": "../../modules/bar/widgets/SystemMonitor.qml",
    "volume": "../../modules/bar/widgets/Volume.qml",
    "media": "../../modules/bar/widgets/Media.qml",
    "notifications": "../../modules/bar/widgets/Notifications.qml",
    "settings": "../../modules/bar/widgets/SettingsButton.qml",
    "launcher": "../../modules/bar/widgets/LauncherButton.qml",
}

function normalizeWidgetId(widgetId, widgetSource) {
    if (typeof widgetId === "string" && LEGACY_WIDGET_IDS[widgetId]) {
        return LEGACY_WIDGET_IDS[widgetId]
    }

    if (typeof widgetSource === "string" && widgetSource.indexOf("DynamicIslandDockZone") !== -1) {
        return "clock"
    }

    if (typeof widgetId === "string" && widgetId) {
        return widgetId
    }

    return "clock"
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
        id: "clock",
        label: "Clock",
        description: "Compact date and time display.",
        section: "right",
        source: "../../modules/bar/widgets/Clock.qml",
    },
    {
        id: "tray",
        label: "System Tray",
        description: "System tray icons with menu support.",
        section: "right",
        source: "../../modules/bar/widgets/Tray.qml",
    },
    {
        id: "active-window",
        label: "Active Window",
        description: "Focused window title.",
        section: "left",
        source: "../../modules/bar/widgets/ActiveWindow.qml",
    },
    {
        id: "workspaces",
        label: "Workspaces",
        description: "Workspace overview with click to focus.",
        section: "center",
        source: "../../modules/bar/widgets/Workspaces.qml",
    },
    {
        id: "brightness",
        label: "Brightness",
        description: "Screen brightness with scroll control.",
        section: "right",
        source: "../../modules/bar/widgets/Brightness.qml",
    },
    {
        id: "battery",
        label: "Battery",
        description: "Primary battery state with percentage.",
        section: "right",
        source: "../../modules/bar/widgets/Battery.qml",
    },
    {
        id: "system-monitor",
        label: "System Monitor",
        description: "Compact CPU and memory usage readout.",
        section: "right",
        source: "../../modules/bar/widgets/SystemMonitor.qml",
    },
    {
        id: "volume",
        label: "Volume",
        description: "Audio volume with scroll and mute.",
        section: "right",
        source: "../../modules/bar/widgets/Volume.qml",
    },
    {
        id: "bluetooth",
        label: "Bluetooth",
        description: "Bluetooth adapter power, scan, and device list.",
        section: "right",
        source: "../../modules/bar/widgets/Bluetooth.qml",
    },
    {
        id: "network",
        label: "Wi-Fi",
        description: "Wi-Fi power, scan, and network list.",
        section: "right",
        source: "../../modules/bar/widgets/Network.qml",
    },
    {
        id: "media",
        label: "Media",
        description: "Compact now playing with lyric priority.",
        section: "left",
        source: "../../modules/bar/widgets/Media.qml",
    },
    {
        id: "notifications",
        label: "Notifications",
        description: "Unread badge with do-not-disturb toggle.",
        section: "right",
        source: "../../modules/bar/widgets/Notifications.qml",
    },
    {
        id: "settings",
        label: "Settings",
        description: "Open the shell settings center.",
        section: "right",
        source: "../../modules/bar/widgets/SettingsButton.qml",
    },
    {
        id: "launcher",
        label: "Launcher",
        description: "Toggle the app launcher search.",
        section: "left",
        source: "../../modules/bar/widgets/LauncherButton.qml",
    },
]

var DEFAULT_LAYOUT_MODEL = {
    version: 1,
    widgets: [
        { id: "launcher", instanceKey: "launcher:0", section: "left", order: 0, enabled: true, source: "../../modules/bar/widgets/LauncherButton.qml" },
        { id: "active-window", instanceKey: "active-window:0", section: "left", order: 1, enabled: true, source: "../../modules/bar/widgets/ActiveWindow.qml" },
        { id: "media", instanceKey: "media:0", section: "left", order: 2, enabled: true, source: "../../modules/bar/widgets/Media.qml" },
        { id: "workspaces", instanceKey: "workspaces:0", section: "center", order: 0, enabled: true, source: "../../modules/bar/widgets/Workspaces.qml" },
        { id: "tray", instanceKey: "tray:0", section: "right", order: 0, enabled: true, source: "../../modules/bar/widgets/Tray.qml" },
        { id: "volume", instanceKey: "volume:0", section: "right", order: 1, enabled: true, source: "../../modules/bar/widgets/Volume.qml" },
        { id: "brightness", instanceKey: "brightness:0", section: "right", order: 2, enabled: true, source: "../../modules/bar/widgets/Brightness.qml" },
        { id: "notifications", instanceKey: "notifications:0", section: "right", order: 3, enabled: true, source: "../../modules/bar/widgets/Notifications.qml" },
        { id: "settings", instanceKey: "settings:0", section: "right", order: 4, enabled: true, source: "../../modules/bar/widgets/SettingsButton.qml" },
        { id: "clock", instanceKey: "clock:0", section: "right", order: 5, enabled: true, source: "../../modules/bar/widgets/Clock.qml" },
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

// Remove a widget by instanceKey and return the updated layout model.
function removeWidgetByKey(layoutModel, instanceKey) {
    var normalizedLayoutModel = normalizeLayoutModel(layoutModel)

    var nextWidgets = normalizedLayoutModel.widgets.filter(function (widgetEntry) {
        return widgetEntry.instanceKey !== instanceKey
    })

    if (nextWidgets.length === normalizedLayoutModel.widgets.length) {
        return normalizedLayoutModel
    }

    return normalizeLayoutModel({ version: 1, widgets: nextWidgets })
}

// Move a widget to a new position within the same section (reorder).
// toOrder is the target index among same-section widgets.
function moveWidgetInSection(layoutModel, instanceKey, toOrder) {
    var normalizedLayoutModel = normalizeLayoutModel(layoutModel)
    var widgets = normalizedLayoutModel.widgets

    var movingWidget = null
    var sectionWidgetsList = []

    for (var i = 0; i < widgets.length; i++) {
        if (widgets[i].instanceKey === instanceKey) {
            movingWidget = cloneLayoutModel(widgets[i])
        }
        if (movingWidget && widgets[i].section === movingWidget.section && widgets[i].instanceKey !== instanceKey) {
            sectionWidgetsList.push(cloneLayoutModel(widgets[i]))
        }
    }

    // Second pass if movingWidget was found late
    if (movingWidget) {
        sectionWidgetsList = []
        for (var j = 0; j < widgets.length; j++) {
            if (widgets[j].section === movingWidget.section && widgets[j].instanceKey !== instanceKey) {
                sectionWidgetsList.push(cloneLayoutModel(widgets[j]))
            }
        }
    }

    if (!movingWidget) {
        return normalizedLayoutModel
    }

    // Clamp toOrder
    var clampedOrder = Math.max(0, Math.min(toOrder, sectionWidgetsList.length))

    // Insert at the target position
    sectionWidgetsList.splice(clampedOrder, 0, movingWidget)

    // Reassign order values
    for (var k = 0; k < sectionWidgetsList.length; k++) {
        sectionWidgetsList[k].order = k
    }

    // Rebuild full widget list: keep other sections unchanged, replace this section
    var otherWidgets = widgets.filter(function (w) {
        return w.section !== movingWidget.section
    }).map(function (w) { return cloneLayoutModel(w) })

    var allWidgets = otherWidgets.concat(sectionWidgetsList)
    return normalizeLayoutModel({ version: 1, widgets: allWidgets })
}

// Move a widget to a different section at a given order position.
function moveWidgetToSection(layoutModel, instanceKey, toSection, toOrder) {
    var normalizedLayoutModel = normalizeLayoutModel(layoutModel)
    var widgets = normalizedLayoutModel.widgets

    var movingWidget = null
    for (var i = 0; i < widgets.length; i++) {
        if (widgets[i].instanceKey === instanceKey) {
            movingWidget = cloneLayoutModel(widgets[i])
            break
        }
    }

    if (!movingWidget) {
        return normalizedLayoutModel
    }

    // If same section, delegate to in-section reorder
    if (movingWidget.section === toSection) {
        return moveWidgetInSection(layoutModel, instanceKey, toOrder)
    }

    // Collect target section widgets (excluding the moving one)
    var targetSectionWidgets = []
    for (var j = 0; j < widgets.length; j++) {
        if (widgets[j].section === toSection && widgets[j].instanceKey !== instanceKey) {
            targetSectionWidgets.push(cloneLayoutModel(widgets[j]))
        }
    }

    // Update moving widget's section
    movingWidget.section = toSection

    // Insert at target position
    var clampedOrder = Math.max(0, Math.min(toOrder, targetSectionWidgets.length))
    targetSectionWidgets.splice(clampedOrder, 0, movingWidget)

    // Reassign order values for target section
    for (var k = 0; k < targetSectionWidgets.length; k++) {
        targetSectionWidgets[k].order = k
    }

    // Rebuild: keep widgets from other sections (excluding moving widget), add target section
    var otherWidgets = widgets.filter(function (w) {
        return w.section !== toSection && w.instanceKey !== instanceKey
    }).map(function (w) { return cloneLayoutModel(w) })

    // Renormalize source section orders
    var sourceSection = movingWidget.section
    // Actually the source section is the original section before move
    var originalSection = null
    for (var m = 0; m < widgets.length; m++) {
        if (widgets[m].instanceKey === instanceKey) {
            originalSection = widgets[m].section
            break
        }
    }

    if (originalSection && originalSection !== toSection) {
        var sourceSectionWidgets = otherWidgets.filter(function (w) {
            return w.section === originalSection
        })
        sourceSectionWidgets.sort(function (a, b) { return a.order - b.order })
        for (var n = 0; n < sourceSectionWidgets.length; n++) {
            sourceSectionWidgets[n].order = n
        }
    }

    var allWidgets = otherWidgets.concat(targetSectionWidgets)
    return normalizeLayoutModel({ version: 1, widgets: allWidgets })
}
