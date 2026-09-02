import Quickshell

// Expose native menu children through a lazily loaded Quickshell boundary.
QtObject {
    id: root
    property QsMenuHandle menu: null
    property alias children: opener.children
    property var values: []
    property int count: 0

    function refreshValues() {
        var model = opener.children
        var next = model ? model.values : []
        root.values = next || []
        root.count = root.values.length
    }

    Component.onCompleted: refreshValues()

    Connections {
        target: opener
        function onChildrenChanged() { root.refreshValues() }
    }

    Connections {
        target: opener.children
        function onObjectInsertedPost() { root.refreshValues() }
        function onObjectRemovedPost() { root.refreshValues() }
    }

    QsMenuOpener {
        id: opener
        menu: root.menu
    }
}
