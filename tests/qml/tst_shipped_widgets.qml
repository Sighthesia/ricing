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

        function test_startupBatchCount_covers_every_shipped_id() {
            compare(Widgets.startupBatchCount, 3)
            for (var i = 0; i < Widgets.ids.length; i++) {
                verify(Widgets.startupBatch(Widgets.ids[i]) < Widgets.startupBatchCount,
                       "shipped id above the batch count: " + Widgets.ids[i])
            }
            verify(Widgets.startupBatch("unknown") < Widgets.startupBatchCount,
                   "unknown ids must stay inside the staged batches")
        }
    }
}
