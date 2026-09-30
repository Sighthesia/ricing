import QtQuick
import "./services" as Services

// Exercise the BatteryService's UPower value normalization without changing
// the live power device or opening a window on the desktop.
Item {
    id: root

    property int checks: 0
    property int failures: 0

    // Lightweight stand-in for the read-only UPowerDevice properties.
    QtObject {
        id: fakeDevice
        property real changeRate: 18.4
        property real timeToEmpty: 12480
        property real timeToFull: 2520
    }

    function check(label, actual, expected) {
        root.checks += 1
        if (actual === expected) {
            console.log("PASS:", label)
            return
        }
        root.failures += 1
        console.log("FAIL:", label, "expected", expected, "got", actual)
    }

    Component.onCompleted: Qt.callLater(function() {
        var service = Services.BatteryService
        root.check("positive rate is a charge rate", service.getChargeRate(fakeDevice), 18.4)
        root.check("positive rate has no discharge rate", service.getDischargeRate(fakeDevice), 0)

        fakeDevice.changeRate = -12.1
        root.check("negative rate has no charge rate", service.getChargeRate(fakeDevice), 0)
        root.check("negative rate is a discharge rate", service.getDischargeRate(fakeDevice), 12.1)

        root.check("time-to-empty is read in seconds",
            service.getTimeEstimate(fakeDevice, "timeToEmpty"), 12480)
        root.check("time-to-full is read in seconds",
            service.getTimeEstimate(fakeDevice, "timeToFull"), 2520)

        fakeDevice.timeToEmpty = 0
        root.check("zero estimate is unknown", service.getTimeEstimate(fakeDevice, "timeToEmpty"), 0)
        console.log("Totals:", root.checks - root.failures, "passed,", root.failures, "failed")
        Qt.quit()
    })
}
