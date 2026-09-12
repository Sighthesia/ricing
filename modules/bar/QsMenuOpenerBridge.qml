import QtQuick
import Quickshell

// Expose native menu children through a lazily loaded Quickshell boundary.
Item {
    id: root
    visible: false
    width: 0
    height: 0
    // Preserve the native handle type through the Loader boundary. A `var`
    // property converts QsMenuEntry handles to QJSValue, which QsMenuOpener
    // cannot assign to its strongly typed menu property.
    property QsMenuHandle menu: null
    property alias children: opener.children
    property var values: []
    property int count: 0

    function refreshValues() {
        if (!opener || !opener.children)
            return
        var next = []
        try { next = opener.children.values } catch (e) { next = [] }
        if (!next)
            next = []
        // Avoid spurious assignments during teardown where root is already destroyed.
        try {
            root.values = next
            root.count = next.length
        } catch (e) {}
    }

    Component.onCompleted: refreshValues()
    onMenuChanged: refreshValues()

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
