import QtQuick
import QtQuick.Layouts
import qs.config

// Compact media identity row used by the media control widget.
Item {
    id: root

    property string title: ""
    property string artist: ""
    property string artUrl: ""
    property string fallbackIcon: "audio-x-generic-symbolic"
    property int artworkSize: Theme.barWidget.pillHeight - Theme.barWidget.contentPaddingV * 2
    property int textMaxWidth: Theme.barWidget.mediaCompactMaxTitleWidth

    readonly property string _displayTitle: root.title !== "" ? root.title : "No Media"

    implicitWidth: _contentRow.implicitWidth
    implicitHeight: _contentRow.implicitHeight

    // Compact content row.
    RowLayout {
        id: _contentRow
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.barWidget.iconLabelSpacing

        // Compact artwork.
        MediaArtwork {
            source: root.artUrl
            fallbackIcon: root.fallbackIcon
            size: root.artworkSize
            Layout.alignment: Qt.AlignVCenter
        }

        // Compact text cluster.
        RowLayout {
            spacing: Theme.barWidget.iconSpacing
            Layout.fillWidth: true
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
                Layout.fillWidth: true
                Layout.maximumWidth: root.textMaxWidth
            }
        }
    }
}