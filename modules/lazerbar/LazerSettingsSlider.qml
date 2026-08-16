import QtQuick
import "LazerSettingsLogic.js" as Logic

// Provide a clamped numeric setting with osu's 5px track and draggable 50x15
// Nub; value changes animate at 250ms OutQuint unless the user is dragging.
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
    readonly property bool effectiveEnabled: enabled && rowEnabled
    readonly property real effectiveAvailableWidth: isFinite(Number(availableWidth)) ? Math.max(0, Number(availableWidth)) : Infinity
    readonly property real displayValue: normalized(value)
    readonly property string displayText: Number(displayValue).toLocaleString(Qt.locale(), 'f', 0) + suffix
    readonly property bool focusVisible: activeFocus
    readonly property bool dragging: dragHandler.active
    readonly property bool hovered: hoverHandler.hovered
    readonly property real normalizedFraction: Logic.sliderFraction(from, to, displayValue)
    readonly property real targetFraction: Logic.sliderFraction(from, to, displayValue)
    signal valueModified(real value)

    implicitWidth: 180
    implicitHeight: 15
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

    // Keep the 25px range padding on both sides of the interactive track area.
    Item {
        id: trackHost
        x: LazerTheme.settingsRangePadding
        y: 0
        width: Math.max(0, root.width - 2 * LazerTheme.settingsRangePadding)
        height: root.height
    }

    // Draw the hollow focus glow around the track while keyboard-focused.
    Rectangle {
        id: focusGlow
        anchors.centerIn: trackHost
        width: trackHost.width + 8
        height: 19
        radius: 9.5
        color: "transparent"
        border.width: 2
        border.color: LazerTheme.osuPink
        opacity: root.focusVisible && root.effectiveEnabled ? 0.55 : 0
        Behavior on opacity { NumberAnimation { duration: MotionTokens.nubHover } }
    }

    // Show the fixed 5px track surface beneath the moving nub.
    Rectangle {
        id: trackRect
        anchors.centerIn: trackHost
        width: trackHost.width
        height: 5
        radius: 2.5
        color: LazerTheme.settingsTrack
    }

    // Fill the travelled portion of the track from the left edge to the nub.
    Rectangle {
        id: fillRect
        anchors.verticalCenter: trackRect.verticalCenter
        x: trackHost.x
        width: root.displayFraction * trackHost.width
        height: 5
        radius: 2.5
        color: LazerTheme.osuPink
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

    // Place the shared nub on the travelled fraction of the usable track.
    LazerSettingsNub {
        id: nub
        x: root.displayFraction * trackHost.width
        y: 0
        sliderMode: true
        hovered: root.hovered || root.dragging
        pressed: root.dragging
        focused: root.focusVisible
        enabled: root.effectiveEnabled
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
        parent: nub
        gesturePolicy: TapHandler.DoubleTap
        enabled: root.effectiveEnabled && root.defaultValue !== undefined
        onDoubleTapped: root.resetToDefault()
    }

    readonly property Item trackItem: trackRect
    readonly property bool trackTapEnabled: trackTapHandler.enabled
    readonly property bool trackFillBehaviorEnabled: fractionBehavior.enabled
    readonly property Item nubItem: nub
    readonly property bool nubDoubleTapEnabled: nubDoubleTapHandler.enabled
}