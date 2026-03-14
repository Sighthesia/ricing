import QtQuick
import qs.config
import qs.services

Item {
    id: wrapper

    property int staggerIndex: 0
    property string widgetId: ""
    // Stable instance key in format "{widgetId}_{n}". Set by BarSection delegate.
    property string instanceKey: ""
    default property alias content: contentContainer.data

    // Collapse layout space during drag; content stays visible (clip: false)
    property bool _isDragging: false
    property bool _suppressNextWidthAnimation: false
    property real _naturalWidth: contentContainer.childrenRect.width
    property real _naturalHeight: contentContainer.childrenRect.height
    property bool _enterStarted: false
    property bool _showSettingsOutline: BarLayoutService.settingsMode
        && wrapper._enterDone
        && !wrapper._isDragging
        && wrapper.implicitWidth >= wrapper._naturalWidth - 0.5

    implicitWidth: _isDragging ? 0 : _naturalWidth
    implicitHeight: _isDragging ? 0 : _naturalHeight

    Behavior on implicitWidth {
        enabled: !wrapper._suppressNextWidthAnimation && BarLayoutService.settingsMode
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

        Behavior on opacity { NumberAnimation { duration: Theme.anim.highlightDuration; easing.type: Theme.anim.highlightType } }
    }

    Item {
        id: contentContainer
        width: childrenRect.width
        height: childrenRect.height
    }

    // --- Enter animation ---
    opacity: 0
    scale: 0.8
    property bool _enterDone: false

    function tryStartEnterAnimation() {
        if (wrapper._enterStarted || wrapper._enterDone)
            return;
        if (wrapper._naturalWidth <= 0 || wrapper._naturalHeight <= 0)
            return;
        wrapper._enterStarted = true;
        enterAnimation.start();
    }

    Component.onCompleted: Qt.callLater(wrapper.tryStartEnterAnimation)
    on_NaturalWidthChanged: wrapper.tryStartEnterAnimation()
    on_NaturalHeightChanged: wrapper.tryStartEnterAnimation()

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
        ScriptAction { script: wrapper._enterDone = true }
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
            let centreInBar = wrapper.mapToItem(bc, wrapper._naturalWidth / 2, 0);
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

    // Find the BarSection child for a given section name
    function findSection(bc, sectionName) {
        for (let i = 0; i < bc.children.length; i++) {
            let child = bc.children[i];
            if (child.role === sectionName && child.insertIndexAt)
                return child;
        }
        return null;
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
                // Save initial center position in BarContent coords
                let bc = wrapper.findBarContent();
                if (bc) {
                    let pt = wrapper.mapToItem(bc, wrapper._naturalWidth / 2, 0);
                    wrapper._dragStartContentX = pt.x;
                }
                wrapper._isDragging = true;
                BarLayoutService.isDragging = true;
                BarLayoutService.draggedWidgetId = wrapper.widgetId;
                BarLayoutService.ghostWidth = wrapper._naturalWidth;
                // Set initial visual position
                BarLayoutService.dragVisualX = wrapper._dragStartContentX - wrapper._naturalWidth / 2;


                // Sync initial ghost position to match current location immediately
                if (bc && bc.hitTestSection) {
                    let zoneName = bc.hitTestSection(wrapper._dragStartContentX);
                    BarLayoutService.ghostSection = zoneName;
                    let sec = wrapper.findSection(bc, zoneName);
                    if (sec) {
                        let secScene = sec.mapToItem(null, 0, 0);
                        let localX = centroid.scenePosition.x - secScene.x;
                        BarLayoutService.ghostIndex = sec.insertIndexAt(localX);
                        console.log("[DRAG START] init ghost: section:", zoneName, "index:", BarLayoutService.ghostIndex);
                    }
                }
            } else {
                let targetSection = BarLayoutService.ghostSection;
                let targetIndex = BarLayoutService.ghostIndex;
                let isSamePlacement = targetSection !== "" && BarLayoutService.isSamePlacement(wrapper.widgetId, targetSection, targetIndex, "left");


                BarLayoutService.isDragging = false;
                BarLayoutService.dragHoverZone = "";
                BarLayoutService.draggedWidgetId = "";
                BarLayoutService.dragVisualX = 0;
                BarLayoutService.ghostSection = "";
                BarLayoutService.ghostIndex = -1;
                BarLayoutService.ghostWidth = 0;

                if (targetSection !== "") {
                    BarLayoutService.moveWidget(
                        wrapper.widgetId, targetSection, "left", targetIndex);
                }

                if (isSamePlacement) {
                    wrapper._suppressNextWidthAnimation = true;
                    wrapper._isDragging = false;
                    widthAnimationRestoreTimer.restart();
                } else {
                    wrapper._isDragging = false;
                }
            }
        }

        onCentroidChanged: {
            if (active) {
                let mouseOffset = centroid.scenePosition.x - startSceneX;
                // Visual center in BarContent coordinates
                let visualCenterX = wrapper._dragStartContentX + mouseOffset;
                BarLayoutService.dragVisualX = visualCenterX - wrapper._naturalWidth / 2;

                let bc = wrapper.findBarContent();
                if (bc && bc.hitTestSection) {
                    let zoneName = bc.hitTestSection(visualCenterX);
                    BarLayoutService.dragHoverZone = zoneName;
                    BarLayoutService.ghostSection = zoneName;

                    let sec = wrapper.findSection(bc, zoneName);
                    if (sec) {
                        let secScene = sec.mapToItem(null, 0, 0);
                        let sectionLocalX = centroid.scenePosition.x - secScene.x;
                        BarLayoutService.ghostIndex = sec.insertIndexAt(sectionLocalX);
                    }
                }
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
