import Quickshell
import QtQuick
import "../../../services" as Services
import "./" as Harnesses

Item {
    Harnesses.BarTransientRevealHostHarness {
        anchors.fill: parent
        barLayoutService: Services.BarLayoutService
    }
}
