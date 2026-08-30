import QtQuick
import "../lazerbar"

// Content body for volume, brightness, media, notifications and tray.
// Bound via BarPopupHost contentData; intent actionKind/payload drive visible kind.
Item {
    id: root

    property string actionKind: ""
    property var payload: null

    implicitWidth: 260
    implicitHeight: root.actionKind === "context" ? 0 : contentColumn.implicitHeight + 16
    width: implicitWidth
    height: implicitHeight
    visible: root.actionKind !== "context"
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
    readonly property int mediaPositionMs: {
        if (payload && payload.mediaControlService && payload.mediaControlService.positionMs !== undefined)
            return Math.max(0, Number(payload.mediaControlService.positionMs))
        if (payload && payload.mediaService && payload.mediaService.positionMs !== undefined)
            return Math.max(0, Number(payload.mediaService.positionMs))
        if (payload && payload.positionMs !== undefined && payload.positionMs !== null)
            return Math.max(0, Number(payload.positionMs))
        return 0
    }
    readonly property int mediaLengthMs: {
        if (payload && payload.mediaControlService && payload.mediaControlService.lengthMs !== undefined)
            return Math.max(0, Number(payload.mediaControlService.lengthMs))
        if (payload && payload.mediaService && payload.mediaService.lengthMs !== undefined)
            return Math.max(0, Number(payload.mediaService.lengthMs))
        if (payload && payload.lengthMs !== undefined && payload.lengthMs !== null)
            return Math.max(0, Number(payload.lengthMs))
        return 0
    }

    function formatMediaTime(milliseconds) {
        var seconds = Math.floor(Math.max(0, Number(milliseconds)) / 1000)
        var minutes = Math.floor(seconds / 60)
        seconds %= 60
        return minutes + ":" + (seconds < 10 ? "0" : "") + seconds
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
        if (payload && typeof payload.onMarkAllRead === "function") {
            payload.onMarkAllRead()
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
            height: volumeSlider.implicitHeight + 16
            visible: root.actionKind === "volume"

            // Settings-row card under the control; hover lifts the whole card.
            Rectangle {
                objectName: "volumeCard"
                anchors.fill: parent
                radius: 6
                color: volumeCardHover.hovered ? LazerTheme.settingsCardHover : LazerTheme.settingsCard
                Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
            }
            HoverHandler { id: volumeCardHover; blocking: false }

            BarPopupSlider {
                id: volumeSlider
                objectName: "volumeSlider"
                anchors.fill: parent
                anchors.margins: 8
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
            height: brightnessSlider.implicitHeight + 16
            visible: root.actionKind === "brightness"

            // Mirror the volume card recipe so both slider rows share one skin.
            Rectangle {
                objectName: "brightnessCard"
                anchors.fill: parent
                radius: 6
                color: brightnessCardHover.hovered ? LazerTheme.settingsCardHover : LazerTheme.settingsCard
                Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
            }
            HoverHandler { id: brightnessCardHover; blocking: false }

            BarPopupSlider {
                id: brightnessSlider
                objectName: "brightnessSlider"
                anchors.fill: parent
                anchors.margins: 8
                value: root.brightnessValue
                muted: false
                label: "Brightness"
                showMute: false
                onValueCommitted: function(v) { root.handleBrightnessValue(v) }
            }
        }

        // Media content: progress plus previous / playPause / next.
        Item {
            id: mediaContent
            objectName: "mediaContent"
            width: parent.width
            height: 72
            visible: root.actionKind === "media"

            // Settings-row card hosts the transport controls.
            Rectangle {
                objectName: "mediaCard"
                anchors.fill: parent
                radius: 6
                color: mediaCardHover.hovered ? LazerTheme.settingsCardHover : LazerTheme.settingsCard
                Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
            }
            HoverHandler { id: mediaCardHover; blocking: false }

            // Existing media timeline data remains visible alongside controls.
            Text {
                objectName: "mediaProgressText"
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.formatMediaTime(root.mediaPositionMs) + " / "
                    + root.formatMediaTime(root.mediaLengthMs)
                color: LazerTheme.textMuted
                font.pixelSize: 10
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                spacing: 8

                // Previous button.
                Rectangle {
                    id: mediaPrevButton
                    objectName: "mediaPrevButton"
                    width: 48
                    height: 32
                    radius: 6
                    color: prevHover.hovered ? LazerTheme.hoverFill : "transparent"

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
                        objectName: "mediaPrevTap"
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
                    color: playHover.hovered ? LazerTheme.hoverFill : "transparent"

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
                        objectName: "mediaPlayPauseTap"
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
                        objectName: "mediaNextTap"
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
            height: 52
            visible: root.actionKind === "notifications"

            // Settings-row card hosts both notification actions.
            Rectangle {
                objectName: "notificationsCard"
                anchors.fill: parent
                radius: 6
                color: notificationsCardHover.hovered ? LazerTheme.settingsCardHover : LazerTheme.settingsCard
                Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
            }
            HoverHandler { id: notificationsCardHover; blocking: false }

            Row {
                anchors.centerIn: parent
                spacing: 8

                Rectangle {
                    id: dndButton
                    objectName: "notificationDndButton"
                    width: 72
                    height: 32
                    radius: 6
                    color: root.notificationDnd ? LazerTheme.settingsSelected : (dndHover.hovered ? LazerTheme.hoverFill : "transparent")
                    border.width: root.notificationDnd ? 1.5 : 0
                    border.color: root.notificationDnd ? LazerTheme.settingsAccent : "transparent"

                    Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
                    Behavior on border.color { ColorAnimation { duration: MotionTokens.fast } }

                    Text {
                        anchors.centerIn: parent
                        text: root.notificationDnd ? "DND On" : "DND Off"
                        color: LazerTheme.textPrimary
                        font.pixelSize: 11
                        font.bold: true
                    }

                    HoverHandler { id: dndHover }
                    TapHandler {
                        objectName: "notificationDndTap"
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
                    color: clearHover.hovered ? LazerTheme.hoverFill : "transparent"

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
                        objectName: "notificationClearTap"
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
            height: 52
            visible: root.actionKind === "tray"

            // Settings-row card hosts both tray actions.
            Rectangle {
                objectName: "trayCard"
                anchors.fill: parent
                radius: 6
                color: trayCardHover.hovered ? LazerTheme.settingsCardHover : LazerTheme.settingsCard
                Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
            }
            HoverHandler { id: trayCardHover; blocking: false }

            Row {
                anchors.centerIn: parent
                spacing: 8

                Rectangle {
                    id: trayActivateButton
                    objectName: "trayActivateButton"
                    width: 72
                    height: 32
                    radius: 6
                    color: activateHover.hovered ? LazerTheme.hoverFill : "transparent"

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
                        objectName: "trayActivateTap"
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
                        objectName: "traySecondaryTap"
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
            color: LazerTheme.settingsCard
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
