import QtQuick
import QtTest
import "../../modules/bar" as Bar

// Contract: the Rescan label must be centred in its button. The ring rides
// beside it, laid out against the label's left edge, so the label does not
// depend on the ring's state.
//
// The Bluetooth foot works this way. The network foot still centres the
// ring+label pair inside a Row, and because the ring holds its 16px slot plus
// 6px of spacing even while idle (opacity 0), that form puts the label ~11px
// right of centre whenever no scan is running — measured, not estimated. It
// is not asserted here: aligning the network foot is a separate decision,
// because its existing test states the invariant as "the label's x does not
// change when the ring appears", which a centred label with changing text
// cannot satisfy and which has to be restated as "its centre holds".
Item {
    id: root
    width: 400
    height: 1200

    Component { id: actionsComp; Bar.BarPopupActions {} }

    function findByName(item, name) {
        if (!item)
            return null
        if (item.objectName === name)
            return item
        var kids = item.children
        if (kids) {
            for (var i = 0; i < kids.length; i++) {
                var r = findByName(kids[i], name)
                if (r)
                    return r
            }
        }
        var dataList = item.data
        if (dataList && dataList !== kids) {
            for (var j = 0; j < dataList.length; j++) {
                if (findByName(dataList[j], name))
                    return findByName(dataList[j], name)
            }
        }
        return null
    }

    function makeBt() {
        var svc = Qt.createQmlObject(
            'import QtQuick; QtObject {'
            + ' property bool bluetoothAvailable: true;'
            + ' property bool available: true;'
            + ' property bool enabled: true;'
            + ' property bool scanningActive: false;'
            + ' property var devices;'
            + ' function startScan() { scanningActive = true } }', root, "m1")
        svc.devices = { values: [{ name: "Headphones", connected: true, paired: true, trusted: true }] }
        return svc
    }

    TestCase {
        name: "RescanLabelCentring"
        when: windowShown

        // Slack of 1px; the defect this guards was 11px, half of the slot the
        // idle ring reserves.
        function test_bluetoothRescanLabelIsCentred() {
            var item = createTemporaryObject(actionsComp, root, {
                actionKind: "bluetooth", payload: { bluetoothService: makeBt() }
            })
            var btn = findByName(item, "btRescanButton")
            var label = findByName(item, "btRescanLabel")
            tryVerify(function () {
                return Math.abs((label.x + label.width / 2) - btn.width / 2) <= 1
            }, 1000, "bluetooth Rescan label is "
                + (label.x + label.width / 2 - btn.width / 2).toFixed(1)
                + "px off centre (label=" + label.width.toFixed(1)
                + "px, button=" + btn.width + "px)")
        }

        // Still centred while the state changes, which is the case a centred
        // label with changing text has to get right.
        function test_bluetoothRescanLabelStaysCentredWhileScanning() {
            var svc = makeBt()
            var item = createTemporaryObject(actionsComp, root, {
                actionKind: "bluetooth", payload: { bluetoothService: svc }
            })
            var btn = findByName(item, "btRescanButton")
            var label = findByName(item, "btRescanLabel")
            svc.scanningActive = true
            wait(50)
            compare(label.text, "Scanning…")
            tryVerify(function () {
                return Math.abs((label.x + label.width / 2) - btn.width / 2) <= 1
            }, 1000, "label drifted off centre while scanning")
        }
    }
}
