import QtQuick
import QtTest
import "../../modules/bar/ShippedWidgets.js" as Widgets

// Pure batch-classification contract for startup widget staging.
Item {
    TestCase {
        name: "ShippedWidgetsStartupBatch"

        function test_startupBatch_assigns_stable_batches() {
            compare(Widgets.startupBatch("clock"), 0)
            compare(Widgets.startupBatch("active-window"), 0)
            compare(Widgets.startupBatch("workspaces"), 1)
            compare(Widgets.startupBatch("tray"), 1)
            compare(Widgets.startupBatch("network"), 2)
            compare(Widgets.startupBatch("unknown"), 2)
        }
    }
}
