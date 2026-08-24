import QtQuick

// Throwaway harness for the media char-transition feedback loop — lives
// beside Media.qml so production relative imports resolve identically.
Item {
    property alias pill: pillLoader.item

    width: 500
    height: 60

    Loader {
        id: pillLoader
        anchors.verticalCenter: parent.verticalCenter
        x: 8
        source: "Media.qml"
        onLoaded: item.instanceKey = "tst"
    }
}
