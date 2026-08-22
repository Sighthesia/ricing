import QtQuick
import QtTest
import "../../services/barlayout/BarLayoutSections.js" as BarLayoutSections
import "../../services/barlayout/BarLayoutLayoutModel.js" as BarLayoutModel

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
}
