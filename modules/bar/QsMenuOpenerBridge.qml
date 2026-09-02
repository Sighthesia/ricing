import Quickshell

// Expose native menu children through a lazily loaded Quickshell boundary.
QtObject {
    id: root
    property var menu: null
    readonly property var childrenModel: opener.children
    readonly property var children: opener.children
    readonly property var values: {
        var _n = opener.children ? opener.children.values.length : 0
        return opener.children ? opener.children.values : []
    }
    readonly property int count: opener.children && opener.children.values
        ? opener.children.values.length : 0

    QsMenuOpener {
        id: opener
        menu: root.menu
    }
}
