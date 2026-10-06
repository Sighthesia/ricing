import QtQuick
import QtTest
import "../../services/barlayout/BarLayoutSections.js" as BarLayoutSections
import "../../services/barlayout/BarLayoutLayoutModel.js" as BarLayoutModel
import "../../modules/bar/ShippedWidgets.js" as ShippedWidgets

Item {
    TestCase {
        name: "BarLayoutSections"

        function test_sectionWidth_returns_zero_for_empty_model() {
            compare(BarLayoutSections.sectionWidth([]), 0)
        }

        function test_sectionWidth_ignores_spacing_for_single_widget() {
            compare(BarLayoutSections.sectionWidth([{ implicitWidth: 80 }]), 80)
        }

        function test_sectionWidth_includes_spacing_between_widgets() {
            compare(
                BarLayoutSections.sectionWidth([
                    { implicitWidth: 80 },
                    { implicitWidth: 100 },
                    { implicitWidth: 60 }
                ]),
                80 + 100 + 60 + (BarLayoutSections.widgetSpacing * 2)
            )
        }
    }

    TestCase {
        name: "BarLayoutModel"

        function test_availableWidgets_include_topbar_component_set() {
            var widgetIds = []
            var widgets = BarLayoutModel.availableWidgets()
            for (var i = 0; i < widgets.length; i++)
                widgetIds.push(widgets[i].id)

            for (var j = 0; j < [
                "active-window", "workspaces", "media", "tray", "volume",
                "brightness", "notifications", "settings", "clock"
            ].length; j++) {
                verify(widgetIds.indexOf([
                    "active-window", "workspaces", "media", "tray", "volume",
                    "brightness", "notifications", "settings", "clock"
                ][j]) !== -1)
            }
        }

        function test_normalizeWidgetId_keeps_settings_id() {
            compare(BarLayoutModel.normalizeWidgetId("settings"), "settings")
        }

        function test_default_layout_spans_all_sections() {
            var model = BarLayoutModel.defaultLayoutModel()
            verify(model.widgets.length > 0)

            var sections = {}
            for (var i = 0; i < model.widgets.length; i++) {
                var entry = model.widgets[i]
                verify(BarLayoutModel.availableWidget(entry.id) !== null,
                       "default layout widget must exist in registry: " + entry.id)
                sections[entry.section] = true
            }
            verify(sections.left && sections.center && sections.right)
        }
    }

    TestCase {
        name: "BarLauncherEntry"

        // Reads a repo file synchronously so mount contracts stay checkable
        // without instantiating Quickshell windows under qmltestrunner.
        // Returns "" when local file reads are disabled in this environment.
        function fileText(relativePath) {
            var xhr = new XMLHttpRequest
            try {
                xhr.open("GET", Qt.resolvedUrl(relativePath), false)
                xhr.send()
            } catch (error) {
                return ""
            }
            return String(xhr.responseText || "")
        }

        function test_shipped_widgets_include_launcher() {
            verify(ShippedWidgets.ships("launcher"))
            verify(ShippedWidgets.ids.indexOf("settings") !== -1)
        }

        // Behavior-level guard for the exact render-filter regression: the
        // launcher entry from a real section listing must survive the same
        // filter BarContent applies before instantiating loaders.
        function test_loadable_filter_keeps_launcher_mapped_to_button() {
            var entries = [
                { id: "clock", instanceKey: "clock:0", source: "../../modules/bar/widgets/Clock.qml" },
                { id: "launcher", instanceKey: "launcher:0", source: "../../modules/bar/widgets/LauncherButton.qml" },
                // Registry id without a shipped implementation must stay dropped.
                { id: "widget-picker-button", instanceKey: "widget-picker-button:0", source: "" },
            ]
            var filtered = ShippedWidgets.loadable(entries)
            compare(filtered.length, 2)
            compare(filtered[1].id, "launcher")
            compare(filtered[1].source, "../../modules/bar/widgets/LauncherButton.qml")
            verify(BarLayoutModel.defaultWidgetSource(filtered[1].id)
                   === filtered[1].source,
                   "surviving launcher entry must remain mapped to LauncherButton")
        }

        // Every default-layout widget must survive the production filter;
        // a silently dropped default (like launcher was) fails here.
        function test_default_layout_widgets_all_survive_render_filter() {
            var model = BarLayoutModel.defaultLayoutModel()
            var filtered = ShippedWidgets.loadable(model.widgets)
            compare(filtered.length, model.widgets.length)
            var launcherSurvived = false
            for (var i = 0; i < filtered.length; i++) {
                if (filtered[i].id === "launcher")
                    launcherSurvived = true
            }
            verify(launcherSurvived, "launcher must survive loadable filtering")
        }

        function test_bar_content_delegates_to_shared_shipped_source() {
            var content = fileText("../../modules/bar/BarContent.qml")
            if (content === "")
                skip("local file reads disabled; run with QML_XHR_ALLOW_FILE_READ=1")
            verify(content.indexOf("ShippedWidgets.loadable") !== -1,
                   "BarContent must filter through the shared ShippedWidgets source")
            verify(content.indexOf("shippedWidgetIds") === -1,
                   "BarContent must not keep a private hardcoded widget list")
        }

        function test_registry_maps_launcher_to_button_widget() {
            compare(BarLayoutModel.defaultWidgetSource("launcher"),
                    "../../modules/bar/widgets/LauncherButton.qml")
            var definition = BarLayoutModel.availableWidget("launcher")
            verify(definition !== null)
            compare(definition.section, "left")
        }

        function test_default_layout_installs_enabled_launcher_entry() {
            var model = BarLayoutModel.defaultLayoutModel()
            var found = false
            for (var i = 0; i < model.widgets.length; i++) {
                if (model.widgets[i].id === "launcher") {
                    found = true
                    compare(model.widgets[i].section, "left")
                    compare(model.widgets[i].enabled, true)
                }
            }
            verify(found, "default layout must ship the launcher entry")
        }

        function test_production_bar_mounts_launcher_stack_and_service() {
            var barTopBar = fileText("../../modules/bar/TopBar.qml")
            if (barTopBar === "")
                skip("local file reads disabled; run with QML_XHR_ALLOW_FILE_READ=1")
            verify(barTopBar.indexOf("LauncherSurface") !== -1,
                   "production bar must mount the launcher surface stack")
            verify(barTopBar.indexOf("Services.LauncherService") !== -1,
                   "mounted launcher surface must reference LauncherService so its IPC target registers")

            verify(fileText("../../modules/lazerbar/TopBar.qml").indexOf("LauncherSurface") !== -1,
                   "legacy top bar must route through the shared launcher surface stack")
            verify(fileText("../../modules/bar/widgets/LauncherButton.qml").indexOf("LauncherService") !== -1,
                   "launcher bar entry must drive the launcher session")
        }

        // The control center is reached from the launcher's rail, not from the bar, and
        // it is a VIEW inside the launcher page rather than a wave route. Nothing on
        // the bar may name it as a target any more: a second entry would give the
        // same surface two spellings again, and the one it replaces would sit on
        // every screen as an affordance the launcher already carries. The seam
        // itself stays, because a wave target refused there must fail loudly rather
        // than open a surface without the session and opener bookkeeping.
        function test_theControlCenterHasNoBarEntryAndTheSeamSurvives() {
            var bar = fileText("../../modules/bar/TopBar.qml")
            if (bar === "")
                skip("local file reads disabled; run with QML_XHR_ALLOW_FILE_READ=1")

            verify(bar.indexOf('controlCenterEntry') < 0,
                   "the bar must not declare a control-center entry")
            verify(bar.indexOf('requestOverlay("control-center"') < 0,
                   "the bar must not ask for the control-center route")
            verify(bar.indexOf('rightEdgeInset') < 0,
                   "the trailing inset existed only to yield space to that entry")

            verify(bar.indexOf("function requestOverlay(target, opener)") !== -1,
                   "the screen scope must keep the shared overlay seam")
            verify(bar.indexOf("CoordLogic.dispatchFor(target, launcherSurface)") !== -1,
                   "the seam must read one dispatch decision from the coordinator registry")
            // One decision, one place. A second lookup of the entry method inside the
            // bar would be a second dispatch table, and the shape it took last time -
            // a missing method quietly handed to the coordinator - is exactly the
            // silent failure the shared decision refuses.
            verify(bar.indexOf("CoordLogic.entryMethodFor(") < 0,
                   "the bar must not re-derive the wave entry method itself")

            // One wave owner, one route registry, no second window: the file must
            // mount exactly one LauncherSurface and exactly one OverlayCoordinator.
            verify(countOccurrences(bar, "LauncherSurface {") === 1,
                   "the production bar mounts exactly one launcher/wave surface")
            verify(countOccurrences(bar, "OverlayCoordinator {") === 1,
                   "the production bar mounts exactly one overlay coordinator")

            // `root` in this file is the bar's Variants, which owns no hover
            // state at all. A glyph that read `root.hovered` would compile, look
            // plausible and never brighten.
            verify(bar.indexOf("root.hovered") < 0,
                   "a bar-surface hover read must name the widget that has it")

            // The owner edge passes the singletons in, rather than the launcher page
            // importing them, so a test can still inject fakes. The page is where
            // they land: it owns the control-center view's Loader, so it is the one
            // place that has to forward them.
            var surface = fileText("../../modules/lazerbar/LauncherSurface.qml")
            verify(surface !== "", "the launcher surface must be readable")
            verify(surface.indexOf("ControlCenter {") < 0,
                   "the surface must not build the control center: the page owns it")
            verify(surface.indexOf("controlCenterPageComponent") < 0,
                   "and no route component may be registered for it")
            verify(surface.indexOf("import \"../../services\"") < 0,
                   "the surface must not import services; the owner edge injects them")

            var page = fileText("../../modules/lazerbar/LauncherPage.qml")
            verify(page !== "", "the launcher page must be readable")
            verify(page.indexOf("ControlCenter {") !== -1,
                   "the launcher page must mount the control-center view")
            // `Services.` in a line comment is a comment, not an import; the page's
            // launcher seam is `services/launcher`, which is a QML component
            // directory and not the singleton registry. So the check is on the
            // registry MODULE specifically - importing `services` would let this
            // page reach a singleton directly and bypass the injection contract.
            verify(page.indexOf("import \"../../services\"") < 0,
                   "the page must not import the service registry; the surface forwards them")
            for (var i = 0; i < controlCenterServiceNames.length; i++) {
                verify(bar.indexOf("Services." + controlCenterServiceNames[i].name) !== -1,
                       "the bar must pass " + controlCenterServiceNames[i].name + " in")
                verify(surface.indexOf(controlCenterServiceNames[i].seam) !== -1,
                       "the surface must forward " + controlCenterServiceNames[i].name
                           + " as " + controlCenterServiceNames[i].seam + " to the page")
                verify(page.indexOf(controlCenterServiceNames[i].seam) !== -1,
                       "the page must forward " + controlCenterServiceNames[i].name
                           + " as " + controlCenterServiceNames[i].seam + " to the view")
            }
        }

        // The services the production owner edge hands to the launcher page, and
        // the page forwards to the control-center view, named once here so the
        // assertions above and the wiring itself cannot drift.
        //
        // Both spellings are listed per service because they are two different
        // contracts: `name` is the registry symbol only the bar may use, and
        // `seam` is the property name the other two files spell. Asserting the
        // registry symbol in the surface or the page would be wrong (it would
        // fail loudly rather than silently), and asserting the seam in the bar
        // would pass without proving the singleton was ever named at all.
        readonly property var controlCenterServiceNames: [
            { name: "NetworkService", seam: "networkService" },
            { name: "BluetoothService", seam: "bluetoothService" },
            { name: "VolumeService", seam: "volumeService" },
            { name: "MediaService", seam: "mediaService" },
            { name: "BatteryService", seam: "batteryService" },
            { name: "NotificationService", seam: "notificationService" },
            { name: "WeatherService", seam: "weatherService" }
        ]

        function countOccurrences(text, needle) {
            var total = 0
            var at = text.indexOf(needle)
            while (at >= 0) {
                total++
                at = text.indexOf(needle, at + needle.length)
            }
            return total
        }
    }
}
