import QtQuick
import QtQuick.Controls
import "../../settings/controls"
import "../../bar/MenuVisuals.js" as MenuVisuals
import "../../../services" as Services

// Render instance-scoped settings controls for the wi-fi widget.
Column {
    id: root

    spacing: MenuVisuals.smallGap

    readonly property string instanceKey: Services.BarLayoutService.activeWidgetSettingsKey
    property string pendingSsid: ""
    property string pendingPassword: ""

    // Wi-Fi power toggle
    SettingToggle {
        width: parent.width
        settingLabel: "Wi-Fi"
        description: "Turn the Wi-Fi adapter on or off."
        checked: Services.NetworkService.wifiEnabled
        onToggled: value => Services.NetworkService.setWifiEnabled(value)
    }

    // Scan control
    Row {
        width: parent.width
        spacing: MenuVisuals.smallGap

        Rectangle {
            width: parent.width
            height: 32
            radius: 8
            color: scanArea.containsMouse ? Qt.alpha(Services.Color.mPrimary, 0.18) : Qt.alpha(Services.Color.mSurfaceVariant, 0.5)
            border.color: Services.Color.mOutline
            border.width: 1

            Services.FluidText {
                anchors.centerIn: parent
                text: Services.NetworkService.scanningActive ? "Scanning…" : "Rescan"
                color: Services.Color.mOnSurface
                basePixelSize: 11
            }

            MouseArea {
                id: scanArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Services.NetworkService.scan()
            }
        }
    }

    // Status line
    Services.FluidText {
        width: parent.width
        text: {
            if (!Services.NetworkService.wifiEnabled) return "Wi-Fi is off"
            if (Services.NetworkService.connecting) return "Connecting to " + Services.NetworkService.connectingTo + "…"
            if (Services.NetworkService.wifiConnected) {
                var cn = Object.values(Services.NetworkService.networks).find(n => n.connected)
                return cn ? ("Connected: " + cn.ssid) : "Connected"
            }
            if (Services.NetworkService.scanningActive) return "Scanning…"
            return Object.keys(Services.NetworkService.networks).length + " networks found"
        }
        color: Services.Color.mOnSurfaceVariant
        basePixelSize: 10
        topPadding: 2
        elide: Text.ElideRight
    }

    // Last error line (transient)
    Services.FluidText {
        width: parent.width
        text: Services.NetworkService.lastError
        color: Services.Color.mError
        basePixelSize: 10
        visible: text !== ""
        topPadding: 2
        elide: Text.ElideRight
    }

    // Password input row (shown when a network needs a password).
    Item {
        width: parent.width
        height: root.pendingSsid !== "" ? pwdColumn.implicitHeight : 0
        visible: root.pendingSsid !== ""

        Column {
            id: pwdColumn
            width: parent.width
            spacing: 4

            Services.FluidText {
                width: parent.width
                text: "Password for " + root.pendingSsid
                color: Services.Color.mOnSurface
                basePixelSize: 11
                font.bold: true
                elide: Text.ElideRight
            }

            TextField {
                id: pwdField
                width: parent.width
                placeholderText: "Enter password"
                echoMode: TextInput.Password
                color: Services.Color.mOnSurface
                font.family: Services.SettingsService.appearance.fontDefault || Qt.application.font.family
                font.pixelSize: 12
                background: Rectangle {
                    radius: 8
                    color: Services.Color.mSurfaceVariant
                    border.color: Services.Color.mOutline
                    border.width: 1
                }
                onTextChanged: root.pendingPassword = text
                onAccepted: root._submitPassword()
                Component.onCompleted: forceActiveFocus()
            }

            Row {
                width: parent.width
                spacing: MenuVisuals.smallGap

                Rectangle {
                    width: (parent.width - parent.spacing) / 2
                    height: 28
                    radius: 8
                    color: cancelPwdArea.containsMouse ? Qt.alpha(Services.Color.mOnSurface, 0.18) : Qt.alpha(Services.Color.mSurfaceVariant, 0.5)
                    border.color: Services.Color.mOutline
                    border.width: 1

                    Services.FluidText {
                        anchors.centerIn: parent
                        text: "Cancel"
                        color: Services.Color.mOnSurface
                        basePixelSize: 11
                    }

                    MouseArea {
                        id: cancelPwdArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root._cancelPassword()
                    }
                }

                Rectangle {
                    width: (parent.width - parent.spacing) / 2
                    height: 28
                    radius: 8
                    color: connectPwdArea.containsMouse ? Qt.alpha(Services.Color.mPrimary, 0.25) : Qt.alpha(Services.Color.mPrimary, 0.15)
                    border.color: Services.Color.mPrimary
                    border.width: 1

                    Services.FluidText {
                        anchors.centerIn: parent
                        text: "Connect"
                        color: Services.Color.mPrimary
                        basePixelSize: 11
                        font.bold: true
                    }

                    MouseArea {
                        id: connectPwdArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root._submitPassword()
                    }
                }
            }
        }
    }

    // Network list
    Services.FluidText {
        text: "Networks"
        color: Services.Color.mPrimary
        basePixelSize: 12
        font.bold: true
        topPadding: 4
        visible: root.pendingSsid === ""
    }

    // Scrollable list of nearby networks.
    Flickable {
        width: parent.width
        height: Math.min(240, netList.implicitHeight)
        contentHeight: netList.implicitHeight
        clip: true
        interactive: contentHeight > height
        visible: root.pendingSsid === ""

        Column {
            id: netList
            width: parent.width
            spacing: 4

            Repeater {
                // Sort by connected-first, then signal descending.
                model: {
                    var arr = Object.values(Services.NetworkService.networks).slice()
                    arr.sort(function (a, b) {
                        if (a.connected !== b.connected) return a.connected ? -1 : 1
                        return b.signal - a.signal
                    })
                    return arr
                }

                delegate: Rectangle {
                    required property var modelData

                    width: parent.width
                    height: 40
                    radius: 8
                    color: modelData.connected
                        ? Qt.alpha(Services.Color.mPrimary, 0.12)
                        : (netArea.containsMouse ? Qt.alpha(Services.Color.mOnSurface, 0.08) : Qt.alpha(Services.Color.mSurfaceVariant, 0.4))
                    border.color: modelData.connected ? Services.Color.mPrimary : Qt.alpha(Services.Color.mOutline, 0.5)
                    border.width: modelData.connected ? 1 : 1

                    MouseArea {
                        id: netArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (modelData.connected) {
                                Services.NetworkService.disconnect(modelData.ssid)
                            } else if (modelData.existing) {
                                Services.NetworkService.connect(modelData.ssid)
                            } else if (Services.NetworkService.isSecured(modelData.security)) {
                                // Need a password — open the inline input.
                                root.pendingSsid = modelData.ssid
                                root.pendingPassword = ""
                            } else {
                                // Open network — connect directly.
                                Services.NetworkService.connect(modelData.ssid, "", false, "open")
                            }
                        }
                    }

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: 8
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        spacing: 6

                        // Signal icon
                        Services.FluidText {
                            text: Services.NetworkService.getSignalIcon(modelData.signal, modelData.connected)
                            explicitFontFamily: "Symbols Nerd Font"
                            color: modelData.connected ? Services.Color.mPrimary : Services.Color.mOnSurface
                            basePixelSize: 12
                            anchors.verticalCenter: parent.verticalCenter
                            width: 16
                            horizontalAlignment: Text.AlignHCenter
                        }

                        // SSID + security
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - secLbl.width - forgetBtn.width - parent.spacing * 2
                            spacing: 1

                            Services.FluidText {
                                text: modelData.ssid
                                color: Services.Color.mOnSurface
                                basePixelSize: 11
                                font.bold: modelData.connected
                                elide: Text.ElideRight
                                width: parent.width
                            }

                            Services.FluidText {
                                id: signalLbl
                                text: Services.NetworkService.getSignalLabel(modelData.signal) + (modelData.existing ? " · saved" : "")
                                color: Services.Color.mOnSurfaceVariant
                                basePixelSize: 9
                            }
                        }

                        // Security icon
                        Services.FluidText {
                            id: secLbl
                            text: Services.NetworkService.isSecured(modelData.security) ? "\uf023" : "" // lock
                            explicitFontFamily: "Symbols Nerd Font"
                            color: Services.Color.mOnSurfaceVariant
                            basePixelSize: 10
                            anchors.verticalCenter: parent.verticalCenter
                            width: 14
                            horizontalAlignment: Text.AlignHCenter
                            visible: text !== ""
                        }

                        // Forget button (saved networks only)
                        Rectangle {
                            id: forgetBtn
                            anchors.verticalCenter: parent.verticalCenter
                            width: 16
                            height: 16
                            radius: 8
                            color: forgetArea.containsMouse ? Qt.alpha(Services.Color.mError, 0.25) : "transparent"
                            border.color: Services.Color.mError
                            border.width: 1
                            visible: modelData.existing && !modelData.connected

                            Services.FluidText {
                                anchors.centerIn: parent
                                text: "\uf00d"
                                explicitFontFamily: "Symbols Nerd Font"
                                color: Services.Color.mError
                                basePixelSize: 8
                            }

                            MouseArea {
                                id: forgetArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Services.NetworkService.forget(modelData.ssid)
                            }
                        }
                    }
                }
            }
        }
    }

    function _submitPassword() {
        if (root.pendingSsid === "") return
        var ssid = root.pendingSsid
        var pwd = root.pendingPassword
        var net = Services.NetworkService.networks[ssid]
        var sec = net ? net.security : "wpa-psk"
        root.pendingSsid = ""
        root.pendingPassword = ""
        Services.NetworkService.connect(ssid, pwd, false, sec)
    }

    function _cancelPassword() {
        root.pendingSsid = ""
        root.pendingPassword = ""
    }
}
