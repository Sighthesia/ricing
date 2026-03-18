import Quickshell
import QtQuick
import qs.config
import qs.services
import qs.modules.launcher as LauncherParts

// Smoke harness for launcher panel and service structural contracts.
ShellRoot {
    id: root

    Loader {
        id: panelLoader
        active: false
        sourceComponent: launcherPanelComponent
    }

    Component {
        id: launcherPanelComponent

        LauncherParts.LauncherPanel {
            id: launcherPanel
        }
    }

    function _assert(condition, message) {
        if (!condition)
            throw new Error(message)
    }

    function _childArray(node) {
        if (!node)
            return []

        if (node.contentChildren !== undefined && node.contentChildren !== null)
            return node.contentChildren
        if (node.children !== undefined && node.children !== null)
            return node.children
        if (node.data !== undefined && node.data !== null)
            return node.data

        return []
    }

    function _findFirst(node, predicate) {
        if (!node)
            return null
        if (predicate(node))
            return node

        let children = root._childArray(node)
        for (let i = 0; i < children.length; i++) {
            let match = root._findFirst(children[i], predicate)
            if (match)
                return match
        }

        return null
    }

    function _resetService() {
        LauncherService.isOpen = false
        LauncherService.prefillText = ""
    }

    Component.onCompleted: {
        root._resetService()

        root._assert(typeof LauncherService.toggle === "function",
            "LauncherService should expose toggle()")
        root._assert(typeof LauncherService.openClipboard === "function",
            "LauncherService should expose openClipboard()")

        LauncherService.toggle()
        root._assert(LauncherService.isOpen === true,
            "LauncherService.toggle() should open the launcher")
        root._assert(LauncherService.prefillText === "",
            "LauncherService.toggle() should keep an empty prefill")

        root._resetService()
        LauncherService.openClipboard()
        root._assert(LauncherService.isOpen === true,
            "LauncherService.openClipboard() should open the launcher")
        root._assert(LauncherService.prefillText === ">clip ",
            "LauncherService.openClipboard() should seed the clipboard prefix")

        root._resetService()
        panelLoader.active = true

        Qt.callLater(function() {
            let panel = panelLoader.item;
            let core = root._findFirst(panel, function(node) {
                return typeof node.openPanel === "function"
                    && typeof node.closePanel === "function"
                    && typeof node.runStructuralEnter === "function"
            })

            root._assert(panel !== null,
                "LauncherStructure smoke should instantiate LauncherPanel")
            root._assert(panel.implicitWidth === 640,
                "LauncherPanel should keep its fixed structural width")
            root._assert(panel.implicitHeight === 480,
                "LauncherPanel should keep its fixed structural height")
            root._assert(panel.focusable === true,
                "LauncherPanel should remain keyboard focusable")
            root._assert(panel.margins.top === Theme.barHeight,
                "LauncherPanel should stay offset below the bar height")
            root._assert(panel.active === LauncherService.isOpen,
                "LauncherPanel active state should follow LauncherService.isOpen")
            root._assert(core !== null,
                "LauncherPanel should instantiate LauncherCore")
            root._assert(core._searchHeader !== undefined && core._searchHeader !== null,
                "LauncherCore should expose a dedicated search header component")
            root._assert(core._resultsList !== undefined && core._resultsList !== null,
                "LauncherCore should expose a dedicated results list component")

            console.log("LauncherStructure smoke test passed")
            Qt.callLater(Qt.quit)
        })
    }
}
