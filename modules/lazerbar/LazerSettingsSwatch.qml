import QtQuick

// Offer a small set of named inks as a single strip of square chips. The chip
// itself is the sample — no label lies under it, so the row stays one line high
// in the bar's own narrow popup. Selection is a thin accent rule under the
// chosen chip, the same "indicator strip" vocabulary the bar and sidebar use;
// the chip is never outlined.
Item {
    id: root

    // [{ value, color }]; `color` is already resolved by the caller, so this
    // control holds no palette knowledge of its own.
    property var model: []
    property string currentValue: ""
    property bool enabled: true
    property bool rowEnabled: true
    property real availableWidth: Infinity
    property real requestedWidth: implicitWidth
    property string accessibleName: ""
    property bool fillWidth: false
    // The bar popup labels its rows at the settings panel's small size; this is
    // the one contract a host needs to ask for it.
    readonly property bool smallRowLabel: true
    readonly property bool effectiveEnabled: enabled && rowEnabled
    readonly property real effectiveAvailableWidth: isFinite(Number(availableWidth)) ? Math.max(0, Number(availableWidth)) : Infinity
    readonly property int currentIndex: indexOf(currentValue)
    readonly property bool focusVisible: activeFocus
    readonly property bool hovered: stripHover.hovered
    readonly property bool flashActive: flash.flashActive
    signal valueModified(string value)

    readonly property real chipSize: 22
    readonly property real chipGap: 6
    readonly property real chipRadius: 4
    readonly property real indicatorHeight: LazerTheme.barIndicatorHeight
    readonly property real indicatorGap: 2
    readonly property int chipCount: root.model ? root.model.length : 0
    readonly property real stripWidth: chipCount > 0
        ? chipCount * chipSize + (chipCount - 1) * chipGap : 0

    implicitWidth: Math.max(22, stripWidth)
    implicitHeight: chipSize + indicatorGap + indicatorHeight
    width: fillWidth ? effectiveAvailableWidth : Math.min(implicitWidth, effectiveAvailableWidth)
    height: implicitHeight
    activeFocusOnTab: effectiveEnabled
    opacity: effectiveEnabled ? 1 : MotionTokens.disabledOpacity
    Accessible.role: Accessible.ComboBox
    Accessible.name: accessibleName

    onEffectiveEnabledChanged: {
        if (!effectiveEnabled && activeFocus)
            focus = false
    }

    function indexOf(candidate) {
        if (!root.model)
            return -1
        for (var i = 0; i < root.model.length; i++) {
            if (String(root.model[i].value) === String(candidate))
                return i
        }
        return -1
    }

    function activate(index) {
        if (!root.effectiveEnabled || index < 0 || index >= root.chipCount)
            return
        var value = String(root.model[index].value)
        root.forceActiveFocus()
        if (value !== String(root.currentValue))
            root.valueModified(value)
        root.restartFlash()
    }

    // Arrows walk the strip, which is how a radio group is expected to behave
    // once it holds focus; the current value is what moves, not a hover cursor.
    function step(delta) {
        if (!root.effectiveEnabled || root.chipCount === 0)
            return
        var from = root.currentIndex >= 0 ? root.currentIndex : 0
        var next = Math.max(0, Math.min(root.chipCount - 1, from + delta))
        root.activate(next)
    }

    function restartFlash() {
        if (!root.effectiveEnabled)
            return
        // The wash sits over the chip that was just chosen, so it has to move
        // before it starts fading.
        flash.x = root.currentIndex >= 0 ? root.currentIndex * (chipSize + chipGap) : 0
        flash.restart()
    }

    Keys.onLeftPressed: event => { step(-1); event.accepted = true }
    Keys.onRightPressed: event => { step(1); event.accepted = true }
    Keys.onSpacePressed: event => { step(0); event.accepted = true }
    Keys.onReturnPressed: event => { step(0); event.accepted = true }

    // One chip per offered ink, in the order the caller listed them.
    Row {
        id: chipRow
        anchors.left: parent.left
        anchors.top: parent.top
        spacing: root.chipGap

        Repeater {
            model: root.model || []

            delegate: Item {
                id: chip

                required property var modelData
                required property int index

                width: root.chipSize
                height: root.chipSize

                Rectangle {
                    anchors.fill: parent
                    radius: root.chipRadius
                    // The ink is the sample, so it is drawn at full strength even
                    // when a neighbouring chip is the selected one. A hollow chip
                    // is the palette's own ink (see the model's `hollow` flag), so
                    // it is drawn as an outline rather than as a colour.
                    readonly property bool hollow: chip.modelData
                        && chip.modelData.hollow === true
                    color: hollow ? "transparent"
                        : (chip.modelData && chip.modelData.color !== undefined
                            ? chip.modelData.color : "transparent")
                    border.width: hollow ? 1.5 : 1
                    border.color: hollow ? LazerTheme.textMuted : LazerTheme.popupBorder

                    Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
                }

                // Hover ring: brightens the chip's own edge instead of scaling
                // it, which is the settings panel's rule for pointer feedback on
                // a surface that already carries a colour.
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -2
                    radius: root.chipRadius + 1
                    color: "transparent"
                    border.width: 1.5
                    border.color: LazerTheme.textPrimary
                    opacity: chipHover.hovered && root.effectiveEnabled
                        && root.currentIndex !== chip.index ? 0.35 : 0
                    enabled: false
                    Behavior on opacity { NumberAnimation { duration: MotionTokens.fast } }
                }

                // Keyboard focus ring, kept as its own layer so it never
                // changes the chip's hit box or the strip's metrics.
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -3
                    radius: root.chipRadius + 2
                    color: "transparent"
                    border.width: 1.5
                    border.color: LazerTheme.focusRing
                    visible: root.effectiveEnabled && root.activeFocus
                        && root.currentIndex === chip.index
                    opacity: visible ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: MotionTokens.fast } }
                }

                HoverHandler {
                    id: chipHover
                    enabled: root.effectiveEnabled
                    blocking: false
                }
                TapHandler {
                    enabled: root.effectiveEnabled
                    gesturePolicy: TapHandler.ReleaseWithinBounds
                    onTapped: root.activate(chip.index)
                }
            }
        }
    }

    // Selection rule under the chosen chip. It slides between chips so the
    // strip reads as one control rather than a row of unrelated buttons.
    Rectangle {
        id: selectionIndicator

        y: root.chipSize + root.indicatorGap
        width: root.chipSize
        height: root.indicatorHeight
        radius: root.indicatorHeight / 2
        color: LazerTheme.settingsAccent
        visible: root.currentIndex >= 0
        // `chipSize` is the chip's own width, so the rule is positioned from the
        // chip that is selected rather than from a moving cursor.
        x: root.currentIndex * (root.chipSize + root.chipGap)

        Behavior on x {
            enabled: !MotionTokens.reducedMotion
            NumberAnimation { duration: MotionTokens.fast; easing.type: Easing.OutQuint }
        }
        Behavior on opacity { NumberAnimation { duration: MotionTokens.fast } }
    }

    // Confirm an accepted pick without changing any chip's input boundary.
    ClickFlash {
        id: flash

        z: 2
        y: 0
        width: root.chipSize
        height: root.chipSize
        radius: root.chipRadius
    }

    // Observe the whole strip so the host row can share the hover highlight.
    HoverHandler {
        id: stripHover
        enabled: root.effectiveEnabled
        blocking: false
    }
}
