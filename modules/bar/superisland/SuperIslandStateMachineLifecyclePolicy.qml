import QtQuick
import qs.services

// Owns state-machine lifecycle bootstrap/teardown and base track resets.
Item {
    id: root

    required property Item host
    required property QtObject state
    required property Item machine

    visible: false
    width: 0
    height: 0

    function initialize() {
        root.state.currentTime = new Date()
        root.machine.syncOverlayFlags()
        const initialActiveEvent = root.host._displayEvent(
            root.host._listensToService ? SuperIslandService.activeEvent : root.host._idleSnapshot()
        )
        root.state._mainDisplayEvent = initialActiveEvent.type !== "idle"
            ? initialActiveEvent
            : root.host._baselineEvent
        root.state._lastActiveEvent = initialActiveEvent
        resetTracks()
        root.state._attachedPanelRevealWidth = root.host._attachedPanelActive ? root.host._attachedPanelWidth : 0
        root.state._attachedPanelRevealHeight = root.host._attachedPanelActive ? root.host._attachedPanelHeight : 0
        root.state._attachedContentOpacity = root.host._attachedPanelActive ? 1 : 0
        root.machine.syncOverlayExtensionReservation()
    }

    function teardown() {
        if (root.host.liveInstance)
            BarLayoutService.clearTransientExtension("super-island-overlay")
    }

    function resetTracks() {
        root.state._mainTrackY = root.host._mainTrackCenterY
        root.state._mainTrackScale = 1
        root.state._mainTrackOpacity = 1
        root.state._flashTrackY = root.host._flashStripY
        root.state._flashTrackScale = root.host._flashScale
        root.state._flashTrackOpacity = 0
    }
}
