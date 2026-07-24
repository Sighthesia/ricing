import "."
import "./tray" as Tray
import "../../services" as Services
import "../../services/barlayout/BarLayoutSections.js" as BarLayoutSections
import QtQuick

// Render a single ordered section inside a shared attached-island surface.
Item {
    id: root

    required property string sectionName
    required property string screenName
    required property real screenX
    required property real screenY
    required property real screenWidth
    required property real screenHeight
    property real blurSourceOffsetX: 0
    property real sectionPushOffsetX: 0
    property bool contentLiftActive: false
    property bool floatingValidationIntent: false
    readonly property var sectionModel: Services.BarLayoutService.sectionWidgets(sectionName)
    readonly property bool hasSectionContent: root.sectionModel.length > 0
    readonly property bool canOpenWidgetPicker: Services.BarLayoutService.layoutReady
    readonly property var blurParts: surfaceLoader.item ? surfaceLoader.item.blurParts : []
    readonly property real residualPushOffsetX: surfaceLoader.item ? surfaceLoader.item.residualPushOffsetX : 0
    readonly property real bodyShrinkX: (surfaceLoader.item && surfaceLoader.item.dockzone) ? surfaceLoader.item.dockzone.bodyShrinkX : 0
    readonly property bool hostsContextMenu: Services.BarLayoutService.contextMenuVisible
        && !Services.BarLayoutService.widgetPickerVisible
        && Services.BarLayoutService.contextMenuScreenName === root.screenName
        && Services.BarLayoutService.contextMenuSection === root.sectionName
    readonly property bool hostsWidgetPicker: Services.BarLayoutService.widgetPickerVisible
        && Services.BarLayoutService.widgetPickerScreenName === root.screenName
        && Services.BarLayoutService.widgetPickerSection === root.sectionName
    readonly property bool hostsWidgetSettings: Services.BarLayoutService.widgetSettingsVisible
        && Services.BarLayoutService.widgetSettingsScreenName === root.screenName
        && Services.BarLayoutService.widgetSettingsSection === root.sectionName
    readonly property string surfaceState: root.sectionName === "center"
        ? ((root.hasSectionContent || root.hostsContextMenu || root.hostsWidgetPicker || root.hostsWidgetSettings)
            ? (root.floatingValidationIntent ? "floating" : "attached")
            : "hidden")
        : ((root.hasSectionContent || root.hostsContextMenu || root.hostsWidgetPicker || root.hostsWidgetSettings) ? "attached" : "hidden")
    // Unified expand request: the latest-wins owner for all expand content
    // (hover details, tray menu, context menu, widget picker, widget settings).
    // null when no expand is active.
    // Object shape: { sourceKey, type, component, expandWidth, expandHeight }
    property var expandRequest: null
    // Retain the outgoing owner until the dockzone has visibly contracted.
    property var _closingExpandRequest: null
    // Retained for the clear timer when switching hover details.
    property string _lastHoverSourceKey: ""
    // When a persistent expand (e.g. Media lyrics) is displaced by interactive
    // content, it is saved here so it can be re-submitted when the displacer clears.
    property var _pendingPersistentRequest: null
    property Timer _expandClearTimer: Timer {
        interval: 600
        repeat: false
        onTriggered: {
            if (root.expandRequest && root.expandRequest.sourceKey === root._lastHoverSourceKey) {
                root._closingExpandRequest = root.expandRequest
                root.expandRequest = null
                root._lastHoverSourceKey = ""

                // Re-submit the displaced persistent expand (e.g. Media lyrics)
                // now that the detail grace period has expired.
                if (root._pendingPersistentRequest) {
                    var pending = root._pendingPersistentRequest
                    root._pendingPersistentRequest = null
                    root.submitExpandRequest(
                        pending.sourceKey,
                        pending.type,
                        pending.component,
                        pending.expandWidth,
                        pending.expandHeight
                    )
                }
            }
        }
    }

    // Submit a new expand request. Latest request always wins.
    // For menu types (tray/context/picker/settings), the request takes effect immediately.
    // For hover details, the request is held until cleared or superseded.
    function submitExpandRequest(sourceKey, type, component, expandWidth, expandHeight) {
        if (!sourceKey)
            return

        root._expandClearTimer.stop()
        root._closingExpandRequest = null

        // When interactive content (detail or menu) displaces a persistent expand,
        // save the persistent so it can be re-submitted when the displacer clears.
        if (root.expandRequest
            && root.expandRequest.type === "persistent"
            && type !== "persistent") {
            root._pendingPersistentRequest = root.expandRequest
        } else if (type === "persistent") {
            // A new persistent request cancels any pending displacement.
            root._pendingPersistentRequest = null
        }

        root._lastHoverSourceKey = type === "detail" ? sourceKey : ""
        root.expandRequest = {
            sourceKey: sourceKey,
            type: type,
            component: component,
            expandWidth: Math.max(0, expandWidth || 0),
            expandHeight: Math.max(0, expandHeight || 0),
        }
    }

    // Clear an expand request. Only succeeds if the given sourceKey matches
    // the current request's sourceKey (or if the request was already null).
    function clearExpandRequest(sourceKey) {
        if (!sourceKey)
            return

        // If a pending persistent matches this key, clear the pending.
        if (root._pendingPersistentRequest && root._pendingPersistentRequest.sourceKey === sourceKey) {
            root._pendingPersistentRequest = null
        }

        if (root.expandRequest && root.expandRequest.sourceKey === sourceKey) {
            var prevType = root.expandRequest.type

            // Delay clearing for hover details so the host spring collapse
            // animates smoothly. For menu types, clear immediately.
            if (prevType === "detail") {
                root._expandClearTimer.restart()
            } else {
                root._closingExpandRequest = root.expandRequest
                root.expandRequest = null
                root._lastHoverSourceKey = ""

                // If a non-persistent request was just cleared and a persistent
                // request is pending (displaced earlier), re-submit it now.
                if (prevType !== "persistent" && root._pendingPersistentRequest) {
                    var pending = root._pendingPersistentRequest
                    root._pendingPersistentRequest = null
                    root.submitExpandRequest(
                        pending.sourceKey,
                        pending.type,
                        pending.component,
                        pending.expandWidth,
                        pending.expandHeight
                    )
                }
            }
        }
    }

    implicitHeight: surfaceLoader.item ? surfaceLoader.item.implicitHeight : Services.BarLayoutService.barHeight
    implicitWidth: root.hasSectionContent
        ? (surfaceLoader.item ? surfaceLoader.item.implicitWidth : 0)
        : (root.canOpenWidgetPicker ? 72 : 0)
    width: implicitWidth
    height: implicitHeight

    // Preserve a small hit target so an empty dockzone can still reopen the widget picker.
    MouseArea {
        anchors.fill: parent
        enabled: !root.hasSectionContent && root.canOpenWidgetPicker
        acceptedButtons: Qt.RightButton
        hoverEnabled: enabled
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: (mouse) => {
            var barPos = root.mapToItem(root.parent, mouse.x, mouse.y)
            var barContent = root.parent

            while (barContent && !barContent.openWidgetContextMenu) {
                barContent = barContent.parent
            }

            if (barContent && barContent.openWidgetContextMenu) {
                var scenePos = root.mapToItem(null, mouse.x, mouse.y)
                Services.TrayMenuService.close()
                barContent.openWidgetContextMenu("", "", scenePos.x, root.screenName, scenePos.x)
            }
        }
    }

    // Route every section through the unified surface owner.
    Loader {
        id: surfaceLoader

        active: true
        sourceComponent: surfaceShell
    }

    // Unified path: owner-managed surface with section-aware model-driven rendering.
    Component {
        id: surfaceShell

        Item {
            id: surfaceRoot
            readonly property var blurParts: dockzone.blurParts
            readonly property real residualPushOffsetX: dockzone.residualPushOffsetX

            implicitWidth: dockzone.implicitWidth
            implicitHeight: dockzone.implicitHeight
            width: implicitWidth
            height: implicitHeight

            function syncCenterFloatingValidationIntent() {
                if (root.sectionName !== "center")
                    return;

                var hasLocalPointerIntent = false;

                for (var i = 0; i < sectionRow.children.length; ++i) {
                    var child = sectionRow.children[i];
                    if (child && child.localPointerIntent) {
                        hasLocalPointerIntent = true;
                        break;
                    }
                }

                root.floatingValidationIntent = hasLocalPointerIntent;
            }

            Component.onCompleted: syncCenterFloatingValidationIntent()

            // Track section hover passively so child mouse areas do not retrigger it.
            HoverHandler {
                id: sectionHoverHandler

                enabled: root.hasSectionContent
            }

            DockzoneSurfaceRoot {
                id: dockzone

                section: root.sectionName
                screenName: root.screenName
                screenX: root.screenX
                screenY: root.screenY
                screenWidth: root.screenWidth
                screenHeight: root.screenHeight
                windowX: surfaceRoot.x + root.x
                blurSourceOffsetX: root.blurSourceOffsetX
                sectionPushOffsetX: root.sectionPushOffsetX
                surfaceHeight: Services.BarLayoutService.barHeight
                contentWidth: sectionRow.implicitWidth
                contentHeight: sectionRow.implicitHeight
                surfaceState: root.surfaceState
                hoverIntent: sectionHoverHandler.hovered
                anchors.fill: parent

                // Host the tray DBus menu by expanding this dockzone downward
                // (island-style) when the menu is open and its anchor icon lives
                // in this section. The body grows by the menu height and widens
                // to the menu width; the menu renders in the body below the icon
                // row. expandHeight/expandWidth are zero for every other section
                // and when closed, so normal dockzones are unaffected.
                readonly property real rowScreenLeft: sectionRow.mapToItem(null, 0, 0).x
                readonly property real rowScreenRight: sectionRow.mapToItem(null, sectionRow.width, 0).x
                readonly property bool hostsTrayMenu: root.hasSectionContent
                    && Services.TrayMenuService.visible
                    && Services.TrayMenuService.anchorX >= rowScreenLeft - 24
                    && Services.TrayMenuService.anchorX <= rowScreenRight + 24
                readonly property bool hostsContextMenu: root.hostsContextMenu && !hostsTrayMenu
                // Menu size sourced from the persistent TrayMenuView below so
                // the natural size is always available (not dependent on a
                // Loader-created instance or an animated viewport).
                readonly property real menuW: persistentTrayMenu.implicitWidth
                readonly property real menuH: persistentTrayMenu.implicitHeight
                readonly property real contextMenuW: persistentContextMenu.implicitWidth
                readonly property real contextMenuH: persistentContextMenu.implicitHeight
                readonly property real widgetPickerW: widgetPickerMeasure.implicitWidth
                readonly property real widgetPickerH: widgetPickerMeasure.implicitHeight
                readonly property real widgetSettingsW: widgetSettingsMeasure.implicitWidth
                readonly property real widgetSettingsH: widgetSettingsMeasure.implicitHeight
                // Keep the menu a little inside the lower glass contour during
                // the expand so foreground text/icons cannot peek through the
                // transparent rounded corners before the body reaches full size.
                readonly property real menuClipInset: Math.max(10, dockzone.bodyRadius * 0.75)
                // The widget picker is a much taller body than the context menu,
                // so keep its lower clip guard shallower to reduce dead space.
                readonly property real pickerClipInset: Math.max(6, dockzone.bodyRadius * 0.45)
                readonly property real menuAnchorX: Services.BarLayoutService.contextMenuX
                    - surfaceRoot.mapToItem(null, 0, 0).x

                // Measure the widget picker without clipping so the host can expand first.
                WidgetPickerView {
                    id: widgetPickerMeasure
                    visible: false
                    enabled: false
                }

                // Measure the widget settings without clipping so the host can expand first.
                WidgetSettingsView {
                    id: widgetSettingsMeasure
                    visible: false
                    enabled: false
                }

                // The unified expand host drives expandHeight/expandWidth directly
                // from the current expand request. Menu requesters already include
                // clip insets; hover details use just the content height.
                readonly property real _targetExpandHeight: root.expandRequest
                    ? root.expandRequest.expandHeight
                    : 0
                readonly property real _revealTargetHeight: root.expandRequest
                    ? root.expandRequest.expandHeight
                    : (root._closingExpandRequest ? root._closingExpandRequest.expandHeight : 0)
                readonly property real _targetExpandWidth: root.expandRequest
                    ? root.expandRequest.expandWidth
                    : 0

                expandHeight: _targetExpandHeight
                expandWidth: (root.expandRequest && root.expandRequest.type !== "detail")
                    ? _targetExpandWidth
                    : 0

                Behavior on expandHeight {
                    SpringAnimation {
                        spring: Services.Motion.islandExpand.spring
                        mass: Services.Motion.islandExpand.mass
                        damping: Services.Motion.islandExpand.dampingExpand
                        epsilon: Services.Motion.islandExpand.epsilon
                    }
                }
                Behavior on expandWidth {
                    SpringAnimation {
                        spring: Services.Motion.islandExpand.spring
                        mass: Services.Motion.islandExpand.mass
                        damping: Services.Motion.islandExpand.dampingExpand
                        epsilon: Services.Motion.islandExpand.epsilon
                    }
                }

                // Unified expand host: renders whichever expand content is active
                // (hover detail, tray menu, context menu, widget picker, or widget
                // settings) in the body area below the widget row.
                // Drives an exit lifecycle for displaced content so detail
                // components fade out as the host contracts rather than cut.
                Item {
                    id: expandHost

                    z: 3
                    x: parent.visualBodyX
                    y: parent.bodyY + parent.topBandHeight
                    width: parent.pushedBodyWidth
                    height: Math.max(0, parent.bodyHeight - parent.topBandHeight)
                    // Stay alive through the host's visual exit.
                    enabled: root.expandRequest !== null || root._closingExpandRequest !== null

                    // Reveal progress for the unified expand lifecycle.
                    // 1 when the host is fully expanded to its target height;
                    // 0 when the host has fully contracted.
                    readonly property real revealProgress: dockzone._revealTargetHeight > 0
                        ? Math.min(1, Math.max(0, dockzone.expandHeight / dockzone._revealTargetHeight))
                        : 0
                    // The current pixel height of the expand viewport.
                    readonly property real revealHeight: Math.max(0, dockzone.expandHeight)
                    // True when interactive content is the active owner.
                    readonly property bool hostIsInteractive: root.expandRequest !== null
                        && (root.expandRequest.type === "tray"
                            || root.expandRequest.type === "context"
                            || root.expandRequest.type === "picker"
                            || root.expandRequest.type === "settings"
                            || root.expandRequest.type === "detail")

                    // Track the previous active component so displaced content
                    // can fade out vs. the host shrink animation, avoiding
                    // hard cuts when switching between details or clearing.
                    property Component _lastActiveComponent: null
                    property Component _exitComponent: null
                    // Closing content follows the host's real contraction progress.
                    property real _exitOpacity: 1

                    // Capture the previous payload when the root owner changes.
                    Connections {
                        target: root

                        function onExpandRequestChanged() {
                            var prevComponent = expandHost._lastActiveComponent
                            var newRequest = root.expandRequest
                            var newComponent = newRequest ? newRequest.component : null

                            if (newRequest) {
                                // Latest-wins replacement is visually atomic: a new
                                // owner never shares the host with stale content.
                                expandHost._exitComponent = null
                                expandHost._exitOpacity = 0
                                expandHost._lastActiveComponent = newComponent
                                return
                            }

                            // Only closing to an empty host retains the last payload
                            // so its exit follows the dockzone's contraction.
                            if (root._closingExpandRequest && prevComponent) {
                                expandHost._exitComponent = prevComponent
                                expandHost._exitOpacity = 1
                            } else {
                                expandHost._exitComponent = null
                                expandHost._exitOpacity = 0
                            }
                            expandHost._lastActiveComponent = null
                        }
                    }

                    // Clear the exit component when the host has contracted
                    // and there is no active request (full clear).
                    onRevealProgressChanged: {
                        if (expandHost.revealProgress < 0.01
                            && !root.expandRequest
                            && root._closingExpandRequest) {
                            root._closingExpandRequest = null
                        }
                        if (expandHost.revealProgress < 0.01
                            && !expandHost._lastActiveComponent
                            && expandHost._exitComponent) {
                            expandHost._exitComponent = null
                        }
                    }

                    // Persistent tray menu renderer — always alive so its natural
                    // implicit size is available for measurement without a hidden
                    // duplicate.  Visible only when the tray menu is the active
                    // expand request.  rootHandle is bound unconditionally so the
                    // view's natural implicitHeight always reflects the current
                    // menu content (handle switches update the QsMenuOpener live)
                    // even when invisible, avoiding a zero-size bootstrap cycle
                    // during the pre-expand measurement read.
                    Tray.TrayMenuView {
                        id: persistentTrayMenu

                        readonly property bool isTrayOwner: (root.expandRequest && root.expandRequest.type === "tray")
                            || (!root.expandRequest && root._closingExpandRequest
                                && root._closingExpandRequest.type === "tray")
                        visible: isTrayOwner
                        enabled: root.expandRequest !== null && root.expandRequest.type === "tray"
                        // Always bind so the implicit size is correct for
                        // measurement regardless of visibility.
                        rootHandle: Services.TrayMenuService.menuHandle
                        viewportWidth: parent ? parent.width : 0
                        viewportHeight: parent ? parent.height : 0
                        // Center the menu in the host viewport, clamped to the
                        // menu's natural width.
                        x: (parent.width - width) / 2
                        width: Math.min(implicitWidth, parent ? parent.width : implicitWidth)
                        height: parent ? parent.height : implicitHeight

                        hostRevealProgress: expandHost.revealProgress
                        hostRevealHeight: expandHost.revealHeight
                        hostIsInteractive: root.expandRequest !== null && root.expandRequest.type === "tray"
                        opacity: expandHost.revealProgress
                        y: (1 - expandHost.revealProgress) * 8
                        clip: true

                        // Live-update the expand host dimensions when async DBus
                        // menu content changes the menu's natural implicit size,
                        // matching the pattern used by persistent expand handlers
                        // (onPersistentExpandHeightChanged et al.) so the body
                        // grows to fit newly arrived entries.
                        onImplicitWidthChanged: _syncTrayExpandDimensions()
                        onImplicitHeightChanged: _syncTrayExpandDimensions()

                        function _syncTrayExpandDimensions() {
                            if (root.expandRequest && root.expandRequest.sourceKey === "tray") {
                                var req = root.expandRequest
                                root.expandRequest = ({
                                    sourceKey: req.sourceKey,
                                    type: req.type,
                                    component: req.component,
                                    expandWidth: Math.max(0, persistentTrayMenu.implicitWidth),
                                    expandHeight: Math.max(0, persistentTrayMenu.implicitHeight + 8 + dockzone.menuClipInset),
                                })
                            }
                        }

                        // Keep tray menu alive while the pointer rests on it.
                        HoverHandler {
                            id: persistentTrayHover

                            enabled: persistentTrayMenu.visible
                            onHoveredChanged: {
                                if (persistentTrayMenu.visible)
                                    Services.TrayMenuService.pointerInMenu = hovered
                            }
                        }
                    }

                    // Persistent bar context menu renderer. Like the tray view,
                    // this same instance measures, reveals, and receives input.
                    BarContextMenuView {
                        id: persistentContextMenu

                        readonly property bool isContextOwner: (root.expandRequest && root.expandRequest.type === "context")
                            || (!root.expandRequest && root._closingExpandRequest
                                && root._closingExpandRequest.type === "context")
                        visible: isContextOwner
                        enabled: root.expandRequest !== null && root.expandRequest.type === "context"
                        viewportWidth: parent ? parent.width : 0
                        viewportHeight: parent ? parent.height : 0
                        x: (parent.width - width) / 2
                        y: (1 - expandHost.revealProgress) * 8
                        width: Math.min(implicitWidth, parent ? parent.width : implicitWidth)
                        height: parent ? parent.height : implicitHeight
                        clip: true
                        opacity: expandHost.revealProgress
                        hostRevealProgress: expandHost.revealProgress
                        hostRevealHeight: expandHost.revealHeight
                        hostIsInteractive: root.expandRequest !== null && root.expandRequest.type === "context"

                        // Keep the active request in sync if menu state changes
                        // alter the visible row set or its natural height.
                        onImplicitWidthChanged: _syncContextExpandDimensions()
                        onImplicitHeightChanged: _syncContextExpandDimensions()

                        function _syncContextExpandDimensions() {
                            if (root.expandRequest && root.expandRequest.sourceKey === "context") {
                                var req = root.expandRequest
                                root.expandRequest = ({
                                    sourceKey: req.sourceKey,
                                    type: req.type,
                                    component: req.component,
                                    expandWidth: Math.max(0, persistentContextMenu.implicitWidth),
                                    expandHeight: Math.max(0, persistentContextMenu.implicitHeight + 8 + dockzone.menuClipInset),
                                })
                            }
                        }
                    }

                    // Active content renderer for details, picker, and settings.
                    // Tray and context menus use persistent instances above.
                    Loader {
                        id: expandContentLoader

                        active: root.expandRequest !== null
                            && root.expandRequest.type !== "tray"
                            && root.expandRequest.type !== "context"
                        // Center all expand content in the host viewport.
                        x: (parent.width - width) / 2
                        y: (1 - expandHost.revealProgress) * 8
                        width: root.expandRequest && root.expandRequest.type === "detail"
                            ? Math.min(root.expandRequest.expandWidth, parent.width)
                            : parent.width
                        height: parent.height
                        clip: true
                        opacity: expandHost.revealProgress
                        enabled: expandHost.hostIsInteractive && expandHost.revealProgress >= 0.99
                        sourceComponent: root.expandRequest ? root.expandRequest.component : null

                        // Pass the host reveal properties to created items so
                        // payloads can drive their own reveal from the actual
                        // animated expand geometry rather than local clips.
                        onItemChanged: {
                            if (item) {
                                item.hostRevealProgress = Qt.binding(function() {
                                    return expandHost.revealProgress
                                })
                                item.hostRevealHeight = Qt.binding(function() {
                                    return expandHost.revealHeight
                                })
                                item.hostIsInteractive = Qt.binding(function() {
                                    return expandHost.hostIsInteractive
                                })
                            }
                        }
                    }

                    // Exiting content renderer: keeps the previous component alive
                    // and visible while the host contracts or until a short fade-out
                    // completes on component replacement.
                    Loader {
                        id: expandExitLoader

                        active: expandHost._exitComponent !== null
                        sourceComponent: expandHost._exitComponent
                        enabled: false
                        // Match the active loader geometry so the exit content
                        // occupies the same viewport region.
                        x: expandContentLoader.x
                        y: expandContentLoader.y
                        width: expandContentLoader.width
                        height: expandContentLoader.height
                        clip: true
                        // Fade driven by host-reveal (when clearing) or explicit
                        // exit animation (when replacing).
                        opacity: (root.expandRequest !== null
                            ? expandHost._exitOpacity
                            : expandHost.revealProgress) * expandHost.revealProgress
                    }
                }

                // Lay out widgets for this section in order.
                Item {
                    id: sectionClip

                    z: 1
                    x: parent.visualBodyX
                    y: parent.bodyY
                    width: parent.pushedBodyWidth
                    height: parent.topBandHeight + (root.expandRequest
                        ? root.expandRequest.expandHeight
                        : 0)

                    // NO clip on this container — hover details are inside it and would
                    // be horizontally clipped when detailWidth > pushedBodyWidth.
                    // Details are centered in the viewport; clipping at pushedBodyWidth
                    // would cut their sides. Row overflow is visually contained by the
                    // glass body and adjacent section z-order; the per-widget BadgeArea
                    // hit-test is unaffected.
                    Item {
                        id: rowClip

                        anchors.fill: parent

                        // Lay out widgets in the moving body.
                        // Pinned to the natural resting body width so hover-driven
                        // expandWidth does not recenter the row and displace edge
                        // widgets away from the cursor (which would close the loop).
                        Row {
                            id: sectionRow

                            readonly property real contentScale: root.sectionName === "left" || root.sectionName === "right"
                                ? (root.contentLiftActive ? 1.035 : 1)
                                : 1

                            x: dockzone.bodyX
                                + (dockzone.naturalBodyWidth - width) / 2
                                + (root.sectionName === "right" ? dockzone.bodyShrinkX : (root.sectionName === "left" ? -dockzone.bodyShrinkX : 0))
                                - sectionClip.x
                            y: (dockzone.topBandHeight - height) / 2
                            spacing: BarLayoutSections.widgetSpacing
                            scale: contentScale

                            Behavior on scale {
                                NumberAnimation {
                                    duration: root.contentLiftActive ? 180 : 260
                                    easing.type: Easing.OutCubic
                                }
                            }

                            // Instantiate each managed widget in sequence.
                            Repeater {
                                model: root.sectionModel.length

                                // Keep each widget wrapper as the delegate so its implicit size drives the row.
                                BarWidgetWrapper {
                                    required property int index

                                    screenName: root.screenName
                                    widgetEntry: root.sectionModel[index]
                                    widgetSource: Qt.resolvedUrl(widgetEntry.source)

                                    onLocalPointerIntentChanged: surfaceRoot.syncCenterFloatingValidationIntent()
                                    onBadgeActiveChanged: {
                                        var wrapper = this
                                        if (badgeActive) {
                                            root.submitExpandRequest(
                                                widgetInstanceKey,
                                                "detail",
                                                wrapper.detailComponent,
                                                dockzoneExpandWidth,
                                                dockzoneExpandHeight
                                            )
                                        } else {
                                            root.clearExpandRequest(widgetInstanceKey)
                                        }
                                    }
                                    onPersistentExpandActiveChanged: {
                                        var wrapper = this
                                        if (persistentExpandActive) {
                                            root.submitExpandRequest(
                                                widgetInstanceKey,
                                                "persistent",
                                                null,
                                                persistentExpandWidth,
                                                persistentExpandHeight
                                            )
                                        } else {
                                            root.clearExpandRequest(widgetInstanceKey)
                                        }
                                    }
                                    onPersistentExpandHeightChanged: {
                                        var wrapper = this
                                        // Update pending persistent dimensions if displaced.
                                        if (root._pendingPersistentRequest
                                            && root._pendingPersistentRequest.sourceKey === wrapper.widgetInstanceKey) {
                                            root._pendingPersistentRequest.expandHeight = Math.max(0, wrapper.persistentExpandHeight || 0)
                                            root._pendingPersistentRequest.expandWidth = Math.max(0, wrapper.persistentExpandWidth || 0)
                                        }
                                        // Update active persistent request if currently shown.
                                        if (root.expandRequest && root.expandRequest.type === "persistent"
                                            && root.expandRequest.sourceKey === wrapper.widgetInstanceKey) {
                                            var req = root.expandRequest
                                            root.expandRequest = ({
                                                sourceKey: req.sourceKey,
                                                type: req.type,
                                                component: req.component,
                                                expandWidth: Math.max(0, wrapper.persistentExpandWidth || 0),
                                                expandHeight: Math.max(0, wrapper.persistentExpandHeight || 0),
                                            })
                                        }
                                    }
                                    onPersistentExpandWidthChanged: {
                                        var wrapper = this
                                        if (root._pendingPersistentRequest
                                            && root._pendingPersistentRequest.sourceKey === wrapper.widgetInstanceKey) {
                                            root._pendingPersistentRequest.expandWidth = Math.max(0, wrapper.persistentExpandWidth || 0)
                                            root._pendingPersistentRequest.expandHeight = Math.max(0, wrapper.persistentExpandHeight || 0)
                                        }
                                        if (root.expandRequest && root.expandRequest.type === "persistent"
                                            && root.expandRequest.sourceKey === wrapper.widgetInstanceKey) {
                                            var req2 = root.expandRequest
                                            root.expandRequest = ({
                                                sourceKey: req2.sourceKey,
                                                type: req2.type,
                                                component: req2.component,
                                                expandWidth: Math.max(0, wrapper.persistentExpandWidth || 0),
                                                expandHeight: Math.max(0, wrapper.persistentExpandHeight || 0),
                                            })
                                        }
                                    }
                                    onDockzoneExpandHeightChanged: {
                                        var wrapper = this
                                        var isPersistentOwner = root.expandRequest
                                            && root.expandRequest.type === "persistent"
                                            && root.expandRequest.sourceKey === wrapper.widgetInstanceKey
                                        if ((wrapper.badgeActive || isPersistentOwner) && root.expandRequest
                                            && root.expandRequest.sourceKey === widgetInstanceKey) {
                                            // Reassign the expandRequest object to trigger QML binding
                                            // re-evaluation on _targetExpandHeight. In-place mutation
                                            // would not propagate because the var reference is unchanged.
                                            var req = root.expandRequest
                                            root.expandRequest = ({
                                                sourceKey: req.sourceKey,
                                                type: req.type,
                                                component: req.component,
                                                expandWidth: Math.max(0, dockzoneExpandWidth || 0),
                                                expandHeight: Math.max(0, dockzoneExpandHeight || 0),
                                            })
                                        }
                                    }
                                }

                            }

                        }
                    }
                }

            }

            Component {
                id: widgetPickerHostComponent
                WidgetPickerView {
                    viewportWidth: parent ? parent.width : 0
                    viewportHeight: parent ? parent.height : 0
                }
            }

            Component {
                id: widgetSettingsHostComponent
                WidgetSettingsView {
                    viewportWidth: parent ? parent.width : 0
                    viewportHeight: parent ? parent.height : 0
                }
            }

            // Watch for menu state changes and submit/clear unified expand requests.
            Connections {
                target: dockzone
                function onHostsTrayMenuChanged() {
                    if (dockzone.hostsTrayMenu) {
                        // No component — the persistent TrayMenuView handles rendering
                        // and menuHandle binding directly.
                        root.submitExpandRequest(
                            "tray", "tray",
                            null,
                            dockzone.menuW,
                            dockzone.menuH + 8 + dockzone.menuClipInset
                        )
                    } else if (root.expandRequest && root.expandRequest.sourceKey === "tray") {
                        root.clearExpandRequest("tray")
                    }
                }
            }

            Connections {
                target: root
                function onHostsContextMenuChanged() {
                    if (root.hostsContextMenu) {
                        root.submitExpandRequest(
                            "context", "context",
                            null,
                            dockzone.contextMenuW,
                            dockzone.contextMenuH + 8 + dockzone.menuClipInset
                        )
                    } else if (root.expandRequest && root.expandRequest.sourceKey === "context") {
                        root.clearExpandRequest("context")
                    }
                }
            }

            Connections {
                target: root
                function onHostsWidgetPickerChanged() {
                    if (root.hostsWidgetPicker) {
                        root.submitExpandRequest(
                            "picker", "picker",
                            widgetPickerHostComponent,
                            dockzone.widgetPickerW,
                            dockzone.widgetPickerH + 8 + dockzone.pickerClipInset
                        )
                    } else if (root.expandRequest && root.expandRequest.sourceKey === "picker") {
                        root.clearExpandRequest("picker")
                    }
                }
            }

            Connections {
                target: root
                function onHostsWidgetSettingsChanged() {
                    if (root.hostsWidgetSettings) {
                        root.submitExpandRequest(
                            "settings", "settings",
                            widgetSettingsHostComponent,
                            dockzone.widgetSettingsW,
                            dockzone.widgetSettingsH + 8 + dockzone.menuClipInset
                        )
                    } else if (root.expandRequest && root.expandRequest.sourceKey === "settings") {
                        root.clearExpandRequest("settings")
                    }
                }
            }

        }

    }

}
