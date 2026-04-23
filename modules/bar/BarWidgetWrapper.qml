import QtQuick
import qs.config
import qs.services

// Wraps a bar widget with shared sizing, drag, and arrival animation behavior.
Item {
    id: wrapper

    property int staggerIndex: 0
    property string widgetId: ""
    // Stable instance key in format "{widgetId}_{n}". Set by BarSection delegate.
    property string instanceKey: ""
    property string sectionRole: ""
    default property alias content: contentContainer.data

    // Collapse layout space during drag; content stays visible (clip: false)
    property bool _isDragging: false
    property bool _suppressNextWidthAnimation: false
    property bool _awaitingDelegateAlignment: false
    property real _naturalWidth: contentContainer.childrenRect.width
    property real _naturalHeight: contentContainer.childrenRect.height
    readonly property var _measurementSource: {
        if (contentContainer.children.length <= 0)
            return null

        const child = contentContainer.children[0]
        if (child && child.item)
            return child.item

        return child
    }
    readonly property real _layoutMeasuredWidth: {
        let source = wrapper._measurementSource

        if (source && source.layoutMeasurementWidth !== undefined) {
            return Math.max(0, Number(source.layoutMeasurementWidth) || 0)
        }

        if (source) {
            let implicitWidth = Math.max(0, Number(source.implicitWidth) || 0)
            if (implicitWidth > 0)
                return implicitWidth

            let sourceWidth = Math.max(0, Number(source.width) || 0)
            if (sourceWidth > 0)
                return sourceWidth
        }

        return Math.max(0, wrapper._naturalWidth)
    }
    property bool _enterStarted: false
    readonly property var _arrivalGeometry: {
        let arrivals = BarLayoutService.geometryArrivals || ({})
        if (!wrapper.instanceKey || arrivals[wrapper.instanceKey] === undefined) {
            return null
        }

        return arrivals[wrapper.instanceKey]
    }
    readonly property bool _overlayArrivalActive:
        !!wrapper._arrivalGeometry
        && wrapper._arrivalGeometry.active === true
        && wrapper._arrivalGeometry.phase === "overlay"
    readonly property bool _delegateArrivalReleased:
        !!wrapper._arrivalGeometry
        && wrapper._arrivalGeometry.active === true
        && wrapper._arrivalGeometry.phase === "delegate"
        && wrapper._arrivalGeometry.delegateReleased === true
    readonly property bool _batonReleasedForWrapper: {
        let arrival = wrapper._arrivalGeometry
        if (!arrival || !arrival.section) {
            return true
        }

        return BarLayoutService.revealLockHolder(arrival.section) === wrapper.instanceKey
    }
    property bool _showSettingsOutline: BarLayoutService.settingsMode
        && wrapper._enterDone
        && !wrapper._isDragging
        && wrapper.implicitWidth >= wrapper._layoutMeasuredWidth - 0.5
    property string _reportedInstanceKey: ""
    // In-memory reporter token so only the active delegate instance can clear its runtime width.
    property string _measurementReporterId:
        "bar_wrapper_" + Date.now().toString(36) + "_" + Math.random().toString(36).slice(2)
    readonly property bool _primaryActionsSuppressed:
        BarLayoutService.suppressWidgetPrimaryActions && !wrapper._isDragging

    implicitWidth: _isDragging ? 0 : _layoutMeasuredWidth
    implicitHeight: _naturalHeight

    Behavior on implicitWidth {
        enabled: false
        NumberAnimation {
            duration: Theme.anim.moveDuration
            easing.type: Theme.anim.moveType
        }
    }

    // Keep local slot reflow smooth while section push is owned above.
    Behavior on x {
        enabled: !wrapper._isDragging && wrapper._enterDone
        NumberAnimation {
            duration: Theme.anim.moveDuration
            easing.type: Theme.anim.moveType
        }
    }

    // Background for highlight pulse + settings mode outline
    Rectangle {
        id: pulseBackground
        anchors.fill: parent
        anchors.margins: -2
        radius: Theme.cornerRadius + 2
        color: "transparent"
        border.color: Colors.highlight
        border.width: wrapper._showSettingsOutline ? 1 : 0
        opacity: wrapper._showSettingsOutline ? 0.5 : 0
        visible: !wrapper._isDragging

        Behavior on opacity { NumberAnimation { duration: Theme.anim.highlightDuration; easing.type: Theme.anim.highlightType } }
    }

    Item {
        id: contentContainer
        width: childrenRect.width
        height: childrenRect.height
        visible: !wrapper._isDragging
    }

    TapHandler {
        acceptedButtons: Qt.LeftButton
        enabled: wrapper._primaryActionsSuppressed
    }

    // --- Enter animation ---
    opacity: 0
    scale: 0.8
    property bool _enterDone: false

    function completeEnterImmediately() {
        wrapper._awaitingDelegateAlignment = false
        wrapper._enterStarted = true
        wrapper.opacity = 1
        wrapper.scale = 1
        wrapper._enterDone = true
    }

    function tryStartEnterAnimation() {
        if (wrapper._enterStarted || wrapper._enterDone)
            return;
        if (wrapper._naturalWidth <= 0 || wrapper._naturalHeight <= 0)
            return;

        let arrival = wrapper._arrivalGeometry

        if (BarLayoutService.settingsMode && wrapper.instanceKey && wrapper.sectionRole) {
            let widgetGeometry = BarLayoutService.widgetGeometry(wrapper.instanceKey)
            let expectedX = widgetGeometry && widgetGeometry.localLeft !== undefined
                ? Number(widgetGeometry.localLeft) || 0
                : wrapper.x

            if (Math.abs(wrapper.x - expectedX) > 0.5) {
                wrapper._awaitingDelegateAlignment = true
                return
            }
        }

        if (BarLayoutService.settingsMode && !arrival) {
            wrapper.completeEnterImmediately()
            return
        }

        if (wrapper._overlayArrivalActive) {
            wrapper._awaitingDelegateAlignment = false
            return;
        }

        if (arrival && arrival.section) {
            if (!wrapper._delegateArrivalReleased || !wrapper._batonReleasedForWrapper) {
                wrapper._awaitingDelegateAlignment = false
                return;
            }
        }

        wrapper._awaitingDelegateAlignment = false
        wrapper._enterStarted = true;
        enterAnimation.start();
    }

    function reportMeasuredWidth() {
        if (!wrapper.instanceKey) {
            return
        }

        let nextWidth = Math.max(0, wrapper._layoutMeasuredWidth)

        if (nextWidth <= 0) {
            return
        }

        let accepted = BarLayoutService.setWidgetMeasuredWidth(wrapper.instanceKey, nextWidth, {
            source: "runtime",
            reporterId: wrapper._measurementReporterId,
            preserveExternalSnapshot: true
        })

        if (accepted) {
            wrapper._reportedInstanceKey = wrapper.instanceKey
        } else if (wrapper._reportedInstanceKey === wrapper.instanceKey) {
            wrapper._reportedInstanceKey = ""
        }

    }

    function clearReportedMeasuredWidth() {
        if (!wrapper._reportedInstanceKey) {
            return
        }

        BarLayoutService.clearWidgetMeasuredWidth(wrapper._reportedInstanceKey, {
            reporterId: wrapper._measurementReporterId
        })
        wrapper._reportedInstanceKey = ""
    }

    Component.onCompleted: {
        wrapper.tryStartEnterAnimation()
        wrapper.reportMeasuredWidth()
        Qt.callLater(wrapper.tryStartEnterAnimation)
        Qt.callLater(wrapper.reportMeasuredWidth)
    }

    Component.onDestruction: wrapper.clearReportedMeasuredWidth()

    on_NaturalHeightChanged: wrapper.tryStartEnterAnimation()

    on_LayoutMeasuredWidthChanged: {
        wrapper.tryStartEnterAnimation()
        wrapper.reportMeasuredWidth()
    }

    on_BatonReleasedForWrapperChanged: wrapper.tryStartEnterAnimation()

    on_DelegateArrivalReleasedChanged: wrapper.tryStartEnterAnimation()

    on_OverlayArrivalActiveChanged: wrapper.tryStartEnterAnimation()

    onXChanged: wrapper.tryStartEnterAnimation()

    onWidthChanged: wrapper.tryStartEnterAnimation()

    onInstanceKeyChanged: {
        if (wrapper._reportedInstanceKey && wrapper._reportedInstanceKey !== wrapper.instanceKey) {
            wrapper.clearReportedMeasuredWidth()
        }
        wrapper.reportMeasuredWidth()
        wrapper.tryStartEnterAnimation()
    }

    on_NaturalWidthChanged: wrapper.tryStartEnterAnimation()

    Timer {
        id: delegateAlignmentRetryTimer
        interval: 16
        repeat: true
        running: wrapper._awaitingDelegateAlignment && !wrapper._enterStarted && !wrapper._enterDone
        onTriggered: wrapper.tryStartEnterAnimation()
    }

    Connections {
        target: BarLayoutService

        function onGeometryArrivalsChanged() {
            wrapper.tryStartEnterAnimation()
        }
    }

    SequentialAnimation {
        id: enterAnimation
        PauseAnimation { duration: wrapper.staggerIndex * Theme.staggerDelay }
        ParallelAnimation {
            NumberAnimation {
                target: wrapper; property: "opacity"
                from: 0; to: 1
                duration: Theme.anim.enterDuration
                easing.type: Theme.anim.enterType
                easing.amplitude: Theme.anim.enterAmplitude
                easing.period: Theme.anim.enterPeriod
            }
            NumberAnimation {
                target: wrapper; property: "scale"
                from: 0.8; to: 1.0
                duration: Theme.anim.enterDuration
                easing.type: Theme.anim.enterType
                easing.amplitude: Theme.anim.enterAmplitude
                easing.period: Theme.anim.enterPeriod
            }
        }
        ScriptAction {
            script: {
                wrapper._enterDone = true
                BarLayoutService.finishArrivalReveal(wrapper.instanceKey)
            }
        }
    }

    // --- Settings mode drag ---
    // Saved initial wrapper center in BarContent space
    property real _dragStartContentX: 0

    // Cursor hint in settings mode: open hand while hoverable, closed during drag.
    HoverHandler {
        enabled: BarLayoutService.settingsMode && wrapper._enterDone
        cursorShape: wrapper._isDragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
    }

    // Right-click opens widget-specific context menu.
    TapHandler {
        acceptedButtons: Qt.RightButton
        enabled: !BarLayoutService.isDragging
        onTapped: function(eventPoint) {
            let bc = wrapper.findBarContent();
            if (!bc) return;
            let centreInBar = wrapper.mapToItem(bc, wrapper.implicitWidth / 2, 0);
            let clickInBar  = wrapper.mapToItem(bc, eventPoint.position.x, 0);
            bc.openWidgetContextMenu(
                wrapper.instanceKey,
                wrapper.widgetId,
                clickInBar.x,
                centreInBar.x);
        }
    }

    Timer {
        id: suppressAnimationTimer
        interval: 0    // 0 = next event loop tick; used to re-enable animation after immediate suppression
        repeat: false
        onTriggered: wrapper._suppressNextWidthAnimation = false
    }

    // Find ancestor with hitTestSection function (BarContent)
    function findBarContent() {
        let bc = wrapper.parent;
        while (bc && !bc.hitTestSection)
            bc = bc.parent;
        return bc;
    }

    DragHandler {
        id: dragHandler
        enabled: BarLayoutService.settingsMode && wrapper._enterDone
        target: null
        xAxis.enabled: true
        yAxis.enabled: false

        property real startSceneX: 0

        onActiveChanged: {
            if (active) {
                startSceneX = centroid.scenePosition.x;
                let bc = wrapper.findBarContent();
                if (bc) {
                    let pt = wrapper.mapToItem(bc, wrapper.implicitWidth / 2, 0);
                    wrapper._dragStartContentX = pt.x;
                }
                wrapper._isDragging = true;
                BarLayoutService.beginDrag(
                    wrapper.instanceKey,
                    wrapper.widgetId,
                    wrapper._dragStartContentX
                );
            } else {
                let dragResult = BarLayoutService.endDrag("left");

                if (dragResult.samePlacement) {
                    wrapper._suppressNextWidthAnimation = true;
                    wrapper._isDragging = false;
                    suppressAnimationTimer.restart();
                } else {
                    wrapper._isDragging = false;
                }
            }
        }

        onCentroidChanged: {
            if (active) {
                let mouseOffset = centroid.scenePosition.x - startSceneX;
                let visualCenterX = wrapper._dragStartContentX + mouseOffset;
                BarLayoutService.updateDrag(visualCenterX);
            }
        }
    }

    // --- Highlight pulse API ---
    function pulse(count) {
        pulseAnimation.loops = count;
        pulseAnimation.start();
    }

    SequentialAnimation {
        id: pulseAnimation
        NumberAnimation {
            target: pulseBackground; property: "opacity"
            from: 0; to: Colors.highlightAlpha
            duration: Theme.anim.highlightDuration
            easing.type: Theme.anim.highlightType
        }
        NumberAnimation {
            target: pulseBackground; property: "opacity"
            from: Colors.highlightAlpha; to: 0
            duration: Theme.anim.highlightDuration
            easing.type: Theme.anim.highlightType
        }
    }
}
