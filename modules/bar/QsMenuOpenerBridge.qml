import Quickshell

// Expose native menu children through a lazily loaded Quickshell boundary.
QtObject {
    id: root
    property var menu: null
    readonly property var children: opener.children

    QsMenuOpener {
        id: opener
        menu: root.menu
    }
}
