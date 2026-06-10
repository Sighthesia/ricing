import Quickshell
import Quickshell.Wayland
import QtQuick
import "../common" as Common
import "../../services" as Services

// Transient notification popups anchored to top-right, auto-dismiss after 5s.
Variants {
    id: root

    model: Quickshell.screens

    // Per-screen notification overlay
    PanelWindow {
        id: notifWindow

        required property var modelData

        screen: modelData
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        anchors {
            top: true
            right: true
        }

        implicitWidth: 360
        implicitHeight: notifList.contentHeight + 16
        visible: notifSurface.opacity > 0 || Services.NotificationService.popupList.count > 0

        BackgroundEffect.blurRegion: Services.SettingsService.appearance.enableBlur ? notificationBlurRegion : null

        // Track blur to each notification card to avoid stack-gap overflow.
        property Variants notificationBlurRegions: Variants {
            model: Services.SettingsService.appearance.enableBlur && notifList.contentItem ? notifList.contentItem.children : []

            Region {
                required property Item modelData

                item: modelData.blurSourceItem ? modelData.blurSourceItem : null
                radius: modelData.blurRadius !== undefined ? modelData.blurRadius : 0
            }
        }

        Region {
            id: notificationBlurRegion

            regions: notificationBlurRegions.instances
        }

        // Notification surface content.
        Common.PopupSurface {
            id: notifSurface

            anchors.fill: parent
            transformOrigin: Item.TopRight
            shown: Services.NotificationService.popupList.count > 0

            // Notification card stack.
            ListView {
                id: notifList

                anchors.top: parent.top
                anchors.right: parent.right
                anchors.topMargin: 8
                anchors.rightMargin: 8
                width: 344
                height: contentHeight
                spacing: 8
                clip: false
                interactive: false
                model: Services.NotificationService.popupList

                add: Transition {
                    ParallelAnimation {
                        NumberAnimation {
                            properties: "opacity"
                            from: 0
                            to: 1
                            duration: Services.Motion.popup.opacityDuration
                            easing.type: Services.Motion.popup.opacityEasing
                        }

                        NumberAnimation {
                            properties: "scale"
                            from: 0.96
                            to: 1
                            duration: Services.Motion.popup.scaleDuration
                            easing.type: Services.Motion.popup.scaleEasing
                            easing.overshoot: Services.Motion.popup.scaleOvershoot
                        }
                    }
                }

                remove: Transition {
                    SequentialAnimation {
                        PropertyAction { property: "ListView.delayRemove"; value: true }

                        ParallelAnimation {
                            NumberAnimation {
                                properties: "opacity"
                                to: 0
                                duration: Services.Motion.popup.opacityDuration
                                easing.type: Services.Motion.popup.opacityEasing
                            }

                            NumberAnimation {
                                properties: "scale"
                                to: 0.96
                                duration: Services.Motion.popup.scaleDuration
                                easing.type: Services.Motion.popup.scaleEasing
                                easing.overshoot: Services.Motion.popup.scaleOvershoot
                            }

                            NumberAnimation {
                                properties: "height"
                                to: 0
                                duration: Services.Motion.number.settleDuration
                                easing.type: Services.Motion.number.settleEasing
                            }
                        }

                        PropertyAction { property: "ListView.delayRemove"; value: false }
                    }
                }

                displaced: Transition {
                    NumberAnimation {
                        properties: "y"
                        duration: Services.Motion.number.contentDuration
                        easing.type: Services.Motion.number.contentEasing
                    }
                }

                // Single notification card.
                delegate: Common.GlassCapsule {
                    id: card

                    width: ListView.view ? ListView.view.width : 344
                    height: 64
                    radius: height / 2
                    surfaceColor: Qt.alpha(Services.Color.mSurface, Services.SettingsService.panelSurfaceOpacity)
                    outlineColor: Services.Color.mOutline
                    scale: 1

                    // Auto-dismiss timer.
                    Timer {
                        id: dismissTimer
                        interval: 5000
                        running: true
                        onTriggered: Services.NotificationService.removeNotification(model.notifId)
                    }

                    // Click to dismiss.
                    MouseArea {
                        anchors.fill: parent
                        onClicked: Services.NotificationService.removeNotification(model.notifId)
                    }

                    Row {
                        anchors.fill: parent
                        anchors.margins: 8
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        spacing: 12

                        // App icon.
                        Image {
                            width: 40
                            height: 40
                            anchors.verticalCenter: parent.verticalCenter
                            source: model.icon || ""
                            sourceSize: Qt.size(40, 40)
                            visible: source.toString() !== ""
                        }

                        // Text content.
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 56
                            spacing: 2

                            // Summary.
                            Services.FluidText {
                                width: parent.width
                                text: model.summary || ""
                                color: Services.Color.mOnSurface
                                basePixelSize: 13
                                font.bold: true
                                elide: Text.ElideRight
                                maximumLineCount: 1
                            }

                            // Body.
                            Services.FluidText {
                                width: parent.width
                                text: model.body || ""
                                color: Services.Color.mOnSurfaceVariant
                                basePixelSize: 12
                                elide: Text.ElideRight
                                maximumLineCount: 1
                            }
                        }
                    }

                    // Countdown progress bar.
                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.bottomMargin: 2
                        anchors.leftMargin: 16
                        height: 2
                        radius: 1
                        color: Services.Color.mPrimary
                        width: 312

                        NumberAnimation on width {
                            from: 312
                            to: 0
                            duration: 5000
                            running: true
                        }
                    }

                    transformOrigin: Item.Center
                }
            }
        }
    }
}
