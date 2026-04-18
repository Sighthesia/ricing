import QtQuick
import QtQuick.Layouts
import qs.config
import "." as MediaParts

// Compact media identity row used by the media control widget.
Item {
    id: root

    property string title: ""
    property string artist: ""
    property string artUrl: ""
    property string fallbackIcon: "audio-x-generic-symbolic"
    property int artworkSize: Theme.barWidget.pillHeight - Theme.barWidget.contentPaddingV * 2
    property int textMaxWidth: Theme.barWidget.mediaCompactMaxTitleWidth
    property bool showArtwork: true
    property bool showText: true

    readonly property string _displayTitle: root.title !== "" ? root.title : "No Media"

    implicitWidth: _contentRow.implicitWidth
    implicitHeight: root.showText ? _contentRow.implicitHeight : root.artworkSize

    // Compact content row.
    RowLayout {
        id: _contentRow
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.barWidget.iconLabelSpacing

        // Compact artwork.
        MediaParts.MediaArtwork {
            visible: root.showArtwork
            source: root.artUrl
            fallbackIcon: root.fallbackIcon
            size: root.artworkSize
            Layout.alignment: Qt.AlignVCenter
        }

        // Compact text cluster.
        RowLayout {
            visible: root.showText
            spacing: Theme.barWidget.iconSpacing
            Layout.alignment: Qt.AlignVCenter

            // Artist label.
            Text {
                visible: root.artist !== ""
                text: root.artist
                color: Colors.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeBody
                elide: Text.ElideRight
                maximumLineCount: 1
                wrapMode: Text.NoWrap
                Layout.alignment: Qt.AlignVCenter
                Layout.maximumWidth: Math.round(
                    root.textMaxWidth * Theme.barWidget.mediaCompactArtistWidthRatio)
            }

            // Artist-title separator.
            Text {
                visible: root.artist !== ""
                text: " - "
                color: Colors.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeBody
                maximumLineCount: 1
                wrapMode: Text.NoWrap
                opacity: Theme.barWidget.mediaFlashLabelOpacity
            }

            // Track title label.
            Text {
                text: root._displayTitle
                color: Colors.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeBody
                font.bold: true
                elide: Text.ElideRight
                maximumLineCount: 1
                wrapMode: Text.NoWrap
                Layout.maximumWidth: root.textMaxWidth
            }
        }
    }
}
