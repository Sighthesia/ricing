.pragma library

.import "BarLayoutGeometry.js" as GeometryUtils
.import "BarLayoutArrival.js" as ArrivalUtils
.import "BarLayoutDerive.js" as DeriveUtils
.import "BarLayoutSections.js" as SectionsUtils
.import "BarLayoutCleanup.js" as CleanupUtils

function _sectionNames() {
    return ["left", "center", "right"]
}

function sectionGeometryWithVisual(sectionName, usableBounds, contentWidths, adaptiveBounds, slotCount, visualPlacement) {
    var contract = SectionsUtils.sectionGeometryContract(sectionName, usableBounds, contentWidths, adaptiveBounds, visualPlacement)

    return GeometryUtils.clampedSectionGeometry(
        sectionName,
        contract.layoutLeft,
        contract.layoutRight,
        contract.contentWidth,
        slotCount,
        contract
    )
}

function recomputeGeometryContracts(options) {
    var sectionNames = _sectionNames()
    var usableBounds = SectionsUtils.barUsableBounds(options.barContentWidth, options.barContentPadding)
    var orderedWidgetsBySection = ({})

    for (var i = 0; i < sectionNames.length; i++) {
        var sectionName = sectionNames[i]
        orderedWidgetsBySection[sectionName] = DeriveUtils.orderedEnabledWidgetsForSection(
            options.layoutModel,
            sectionName,
            options.instanceKeyAtFn
        )
    }

    var contentWidths = DeriveUtils.contentWidthsBySection(
        orderedWidgetsBySection,
        sectionNames,
        options.effectiveMeasuredWidthFn,
        options.widgetSpacing
    )
    var adaptiveBounds = SectionsUtils.resolveAdaptiveSectionBounds(usableBounds, contentWidths)

    var nextSectionGeometries = {
        left: sectionGeometryWithVisual(
            "left",
            usableBounds,
            contentWidths,
            adaptiveBounds,
            orderedWidgetsBySection.left.length,
            SectionsUtils.resolveVisualPlacement("left", usableBounds, contentWidths, adaptiveBounds)
        ),
        center: sectionGeometryWithVisual(
            "center",
            usableBounds,
            contentWidths,
            adaptiveBounds,
            orderedWidgetsBySection.center.length,
            SectionsUtils.resolveVisualPlacement("center", usableBounds, contentWidths, adaptiveBounds)
        ),
        right: sectionGeometryWithVisual(
            "right",
            usableBounds,
            contentWidths,
            adaptiveBounds,
            orderedWidgetsBySection.right.length,
            SectionsUtils.resolveVisualPlacement("right", usableBounds, contentWidths, adaptiveBounds)
        )
    }

    var nextSlotGeometries = DeriveUtils.slotGeometriesFromSections(
        sectionNames,
        nextSectionGeometries,
        orderedWidgetsBySection,
        function(sectionName, sectionLeft, orderedWidgets) {
        return DeriveUtils.slotGeometryOutput(
            sectionName,
            sectionLeft,
            orderedWidgets,
            options.effectiveMeasuredWidthFn,
            GeometryUtils.slotGeometryRecord,
            options.widgetSpacing,
            nextSectionGeometries[sectionName]
        )
        }
    )
    var nextWidgetGeometries = DeriveUtils.widgetGeometriesFromSlots(
        sectionNames,
        nextSlotGeometries,
        GeometryUtils.widgetGeometryFromSlot
    )
    var nextSuperIslandInstanceKey = SectionsUtils.primaryInstanceKeyForWidget(
        "superIsland",
        nextSlotGeometries,
        sectionNames,
        options.barContentWidth
    )
    var nextPickerAnchors = DeriveUtils.pickerAnchorsFromSections(
        sectionNames,
        nextSectionGeometries,
        options.widgetPickerTargetSection,
        function(centerX) {
            return GeometryUtils.clampPickerLeftMargin(
                centerX,
                options.barContentPadding,
                options.barContentWidth,
                options.pickerPanelWidth
            )
        }
    )
    var nextArrivalGeometries = ArrivalUtils.syncArrivalGeometriesWithSlots(
        options.arrivalGeometries,
        nextSlotGeometries
    )

    return {
        sectionGeometries: nextSectionGeometries,
        slotGeometries: nextSlotGeometries,
        widgetGeometries: nextWidgetGeometries,
        superIslandInstanceKey: nextSuperIslandInstanceKey,
        pickerAnchors: nextPickerAnchors,
        arrivalGeometries: nextArrivalGeometries
    }
}

function layoutInstanceKeySet(layoutModel, instanceKeyAtFn) {
    return CleanupUtils.layoutInstanceKeySet(layoutModel, instanceKeyAtFn)
}

function cleanupStaleGeometryState(
    layoutModel,
    instanceKeyAtFn,
    widgetMeasuredWidths,
    widgetMeasurementMetadata,
    arrivalGeometries,
    arrivalRevealLocks,
    draggedInstanceKey
) {
    var activeInstanceKeys = layoutInstanceKeySet(layoutModel, instanceKeyAtFn)

    return CleanupUtils.cleanupStaleGeometryState(
        activeInstanceKeys,
        widgetMeasuredWidths,
        widgetMeasurementMetadata,
        arrivalGeometries,
        arrivalRevealLocks,
        draggedInstanceKey
    )
}

function insertionSlots(sectionGeometry, slots, excludeInstanceKey, widgetSpacing) {
    if (!excludeInstanceKey)
        return slots

    var filteredSlots = []
    var currentLeft = sectionGeometry.layoutLeft !== undefined ? sectionGeometry.layoutLeft : sectionGeometry.visualLeft
    var spacing = Math.max(0, Number(widgetSpacing) || 0)

    for (var i = 0; i < slots.length; i++) {
        if (slots[i].instanceKey === excludeInstanceKey)
            continue

        var slot = slots[i]
        filteredSlots.push(GeometryUtils.slotGeometryRecord(slot.section, {
            id: slot.id,
            instanceKey: slot.instanceKey,
            order: slot.order,
            alignment: slot.alignment,
            measuredWidth: slot.measuredWidth
        }, filteredSlots.length, currentLeft, slot.width, sectionGeometry))
        currentLeft += slot.width

        if (i < slots.length - 1)
            currentLeft += spacing
    }

    return filteredSlots
}
