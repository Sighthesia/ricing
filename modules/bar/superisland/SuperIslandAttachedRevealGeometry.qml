import QtQuick

// Attached reveal geometry keeps the reveal shell's width, height, and offset math together.
QtObject {
    id: root

    // Host-injected state: whether the attached panel is active.
    required property bool attachedPanelActive

    // Host-injected state: the seed width used before the reveal fully expands.
    required property real attachedRevealSeedWidth

    // Host-injected state: the current target reveal width.
    required property real attachedPanelRevealWidth

    // Host-injected state: the current live reveal width.
    required property real attachedPanelWidth

    // Host-injected state: the seed height used before the reveal fully expands.
    required property real attachedRevealSeedHeight

    // Host-injected state: the current target reveal height.
    required property real attachedPanelRevealHeight

    // Host-injected state: the current live reveal height.
    required property real attachedPanelHeight

    // Host-injected state: whether the bar-expanded hint should use vertical-only reveal progress.
    required property bool barExpandedHintActive

    // Host-injected state: the vertical lift applied to the reveal shell.
    required property real overlayRevealLift

    // Visible width clamps to the current reveal width without shrinking below the seed width.
    readonly property real attachedPanelVisibleWidth:
        root.attachedPanelActive
            ? Math.max(
                root.attachedRevealSeedWidth,
                Math.min(root.attachedPanelRevealWidth, root.attachedPanelWidth)
            )
            : root.attachedRevealSeedWidth

    // Visible height clamps to the current reveal height without dipping below zero.
    readonly property real attachedPanelVisibleHeight:
        root.attachedPanelActive
            ? Math.max(0, Math.min(root.attachedPanelRevealHeight, root.attachedPanelHeight))
            : 0

    // Horizontal reveal progress tracks the visible width relative to the seed width.
    readonly property real attachedWidthRevealProgress:
        root.attachedPanelWidth > root.attachedRevealSeedWidth
            ? Math.max(
                0,
                Math.min(
                    1,
                    (Math.min(root.attachedPanelRevealWidth, root.attachedPanelWidth) - root.attachedRevealSeedWidth)
                        / (root.attachedPanelWidth - root.attachedRevealSeedWidth)
                )
            )
            : 1

    // Vertical reveal progress tracks the visible height relative to the seed height.
    readonly property real attachedHeightRevealProgress:
        root.attachedPanelHeight > root.attachedRevealSeedHeight
            ? Math.max(
                0,
                Math.min(
                    1,
                    (root.attachedPanelVisibleHeight - root.attachedRevealSeedHeight)
                        / (root.attachedPanelHeight - root.attachedRevealSeedHeight)
                )
            )
            : 1

    // Overall reveal progress follows the slower of the width and height reveal paths.
    readonly property real attachedRevealProgress:
        root.attachedPanelActive
            ? Math.min(root.attachedWidthRevealProgress, root.attachedHeightRevealProgress)
            : 0

    // Vertical reveal progress switches to the height path when bar-expanded hint mode is active.
    readonly property real attachedVerticalRevealProgress:
        root.barExpandedHintActive ? root.attachedHeightRevealProgress : root.attachedRevealProgress

    // Reveal offset eases the panel upward as the visible shell grows.
    readonly property real attachedRevealYOffset:
        (1 - root.attachedVerticalRevealProgress) * root.overlayRevealLift
}
