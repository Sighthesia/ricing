pragma Singleton
import QtQuick
import "barlayout/BarLayoutLayoutModel.js" as BarLayoutModel
import "barlayout/BarLayoutSections.js" as BarLayoutSections

// Own the default bar layout and expose section lookup helpers.
QtObject {
    id: root

    readonly property int barHeight: 42
    readonly property var layoutModel: BarLayoutModel.defaultLayoutModel()

    function sectionWidgets(sectionName) {
        return BarLayoutModel.sectionWidgets(layoutModel, sectionName);
    }

    function sectionWidth(sectionModel) {
        return BarLayoutSections.sectionWidth(sectionModel);
    }

}
