import QtQuick
import QtTest
import "../../modules/lazerbar"

// Exercise the pure QML host and all static route templates without Quickshell.
TestCase {
    name: "FullscreenOverlayHost"

    FullscreenOverlayHost {
        id: host
        width: 800
        height: 600
        visible: false
        settingsComponent: settingsProbe
        musicComponent: musicProbe
    }

    function test_geometryAndRoutes() {
        compare(host.surfaceWidth, 704)
        compare(host.surfaceHeight, 504)
        host.openRoute("wiki", null)
        tryCompare(host, "phase", "open", 1000)
        compare(host.route, "wiki")
        host.openRoute("news", null)
        compare(host.route, "news")
        host.openRoute("beatmap", null)
        compare(host.route, "beatmap")
    }

    function test_escapeClosesAndClearsRoute() {
        host.inputActive = false
        host.pageCanGoBack = false
        host.openRoute("wiki", null)
        tryCompare(host, "phase", "open", 1000)
        verify(host.handleEscape())
        tryCompare(host, "phase", "closed", 1000)
        compare(host.route, "")
    }

    function test_staticPagesLoad() {
        var pages = [wikiPage.createObject(host), newsPage.createObject(host), beatmapPage.createObject(host)]
        compare(pages.length, 3)
        for (var i = 0; i < pages.length; ++i) {
            verify(pages[i].implicitWidth > 0)
            verify(pages[i].implicitHeight > 0)
            pages[i].destroy()
        }
    }

    function test_compatibilityRoutesActivateLoadedContent() {
        host.openRoute("settings", null)
        tryCompare(host, "phase", "open", 1000)
        verify(host.routeItem)
        compare(host.routeItem.objectName, "settings-probe")
        compare(host.routeItem.openCount, 1)

        host.openRoute("music", null)
        tryCompare(host.routeItem, "objectName", "music-probe")
        compare(host.routeItem.openCount, 1)
        host.close()
        tryCompare(host, "phase", "closed", 1000)
    }

    Component { id: wikiPage; WikiLikePage {} }
    Component { id: newsPage; NewsLikePage {} }
    Component { id: beatmapPage; BeatmapLikePage {} }
    Component {
        id: settingsProbe
        Item {
            objectName: "settings-probe"
            property int openCount: 0
            function open() { openCount += 1 }
        }
    }
    Component {
        id: musicProbe
        Item {
            objectName: "music-probe"
            property int openCount: 0
            function open() { openCount += 1 }
        }
    }
}
