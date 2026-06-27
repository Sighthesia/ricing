import QtQuick
import QtQuick.Controls
import "../../settings/controls"
import "../../bar/MenuVisuals.js" as MenuVisuals
import "../../../services" as Services

// Render instance-scoped settings controls for the bluetooth widget.
Column {
    id: root

    spacing: MenuVisuals.smallGap

    readonly property string instanceKey: Services.BarLayoutService.activeWidgetSettingsKey

    // Adapter power toggle
    SettingToggle {
        width: parent.width
        settingLabel: "Bluetooth"
        description: "Turn the Bluetooth adapter on or off."
        checked: Services.BluetoothService.enabled
        onToggled: value => Services.BluetoothService.setBluetoothEnabled(value)
    }

    // Scan + discoverable controls row
    Row {
        width: parent.width
        spacing: MenuVisuals.smallGap

        // Scan toggle
        Rectangle {
            width: (parent.width - parent.spacing) / 2
            height: 32
            radius: 8
            color: scanArea.containsMouse ? Qt.alpha(Services.Color.mPrimary, 0.18) : Qt.alpha(Services.Color.mSurfaceVariant, 0.5)
            border.color: Services.Color.mOutline
            border.width: 1

            Services.FluidText {
                anchors.centerIn: parent
                text: Services.BluetoothService.scanningActive ? "Stop scan" : "Scan"
                color: Services.Color.mOnSurface
                basePixelSize: 11
            }

            MouseArea {
                id: scanArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Services.BluetoothService.setScanActive(!Services.BluetoothService.scanningActive)
            }
        }

        // Discoverable toggle
        Rectangle {
            width: (parent.width - parent.spacing) / 2
            height: 32
            radius: 8
            color: discArea.containsMouse ? Qt.alpha(Services.Color.mPrimary, 0.18) : Qt.alpha(Services.Color.mSurfaceVariant, 0.5)
            border.color: Services.Color.mOutline
            border.width: 1

            Services.FluidText {
                anchors.centerIn: parent
                text: Services.BluetoothService.discoverable ? "Hidden" : "Discoverable"
                color: Services.Color.mOnSurface
                basePixelSize: 11
            }

            MouseArea {
                id: discArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Services.BluetoothService.setDiscoverable(!Services.BluetoothService.discoverable)
            }
        }
    }

    // Device list
    Services.FluidText {
        text: "Devices"
        color: Services.Color.mPrimary
        basePixelSize: 12
        font.bold: true
        topPadding: 4
    }

    // Scrollable list of known bluetooth devices with pair/connect/forget actions.
    Flickable {
        width: parent.width
        height: Math.min(220, deviceList.implicitHeight)
        contentHeight: deviceList.implicitHeight
        clip: true
        interactive: contentHeight > height

        Column {
            id: deviceList
            width: parent.width
            spacing: 4

            Repeater {
                // Sort a copy so UI stays stable while actions mutate state.
                model: Services.BluetoothService.devices
                    ? Services.BluetoothService.sortDevices(Services.BluetoothService.devices.values.slice())
                    : []

                delegate: Rectangle {
                    required property var modelData

                    width: parent.width
                    height: 44
                    radius: 8
                    color: Qt.alpha(Services.Color.mSurfaceVariant, 0.4)
                    border.color: Qt.alpha(Services.Color.mOutline, 0.5)
                    border.width: 1

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: 8
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        spacing: 6

                        // Device icon
                        Services.FluidText {
                            text: Services.BluetoothService.getDeviceIcon(modelData)
                            explicitFontFamily: "Symbols Nerd Font"
                            color: modelData.connected ? Services.Color.mPrimary : Services.Color.mOnSurface
                            basePixelSize: 12
                            anchors.verticalCenter: parent.verticalCenter
                            width: 16
                            horizontalAlignment: Text.AlignHCenter
                        }

                        // Name + status
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - connectBtn.width - forgetBtn.width - parent.spacing * 2
                            spacing: 1

                            Services.FluidText {
                                text: modelData.name || modelData.deviceName || "Unknown device"
                                color: Services.Color.mOnSurface
                                basePixelSize: 11
                                font.bold: modelData.connected
                                elide: Text.ElideRight
                                width: parent.width
                            }

                            Services.FluidText {
                                text: {
                                    if (modelData.connected) return "Connected"
                                    if (modelData.pairing) return "Pairing…"
                                    if (modelData.paired) return "Paired"
                                    return "Not paired"
                                }
                                color: Services.Color.mOnSurfaceVariant
                                basePixelSize: 9
                            }
                        }

                        // Pair / connect / disconnect / busy indicator
                        Rectangle {
                            id: connectBtn
                            anchors.verticalCenter: parent.verticalCenter
                            width: 18
                            height: 18
                            radius: 9
                            color: Services.BluetoothService.isDeviceBusy(modelData)
                                ? "transparent"
                                : (connectArea.containsMouse ? Qt.alpha(Services.Color.mPrimary, 0.25) : "transparent")
                            border.color: Services.BluetoothService.isDeviceBusy(modelData) ? Services.Color.mOnSurfaceVariant : Services.Color.mPrimary
                            border.width: 1

                            Services.FluidText {
                                anchors.centerIn: parent
                                text: {
                                    if (Services.BluetoothService.isDeviceBusy(modelData)) return "\uf110"
                                    if (Services.BluetoothService.canConnect(modelData)) return "\uf067"
                                    if (Services.BluetoothService.canDisconnect(modelData)) return "\uf068"
                                    if (Services.BluetoothService.canPair(modelData)) return "\uf128"
                                    return ""
                                }
                                explicitFontFamily: "Symbols Nerd Font"
                                color: Services.BluetoothService.isDeviceBusy(modelData) ? Services.Color.mOnSurfaceVariant : Services.Color.mPrimary
                                basePixelSize: 9
                                RotationAnimator on rotation {
                                    from: 0
                                    to: 360
                                    duration: 800
                                    loops: Animation.Infinite
                                    running: Services.BluetoothService.isDeviceBusy(modelData)
                                }
                            }

                            MouseArea {
                                id: connectArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (Services.BluetoothService.canConnect(modelData))
                                        Services.BluetoothService.connectDeviceWithTrust(modelData)
                                    else if (Services.BluetoothService.canDisconnect(modelData))
                                        Services.BluetoothService.disconnectDevice(modelData)
                                    else if (Services.BluetoothService.canPair(modelData))
                                        Services.BluetoothService.pairDevice(modelData)
                                }
                            }
                        }

                        // Forget button (only for paired/connected)
                        Rectangle {
                            id: forgetBtn
                            anchors.verticalCenter: parent.verticalCenter
                            width: 18
                            height: 18
                            radius: 9
                            color: forgetArea.containsMouse ? Qt.alpha(Services.Color.mError, 0.25) : "transparent"
                            border.color: Services.Color.mError
                            border.width: 1
                            visible: (modelData.paired || modelData.connected) && !Services.BluetoothService.isDeviceBusy(modelData)

                            Services.FluidText {
                                anchors.centerIn: parent
                                text: "\uf00d" // times
                                explicitFontFamily: "Symbols Nerd Font"
                                color: Services.Color.mError
                                basePixelSize: 9
                            }

                            MouseArea {
                                id: forgetArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Services.BluetoothService.forgetDevice(modelData)
                            }
                        }
                    }
                }
            }
        }
    }
}
