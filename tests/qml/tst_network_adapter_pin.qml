import QtQuick
import QtTest
import "../../services/network/NetworkLogic.js" as Logic

// NetworkManager pins a profile to the adapter it was created on. Adapter
// names move (wlan0 → wlo1, predictable names dropped), and a profile left
// pinned to a device that is gone is refused with
// "not compatible … (mismatching interface name)" — permanently, with no way
// to recover from the panel. These cover the ranking that avoids it and the
// repair that fixes an already-stranded profile.
Item {
    // One profile's detail block, exactly as `nmcli -t` prints it: a
    // "<field>:<value>" line per requested field, groups split by a blank line.
    function detailRow(ssid, uuid, keyMgmt, ifname) {
        var text = "802-11-wireless.ssid:" + ssid + "\n"
            + "connection.uuid:" + uuid + "\n"
        if (keyMgmt !== null)
            text += "802-11-wireless-security.key-mgmt:" + keyMgmt + "\n"
        if (ifname !== null)
            text += "connection.interface-name:" + ifname + "\n"
        return text
    }

    TestCase {
        name: "NetworkAdapterPin"
        when: windowShown

        function test_profileRankOrdersByUsability() {
            compare(Logic.profileRank({ ifname: "" }, "wlo1"), 0, "unpinned works anywhere")
            compare(Logic.profileRank({ ifname: "wlo1" }, "wlo1"), 1)
            compare(Logic.profileRank({ ifname: "wlp0s20f3" }, "wlo1"), 2, "dead pin")
            compare(Logic.profileRank({ ifname: "wlo1" }, ""), 2, "no adapter to match yet")
            compare(Logic.profileRank(null, "wlo1"), 3)
        }

        // The dead-pinned duplicate is listed first, exactly as NetworkManager
        // happens to order it; picking by order alone activates a profile that
        // can never succeed.
        function test_parseProfileListPrefersTheLiveAdapter() {
            var base = "Mate 40 Pro 1:uuid-dead:802-11-wireless\n"
                + "Mate 40 Pro:uuid-live:802-11-wireless"
            var detail = detailRow("Mate 40 Pro", "uuid-dead", "wpa-psk", "wlp0s20f3")
                + "\n" + detailRow("Mate 40 Pro", "uuid-live", "wpa-psk", "wlo1")
            var result = Logic.parseProfileList(base, detail, "wlo1")
            compare(result.bySsid["Mate 40 Pro"].uuid, "uuid-live")
            compare(result.bySsid["Mate 40 Pro"].ifname, "wlo1")
        }

        function test_parseProfileListPrefersUnpinnedOverPinned() {
            var base = "A:uuid-pinned:802-11-wireless\nB:uuid-any:802-11-wireless"
            var detail = detailRow("Home", "uuid-pinned", "wpa-psk", "wlo1")
                + "\n" + detailRow("Home", "uuid-any", "wpa-psk", "")
            var result = Logic.parseProfileList(base, detail, "wlo1")
            compare(result.bySsid["Home"].uuid, "uuid-any",
                "an unpinned profile works on any adapter")
        }

        function test_parseProfileListKeepsSoleDeadPinWhenNothingElseExists() {
            var base = "Old:uuid-dead:802-11-wireless"
            var detail = detailRow("Old", "uuid-dead", "wpa-psk", "wlp0s20f3")
            var result = Logic.parseProfileList(base, detail, "wlo1")
            compare(result.bySsid["Old"].uuid, "uuid-dead",
                "the only profile is still the target; the repair handles it")
        }

        function test_parseProfileListIsStableAcrossScans() {
            var base = "Net:uuid-a:802-11-wireless\nNet 1:uuid-b:802-11-wireless"
            var detail = detailRow("Net", "uuid-a", "wpa-psk", "wlo1")
                + "\n" + detailRow("Net", "uuid-b", "wpa-psk", "wlo1")
            var first = Logic.parseProfileList(base, detail, "wlo1").bySsid["Net"].uuid
            var second = Logic.parseProfileList(base, detail, "wlo1").bySsid["Net"].uuid
            compare(first, second, "an equal-rank tie must not flap between scans")
            compare(first, "uuid-a")
        }

        function test_isStaleAdapterPin() {
            verify(Logic.isStaleAdapterPin({ ifname: "wlp0s20f3" }, "wlo1"))
            verify(!Logic.isStaleAdapterPin({ ifname: "wlo1" }, "wlo1"))
            verify(!Logic.isStaleAdapterPin({ ifname: "" }, "wlo1"), "unpinned is fine")
            verify(!Logic.isStaleAdapterPin(null, "wlo1"))
            verify(!Logic.isStaleAdapterPin({ ifname: "wlo1" }, ""), "no adapter known yet")
        }

        function test_planRepairsADeadPin() {
            var dead = { uuid: "u", name: "n", ifname: "wlp0s20f3" }
            compare(Logic.connectPlan(dead, false, "wlo1"), "modify",
                "a dead pin is repaired before activating, not abandoned")
        }

        function test_planActivatesWhenThePinIsGood() {
            compare(Logic.connectPlan({ uuid: "u", ifname: "wlo1" }, false, "wlo1"), "activate")
            compare(Logic.connectPlan({ uuid: "u", ifname: "" }, false, "wlo1"), "activate")
        }

        function test_modifyArgsRepointsWithoutTouchingTheSecret() {
            // The stored secret is still good, so it must not be rewritten.
            compare(Logic.modifyArgs("uuid-a", "", "wlo1", true).join(" "),
                "connection modify uuid uuid-a connection.interface-name wlo1")
        }

        function test_modifyArgsRepointsAndRewritesSecret() {
            compare(Logic.modifyArgs("uuid-a", "hunter2", "wlo1", true).join(" "),
                "connection modify uuid uuid-a connection.interface-name wlo1"
                + " 802-11-wireless-security.psk hunter2")
        }

        function test_modifyArgsLeavesTheAdapterAloneWhenThePinIsGood() {
            compare(Logic.modifyArgs("uuid-a", "hunter2", "wlo1", false).join(" "),
                "connection modify uuid uuid-a 802-11-wireless-security.psk hunter2")
        }

        function test_classifyDeadPinReadsAsSomethingActionable() {
            compare(Logic.classifyConnectError("Error: Connection activation failed: "
                + "No suitable device found for this connection (device enp2s0 not "
                + "available because profile is not compatible with device "
                + "(mismatching interface name))."),
            "No adapter matches this saved profile")
            compare(Logic.classifyConnectError(
                "Error: Device wlo1 is not compatible with the connection 'Home'."),
            "No adapter matches this saved profile")
        }
    }
}
