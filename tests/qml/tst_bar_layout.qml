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
    }
}
