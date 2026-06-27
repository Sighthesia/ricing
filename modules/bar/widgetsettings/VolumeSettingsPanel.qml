import QtQuick
import QtQuick.Controls
import Quickshell.Services.Pipewire
import "../../settings/controls"
import "../../bar/MenuVisuals.js" as MenuVisuals
import "../../../services" as Services

// Render instance-scoped settings controls for the volume widget.
Column {
    id: root

    spacing: MenuVisuals.smallGap

    readonly property string instanceKey: Services.BarLayoutService.activeWidgetSettingsKey

    // --- Output devices ---
    Services.FluidText {
        text: "Output Device"
        color: Services.Color.mPrimary
        basePixelSize: 12
        font.bold: true
        topPadding: 4
    }

    // Scrollable list of available output sinks.
    Flickable {
        width: parent.width
        height: Math.min(160, outList.implicitHeight)
        contentHeight: outList.implicitHeight
        clip: true
        interactive: contentHeight > height

        Column {
            id: outList
            width: parent.width
            spacing: 4

            Repeater {
                model: Services.VolumeService.sinks

                delegate: Rectangle {
                    required property var modelData
                    id: outDev

                    width: parent.width
                    height: 36
                    radius: 8
                    color: outDev._isDefault ? Qt.alpha(Services.Color.mPrimary, 0.15)
                        : (devArea.containsMouse ? Qt.alpha(Services.Color.mOnSurface, 0.08) : Qt.alpha(Services.Color.mSurfaceVariant, 0.4))
                    border.color: outDev._isDefault ? Services.Color.mPrimary : Qt.alpha(Services.Color.mOutline, 0.5)
                    border.width: 1

                    readonly property bool _isDefault: Pipewire.defaultAudioSink === modelData

                    MouseArea {
                        id: devArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Services.VolumeService.setAudioSink(modelData)
                    }

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: 8
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        spacing: 6

                        // Active check icon
                        Services.FluidText {
                            text: outDev._isDefault ? "\uf00c" : "\uf028" // check / volume icon
                            explicitFontFamily: "Symbols Nerd Font"
                            color: outDev._isDefault ? Services.Color.mPrimary : Services.Color.mOnSurfaceVariant
                            basePixelSize: 11
                            anchors.verticalCenter: parent.verticalCenter
                            width: 14
                            horizontalAlignment: Text.AlignHCenter
                        }

                        Services.FluidText {
                            text: Services.VolumeService.deviceLabel(modelData)
                            color: outDev._isDefault ? Services.Color.mPrimary : Services.Color.mOnSurface
                            basePixelSize: 11
                            font.bold: outDev._isDefault
                            elide: Text.ElideRight
                            width: parent.width - 14 - parent.spacing
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
            }
        }
    }

    // --- Input devices ---
    Services.FluidText {
        text: "Input Device"
        color: Services.Color.mPrimary
        basePixelSize: 12
        font.bold: true
        topPadding: 4
    }

    // Scrollable list of available input sources.
    Flickable {
        width: parent.width
        height: Math.min(160, inList.implicitHeight)
        contentHeight: inList.implicitHeight
        clip: true
        interactive: contentHeight > height

        Column {
            id: inList
            width: parent.width
            spacing: 4

            Repeater {
                model: Services.VolumeService.sources

                delegate: Rectangle {
                    required property var modelData
                    id: inDev

                    width: parent.width
                    height: 36
                    radius: 8
                    color: inDev._isDefault ? Qt.alpha(Services.Color.mPrimary, 0.15)
                        : (inArea.containsMouse ? Qt.alpha(Services.Color.mOnSurface, 0.08) : Qt.alpha(Services.Color.mSurfaceVariant, 0.4))
                    border.color: inDev._isDefault ? Services.Color.mPrimary : Qt.alpha(Services.Color.mOutline, 0.5)
                    border.width: 1

                    readonly property bool _isDefault: Pipewire.defaultAudioSource === modelData

                    MouseArea {
                        id: inArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Services.VolumeService.setAudioSource(modelData)
                    }

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: 8
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        spacing: 6

                        Services.FluidText {
                            text: inDev._isDefault ? "\uf00c" : "\uf130" // check / mic icon
                            explicitFontFamily: "Symbols Nerd Font"
                            color: inDev._isDefault ? Services.Color.mPrimary : Services.Color.mOnSurfaceVariant
                            basePixelSize: 11
                            anchors.verticalCenter: parent.verticalCenter
                            width: 14
                            horizontalAlignment: Text.AlignHCenter
                        }

                        Services.FluidText {
                            text: Services.VolumeService.deviceLabel(modelData)
                            color: inDev._isDefault ? Services.Color.mPrimary : Services.Color.mOnSurface
                            basePixelSize: 11
                            font.bold: inDev._isDefault
                            elide: Text.ElideRight
                            width: parent.width - 14 - parent.spacing
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
            }
        }
    }
}
