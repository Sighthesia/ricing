.pragma library

function orderedEnabledWidgetsForSection(layoutModel, sectionName, instanceKeyAtFn) {
    var widgets = []

    for (var i = 0; i < layoutModel.count; i++) {
        var item = layoutModel.get(i)

        if (!item.enabled || item.section !== sectionName)
            continue

        widgets.push({
            id: item.id,
            section: item.section,
            alignment: item.alignment,
            order: item.order,
            modelIndex: i,
            instanceKey: instanceKeyAtFn(i)
        })
    }

    widgets.sort(function(a, b) {
        if (a.order !== b.order)
            return a.order - b.order

        return a.modelIndex - b.modelIndex
    })

    return widgets
}

function slotGeometryOutput(sectionName, sectionLeft, orderedWidgets, effectiveMeasuredWidthFn, slotGeometryRecordFn) {
    var slots = []
    var currentLeft = sectionLeft

    for (var i = 0; i < orderedWidgets.length; i++) {
        var widget = orderedWidgets[i]
        var measuredWidth = effectiveMeasuredWidthFn(widget.instanceKey)

        slots.push(slotGeometryRecordFn(sectionName, {
            id: widget.id,
            instanceKey: widget.instanceKey,
            order: widget.order,
            alignment: widget.alignment,
            measuredWidth: measuredWidth
        }, i, currentLeft, measuredWidth))

        currentLeft += measuredWidth
    }

    return slots
}

function measuredContentWidth(orderedWidgets, effectiveMeasuredWidthFn) {
    var totalWidth = 0

    for (var i = 0; i < orderedWidgets.length; i++)
        totalWidth += effectiveMeasuredWidthFn(orderedWidgets[i].instanceKey)

    return Math.max(0, totalWidth)
}

function contentWidthsBySection(orderedWidgetsBySection, sectionNames, effectiveMeasuredWidthFn) {
    var contentWidths = {}

    for (var i = 0; i < sectionNames.length; i++) {
        var sectionName = sectionNames[i]
        contentWidths[sectionName] = measuredContentWidth(
            orderedWidgetsBySection[sectionName],
            effectiveMeasuredWidthFn
        )
    }

    return contentWidths
}

function slotGeometriesFromSections(sectionNames, sectionGeometries, orderedWidgetsBySection, slotGeometryOutputFn) {
    var nextSlotGeometries = {}

    for (var i = 0; i < sectionNames.length; i++) {
        var sectionName = sectionNames[i]
        nextSlotGeometries[sectionName] = slotGeometryOutputFn(
            sectionName,
            sectionGeometries[sectionName].visualLeft,
            orderedWidgetsBySection[sectionName]
        )
    }

    return nextSlotGeometries
}

function widgetGeometriesFromSlots(sectionNames, slotGeometries, widgetGeometryFromSlotFn) {
    var nextWidgetGeometries = ({})

    for (var i = 0; i < sectionNames.length; i++) {
        var sectionName = sectionNames[i]
        var slots = slotGeometries[sectionName]

        if (!Array.isArray(slots))
            continue

        for (var slotIndex = 0; slotIndex < slots.length; slotIndex++) {
            var slot = slots[slotIndex]
            nextWidgetGeometries[slot.instanceKey] = widgetGeometryFromSlotFn(sectionName, slot)
        }
    }

    return nextWidgetGeometries
}

function pickerAnchorsFromSections(sectionNames, sectionGeometries, activeSectionName, clampPickerLeftMarginFn) {
    var nextPickerAnchors = {}

    for (var i = 0; i < sectionNames.length; i++) {
        var sectionName = sectionNames[i]
        var geometry = sectionGeometries[sectionName]

        nextPickerAnchors[sectionName] = {
            section: sectionName,
            centerX: geometry.centerX,
            leftMargin: clampPickerLeftMarginFn(geometry.centerX),
            active: sectionName === activeSectionName
        }
    }

    return nextPickerAnchors
}
