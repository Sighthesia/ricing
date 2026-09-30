pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.UPower

// Expose the primary laptop battery as compact bar-friendly state.
Singleton {
    id: root

    readonly property var laptopBatteries: UPower.devices && UPower.devices.values
        ? UPower.devices.values.filter(device => device && device.isLaptopBattery)
        : []
    readonly property var primaryDevice: UPower.displayDevice && UPower.displayDevice.isPresent
        ? UPower.displayDevice
        : (root.laptopBatteries.length > 0 ? root.laptopBatteries[0] : null)
    readonly property bool available: !!root.primaryDevice && root.isDevicePresent(root.primaryDevice)
    readonly property bool ready: !!root.primaryDevice && root.isDeviceReady(root.primaryDevice)
    readonly property int percentage: root.ready ? root.getPercentage(root.primaryDevice) : 0
    readonly property bool charging: root.ready && root.isCharging(root.primaryDevice)
    readonly property bool pluggedIn: root.ready && root.isPluggedIn(root.primaryDevice)
    // UPower reports positive changeRate while charging and negative while discharging.
    readonly property real chargeRate: root.ready ? root.getChargeRate(root.primaryDevice) : 0
    readonly property real dischargeRate: root.ready ? root.getDischargeRate(root.primaryDevice) : 0
    readonly property real timeToEmpty: root.ready && !root.charging && !root.pluggedIn
        ? root.getTimeEstimate(root.primaryDevice, "timeToEmpty") : 0
    readonly property real timeToFull: root.ready && root.charging
        ? root.getTimeEstimate(root.primaryDevice, "timeToFull") : 0
    readonly property bool low: root.ready && !root.charging && !root.pluggedIn && root.percentage <= 20 && root.percentage > 10
    readonly property bool critical: root.ready && !root.charging && !root.pluggedIn && root.percentage <= 10
    readonly property string iconText: {
        if (!root.available)
            return ""
        if (!root.ready)
            return "?"
        if (root.charging)
            return "CHG"
        if (root.pluggedIn)
            return "AC"
        return "BAT"
    }

    function isDevicePresent(device) {
        if (!device)
            return false

        if (device.isPresent !== undefined)
            return device.isPresent === true

        return device.ready === true && device.percentage !== undefined
    }

    function isDeviceReady(device) {
        return root.isDevicePresent(device) && device.ready === true && device.percentage !== undefined
    }

    function getPercentage(device) {
        if (!device || device.percentage === undefined)
            return 0

        return Math.round(device.percentage * 100)
    }

    function getChangeRate(device) {
        if (!device || device.changeRate === undefined)
            return 0

        var value = Number(device.changeRate)
        return isFinite(value) ? value : 0
    }

    function getChargeRate(device) {
        return Math.max(0, root.getChangeRate(device))
    }

    function getDischargeRate(device) {
        return Math.max(0, -root.getChangeRate(device))
    }

    function getTimeEstimate(device, propertyName) {
        if (!device || device[propertyName] === undefined)
            return 0

        var value = Number(device[propertyName])
        return isFinite(value) && value > 0 ? value : 0
    }

    function isCharging(device) {
        return !!device && device.state === UPowerDeviceState.Charging
    }

    function isPluggedIn(device) {
        return !!device && (device.state === UPowerDeviceState.FullyCharged
            || device.state === UPowerDeviceState.PendingCharge)
    }
}
