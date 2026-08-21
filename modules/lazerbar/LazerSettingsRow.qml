import QtQuick
import QtQuick.Effects
import "LazerSettingsLogic.js" as Logic

// Present one settings entry as osu's full-width card with a reserved reset zone,
// then label above control with 5px spacing. Description text remains searchable
// but no longer creates a floating surface.
Item {
    id: root

    property string labelText: ""
    property string descriptionText: ""
    property bool enabled: true
    property string searchQuery: ""
    property var defaultValue: undefined
    property var currentValue: undefined
    property var resetCallback: null
    readonly property bool matchesSearch: Logic.matchesSearch(labelText, descriptionText, searchQuery)
    readonly property bool searchVisible: matchesSearch
    readonly property bool searchHidden: Logic.normalizeSearchQuery(searchQuery).length > 0 && !matchesSearch
    // Cascade the exit down the list so bulk filtering never pops at once.
    readonly property real searchExitDelay: Math.round(Math.min(150, Math.max(0, root.y / 6)))
    // Open-session wave state: held rows share the search-hidden geometry.
    property bool revealHeld: false
    property bool snapTransitions: false
    readonly property bool geometryHeld: searchHidden || revealHeld
    readonly property bool contentEnabled: enabled
    readonly property bool hasDefault: defaultValue !== undefined
    readonly property bool isDefault: hasDefault && Logic.valuesEqual(defaultValue, currentValue)
    readonly property bool revertVisible: hasDefault && !isDefault && enabled
    readonly property bool canReset: revertVisible && enabled
    readonly property real contentPadding: 12
    readonly property real revertZoneWidth: 28
    readonly property real revertContentGap: 12
    readonly property real cardRadius: 6
    readonly property real revertVisualWidth: root.revertZoneWidth + root.cardRadius
    readonly property real revertVisibleX: root.width - root.revertVisualWidth
    readonly property real revertHiddenX: root.revertVisibleX - root.revertVisualWidth
    readonly property real reservedResetWidth: root.hasDefault ? root.revertZoneWidth : 0
    readonly property real reservedResetGap: root.hasDefault ? root.revertContentGap : 0
    readonly property real cardBodyWidth: Math.max(0, root.width - root.reservedResetWidth)
    readonly property bool flashActive: resetFlashAnimation.running || resetFlashOverlay.opacity > 0
    readonly property Item flashOverlayItem: resetFlashOverlay
    readonly property Animation flashAnimationItem: resetFlashAnimation
    readonly property real labelControlGap: 5
    default property alias control: controlHost.children
    readonly property Item controlItem: controlHost.children.length > 0 ? controlHost.children[0] : null
    readonly property bool controlSupportsRowEnabled: controlItem !== null && controlItem.rowEnabled !== undefined
    readonly property bool controlSupportsAvailableWidth: controlItem !== null && controlItem.availableWidth !== undefined
    readonly property bool controlSupportsRequestedWidth: controlItem !== null && controlItem.requestedWidth !== undefined
    readonly property bool controlSupportsFillWidth: controlItem !== null && controlItem.fillWidth !== undefined
    readonly property bool controlOwnsLabel: controlItem !== null && controlItem.rowPresentation === "choice"
    readonly property string rowPresentation: controlItem && controlItem.rowPresentation !== undefined
                                           ? String(controlItem.rowPresentation) : "standard"
    readonly property bool inlinePresentation: rowPresentation === "inline"
    readonly property bool splitPresentation: rowPresentation === "split"
    readonly property bool choicePresentation: rowPresentation === "choice"
    readonly property bool rowHovered: ((rowHover.hovered && rowHover.point.position.x < root.revertVisibleX)
                                        || rowHoverArea.containsMouse)
                                      || (controlItem && controlItem.hovered === true)
    readonly property bool rowHoverBlocking: rowHover.blocking
    readonly property bool rowHighlighted: rowHovered
    readonly property point debugHoverScenePoint: rowHover.point.scenePosition
    readonly property bool compactLayout: width < 480
    readonly property real choiceMenuReservedHeight: root.choicePresentation && root.controlItem
                                                   && root.controlItem.menuReservedHeight !== undefined
                                                   ? Math.max(0, Number(root.controlItem.menuReservedHeight)) : 0
    readonly property real safeRequestedWidth: controlSupportsRequestedWidth
                                          && isFinite(Number(controlItem.requestedWidth))
                                          ? Math.max(0, Number(controlItem.requestedWidth))
                                          : (controlItem && isFinite(Number(controlItem.implicitWidth))
                                             ? Math.max(0, Number(controlItem.implicitWidth)) : 0)
    readonly property real safeControlWidth: controlItem && isFinite(Number(controlItem.width))
                                             ? Math.max(0, Number(controlItem.width)) : 0
    readonly property real safeImplicitWidth: controlItem && isFinite(Number(controlItem.implicitWidth))
                                               ? Math.max(0, Number(controlItem.implicitWidth)) : 0
    readonly property real safeControlHeight: controlItem && isFinite(Number(controlItem.height))
                                                && Number(controlItem.height) > 0
                                                ? Number(controlItem.height)
                                                : (controlItem && isFinite(Number(controlItem.implicitHeight))
                                                   ? Math.max(0, Number(controlItem.implicitHeight)) : 0)
    readonly property real safeMainControlHeight: controlItem && controlItem.mainControlHeight !== undefined
                                                   && isFinite(Number(controlItem.mainControlHeight))
                                                   ? Math.max(0, Number(controlItem.mainControlHeight))
                                                   : safeControlHeight
    readonly property real inlineControlWidth: Math.min(Math.max(0, contentHost.width), safeRequestedWidth)
    readonly property real splitControlWidth: Math.min(240, Math.max(0, contentHost.width * 0.55))
    readonly property real cardContentHeight: inlinePresentation ? 44
                                          : (choicePresentation ? safeControlHeight
                                             : (splitPresentation ? 52
                                                 : 10 + labelItem.implicitHeight + labelControlGap + safeControlHeight + 10))

    implicitWidth: 640
    readonly property real textRegionWidth: contentHost.width
    readonly property real controlRegionLeft: contentHost.x
    // Own the list gap inside the height so a fully exited row frees exactly
    // zero space; removing it from the Column then causes no layout jump.
    readonly property real listGap: 8
    implicitHeight: cardContentHeight
    // The wave never touches layout: rows keep their final slot and only the
    // clipped visual host grows in, so scrolling works while items reveal.
    height: matchesSearch ? implicitHeight + listGap : 0
    visible: !searchHidden || height > 0.5 || opacity > 0.01
    opacity: root.enabled ? 1 : LazerTheme.settingsDisabledAlpha
    // Held (not yet revealed) rows keep their slot but take no input.
    readonly property bool interactable: matchesSearch && !revealHeld
    // Animated visual height driving the reveal grow inside the clip host.
    property real revealHeight: geometryHeld ? 0 : implicitHeight
    readonly property real revealProgress: implicitHeight > 0 ? Math.min(1, revealHeight / implicitHeight) : 1
    // Upward pre-offset set by the section: unrevealed rows sit where the old
    // compressed layout would have placed them, gliding down as the wave lands.
    property real revealShift: 0

    onRevealProgressChanged: {
        var parentColumn = root.parent
        if (parentColumn && parentColumn.chainSync !== undefined)
            parentColumn.chainSync()
    }
    // While revealing, clip at the row bounds so shifted rows never paint
    // over the section header; restore overflow behavior once landed.
    clip: revealHeld || snapTransitions || revealProgress < 1

    Behavior on height {
        enabled: !MotionTokens.reducedMotion
        SequentialAnimation {
            PauseAnimation { duration: root.searchHidden ? root.searchExitDelay : 0 }
            NumberAnimation { duration: MotionTokens.slow; easing.type: Easing.OutQuint }
        }
    }
    Behavior on revealHeight {
        enabled: !MotionTokens.reducedMotion && !root.snapTransitions
        SequentialAnimation {
            PauseAnimation { duration: root.searchHidden ? root.searchExitDelay : 0 }
            NumberAnimation { duration: MotionTokens.slow; easing.type: Easing.OutQuint }
        }
    }

    Timer {
        id: revealTimer
        interval: 0
        repeat: false
        onTriggered: {
            root.snapTransitions = false
            root.revealHeld = false
        }
    }

    // Collapse instantly for the open-session wave, then release on schedule.
    function holdInstantly() {
        revealTimer.stop()
        root.snapTransitions = true
        root.revealHeld = true
    }

    // Leave the held state without animation (wave cancelled).
    function releaseInstantly() {
        revealTimer.stop()
        root.snapTransitions = true
        root.revealHeld = false
        Qt.callLater(function () { root.snapTransitions = false })
    }

    // The timer owns the wave stagger so releases animate immediately.
    function playReveal(delayMs) {
        revealTimer.interval = Math.max(0, Math.round(Number(delayMs) || 0))
        revealTimer.restart()
    }

    // Observe the complete row, including areas covered by embedded controls.
    HoverHandler {
        id: rowHover
        enabled: root.enabled && root.interactable
        // Keep the row highlight observer from starving embedded controls.
        blocking: false
    }

    // Clip the growing reveal so rows expand visually while the layout
    // underneath stays at its final, scrollable geometry.
    Item {
        id: visualHost
        anchors.left: parent.left
        anchors.top: parent.top
        width: root.width
        height: root.revealHeight
        clip: true
        opacity: root.revealProgress
        x: geometryHeld ? -8 : 0
        y: -root.revealShift

        Behavior on x {
            enabled: !MotionTokens.reducedMotion && !root.snapTransitions
            SequentialAnimation {
                PauseAnimation { duration: root.searchHidden ? root.searchExitDelay : 0 }
                NumberAnimation { duration: MotionTokens.slow; easing.type: Easing.OutQuint }
            }
        }

        // Observe only the row surface; leave the exposed reset button region to its own handlers.
        MouseArea {
            id: rowHoverArea
            z: 0.5
            anchors.left: parent.left
            anchors.top: parent.top
            height: root.revealHeight
            width: root.hasDefault ? Math.max(0, root.revertVisibleX) : root.width
            enabled: root.enabled && root.interactable
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
        }

        // Keep one shared card surface behind every setting presentation.
        Rectangle {
            id: cardSurface
            z: 1
            anchors.left: parent.left
            anchors.top: parent.top
            height: root.revealHeight
            width: root.cardBodyWidth
            radius: root.cardRadius
            visible: !root.choicePresentation
            color: root.rowHighlighted ? LazerTheme.settingsCardHover : LazerTheme.settingsCard
            border.width: root.rowHighlighted ? 1.5 : 0
            border.color: root.rowHighlighted ? LazerTheme.settingsAccent : "transparent"
            Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
            Behavior on width { enabled: !MotionTokens.reducedMotion; NumberAnimation { duration: MotionTokens.fast; easing.type: Easing.OutQuint } }
            Behavior on border.width { NumberAnimation { duration: 100 } }
            Behavior on border.color { ColorAnimation { duration: 100 } }
        }

        // Keep the row focus ring above embedded controls without owning input.
        Rectangle {
            id: cardHighlight
            z: 2
            anchors.left: parent.left
            anchors.top: parent.top
            height: root.revealHeight
            width: root.cardBodyWidth
            radius: cardSurface.radius
            visible: !root.choicePresentation
            color: "transparent"
            border.width: root.rowHighlighted ? 1.5 : 0
            border.color: root.rowHighlighted ? LazerTheme.settingsAccent : "transparent"
            enabled: false
            Behavior on width { enabled: !MotionTokens.reducedMotion; NumberAnimation { duration: MotionTokens.fast; easing.type: Easing.OutQuint } }
            Behavior on border.width { NumberAnimation { duration: 100 } }
            Behavior on border.color { ColorAnimation { duration: 100 } }
        }

    // Propagate availability to the single injected control.
    Binding {
        target: root.controlItem
        property: "rowEnabled"
        value: root.enabled
        when: root.controlSupportsRowEnabled
    }

    // Give built-in controls a one-way width budget without owning their width.
    Binding {
        target: root.controlItem
        property: "availableWidth"
        value: root.inlinePresentation ? root.safeRequestedWidth
              : (root.splitPresentation ? Math.min(240, Math.max(0, contentHost.width * 0.55))
                 : contentHost.width)
        when: root.controlSupportsAvailableWidth
    }

    // Full-width controls (fields, dropdowns, sliders) fill the content column.
    Binding {
        target: root.controlItem
        property: "requestedWidth"
        value: contentHost.width
        when: root.controlSupportsFillWidth && root.controlItem.fillWidth
    }

    // Let embedded-label controls reuse the row's existing setting label.
    Binding {
        target: root.controlItem
        property: "fieldLabel"
        value: root.labelText
        when: root.controlOwnsLabel && root.controlItem.fieldLabel !== undefined
    }

    function activateReset() {
        if (!root.canReset || !root.resetCallback)
            return
        root.resetCallback()
        restartResetFlash()
    }

    function restartResetFlash() {
        if (MotionTokens.reducedMotion) {
            resetFlashAnimation.stop()
            resetFlashOverlay.opacity = 0
            return
        }
        resetFlashAnimation.restart()
    }

    Connections {
        target: MotionTokens
        function onReducedMotionChanged() {
            if (MotionTokens.reducedMotion)
                root.restartResetFlash()
        }
    }

    // Slide the restore-default strip from behind the row card's rounded edge.
    Item {
        id: revertButton
        z: 0
        x: Math.max(0, root.revertVisible ? root.revertVisibleX : root.revertHiddenX)
        y: 0
        width: root.revertVisualWidth
        height: root.choicePresentation ? root.safeMainControlHeight : root.revealHeight
        visible: root.enabled && root.hasDefault && (root.revertVisible || x > root.revertHiddenX + 0.5)
        enabled: root.canReset && root.interactable
        activeFocusOnTab: root.canReset
        Accessible.role: Accessible.Button
        Accessible.name: "恢复默认"
        scale: revertPress.pressed ? MotionTokens.pressScale : 1
        Behavior on scale {
            enabled: !MotionTokens.reducedMotion
            NumberAnimation { duration: MotionTokens.fast; easing.type: Easing.OutQuint }
        }
        Behavior on x {
            enabled: !MotionTokens.reducedMotion
            NumberAnimation { duration: MotionTokens.fast; easing.type: Easing.OutQuint }
        }

        Rectangle {
            anchors.fill: parent
            topLeftRadius: 0
            topRightRadius: root.cardRadius
            bottomRightRadius: root.cardRadius
            bottomLeftRadius: 0
            color: revertHover.hovered || revertPress.pressed || revertButton.activeFocus
                   ? LazerTheme.settingsResetSurfaceHover : LazerTheme.settingsResetSurface
            border.width: revertButton.activeFocus ? 1 : 0
            border.color: LazerTheme.focusRing
            Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
        }

        // Confirm a reset while keeping the pseudo-crescent surface geometry.
        Rectangle {
            id: resetFlashOverlay
            z: 1
            anchors.fill: parent
            topLeftRadius: 0
            topRightRadius: root.cardRadius
            bottomRightRadius: root.cardRadius
            bottomLeftRadius: 0
            color: LazerTheme.textPrimary
            opacity: 0
            enabled: false
        }

        Image {
            id: revertIcon
            z: 2
            anchors.centerIn: parent
            anchors.horizontalCenterOffset: root.cardRadius / 2
            width: 14
            height: 14
            source: "icons/undo.svg"
            fillMode: Image.PreserveAspectFit
        }
        MultiEffect {
            z: 2
            anchors.fill: revertIcon
            source: revertIcon
            visible: revertIcon.visible
            colorization: 1
                colorizationColor: revertHover.hovered || revertPress.pressed || revertButton.activeFocus
                                   ? LazerTheme.settingsAccent : LazerTheme.textMuted
            Behavior on colorizationColor { ColorAnimation { duration: MotionTokens.fast } }
        }

        // Match the shared osu-style click flash timing.
        NumberAnimation {
            id: resetFlashAnimation
            target: resetFlashOverlay
            property: "opacity"
            from: MotionTokens.clickFlashOpacity
            to: 0
            duration: MotionTokens.clickFlashDuration
            easing.type: MotionTokens.clickFlashEasing
            running: false
        }

        HoverHandler {
            id: revertHover
            enabled: root.canReset && root.interactable
        }
        TapHandler {
            id: revertPress
            enabled: root.canReset && root.interactable
            onTapped: root.activateReset()
        }
        Keys.onPressed: event => {
            if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) && root.canReset) {
                root.activateReset()
                event.accepted = true
            }
        }
    }

    // Own one stable content rectangle for every presentation mode.
    Item {
        id: contentHost
        z: 1
        x: root.choicePresentation ? 0 : contentPadding
        y: root.choicePresentation || root.inlinePresentation || root.splitPresentation ? 0 : 10
        width: Math.max(0, root.width - (root.choicePresentation
                                        ? root.reservedResetWidth
                                        : contentPadding + root.reservedResetGap + root.reservedResetWidth))
        height: root.inlinePresentation ? 44
                : (root.choicePresentation ? root.safeControlHeight
                   : (root.splitPresentation ? 52
                       : root.implicitHeight - 20))
        Behavior on width { enabled: !MotionTokens.reducedMotion; NumberAnimation { duration: MotionTokens.fast; easing.type: Easing.OutQuint } }

        Text {
            id: labelItem
            width: root.inlinePresentation ? Math.max(0, parent.width - controlHost.width - 12) : parent.width
            visible: !root.controlOwnsLabel
            height: root.inlinePresentation ? parent.height : implicitHeight
            anchors.verticalCenter: root.inlinePresentation ? parent.verticalCenter : undefined
            anchors.top: root.splitPresentation ? undefined : parent.top
            anchors.bottom: root.splitPresentation ? valueItem.top : undefined
            anchors.bottomMargin: root.splitPresentation ? 2 : 0
            text: root.labelText
            color: root.splitPresentation ? LazerTheme.settingsNavInactive : LazerTheme.textPrimary
            font.pixelSize: root.splitPresentation ? 11 : 14
            elide: Text.ElideRight
            verticalAlignment: root.inlinePresentation ? Text.AlignVCenter : Text.AlignTop
        }

        Text {
            id: valueItem
            visible: root.splitPresentation
            anchors.left: labelItem.left
            anchors.top: root.splitPresentation ? undefined : labelItem.bottom
            anchors.bottom: root.splitPresentation ? parent.bottom : undefined
            anchors.bottomMargin: root.splitPresentation ? 10 : 0
            text: root.splitPresentation && root.controlItem && root.controlItem.displayText !== undefined
                  ? String(root.controlItem.displayText) : ""
            color: LazerTheme.textPrimary
            font.pixelSize: 14
            font.weight: Font.DemiBold
            Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
        }

        Item {
            id: controlHost
            x: root.inlinePresentation || root.splitPresentation
               ? Math.max(0, parent.width - width) : 0
            y: root.choicePresentation ? 0
               : root.inlinePresentation ? Math.max(0, (parent.height - height) / 2)
               : root.splitPresentation ? Math.max(0, (parent.height - height) / 2)
               : labelItem.implicitHeight + root.labelControlGap
            width: root.inlinePresentation ? root.inlineControlWidth
                 : (root.choicePresentation ? parent.width
                     : (root.splitPresentation ? root.splitControlWidth : parent.width))
            height: root.safeControlHeight
            Behavior on x { enabled: !MotionTokens.reducedMotion; NumberAnimation { duration: MotionTokens.fast; easing.type: Easing.OutQuint } }
            Behavior on width { enabled: !MotionTokens.reducedMotion; NumberAnimation { duration: MotionTokens.fast; easing.type: Easing.OutQuint } }
        }
    }
    }

    readonly property Item labelTextItem: labelItem
    readonly property Item valueTextItem: valueItem
    readonly property Item contentItem: contentHost
    readonly property Item revertButtonItem: revertButton
    readonly property Item cardItem: cardSurface
    readonly property Item cardHighlightItem: cardHighlight
    readonly property bool hovered: rowHovered
}
