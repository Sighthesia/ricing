import Quickshell
import QtQuick
import qs.config
import qs.modules.bar
import qs.services

// Smoke harness for the first shared bar-layout geometry contract.
ShellRoot {
    id: root

    property Item _barContent: null
    property Item _dragOverlayProbe: null
    property Item _teardownWrapperProbe: null
    property Item _handoffOldWrapperProbe: null
    property Item _handoffNewWrapperProbe: null
    property var _waitCondition: null
    property var _waitSuccess: null
    property string _waitFailureMessage: ""
    property int _waitAttemptsRemaining: 0

    function _findDescendantByRole(node, roleName) {
        if (!node || !node.children) {
            return null
        }

        for (let i = 0; i < node.children.length; i++) {
            let child = node.children[i]

            if (child && child.role === roleName) {
                return child
            }

            let nested = _findDescendantByRole(child, roleName)
            if (nested) {
                return nested
            }
        }

        return null
    }

    function _findDescendantByObjectName(node, objectName) {
        if (!node || !node.children) {
            return null
        }

        for (let i = 0; i < node.children.length; i++) {
            let child = node.children[i]

            if (child && child.objectName === objectName) {
                return child
            }

            let nested = _findDescendantByObjectName(child, objectName)
            if (nested) {
                return nested
            }
        }

        return null
    }

    function _findDescendantByZoneName(node, zoneName) {
        if (!node || !node.children) {
            return null
        }

        for (let i = 0; i < node.children.length; i++) {
            let child = node.children[i]

            if (child && child.zoneName === zoneName) {
                return child
            }

            let nested = _findDescendantByZoneName(child, zoneName)
            if (nested) {
                return nested
            }
        }

        return null
    }

    function _findDescendant(node, predicate) {
        if (!node || !node.children) {
            return null
        }

        for (let i = 0; i < node.children.length; i++) {
            let child = node.children[i]

            if (child && predicate(child)) {
                return child
            }

            let nested = _findDescendant(child, predicate)
            if (nested) {
                return nested
            }
        }

        return null
    }

    function _findDirectChild(node, predicate) {
        if (!node || !node.children) {
            return null
        }

        for (let i = 0; i < node.children.length; i++) {
            let child = node.children[i]
            if (child && predicate(child)) {
                return child
            }
        }

        return null
    }

    function _findWrappersForSection(sectionItem) {
        let wrappers = []

        if (!sectionItem) {
            return wrappers
        }

        let widgetRow = root._findDirectChild(sectionItem, child => typeof child.spacing === "number")
        if (!widgetRow || !widgetRow.children) {
            return wrappers
        }

        for (let i = 0; i < widgetRow.children.length; i++) {
            let child = widgetRow.children[i]
            if (!child || typeof child.widgetId !== "string" || child.widgetId === "") {
                continue
            }

            wrappers.push(child)
        }

        return wrappers
    }

    function _assert(condition, message) {
        if (!condition)
            throw new Error(message)
    }

    function _waitUntil(condition, onSuccess, failureMessage, attempts, interval) {
        root._waitCondition = condition
        root._waitSuccess = onSuccess
        root._waitFailureMessage = failureMessage
        root._waitAttemptsRemaining = attempts || 120
        waitTimer.interval = interval || 16
        waitTimer.restart()
    }

    function _approxEqual(a, b, tolerance) {
        return Math.abs(a - b) <= tolerance
    }

    function _finishSuccess() {
        console.log("BarLayoutGeometry smoke test passed")
        Qt.callLater(Qt.quit)
    }

    function _instanceKeyForWidgetId(widgetId) {
        for (let i = BarLayoutService.layoutModel.count - 1; i >= 0; i--) {
            let item = BarLayoutService.layoutModel.get(i)
            if (item.id === widgetId) {
                return item.instanceKey
            }
        }

        return ""
    }

    function _slotForInstance(sectionName, instanceKey) {
        let slots = BarLayoutService.sectionSlots(sectionName)
        for (let i = 0; i < slots.length; i++) {
            if (slots[i].instanceKey === instanceKey) {
                return slots[i]
            }
        }

        return null
    }

    function _runRemovalCleanupAssertions(instanceKey, widgetId, sectionName) {
        BarLayoutService.setWidgetMeasuredWidth(instanceKey, 133)
        BarLayoutService.beginDrag(instanceKey, widgetId, 140)
        BarLayoutService.removeWidget(instanceKey)

        let remainingSlots = BarLayoutService.sectionSlots(sectionName)
        let removedSlot = remainingSlots.find(slot => slot.instanceKey === instanceKey)

        root._assert(BarLayoutService.measuredWidthForInstance(instanceKey) === 0,
            "BarLayoutService should clear cached widget width when a layout entry is removed")
        root._assert(removedSlot === undefined,
            "BarLayoutService should remove stale slot geometry when a layout entry is removed")
        root._assert(BarLayoutService.dragSnapshot.active === false,
            "BarLayoutService should clear drag state when the removed widget is the active drag instance")
        root._assert(BarLayoutService.dragSnapshot.instanceKey === "",
            "BarLayoutService should drop the removed drag instance key from dragSnapshot")

        root._runReporterHandoffAssertions()
    }

    function _runReporterHandoffAssertions() {
        BarLayoutService.resetLayout()
        BarLayoutService.addWidget("clock", "left")

        let clockInstanceKey = root._instanceKeyForWidgetId("clock")

        root._handoffOldWrapperProbe = Qt.createQmlObject(`
            import QtQuick
            import qs.modules.bar

            BarWidgetWrapper {
                instanceKey: "${clockInstanceKey}"
                widgetId: "clock"

                Rectangle {
                    width: 123
                    height: 24
                }
            }
        `, root, "BarWidgetWrapperOldReporterProbe")

        Qt.callLater(() => {
            root._assert(BarLayoutService.measuredWidthForInstance(clockInstanceKey) === 123,
                "BarLayoutGeometry smoke should seed the old delegate width before reporter handoff")

            root._handoffNewWrapperProbe = Qt.createQmlObject(`
                import QtQuick
                import qs.modules.bar

                BarWidgetWrapper {
                    instanceKey: "${clockInstanceKey}"
                    widgetId: "clock"

                    Rectangle {
                        width: 171
                        height: 24
                    }
                }
            `, root, "BarWidgetWrapperNewReporterProbe")

            Qt.callLater(() => {
                root._assert(BarLayoutService.measuredWidthForInstance(clockInstanceKey) === 171,
                    "BarLayoutService should allow a replacement delegate to take over width reporting for the same instance key")

                root._handoffOldWrapperProbe.destroy()
                root._handoffOldWrapperProbe = null

                Qt.callLater(() => {
                    root._assert(BarLayoutService.measuredWidthForInstance(clockInstanceKey) === 171,
                        "BarLayoutService should keep the replacement delegate width after the older delegate is destroyed")

                    root._handoffNewWrapperProbe.destroy()
                    root._handoffNewWrapperProbe = null

                    Qt.callLater(() => {
                        root._assert(BarLayoutService.measuredWidthForInstance(clockInstanceKey) === 0,
                            "BarLayoutService should clear the width only after the active replacement delegate is also destroyed")

                        root._finishSuccess()
                    })
                })
            })
        })
    }

    function _runArrivalAssertions() {
        BarLayoutService.resetLayout()
        BarLayoutService.setBarMetrics(360, 24)
        BarLayoutService.activePanel = "layout"
        BarLayoutService.addWidget("clock", "left")
        BarLayoutService.addWidget("mediaControl", "left")

        root._waitUntil(
            () => {
                let leftSection = root._findDescendantByRole(root._barContent, "left")
                let wrappers = root._findWrappersForSection(leftSection)

                return wrappers.length >= 3
                    && wrappers[1]._naturalWidth > 0
                    && wrappers[2]._naturalWidth > 0
            },
            () => {
                let leftSection = root._findDescendantByRole(root._barContent, "left")
                let wrappers = root._findWrappersForSection(leftSection)
                let baseWrapper = wrappers[0]
                let firstArrivingWrapper = wrappers[1]
                let secondArrivingWrapper = wrappers[2]
                let firstArrival = BarLayoutService.arrivalGeometry(firstArrivingWrapper.instanceKey)
                let secondArrival = BarLayoutService.arrivalGeometry(secondArrivingWrapper.instanceKey)
                let firstActor = root._findDescendant(root._barContent,
                    child => child
                        && child.objectName === "dragOverlayArrivalActor"
                        && child.instanceKey === firstArrivingWrapper.instanceKey)
                let secondActor = root._findDescendant(root._barContent,
                    child => child
                        && child.objectName === "dragOverlayArrivalActor"
                        && child.instanceKey === secondArrivingWrapper.instanceKey)

                root._assert(typeof BarLayoutService.arrivalGeometry === "function",
                    "BarLayoutService should expose arrivalGeometry() for overlay-arrival handoff")
                root._assert(firstArrival !== null && firstArrival.active === true,
                    "BarLayoutService should publish an active overlay-arrival snapshot for the first inserted widget")
                root._assert(secondArrival !== null && secondArrival.active === true,
                    "BarLayoutService should publish an active overlay-arrival snapshot for the later inserted widget")
                root._assert(firstArrival.widgetId === "clock" && firstArrival.phase === "overlay",
                    "First overlay-arrival snapshot should describe the widget id and overlay handoff phase")
                root._assert(secondArrival.widgetId === "mediaControl" && secondArrival.phase === "overlay",
                    "Later overlay-arrival snapshot should describe the widget id and overlay handoff phase")
                root._assert(firstArrivingWrapper.opacity <= 0.01,
                    "Inserted widget should remain hidden while its overlay-arrival snapshot is still active")
                root._assert(secondArrivingWrapper.opacity <= 0.01,
                    "Later inserted widget should remain hidden while its overlay-arrival snapshot is still active")
                root._assert(firstActor !== null && firstActor.visible,
                    "DragOverlay should render an overlay arrival actor for the first inserted widget")
                root._assert(secondActor !== null && secondActor.visible,
                    "DragOverlay should render an overlay arrival actor for the later inserted widget")
                root._assert(root._approxEqual(firstActor.x, firstArrival.barLeft, 0.5)
                        && root._approxEqual(firstActor.width, firstArrival.barWidth, 0.5),
                    "Overlay arrival actor should use the first widget's service-owned slot geometry")
                        root._assert(root._approxEqual(secondActor.x, secondArrival.barLeft, 0.5)
                                && root._approxEqual(secondActor.width, secondArrival.barWidth, 0.5),
                            "Overlay arrival actor should use the later widget's service-owned slot geometry")
                        root._assert(secondArrivingWrapper.opacity <= 0.01,
                            "Later inserted widget should stay hidden until the earlier overlay handoff has released reveal order")

                root._waitUntil(
                    () => {
                        let refreshedLeftSection = root._findDescendantByRole(root._barContent, "left")
                        let refreshedWrappers = root._findWrappersForSection(refreshedLeftSection)
                        if (refreshedWrappers.length < 3) {
                            return false
                        }

                        let firstWrapper = refreshedWrappers[1]
                        let secondWrapper = refreshedWrappers[2]
                        let firstArrival = BarLayoutService.arrivalGeometry(firstWrapper.instanceKey)
                        let secondArrival = BarLayoutService.arrivalGeometry(secondWrapper.instanceKey)
                        return firstArrival !== null
                            && firstArrival.phase === "delegate"
                            && firstArrival.delegateReleased === true
                            && BarLayoutService.revealLockHolder("left") === firstWrapper.instanceKey
                            && firstWrapper.opacity > 0.01
                            && secondArrival !== null
                            && secondArrival.active === true
                            && secondArrival.phase === "overlay"
                            && secondWrapper.opacity <= 0.01
                    },
                    () => {
                        let revealedLeftSection = root._findDescendantByRole(root._barContent, "left")
                        let revealedWrappers = root._findWrappersForSection(revealedLeftSection)
                        let firstWrapper = revealedWrappers[1]
                        let secondWrapper = revealedWrappers[2]
                        let firstArrival = BarLayoutService.arrivalGeometry(firstWrapper.instanceKey)
                        let secondArrival = BarLayoutService.arrivalGeometry(secondWrapper.instanceKey)

                        root._assert(firstArrival !== null && firstArrival.phase === "delegate",
                            "First inserted widget should receive the delegate baton before the later widget")
                        root._assert(firstWrapper.opacity > 0.01,
                            "First inserted widget should begin reveal while the later widget still waits")
                        root._assert(secondArrival !== null && secondArrival.phase === "overlay",
                            "Later inserted widget should remain in overlay phase until the earlier reveal completes")
                        root._assert(secondWrapper.opacity <= 0.01,
                            "Later inserted widget should stay hidden until the earlier delegate finishes enter")

                        root._waitUntil(
                            () => {
                                let settledLeftSection = root._findDescendantByRole(root._barContent, "left")
                                let settledWrappers = root._findWrappersForSection(settledLeftSection)
                                if (settledWrappers.length < 3) {
                                    return false
                                }

                                let firstArrival = BarLayoutService.arrivalGeometry(settledWrappers[1].instanceKey)
                                let secondArrival = BarLayoutService.arrivalGeometry(settledWrappers[2].instanceKey)
                                let firstActor = root._findDescendant(root._barContent,
                                    child => child
                                        && child.objectName === "dragOverlayArrivalActor"
                                        && child.instanceKey === settledWrappers[1].instanceKey)
                                let secondActor = root._findDescendant(root._barContent,
                                    child => child
                                        && child.objectName === "dragOverlayArrivalActor"
                                        && child.instanceKey === settledWrappers[2].instanceKey)

                                return firstArrival === null
                                    && secondArrival === null
                                    && firstActor === null
                                    && secondActor === null
                                    && settledWrappers[1].opacity > 0.01
                                    && settledWrappers[2].opacity > 0.01
                            },
                            () => {
                                let finalLeftSection = root._findDescendantByRole(root._barContent, "left")
                                let finalWrappers = root._findWrappersForSection(finalLeftSection)
                                let revealedFirstWrapper = finalWrappers[1]
                                let revealedSecondWrapper = finalWrappers[2]
                                let revealedFirstSlot = root._slotForInstance("left", revealedFirstWrapper.instanceKey)
                                let revealedSecondSlot = root._slotForInstance("left", revealedSecondWrapper.instanceKey)

                                root._assert(revealedFirstWrapper.width + 0.5 >= revealedFirstWrapper._naturalWidth,
                                    "Inserted left-section widget should occupy its natural width on the first visible layout tick")
                                root._assert(revealedSecondWrapper.width + 0.5 >= revealedSecondWrapper._naturalWidth,
                                    "Later inserted left-section widget should not render wider content than its first layout box")
                                root._assert(revealedFirstSlot !== null && revealedSecondSlot !== null,
                                    "BarLayoutService should keep left-section slot geometry for both revealed widgets")
                                root._assert(revealedSecondSlot.left + 0.5 >= revealedFirstSlot.right,
                                    "Inserted widget should not begin by overlapping the previous left-section widget")

                                root._runTeardownCleanupAssertions()
                            },
                            "Inserted left-section widgets did not reveal after their serial overlay-arrival handoff completed",
                            Math.ceil((Theme.anim.enterDuration * 3 + Theme.staggerDelay * 8 + 320) / 16),
                            16
                        )
                    },
                    "First inserted widget did not start reveal before the later widget in the serial overlay-arrival handoff",
                    Math.ceil((Theme.anim.enterDuration * 2 + Theme.staggerDelay * 6 + 240) / 16),
                    16
                )
            },
            "Inserted left-section widgets did not reach the overlay-arrival hidden state in time",
            Math.ceil((Theme.anim.enterDuration + Theme.staggerDelay * 6 + 160) / 16),
            16
        )
    }

    function _runTeardownCleanupAssertions() {
        BarLayoutService.resetLayout()
        BarLayoutService.addWidget("clock", "left")
        let clockInstanceKey = root._instanceKeyForWidgetId("clock")

        root._teardownWrapperProbe = Qt.createQmlObject(`
            import QtQuick
            import qs.modules.bar

            BarWidgetWrapper {
                instanceKey: "${clockInstanceKey}"
                widgetId: "clock"

                Rectangle {
                    width: 123
                    height: 24
                }
            }
        `, root, "BarWidgetWrapperTeardownProbe")

        Qt.callLater(() => {
            root._assert(clockInstanceKey !== "",
                "BarLayoutGeometry smoke should resolve the runtime instance key for the teardown probe")
            root._assert(BarLayoutService.measuredWidthForInstance(clockInstanceKey) > 0,
                "BarWidgetWrapper should report its measured width into BarLayoutService before teardown")

            root._teardownWrapperProbe.destroy()
            root._teardownWrapperProbe = null

            Qt.callLater(() => {
                root._assert(BarLayoutService.measuredWidthForInstance(clockInstanceKey) === 0,
                    "BarLayoutService should clear cached widget width when a widget delegate is destroyed")
                root._runRemovalCleanupAssertions(clockInstanceKey, "clock", "left")
            })
        })
    }

    Component.onCompleted: {
        BarLayoutService.resetLayout()
        BarLayoutService.addWidget("notificationBell", "right")
        BarLayoutService.setBarMetrics(360, 24)
        BarLayoutService.setWidgetMeasuredWidth("workspaceWidget_0", 170)
        BarLayoutService.setWidgetMeasuredWidth("superIsland_0", 120)
        BarLayoutService.widgetPickerTargetSection = "left"
        BarLayoutService.setWidgetMeasuredWidth("notificationBell_0", 70)

        root._barContent = Qt.createQmlObject(`
            import QtQuick
            import qs.modules.bar

            BarContent {
                width: 360
                height: 48
            }
        `, root, "BarContentGeometryProbe")

        let geometry = BarLayoutService.sectionGeometry("left")
        let centerGeometry = BarLayoutService.sectionGeometry("center")
        let rightGeometry = BarLayoutService.sectionGeometry("right")
        let renderedLeftSection = root._findDescendantByRole(root._barContent, "left")
        let renderedCenterSection = root._findDescendantByRole(root._barContent, "center")
        let renderedRightSection = root._findDescendantByRole(root._barContent, "right")
        let renderedCenterRow = root._findDirectChild(renderedCenterSection,
            child => typeof child.spacing === "number")
        let midpoint = BarLayoutService.barContentWidth / 2
        let usableLeft = BarLayoutService.barContentPadding
        let usableRight = BarLayoutService.barContentWidth - BarLayoutService.barContentPadding

        root._assert(typeof BarLayoutService.sectionGeometry === "function",
            "BarLayoutService should expose sectionGeometry()")

        root._assert(typeof BarLayoutService.pickerAnchorGeometry === "function",
            "BarLayoutService should expose pickerAnchorGeometry()")

        root._assert(typeof BarLayoutService.barContentWidth === "number",
            "BarLayoutService should expose runtime bar content width")
        root._assert(typeof BarLayoutService.barContentPadding === "number",
            "BarLayoutService should expose runtime bar content padding")
        root._assert(typeof BarLayoutService.geometrySections === "object",
            "BarLayoutService should expose runtime section geometry state")
        root._assert(typeof BarLayoutService.geometryPickerAnchors === "object",
            "BarLayoutService should expose runtime picker-anchor state")
        root._assert(geometry !== undefined && geometry !== null,
            "BarLayoutService.sectionGeometry() should return an object")
        root._assert(typeof centerGeometry.visualLeft === "number",
            "BarLayoutService should expose center visual geometry")
        root._assert(typeof centerGeometry.visualWidth === "number",
            "BarLayoutService should expose center visual width")
        root._assert(typeof centerGeometry.visualCenterX === "number",
            "BarLayoutService should expose center visual midpoint")

        let anchor = BarLayoutService.pickerAnchorGeometry("left")
        root._assert(anchor !== undefined && anchor !== null,
            "BarLayoutService should publish picker anchor state")
        root._assert(anchor.active === true,
            "BarLayoutService picker anchor should track the active target section")
        root._assert(typeof anchor.centerX === "number",
            "BarLayoutService picker anchor should include a numeric center position")
        root._assert(typeof anchor.leftMargin === "number",
            "BarLayoutService picker anchor should include a numeric left margin")
        root._assert(anchor.centerX === geometry.centerX,
            "BarLayoutService picker anchor should derive from section geometry state")

        root._assert(root._approxEqual(geometry.left, usableLeft, 0.5),
            "BarLayoutService should anchor the left frame to the usable left edge")
        root._assert(root._approxEqual(rightGeometry.right, usableRight, 0.5),
            "BarLayoutService should anchor the right frame to the usable right edge")
        root._assert(root._approxEqual(geometry.right, centerGeometry.left, 0.5),
            "BarLayoutService should make the left and center frames meet without a gap")
        root._assert(root._approxEqual(centerGeometry.right, rightGeometry.left, 0.5),
            "BarLayoutService should make the center and right frames meet without a gap")

        let equalThirdWidth = (BarLayoutService.barContentWidth - 2 * BarLayoutService.barContentPadding) / 3
        root._assert(!root._approxEqual(geometry.width, equalThirdWidth, 0.5),
            "BarLayoutService should no longer keep the left region at an equal-third width")
        root._assert(!root._approxEqual(rightGeometry.width, equalThirdWidth, 0.5),
            "BarLayoutService should no longer keep the right region at an equal-third width")
        root._assert(root._approxEqual(centerGeometry.centerX, midpoint, 0.5),
            "BarLayoutService should keep the center region visually centered on the bar midpoint")
        root._assert(root._approxEqual(centerGeometry.visualCenterX, midpoint, 0.5),
            "BarLayoutService should keep center visual content centered on the bar midpoint")
        root._assert(root._approxEqual(centerGeometry.visualLeft + centerGeometry.visualWidth / 2,
            centerGeometry.visualCenterX, 0.5),
            "BarLayoutService visual geometry should stay internally centered")
        root._assert(renderedLeftSection !== null,
            "BarLayoutGeometry smoke should locate the rendered left section")
        root._assert(renderedCenterSection !== null,
            "BarLayoutGeometry smoke should locate the rendered center section")
        root._assert(renderedRightSection !== null,
            "BarLayoutGeometry smoke should locate the rendered right section")
        root._assert(renderedCenterRow !== null,
            "BarLayoutGeometry smoke should locate the center section widget row")
        root._assert(root._approxEqual(renderedLeftSection.x, geometry.left, 0.5),
            "BarContent should place the left section from the service frame geometry")
        root._assert(root._approxEqual(renderedCenterSection.x,
            centerGeometry.left, 0.5),
            "BarContent should place the center section from the service frame geometry")
        root._assert(root._approxEqual(renderedRightSection.x, rightGeometry.left, 0.5),
            "BarContent should place the right section from the service frame geometry")
        root._assert(root._approxEqual(renderedLeftSection.width, geometry.width, 0.5),
            "BarSection should use the left frame width instead of collapsing to content width")
        root._assert(root._approxEqual(renderedCenterSection.width, centerGeometry.width, 0.5),
            "BarSection should use the center frame width instead of content width")
        root._assert(root._approxEqual(renderedRightSection.width, rightGeometry.width, 0.5),
            "BarSection should use the right frame width instead of collapsing to content width")
        root._assert(centerGeometry.width < centerGeometry.visualWidth,
            "BarLayoutService should shrink center interaction width when side content expands")
        root._assert(centerGeometry.visualLeft < centerGeometry.left,
            "BarLayoutService should allow the centered visual band to extend left of a narrowed frame")
        root._assert(root._approxEqual(renderedCenterRow.x,
            centerGeometry.visualLeft - centerGeometry.left, 0.5),
            "BarSection should preserve the centered visual-band offset even when it is negative")
        root._assert(centerGeometry.width >= 0 && geometry.width >= 0 && rightGeometry.width >= 0,
            "BarLayoutService should clamp section widths to non-negative values")
        root._assert(root._barContent.hitTestSection(geometry.right - 1) === "left",
            "BarContent should use service-backed adaptive boundaries for left hit testing")
        root._assert(root._barContent.hitTestSection(centerGeometry.centerX) === "center",
            "BarContent should map the bar midpoint to the centered section")

        BarLayoutService.widgetPickerTargetSection = "center"
        let centerAnchor = BarLayoutService.pickerAnchorGeometry("center")
        root._assert(BarLayoutService.widgetPickerLeftMargin === centerAnchor.leftMargin,
            "BarLayoutService should keep picker placement aligned with service-backed anchor geometry")

        BarLayoutService.resetLayout()
        BarLayoutService.addWidget("clock", "left")
        BarLayoutService.addWidget("mediaControl", "left")
        BarLayoutService.setWidgetMeasuredWidth("workspaceWidget_0", 90)
        BarLayoutService.setWidgetMeasuredWidth("clock_0", 140)
        BarLayoutService.setWidgetMeasuredWidth("mediaControl_0", 80)

        let leftSection = root._findDescendantByRole(root._barContent, "left")
        root._assert(leftSection !== null,
            "BarLayoutGeometry smoke should locate the rendered left section")
        root._assert(typeof BarLayoutService.insertionIndexForSectionX === "function",
            "BarLayoutService should expose insertionIndexForSectionX() for slot-backed insertion targeting")
        root._assert(typeof BarLayoutService.insertionIndicatorGeometry === "function",
            "BarLayoutService should expose insertionIndicatorGeometry() for slot-backed insertion visuals")

        let insertionBoundaryBefore = BarLayoutService.insertionIndicatorGeometry("left", 1)
        let indexBefore = leftSection.insertIndexAt(insertionBoundaryBefore.sectionLocalX + 1)

        BarLayoutService.setWidgetMeasuredWidth("workspaceWidget_0", 150)
        BarLayoutService.setWidgetMeasuredWidth("clock_0", 100)

        let insertionBoundaryAfter = BarLayoutService.insertionIndicatorGeometry("left", 1)
        let indexAfter = leftSection.insertIndexAt(insertionBoundaryAfter.sectionLocalX + 1)

        root._assert(indexBefore === 1,
            "BarSection should resolve the first logical insertion boundary before sibling widths change")
        root._assert(indexAfter === 1,
            "BarSection should resolve the same logical insertion boundary after sibling widths change")
        root._assert(indexBefore === indexAfter,
            "Insertion index should stay stable when sibling widths change")

        BarLayoutService.resetLayout()
        BarLayoutService.addWidget("clock", "left")
        BarLayoutService.addWidget("clock", "right")

        let duplicateClockKeys = []
        for (let i = 0; i < BarLayoutService.layoutModel.count; i++) {
            let item = BarLayoutService.layoutModel.get(i)
            if (item.id === "clock") {
                duplicateClockKeys.push(item.instanceKey)
            }
        }

        let leftClockKey = duplicateClockKeys[0]
        let rightClockKey = duplicateClockKeys[1]

        root._assert(BarLayoutService.isSamePlacement(leftClockKey, "left", 1, "left"),
            "BarLayoutService should report placement by stable instance key for the first duplicate")
        root._assert(!BarLayoutService.isSamePlacement(rightClockKey, "left", 1, "left"),
            "BarLayoutService should not treat a different duplicate instance as already occupying that slot")

        BarLayoutService.moveWidget(rightClockKey, "left", "left", 0)

        let workspaceSection = ""
        let workspaceOrder = -1
        let firstClockSection = ""
        let firstClockOrder = -1
        let movedClockSection = ""
        let movedClockOrder = -1

        for (let i = 0; i < BarLayoutService.layoutModel.count; i++) {
            let item = BarLayoutService.layoutModel.get(i)
            if (item.instanceKey === "workspaceWidget_0") {
                workspaceSection = item.section
                workspaceOrder = item.order
            } else if (item.instanceKey === leftClockKey) {
                firstClockSection = item.section
                firstClockOrder = item.order
            } else if (item.instanceKey === rightClockKey) {
                movedClockSection = item.section
                movedClockOrder = item.order
            }
        }

        root._assert(workspaceSection === "left" && workspaceOrder === 1,
            "BarLayoutService should keep the original left-side instance in place when moving a duplicate")
        root._assert(firstClockSection === "left" && firstClockOrder === 2,
            "BarLayoutService should keep the existing left duplicate instead of moving the wrong instance")
        root._assert(movedClockSection === "left" && movedClockOrder === 0,
            "BarLayoutService should move the targeted duplicate instance by instance key")

        let duplicateIndicator = BarLayoutService.insertionIndicatorGeometry("left", 1, rightClockKey)
        root._assert(typeof duplicateIndicator.sectionLocalX === "number",
            "BarLayoutService insertion indicator should expose section-local X for section rendering")
        root._assert(typeof duplicateIndicator.barX === "number",
            "BarLayoutService insertion indicator should expose bar X for cross-component consumers")
        root._assert(root._approxEqual(duplicateIndicator.barX,
            BarLayoutService.sectionGeometry("left").left + duplicateIndicator.sectionLocalX, 0.5),
            "BarLayoutService insertion indicator should keep section-local and bar-space coordinates aligned")

        let narrowedCenterIndicator = BarLayoutService.insertionIndicatorGeometry("center", 0)
        root._assert(narrowedCenterIndicator.sectionLocalX < 0,
            "BarLayoutService should allow negative frame-local insertion coordinates when the visual band starts left of the narrowed center frame")

        BarLayoutService.resetLayout()
        BarLayoutService.addWidget("clock", "left")
        BarLayoutService.addWidget("mediaControl", "left")
        BarLayoutService.setBarMetrics(360, 24)
        BarLayoutService.setWidgetMeasuredWidth("workspaceWidget_0", 90)
        BarLayoutService.setWidgetMeasuredWidth("clock_0", 140)
        BarLayoutService.setWidgetMeasuredWidth("mediaControl_0", 80)
        BarLayoutService.setWidgetMeasuredWidth("superIsland_0", 120)

        root._assert(typeof BarLayoutService.beginDrag === "function",
            "BarLayoutService should expose beginDrag() to own drag-session state")
        root._assert(typeof BarLayoutService.updateDrag === "function",
            "BarLayoutService should expose updateDrag() to derive ghost geometry from pointer movement")
        root._assert(typeof BarLayoutService.endDrag === "function",
            "BarLayoutService should expose endDrag() to clear service-owned drag state")

        root._dragOverlayProbe = Qt.createQmlObject(`
            import QtQuick
            import qs.modules.bar

            Item {
                width: 360
                height: 48

                DragOverlay {
                    anchors.fill: parent
                    widgetRegistry: ({})
                }
            }
        `, root, "DragOverlayProbe")

        BarLayoutService.beginDrag("workspaceWidget_0", "workspaceWidget", 69)

        let dragSnapshotAtStart = BarLayoutService.dragSnapshot
        let floatingCopy = root._findDescendantByObjectName(root._dragOverlayProbe, "dragOverlayFloatingCopy")
        let dragLeftZone = root._findDescendantByZoneName(root._dragOverlayProbe, "left")
        let dragCenterZone = root._findDescendantByZoneName(root._dragOverlayProbe, "center")
        let dragRightZone = root._findDescendantByZoneName(root._dragOverlayProbe, "right")
        let leftDragGeometry = BarLayoutService.sectionGeometry("left")
        let centerDragGeometry = BarLayoutService.sectionGeometry("center")
        let rightDragGeometry = BarLayoutService.sectionGeometry("right")
        let dragEqualThirdWidth = (BarLayoutService.barContentWidth - 2 * BarLayoutService.barContentPadding) / 3

        root._assert(dragSnapshotAtStart.active === true,
            "BarLayoutService beginDrag() should activate the shared drag snapshot")
        root._assert(dragSnapshotAtStart.instanceKey === "workspaceWidget_0",
            "BarLayoutService beginDrag() should track the dragged instance by stable key")
        root._assert(dragSnapshotAtStart.widgetId === "workspaceWidget",
            "BarLayoutService beginDrag() should track the dragged widget id")
        root._assert(typeof dragSnapshotAtStart.visual === "object" && dragSnapshotAtStart.visual !== null,
            "BarLayoutService should expose drag visual geometry through dragSnapshot.visual")
        root._assert(typeof dragSnapshotAtStart.ghost === "object" && dragSnapshotAtStart.ghost !== null,
            "BarLayoutService should expose ghost geometry through dragSnapshot.ghost")
        root._assert(dragSnapshotAtStart.visual.width === 90,
            "BarLayoutService beginDrag() should freeze dragged width from the measured service snapshot")

        BarLayoutService.setWidgetMeasuredWidth("workspaceWidget_0", 150)

        root._assert(BarLayoutService.dragSnapshot.visual.width === 90,
            "BarLayoutService should keep dragged width stable after later width measurements change")
        root._assert(floatingCopy !== null,
            "BarLayoutGeometry smoke should locate the floating drag copy")
        root._assert(root._approxEqual(floatingCopy.width, BarLayoutService.dragSnapshot.visual.width, 0.5),
            "DragOverlay should size the floating copy from the service drag snapshot")
        root._assert(dragLeftZone !== null && dragCenterZone !== null && dragRightZone !== null,
            "BarLayoutGeometry smoke should locate DragOverlay drop zones during drag")
        root._assert(root._approxEqual(dragLeftZone.x, leftDragGeometry.left, 0.5),
            "DragOverlay should place the left drop zone from service section geometry")
        root._assert(root._approxEqual(dragCenterZone.x, centerDragGeometry.left, 0.5),
            "DragOverlay should place the center drop zone from service section geometry")
        root._assert(root._approxEqual(dragRightZone.x, rightDragGeometry.left, 0.5),
            "DragOverlay should place the right drop zone from service section geometry")
        root._assert(root._approxEqual(dragCenterZone.width, centerDragGeometry.width, 0.5),
            "DragOverlay should size drop zones from service section geometry")
        root._assert(!root._approxEqual(dragCenterZone.width, dragEqualThirdWidth, 0.5),
            "DragOverlay should no longer size drop zones from bar width divided by three")
        root._assert(typeof BarLayoutService.sectionForBarX === "function",
            "BarLayoutService should expose sectionForBarX() for shared hit testing")
        root._assert(root._barContent.hitTestSection(centerDragGeometry.centerX)
                === BarLayoutService.sectionForBarX(centerDragGeometry.centerX),
            "BarContent hit testing should delegate to the shared service-owned section geometry")

        BarLayoutService.updateDrag(leftDragGeometry.visualLeft + 141)

        root._assert(BarLayoutService.dragSnapshot.ghost.section === "left",
            "BarLayoutService updateDrag() should derive the hover section from shared section geometry")
        root._assert(BarLayoutService.dragSnapshot.ghost.index === 1,
            "BarLayoutService updateDrag() should derive the ghost insertion index from shared slot geometry")
        root._assert(BarLayoutService.dragSnapshot.ghost.line !== null,
            "BarLayoutService should publish service-owned ghost line geometry during drag")

        BarLayoutService.endDrag()

        root._assert(BarLayoutService.dragSnapshot.active === false,
            "BarLayoutService endDrag() should clear the shared drag snapshot")

        BarLayoutService.resetLayout()
        BarLayoutService.addWidget("notificationBell", "right")
        BarLayoutService.setBarMetrics(900, 24)
        BarLayoutService.setWidgetMeasuredWidth("workspaceWidget_0", 170)
        BarLayoutService.setWidgetMeasuredWidth("superIsland_0", 120)
        BarLayoutService.setWidgetMeasuredWidth("notificationBell_0", 70)
        BarLayoutService.activePanel = "layout"
        BarLayoutService.widgetPickerOpen = false
        BarLayoutService.widgetPickerTargetSection = "right"

        root._dragOverlayProbe = Qt.createQmlObject(`
            import QtQuick
            import qs.modules.bar

            Item {
                width: 900
                height: 48

                DragOverlay {
                    anchors.fill: parent
                    widgetRegistry: ({})
                }
            }
        `, root, "DragOverlayPickerProbe")

        let pickerRightZone = root._findDescendantByZoneName(root._dragOverlayProbe, "right")
        let pickerRightArea = root._findDescendant(pickerRightZone,
            child => typeof child.clicked === "function")
        let rightPickerAnchor = BarLayoutService.pickerAnchorGeometry("right")
        let pickerEqualThirdWidth = (BarLayoutService.barContentWidth - 2 * BarLayoutService.barContentPadding) / 3

        root._assert(pickerRightZone !== null,
            "BarLayoutGeometry smoke should locate the right drop zone for picker anchoring")
        root._assert(pickerRightArea !== null,
            "BarLayoutGeometry smoke should locate the right drop-zone click target")
        root._assert(!root._approxEqual(pickerRightZone.width, pickerEqualThirdWidth, 0.5),
            "DropZone picker test should use a service-owned width instead of an equal-third width")
        root._assert(root._approxEqual(
            pickerRightZone.children[0].width,
            pickerRightZone.width,
            0.5
        ), "DropZone visible border should follow the service-owned zone width without extra inset shrinkage")

        pickerRightArea.clicked(null)

        root._assert(BarLayoutService.widgetPickerOpen === true,
            "DropZone click should open the widget picker in layout mode")
        root._assert(BarLayoutService.widgetPickerTargetSection === "right",
            "DropZone click should target the clicked section")
        root._assert(root._approxEqual(BarLayoutService.widgetPickerLeftMargin,
            rightPickerAnchor.leftMargin, 0.5),
            "DropZone click should position the picker from the service-owned anchor geometry")

        root._runArrivalAssertions()
    }

    Timer {
        id: waitTimer

        repeat: true
        running: false

        onTriggered: {
            if (!root._waitCondition) {
                stop()
                return
            }

            if (root._waitCondition()) {
                let success = root._waitSuccess

                root._waitCondition = null
                root._waitSuccess = null
                root._waitFailureMessage = ""
                root._waitAttemptsRemaining = 0
                stop()

                if (success) {
                    success()
                }
                return
            }

            root._waitAttemptsRemaining -= 1
            if (root._waitAttemptsRemaining > 0) {
                return
            }

            let failureMessage = root._waitFailureMessage || "Timed out waiting for geometry smoke condition"

            root._waitCondition = null
            root._waitSuccess = null
            root._waitFailureMessage = ""
            root._waitAttemptsRemaining = 0
            stop()

            throw new Error(failureMessage)
        }
    }
}
