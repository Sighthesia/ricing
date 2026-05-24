import Quickshell
import Quickshell.Wayland
import QtQuick
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

        width: 360
        height: notifColumn.implicitHeight + 16

        // Hide window when no notifications
        visible: Services.NotificationService.popupList.count > 0

        BackgroundEffect.blurRegion: Services.SettingsService.appearance.enableBlur ? notificationBlurRegion : null

        // Track blur to each notification card to avoid stack-gap overflow.
        property Variants notificationBlurRegions: Variants {
            model: Services.SettingsService.appearance.enableBlur ? notifColumn.children : []

            Region {
                required property Item modelData

                item: modelData.visible && modelData.blurSourceItem ? modelData.blurSourceItem : null
                radius: 12
            }
        }

        Region {
            id: notificationBlurRegion

            regions: notificationBlurRegions.instances
        }

        // Notification card stack
        Column {
            id: notifColumn
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: 8
            anchors.rightMargin: 8
            width: 344
            spacing: 8

            Repeater {
                model: Services.NotificationService.popupList

                // Single notification card
                Rectangle {
                    id: card

                    readonly property Item blurSourceItem: cardBlurSource

                    width: 344
                    height: 64
                    radius: 12
                    color: Qt.alpha(Services.Color.mSurface, Services.SettingsService.panelSurfaceOpacity)
                    opacity: 1

                    // Full-size blur source — covers the entire visible fill geometry.
                    Item {
                        id: cardBlurSource

                        anchors.fill: parent
                    }

                    // Auto-dismiss timer
                    Timer {
                        id: dismissTimer
                        interval: 5000
                        running: true
                        onTriggered: Services.NotificationService.removeNotification(model.notifId)
                    }

                    // Click to dismiss
                    MouseArea {
                        anchors.fill: parent
                        onClicked: Services.NotificationService.removeNotification(model.notifId)
                    }

                    Row {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 10

                        // App icon
                        Image {
                            width: 40
                            height: 40
                            anchors.verticalCenter: parent.verticalCenter
                            source: model.icon || ""
                            sourceSize: Qt.size(40, 40)
                            visible: source.toString() !== ""
                        }

                        // Text content
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 60
                            spacing: 2

                            // Summary
                            Text {
                                width: parent.width
                                text: model.summary || ""
                                color: Services.Color.mOnSurface
                                font.pixelSize: 13
                                font.bold: true
                                elide: Text.ElideRight
                                maximumLineCount: 1
                            }

                            // Body
                            Text {
                                width: parent.width
                                text: model.body || ""
                                color: Services.Color.mOnSurfaceVariant
                                font.pixelSize: 12
                                elide: Text.ElideRight
                                maximumLineCount: 1
                            }
                        }
                    }

                    // Countdown progress bar
                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.bottomMargin: 2
                        anchors.leftMargin: 12
                        height: 2
                        radius: 1
                        color: Services.Color.mPrimary
                        width: 320

                        NumberAnimation on width {
                            from: 320
                            to: 0
                            duration: 5000
                            running: true
                        }
                    }

                    // Border overlay rendered above all content.
                    Rectangle {
                        anchors.fill: parent
                        radius: card.radius
                        color: "transparent"
                        border.color: Services.Color.mOutline
                        border.width: 1
                    }
                }
            }
        }
    }
}
