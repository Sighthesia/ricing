import QtQuick
import QtTest
import "../../services/CapsuleMetrics.js" as CapsuleMetrics

Item {
    TestCase {
        name: "CapsuleMetrics"

        function test_compact_capsule_padding_keeps_two_to_one_ratio() {
            compare(CapsuleMetrics.compactSidePadding, 12)
            compare(CapsuleMetrics.compactVerticalPadding, 6)
            compare(CapsuleMetrics.compactInnerHorizontal, 24)
            compare(CapsuleMetrics.compactInnerVertical, 12)
        }

        function test_regular_capsule_padding_keeps_two_to_one_ratio() {
            compare(CapsuleMetrics.regularSidePadding, 16)
            compare(CapsuleMetrics.regularVerticalPadding, 8)
            compare(CapsuleMetrics.regularInnerHorizontal, 32)
            compare(CapsuleMetrics.regularInnerVertical, 16)
        }

        function test_concentric_inner_radius_subtracts_inset() {
            compare(CapsuleMetrics.concentricInnerRadius(20, 6), 14)
            compare(CapsuleMetrics.concentricInnerRadius(8, 12), 0)
        }
    }
}
