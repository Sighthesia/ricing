import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import qs.config

Item {
    id: root

    required property var event
    required property string iconSource
    property bool compact: false
    readonly property int _contentInsetV: Theme.barWidget.contentPaddingV
    readonly property int _artworkSize:
        Math.max(Theme.barWidget.primaryIconSize, Theme.barWidget.primaryIconSize + root._contentInsetV * 2)

    implicitWidth: root.compact ? compactContent.implicitWidth : content.implicitWidth
    implicitHeight: root.compact
        ? (Theme.fontSizeBody + root._contentInsetV * 2)
        : (Theme.barWidget.pillHeight - root._contentInsetV * 2)

    RowLayout {
        id: compactContent
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: root.compact
            ? Math.max(1, Math.round(Theme.barWidget.contentPaddingV / 2))
            : 0
        visible: root.compact
        spacing: Theme.barWidget.iconLabelSpacing

        Rectangle {
            radius: width / 2
            color: Qt.rgba(1, 1, 1, 0.05)
            border.color: Colors.border
            border.width: 1
            implicitWidth: Theme.barWidget.primaryIconSize + root._contentInsetV * 2
            implicitHeight: implicitWidth
            Layout.alignment: Qt.AlignVCenter

            Item {
                id: compactMaskContainer
                anchors.fill: parent
                layer.enabled: true
                layer.smooth: true
                visible: false

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: "white"
                }
            }

            Image {
                id: compactArtSource
                anchors.fill: parent
                visible: false
                source: root.iconSource
                fillMode: Image.PreserveAspectCrop
                smooth: true
            }

            OpacityMask {
                anchors.fill: parent
                source: compactArtSource
                maskSource: compactMaskContainer
            }
        }

        Text {
            text: root.event.title || "Media"
            color: Colors.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeBody
            font.bold: true
            elide: Text.ElideRight
            Layout.maximumWidth: Math.round(220 * Theme.uiScale)
            Layout.alignment: Qt.AlignVCenter
        }

        Rectangle {
            radius: Theme.cornerRadius
            color: Colors.highlight
            opacity: Colors.highlightAlpha + 0.1
            implicitHeight: compactStateText.implicitHeight + Theme.barWidget.badgePaddingV * 2
            implicitWidth: compactStateText.implicitWidth + Theme.barWidget.badgePaddingH * 2
            Layout.alignment: Qt.AlignVCenter

            Text {
                id: compactStateText
                anchors.centerIn: parent
                text: root.event.subtitle === "paused" ? "Pause" : "Playing"
                color: Colors.text
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeSmall
                font.bold: true
            }
        }
    }

    RowLayout {
        id: content
        anchors.verticalCenter: parent.verticalCenter
        visible: !root.compact
        spacing: Theme.barWidget.iconLabelSpacing

        Rectangle {
            radius: width / 2
            color: Qt.rgba(1, 1, 1, 0.05)
            border.color: Colors.border
            border.width: 1
            implicitWidth: root._artworkSize
            implicitHeight: root._artworkSize
            Layout.alignment: Qt.AlignVCenter

            Item {
                id: fullMaskContainer
                anchors.fill: parent
                layer.enabled: true
                layer.smooth: true
                visible: false

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: "white"
                }
            }

            Image {
                id: fullArtSource
                anchors.fill: parent
                visible: false
                source: root.iconSource
                fillMode: Image.PreserveAspectCrop
                smooth: true
            }

            OpacityMask {
                anchors.fill: parent
                source: fullArtSource
                maskSource: fullMaskContainer
            }
        }

        ColumnLayout {
            spacing: 0
            Layout.alignment: Qt.AlignVCenter

            Text {
                text: root.event.title || "Media"
                color: Colors.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeBody
                font.bold: true
                elide: Text.ElideRight
                Layout.maximumWidth: Math.round(200 * Theme.uiScale)
            }

            Text {
                visible: text !== ""
                text: root.event.subtitle || ""
                color: Colors.textMuted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                elide: Text.ElideRight
                Layout.maximumWidth: Math.round(200 * Theme.uiScale)
            }
        }

        Rectangle {
            radius: Theme.cornerRadius
            color: Colors.highlight
            opacity: Colors.highlightAlpha + 0.1
            implicitHeight: stateText.implicitHeight + Theme.barWidget.badgePaddingV * 2
            implicitWidth: stateText.implicitWidth + Theme.barWidget.badgePaddingH * 2
            Layout.alignment: Qt.AlignVCenter

            Text {
                id: stateText
                anchors.centerIn: parent
                text: root.event.subtitle === "paused" ? "Pause" : "Playing"
                color: Colors.text
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeSmall
                font.bold: true
            }
        }
    }
}