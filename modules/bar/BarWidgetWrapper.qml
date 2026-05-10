import QtQuick

// Host a managed bar widget with shared section sizing.
Item {
    id: root

    required property string widgetSource

    implicitHeight: loader.item ? loader.item.implicitHeight : 0
    implicitWidth: loader.item ? loader.item.implicitWidth : 0
    width: implicitWidth
    height: implicitHeight

    // Load the managed widget source for this wrapper.
    Loader {
        id: loader

        anchors.centerIn: parent
        source: Qt.resolvedUrl(root.widgetSource)
    }

}
