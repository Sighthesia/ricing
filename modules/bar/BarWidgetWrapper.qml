import QtQuick

// Host a managed bar widget with shared section sizing.
Item {
    id: root

    required property var widgetEntry
    required property string widgetSource
    required property string screenName

    readonly property string widgetInstanceKey: widgetEntry && widgetEntry.instanceKey ? widgetEntry.instanceKey : ""
    readonly property bool localPointerIntent: pointerArea.containsMouse
    objectName: widgetInstanceKey

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

    // Track passive pointer presence without binding the wrapper to dockzone semantics.
    MouseArea {
        id: pointerArea

        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }

}
