import QtQuick
import QtTest
import "../../services/barlayout/BarLayoutSections.js" as BarLayoutSections

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
}
