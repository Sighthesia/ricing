var DEFAULT_LAYOUT_MODEL = {
    left: [],
    center: [
        {
            id: "dynamic-island-dock-zone",
            source: "../../modules/background/DynamicIslandDockZone.qml",
        },
    ],
    right: [],
}

function defaultLayoutModel() {
    return DEFAULT_LAYOUT_MODEL
}

function sectionWidgets(layoutModel, sectionName) {
    if (!layoutModel || !layoutModel[sectionName]) {
        return []
    }

    return layoutModel[sectionName]
}
