import QtQuick
import qs.config
import qs.services

// Draws layout-mode drag feedback, ghost slots, and arrival overlays above the bar.
Item {
    id: dragOverlay

    property var widgetRegistry: ({})
    property var _arrivalActorItems: ({})

    anchors.fill: parent
    z: 999

    visible: opacity > 0
    enabled: BarLayoutService.settingsMode
    opacity: BarLayoutService.settingsMode ? 1.0 : 0.0

    Behavior on opacity {
        NumberAnimation {
            duration: Theme.anim.moveDuration
            easing.type: Easing.OutQuad
        }
    }

    function _sectionGeometry(sectionName) {
        return BarLayoutService.sectionGeometry(sectionName)
    }

    function _arrivalSnapshot(instanceKey) {
        let arrivals = BarLayoutService.geometryArrivals || ({})
        return arrivals[instanceKey] !== undefined ? arrivals[instanceKey] : null
    }

    function _syncArrivalActors() {
        let arrivals = BarLayoutService.geometryArrivals || ({})
        let nextKeys = {}

        for (let instanceKey in arrivals) {
            let snapshot = arrivals[instanceKey]
            if (!snapshot || snapshot.active !== true) {
                continue
            }

            nextKeys[instanceKey] = true

            if (dragOverlay._arrivalActorItems[instanceKey]) {
                continue
            }

            let actor = arrivalActorComponent.createObject(dragOverlay, {
                instanceKey: instanceKey,
                snapshot: snapshot,
                widgetRegistry: dragOverlay.widgetRegistry
            })

            if (!actor) {
                BarLayoutService.completeArrivalGeometry(instanceKey)
                continue
            }

            let nextItems = Object.assign({}, dragOverlay._arrivalActorItems)
            nextItems[instanceKey] = actor
            dragOverlay._arrivalActorItems = nextItems
        }

        for (let knownKey in dragOverlay._arrivalActorItems) {
            if (nextKeys[knownKey]) {
                continue
            }

            let actor = dragOverlay._arrivalActorItems[knownKey]
            let nextItems = Object.assign({}, dragOverlay._arrivalActorItems)
            delete nextItems[knownKey]
            dragOverlay._arrivalActorItems = nextItems

            if (actor) {
                actor.destroy()
            }
        }
    }

    DropZone {
        id: leftZone
        zoneName: "left"
        x: dragOverlay._sectionGeometry("left").left
        y: 0
        width: dragOverlay._sectionGeometry("left").width
        height: Theme.barHeight
    }

    DropZone {
        id: centerZone
        zoneName: "center"
        x: dragOverlay._sectionGeometry("center").left
        y: 0
        width: dragOverlay._sectionGeometry("center").width
        height: Theme.barHeight
    }

    DropZone {
        id: rightZone
        zoneName: "right"
        x: dragOverlay._sectionGeometry("right").left
        y: 0
        width: dragOverlay._sectionGeometry("right").width
        height: Theme.barHeight
    }

    Item {
        id: floatingCopy
        objectName: "dragOverlayFloatingCopy"
        visible: BarLayoutService.dragSnapshot.active && BarLayoutService.dragSnapshot.widgetId !== ""
        enabled: false
        x: BarLayoutService.dragSnapshot.visual.left
        anchors.verticalCenter: parent.verticalCenter
        width: BarLayoutService.dragSnapshot.visual.width
        height: parent.height
        scale: Theme.dragScale
        opacity: Theme.dragOpacity

        Loader {
            id: floatingLoader
            anchors.verticalCenter: parent.verticalCenter
            source: {
                if (!floatingCopy.visible) return ""
                let wid = BarLayoutService.dragSnapshot.widgetId
                return dragOverlay.widgetRegistry[wid] || ""
            }
            active: source !== ""
        }
    }

    Component {
        id: arrivalActorComponent

        Item {
            id: arrivalActor

            required property string instanceKey
            required property var snapshot
            required property var widgetRegistry

            readonly property var _currentSnapshot: dragOverlay._arrivalSnapshot(instanceKey)
            readonly property string _widgetId: _currentSnapshot && _currentSnapshot.widgetId
                ? _currentSnapshot.widgetId
                : (snapshot.widgetId || "")
            readonly property string _source: widgetRegistry[_widgetId] || ""
            property bool _completed: false

            objectName: "dragOverlayArrivalActor"
            visible: _currentSnapshot !== null
                && _currentSnapshot.active === true
                && _currentSnapshot.phase === "overlay"
                && _widgetId !== ""
            x: _currentSnapshot ? (_currentSnapshot.barLeft || 0) : (snapshot.barLeft || 0)
            width: _currentSnapshot ? (_currentSnapshot.barWidth || 0) : (snapshot.barWidth || 0)
            height: parent.height
            anchors.verticalCenter: parent.verticalCenter
            opacity: 0
            scale: 0.92

            function _completeHandoff() {
                if (arrivalActor._completed || !arrivalActor.instanceKey) {
                    return
                }

                arrivalActor._completed = true
                BarLayoutService.requestArrivalReveal(arrivalActor.instanceKey)
            }

            Component.onCompleted: {
                handoffTimer.start()

                if (arrivalActor._source === "") {
                    return
                }

                arriveAnimation.start()
            }

            Loader {
                anchors.verticalCenter: parent.verticalCenter
                source: arrivalActor._source
                active: arrivalActor.visible && arrivalActor._source !== ""

                onLoaded: {
                    if (item && item.hasOwnProperty("liveInstance")) {
                        item.liveInstance = false
                    }

                    if (item && item.hasOwnProperty("debugInstanceLabel")) {
                        item.debugInstanceLabel = "overlay:" + arrivalActor.instanceKey
                    }
                }

                onStatusChanged: {
                    if (status === Loader.Error) {
                        arrivalActor._completeHandoff()
                    }
                }
            }

            Timer {
                id: handoffTimer
                interval: Theme.anim.enterDuration
                repeat: false
                onTriggered: arrivalActor._completeHandoff()
            }

            SequentialAnimation {
                id: arriveAnimation

                ParallelAnimation {
                    NumberAnimation {
                        target: arrivalActor
                        property: "opacity"
                        from: 0
                        to: 1
                        duration: Theme.anim.enterDuration
                        easing.type: Theme.anim.enterType
                        easing.amplitude: Theme.anim.enterAmplitude
                        easing.period: Theme.anim.enterPeriod
                    }

                    NumberAnimation {
                        target: arrivalActor
                        property: "scale"
                        from: 0.92
                        to: 1
                        duration: Theme.anim.enterDuration
                        easing.type: Theme.anim.enterType
                        easing.amplitude: Theme.anim.enterAmplitude
                        easing.period: Theme.anim.enterPeriod
                    }
                }
            }
        }
    }

    Component.onCompleted: _syncArrivalActors()

    Connections {
        target: BarLayoutService

        function onGeometryArrivalsChanged() {
            dragOverlay._syncArrivalActors()
        }
    }
}
