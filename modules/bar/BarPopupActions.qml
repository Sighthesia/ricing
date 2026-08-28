import QtQuick
import "../lazerbar"

// Content body for volume, brightness, media, notifications and tray.
// Bound via BarPopupHost contentData; intent actionKind/payload drive visible kind.
Item {
    id: root

    property string actionKind: ""
    property var payload: null

    implicitWidth: 260
    implicitHeight: contentColumn.implicitHeight + 16
    width: implicitWidth
    height: implicitHeight
    visible: true
    clip: false

    // Helpers to resolve payload values with fallback to real services.
    readonly property real volumeValue: {
        if (payload && payload.volume !== undefined && payload.volume !== null)
            return Math.max(0, Math.min(1, Number(payload.volume)))
        if (payload && payload.volumeService && payload.volumeService.sinkVolume !== undefined)
            return Math.max(0, Math.min(1, Number(payload.volumeService.sinkVolume)))
        return 0.5
    }
    readonly property bool volumeMuted: {
        if (payload && payload.muted !== undefined)
            return !!payload.muted
        if (payload && payload.volumeService && payload.volumeService.sinkMuted !== undefined)
            return !!payload.volumeService.sinkMuted
        return false
    }
    readonly property real brightnessValue: {
        if (payload && payload.brightness !== undefined && payload.brightness !== null)
            return Math.max(0, Math.min(1, Number(payload.brightness)))
        if (payload && payload.brightnessService && payload.brightnessService.brightness !== undefined)
            return Math.max(0, Math.min(1, Number(payload.brightnessService.brightness)))
        return 0.8
    }
    readonly property bool notificationDnd: {
        if (payload && payload.dndEnabled !== undefined)
            return !!payload.dndEnabled
        if (payload && payload.notificationService && payload.notificationService.dndEnabled !== undefined)
            return !!payload.notificationService.dndEnabled
        return false
    }

    function handleVolumeValue(v) {
        var nv = Math.max(0, Math.min(1, Number(v)))
        if (!isFinite(nv))
            nv = 0
        if (payload && typeof payload.onVolumeChanged === "function") {
            payload.onVolumeChanged(nv)
            return
        }
        if (payload && payload.volumeService && typeof payload.volumeService.setSinkVolume === "function") {
            payload.volumeService.setSinkVolume(nv)
            return
        }
        if (payload && typeof payload.onValueChanged === "function") {
            payload.onValueChanged(nv)
            return
        }
        // Fallback no-op when no injected service; real shell wires payload to
        // VolumeService.setSinkVolume / toggleSinkMute, so no direct import is
        // needed for qmltestrunner isolation.
    }

    function handleToggleMute() {
        if (payload && typeof payload.onToggleMute === "function") {
            payload.onToggleMute()
            return
        }
        if (payload && typeof payload.onToggleRequested === "function") {
            payload.onToggleRequested()
            return
        }
        if (payload && payload.volumeService && typeof payload.volumeService.toggleSinkMute === "function") {
            payload.volumeService.toggleSinkMute()
            return
        }
    }

    function handleBrightnessValue(v) {
        var nv = Math.max(0, Math.min(1, Number(v)))
        if (!isFinite(nv))
            nv = 0
        if (payload && typeof payload.onBrightnessChanged === "function") {
            payload.onBrightnessChanged(nv)
            return
        }
        if (payload && payload.brightnessService && typeof payload.brightnessService.setBrightness === "function") {
            payload.brightnessService.setBrightness(nv)
            return
        }
        if (payload && typeof payload.onValueChanged === "function") {
            payload.onValueChanged(nv)
            return
        }
    }

    function handleMediaPrevious() {
        if (payload && typeof payload.onPrevious === "function") {
            payload.onPrevious()
            return
        }
        if (payload && payload.mediaService && typeof payload.mediaService.previous === "function") {
            payload.mediaService.previous()
            return
        }
    }

    function handleMediaPlayPause() {
        if (payload && typeof payload.onPlayPause === "function") {
            payload.onPlayPause()
            return
        }
        if (payload && payload.mediaService && typeof payload.mediaService.playPause === "function") {
            payload.mediaService.playPause()
            return
        }
    }

    function handleMediaNext() {
        if (payload && typeof payload.onNext === "function") {
            payload.onNext()
            return
        }
        if (payload && payload.mediaService && typeof payload.mediaService.next === "function") {
            payload.mediaService.next()
            return
        }
    }

    function handleToggleDnd() {
        if (payload && typeof payload.onToggleDnd === "function") {
            payload.onToggleDnd()
            return
        }
        if (payload && payload.notificationService && typeof payload.notificationService.dndEnabled !== "undefined") {
            try { payload.notificationService.dndEnabled = !payload.notificationService.dndEnabled } catch (e) {}
            return
        }
    }

    function handleClearNotifications() {
        if (payload && typeof payload.onClear === "function") {
            payload.onClear()
            return
        }
        if (payload && typeof payload.onClearSticky === "function") {
            payload.onClearSticky()
            return
        }
        if (payload && payload.notificationService && typeof payload.notificationService.clearStickyNotifications === "function") {
            payload.notificationService.clearStickyNotifications()
            return
        }
        if (payload && payload.notificationService && typeof payload.notificationService.markAllRead === "function") {
            payload.notificationService.markAllRead()
            return
        }
    }

    function handleTrayActivate() {
        if (payload && typeof payload.onActivate === "function") {
            payload.onActivate()
            return
        }
        if (payload && payload.trayModel && typeof payload.trayModel.activate === "function") {
            payload.trayModel.activate()
            return
        }
        if (payload && typeof payload.activate === "function") {
            payload.activate()
            return
        }
        try {
            if (payload && payload.trayItem && typeof payload.trayItem.activate === "function")
                payload.trayItem.activate()
        } catch (e) {}
    }

    function handleTraySecondary() {
        if (payload && typeof payload.onSecondaryActivate === "function") {
            payload.onSecondaryActivate()
            return
        }
        if (payload && typeof payload.onSecondary === "function") {
            payload.onSecondary()
            return
        }
        if (payload && payload.trayModel && typeof payload.trayModel.secondaryActivate === "function") {
            payload.trayModel.secondaryActivate()
            return
        }
        if (payload && typeof payload.secondaryActivate === "function") {
            payload.secondaryActivate()
            return
        }
        try {
            if (payload && payload.trayItem && typeof payload.trayItem.secondaryActivate === "function")
                payload.trayItem.secondaryActivate()
        } catch (e) {}
    }

    // Root content container; always visible when actionKind is known.
    Column {
        id: contentColumn
        objectName: "actionsRoot"
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 8
        spacing: 8
        visible: true

        // Volume content.
        Item {
            id: volumeContent
            objectName: "volumeContent"
            width: parent.width
            height: volumeSlider.implicitHeight
            visible: root.actionKind === "volume"

            BarPopupSlider {
                id: volumeSlider
                objectName: "volumeSlider"
                anchors.fill: parent
                value: root.volumeValue
                muted: root.volumeMuted
                label: "Volume"
                showMute: true
                onValueCommitted: function(v) { root.handleVolumeValue(v) }
                onToggleRequested: root.handleToggleMute()
            }
        }

        // Brightness content.
        Item {
            id: brightnessContent
            objectName: "brightnessContent"
            width: parent.width
            height: brightnessSlider.implicitHeight
            visible: root.actionKind === "brightness"

            BarPopupSlider {
                id: brightnessSlider
                objectName: "brightnessSlider"
                anchors.fill: parent
                value: root.brightnessValue
                muted: false
                label: "Brightness"
                showMute: false
                onValueCommitted: function(v) { root.handleBrightnessValue(v) }
            }
        }

        // Media content: previous / playPause / next.
        Item {
            id: mediaContent
            objectName: "mediaContent"
            width: parent.width
            height: 36
            visible: root.actionKind === "media"

            Row {
                anchors.centerIn: parent
                spacing: 8

                // Previous button.
                Rectangle {
                    id: mediaPrevButton
                    objectName: "mediaPrevButton"
                    width: 48
                    height: 32
                    radius: 6
                    color: prevHover.hovered ? LazerTheme.hoverFill : "transparent"
                    border.color: LazerTheme.popupBorder
                    border.width: 1

                    Behavior on color { ColorAnimation { duration: MotionTokens.fast } }

                    Text {
                        anchors.centerIn: parent
                        text: "Prev"
                        color: LazerTheme.textPrimary
                        font.pixelSize: 11
                        font.bold: true
                    }

                    HoverHandler { id: prevHover }
                    TapHandler {
                        gesturePolicy: TapHandler.ReleaseWithinBounds
                        onTapped: root.handleMediaPrevious()
                    }
                }

                // Play/Pause button.
                Rectangle {
                    id: mediaPlayPauseButton
                    objectName: "mediaPlayPauseButton"
                    width: 64
                    height: 32
                    radius: 6
                    color: playHover.hovered ? LazerTheme.hoverFill : LazerTheme.settingsControlSurface
                    border.color: LazerTheme.popupBorder
                    border.width: 1

                    Behavior on color { ColorAnimation { duration: MotionTokens.fast } }

                    Text {
                        anchors.centerIn: parent
                        text: "Play"
                        color: LazerTheme.textPrimary
                        font.pixelSize: 11
                        font.bold: true
                    }

                    HoverHandler { id: playHover }
                    TapHandler {
                        gesturePolicy: TapHandler.ReleaseWithinBounds
                        onTapped: root.handleMediaPlayPause()
                    }
                }

                // Next button.
                Rectangle {
                    id: mediaNextButton
                    objectName: "mediaNextButton"
                    width: 48
                    height: 32
                    radius: 6
                    color: nextHover.hovered ? LazerTheme.hoverFill : "transparent"
                    border.color: LazerTheme.popupBorder
                    border.width: 1

                    Behavior on color { ColorAnimation { duration: MotionTokens.fast } }

                    Text {
                        anchors.centerIn: parent
                        text: "Next"
                        color: LazerTheme.textPrimary
                        font.pixelSize: 11
                        font.bold: true
                    }

                    HoverHandler { id: nextHover }
                    TapHandler {
                        gesturePolicy: TapHandler.ReleaseWithinBounds
                        onTapped: root.handleMediaNext()
                    }
                }
            }
        }

        // Notifications content: DND toggle and clear.
        Item {
            id: notificationsContent
            objectName: "notificationsContent"
            width: parent.width
            height: 36
            visible: root.actionKind === "notifications"

            Row {
                anchors.centerIn: parent
                spacing: 8

                Rectangle {
                    id: dndButton
                    objectName: "notificationDndButton"
                    width: 72
                    height: 32
                    radius: 6
                    color: root.notificationDnd ? LazerTheme.activeFill : (dndHover.hovered ? LazerTheme.hoverFill : LazerTheme.settingsControlSurface)
                    border.color: root.notificationDnd ? LazerTheme.accentColor : LazerTheme.popupBorder
                    border.width: root.notificationDnd ? 2 : 1

                    Behavior on color { ColorAnimation { duration: MotionTokens.fast } }

                    Text {
                        anchors.centerIn: parent
                        text: root.notificationDnd ? "DND On" : "DND Off"
                        color: LazerTheme.textPrimary
                        font.pixelSize: 11
                        font.bold: true
                    }

                    HoverHandler { id: dndHover }
                    TapHandler {
                        gesturePolicy: TapHandler.ReleaseWithinBounds
                        onTapped: root.handleToggleDnd()
                    }
                }

                Rectangle {
                    id: clearButton
                    objectName: "notificationClearButton"
                    width: 72
                    height: 32
                    radius: 6
                    color: clearHover.hovered ? LazerTheme.hoverFill : LazerTheme.settingsControlSurface
                    border.color: LazerTheme.popupBorder
                    border.width: 1

                    Behavior on color { ColorAnimation { duration: MotionTokens.fast } }

                    Text {
                        anchors.centerIn: parent
                        text: "Clear"
                        color: LazerTheme.textPrimary
                        font.pixelSize: 11
                        font.bold: true
                    }

                    HoverHandler { id: clearHover }
                    TapHandler {
                        gesturePolicy: TapHandler.ReleaseWithinBounds
                        onTapped: root.handleClearNotifications()
                    }
                }
            }
        }

        // Tray content: activate / secondary activate.
        Item {
            id: trayContent
            objectName: "trayContent"
            width: parent.width
            height: 36
            visible: root.actionKind === "tray"

            Row {
                anchors.centerIn: parent
                spacing: 8

                Rectangle {
                    id: trayActivateButton
                    objectName: "trayActivateButton"
                    width: 72
                    height: 32
                    radius: 6
                    color: activateHover.hovered ? LazerTheme.hoverFill : LazerTheme.settingsControlSurface
                    border.color: LazerTheme.popupBorder
                    border.width: 1

                    Behavior on color { ColorAnimation { duration: MotionTokens.fast } }

                    Text {
                        anchors.centerIn: parent
                        text: "Open"
                        color: LazerTheme.textPrimary
                        font.pixelSize: 11
                        font.bold: true
                    }

                    HoverHandler { id: activateHover }
                    TapHandler {
                        gesturePolicy: TapHandler.ReleaseWithinBounds
                        onTapped: root.handleTrayActivate()
                    }
                }

                Rectangle {
                    id: traySecondaryButton
                    objectName: "traySecondaryButton"
                    width: 72
                    height: 32
                    radius: 6
                    color: secondaryHover.hovered ? LazerTheme.hoverFill : "transparent"
                    border.color: LazerTheme.popupBorder
                    border.width: 1

                    Behavior on color { ColorAnimation { duration: MotionTokens.fast } }

                    Text {
                        anchors.centerIn: parent
                        text: "Menu"
                        color: LazerTheme.textPrimary
                        font.pixelSize: 11
                        font.bold: true
                    }

                    HoverHandler { id: secondaryHover }
                    TapHandler {
                        gesturePolicy: TapHandler.ReleaseWithinBounds
                        onTapped: root.handleTraySecondary()
                    }
                }
            }
        }

        // Fallback for unknown kinds keeps a visible placeholder.
        Rectangle {
            id: fallbackContent
            objectName: "fallbackContent"
            width: parent.width
            height: 32
            radius: 6
            color: LazerTheme.settingsControlSurface
            visible: root.actionKind !== "volume" && root.actionKind !== "brightness" && root.actionKind !== "media" && root.actionKind !== "notifications" && root.actionKind !== "tray" && root.actionKind !== ""

            Text {
                anchors.centerIn: parent
                text: root.actionKind === "" ? "No action" : root.actionKind
                color: LazerTheme.textMuted
                font.pixelSize: 11
            }
        }
    }
}
