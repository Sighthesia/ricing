import QtQuick
import "LazerSettingsLogic.js" as Logic

// Provide a clamped numeric setting with a thick trough and embedded thumb.
Item {
    id: root

    property real value: 0
    property real from: 0
    property real to: 100
    property real stepSize: 1
    property string suffix: ""
    property var defaultValue: undefined
    property bool enabled: true
    property bool rowEnabled: true
    property real availableWidth: Infinity
    property real requestedWidth: implicitWidth
    property string accessibleName: ""
    property bool fillWidth: true
    readonly property string rowPresentation: "split"
    readonly property bool effectiveEnabled: enabled && rowEnabled
    readonly property real effectiveAvailableWidth: isFinite(Number(availableWidth)) ? Math.max(0, Number(availableWidth)) : Infinity
    readonly property real displayValue: normalized(value)
    readonly property string displayText: Number(displayValue).toLocaleString(Qt.locale(), 'f', 0) + suffix
    readonly property bool focusVisible: activeFocus
    readonly property bool dragging: dragHandler.active
    readonly property bool hovered: hoverHandler.hovered
    readonly property real normalizedFraction: Logic.sliderFraction(from, to, displayValue)
    readonly property real targetFraction: Logic.sliderFraction(from, to, displayValue)
    readonly property real defaultFraction: defaultValue === undefined
                                           ? 0 : Logic.sliderFraction(from, to, defaultValue)
    readonly property bool defaultMarkerVisible: defaultValue !== undefined
    readonly property bool defaultMarkerAtValue: defaultValue !== undefined && displayValue === normalized(defaultValue)
    signal valueModified(real value)

    implicitWidth: 220
    implicitHeight: 26
    width: Math.min(Math.max(0, isFinite(Number(requestedWidth)) ? Number(requestedWidth) : implicitWidth), effectiveAvailableWidth)
    height: implicitHeight
    activeFocusOnTab: effectiveEnabled
    opacity: effectiveEnabled ? 1 : LazerTheme.settingsDisabledAlpha
    Accessible.role: Accessible.Slider
    Accessible.name: accessibleName

    function normalized(candidate) {
        var start = Number(from)
        var end = Number(to)
        var low = Math.min(start, end)
        var high = Math.max(start, end)
        var step = Number(stepSize)
        if (!isFinite(step) || step <= 0)
            step = 1
        var number = Number(candidate)
        if (!isFinite(number))
            number = start
        var clamped = Math.max(low, Math.min(high, number))
        if (start === end)
            return start
        if (clamped === start || clamped === end)
            return clamped
        var direction = end >= start ? 1 : -1
        var steps = Math.round((clamped - start) / (step * direction))
        return Math.max(low, Math.min(high, start + steps * step * direction))
    }

    function setValue(candidate) {
        var next = normalized(candidate)
        if (next === Number(value))
            return
        valueModified(next)
    }

    function increase() { if (effectiveEnabled) setValue(displayValue + stepSize) }
    function decrease() { if (effectiveEnabled) setValue(displayValue - stepSize) }

    function moveAlongTrack(delta) {
        if (effectiveEnabled)
            setValue(displayValue + (to >= from ? stepSize : -stepSize) * delta)
    }

    function valueForTrackPosition(position) {
        var trackWidth = Math.max(0, trackHost.width)
        if (trackWidth <= 0 || from === to)
            return normalized(from)
        var fraction = Math.max(0, Math.min(1, Number(position) / trackWidth))
        return Logic.sliderValueFromFraction(from, to, fraction, stepSize)
    }

    function valueFromPointerX(pointerX) {
        var fraction = Logic.sliderFractionForPosition(pointerX, root.width, LazerTheme.settingsRangePadding)
        return Logic.sliderValueFromFraction(root.from, root.to, fraction, root.stepSize)
    }

    function resetToDefault() {
        if (!root.effectiveEnabled || root.defaultValue === undefined)
            return
        root.forceActiveFocus()
        root.setValue(root.defaultValue)
    }

    // Request the value tooltip anchored to the moving Nub so the content can
    // follow per-frame geometry instead of the static slider root.
    function refreshTooltip() {
        if (!root.effectiveEnabled) {
            SettingsOverlayBridge.hideTooltip(root.nubItem)
            return
        }
        // Read the source properties directly: bound mirrors (hovered,
        // dragging, focusVisible) are not re-evaluated until after the
        // notify handler runs, so inside these handlers they are stale.
        if (hoverHandler.hovered || dragHandler.active || root.activeFocus)
            SettingsOverlayBridge.showTooltip(root.displayText, root.nubItem, 2)
        else
            SettingsOverlayBridge.hideTooltip(root.nubItem)
    }

    Keys.onPressed: event => {
        if (!root.effectiveEnabled)
            return
        if (event.key === Qt.Key_Left) {
            moveAlongTrack(-1)
            event.accepted = true
        } else if (event.key === Qt.Key_Right) {
            moveAlongTrack(1)
            event.accepted = true
        }
    }

    onEffectiveEnabledChanged: {
        if (!effectiveEnabled && activeFocus)
            focus = false
        refreshTooltip()
    }

    onActiveFocusChanged: refreshTooltip()
    onDisplayTextChanged: {
        if (hoverHandler.hovered || dragHandler.active || root.activeFocus)
            refreshTooltip()
    }

    // Use the full right-hand row column as the interactive track area.
    Item {
        id: trackHost
        x: 0
        y: 0
        width: root.width
        height: root.height
    }

    // Draw a restrained focus outline around the trough.
    Rectangle {
        id: focusGlow
        anchors.fill: trackHost
        radius: 4
        color: "transparent"
        border.width: 2
        border.color: LazerTheme.focusRing
        opacity: root.focusVisible && root.effectiveEnabled ? 0.7 : 0
        Behavior on opacity { NumberAnimation { duration: MotionTokens.nubHover } }
    }

    // Show the thick rounded control trough.
    Rectangle {
        id: trackRect
        z: 0
        anchors.fill: trackHost
        radius: 4
        color: LazerTheme.settingsTrack
        Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
    }

    // Fill the travelled portion of the trough.
    Rectangle {
        id: fillRect
        z: 1
        anchors.left: trackRect.left
        anchors.top: trackRect.top
        anchors.bottom: trackRect.bottom
        width: root.displayFraction * trackHost.width
        radius: 4
        color: LazerTheme.settingsAccent
        Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
    }

    // Keep the default marker above the active thumb so the default remains legible.
    Rectangle {
        id: defaultMarker
        z: 4
        x: Math.max(0, Math.min(trackHost.width - width,
                                 root.defaultFraction * trackHost.width - width / 2))
        anchors.verticalCenter: trackHost.verticalCenter
        width: 5
        height: root.defaultMarkerAtValue ? Math.max(0, trackHost.height - 14) : 6
        radius: height / 2
        color: "#D5CCFF"
        opacity: root.defaultMarkerVisible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: MotionTokens.fast } }
        Behavior on height { enabled: !MotionTokens.reducedMotion; NumberAnimation { duration: MotionTokens.fast; easing.type: Easing.OutQuint } }
        Behavior on x { enabled: !MotionTokens.reducedMotion; NumberAnimation { duration: MotionTokens.fast; easing.type: Easing.OutQuint } }
    }

    // Animate the nub toward its value unless the user is actively dragging.
    property real displayFraction: 0
    Binding {
        target: root
        property: "displayFraction"
        value: root.targetFraction
        when: !root.dragging
        restoreMode: Binding.RestoreNone
    }
    Behavior on displayFraction {
        id: fractionBehavior
        enabled: !root.dragging && !MotionTokens.reducedMotion
        NumberAnimation { duration: MotionTokens.sliderNubMove; easing.type: Easing.OutQuint }
    }

    // Keep the active thumb as a brighter full-height continuation of the fill.
    Rectangle {
        id: thumb
        z: 3
        x: Math.max(0, Math.min(trackHost.width - width,
                                 root.displayFraction * trackHost.width - width / 2))
        anchors.verticalCenter: trackHost.verticalCenter
        width: 12
        height: trackHost.height
        radius: 4
        color: LazerTheme.settingsSliderThumb
        scale: root.dragging ? MotionTokens.pressScale : (root.hovered ? 1.06 : 1)

        Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
        Behavior on scale { enabled: !MotionTokens.reducedMotion; NumberAnimation { duration: MotionTokens.fast; easing.type: Easing.OutQuint } }

    }

    HoverHandler {
        id: hoverHandler
        enabled: root.effectiveEnabled
        onHoveredChanged: root.refreshTooltip()
    }

    // Map taps anywhere on the track to the value under the pointer.
    TapHandler {
        id: trackTapHandler
        enabled: root.effectiveEnabled
        onTapped: eventPoint => {
            root.forceActiveFocus()
            root.setValue(root.valueFromPointerX(eventPoint.position.x))
        }
    }

    // Scrub toward a pointer x in slider coordinates, honoring the 25px padding.
    function scrubToPointer(pointerX) {
        var fraction = Logic.sliderFractionForPosition(pointerX, root.width, LazerTheme.settingsRangePadding)
        root.displayFraction = fraction
        root.setValue(Logic.sliderValueFromFraction(root.from, root.to, fraction, root.stepSize))
    }

    // Drag horizontally to scrub; the vertical axis stays owned by the page
    // Flickable so rows keep scrolling.
    DragHandler {
        id: dragHandler
        enabled: root.effectiveEnabled
        target: null
        xAxis.enabled: true
        yAxis.enabled: false
        onActiveChanged: {
            if (dragHandler.active)
                root.scrubToPointer(dragHandler.centroid.pressPosition.x + dragHandler.translation.x)
            root.refreshTooltip()
        }
        onTranslationChanged: {
            if (dragHandler.active)
                root.scrubToPointer(dragHandler.centroid.pressPosition.x + dragHandler.translation.x)
        }
    }

    // Double-click the nub to restore the explicitly provided default value.
    TapHandler {
        id: nubDoubleTapHandler
        parent: thumb
        gesturePolicy: TapHandler.DoubleTap
        enabled: root.effectiveEnabled && root.defaultValue !== undefined
        onDoubleTapped: root.resetToDefault()
    }

    readonly property Item trackItem: trackRect
    readonly property Item trackFillItem: fillRect
    readonly property Item defaultMarkerItem: defaultMarker
    readonly property Item thumbLightItem: null
    readonly property bool trackTapEnabled: trackTapHandler.enabled
    readonly property bool trackFillBehaviorEnabled: fractionBehavior.enabled
    readonly property Item nubItem: thumb
    readonly property color thumbColor: thumb.color
    readonly property bool nubDoubleTapEnabled: nubDoubleTapHandler.enabled
}
