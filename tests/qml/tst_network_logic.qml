import QtQuick
import QtTest
import "../../services/network/NetworkLogic.js" as Logic

// Unit-test the pure Wi-Fi plumbing: terse `nmcli -t` parsing (escaped SSIDs,
// multi-band duplicates), saved-profile lookup by SSID rather than by profile
// name, connect-strategy choice and stderr → user-facing message. These are
// the rules that made saved networks look unknown and every failure read the
// same inside the popup.
Item {
    TestCase {
        name: "NetworkTerseParsing"
        when: windowShown

        function test_splitTersePlainFields() {
            var parts = Logic.splitTerse("HomeWifi:WPA2:85:*", 4)
            compare(parts.length, 4)
            compare(parts[0], "HomeWifi")
            compare(parts[1], "WPA2")
            compare(parts[2], "85")
            compare(parts[3], "*")
        }

        function test_splitTerseEscapedSeparator() {
            // nmcli escapes the separator inside a value, so "Cafe:2.4G" must
            // not be read as two fields.
            var parts = Logic.splitTerse("Cafe\\:2.4G:WPA2:70:", 4)
            compare(parts.length, 4)
            compare(parts[0], "Cafe:2.4G")
            compare(parts[1], "WPA2")
            compare(parts[2], "70")
            compare(parts[3], "")
        }

        function test_splitTerseStopsAtFieldBudget() {
            var parts = Logic.splitTerse("a:b:c:d:e", 3)
            compare(parts.length, 3)
            compare(parts[0], "a")
            compare(parts[1], "b")
            compare(parts[2], "c:d:e")
        }

        function test_unescapeTerse() {
            compare(Logic.unescapeTerse("Cafe\\:2.4G"), "Cafe:2.4G")
            compare(Logic.unescapeTerse("back\\\\slash"), "back\\slash")
            compare(Logic.unescapeTerse("plain"), "plain")
            compare(Logic.unescapeTerse(undefined), "")
        }

        function test_parseWifiListMapsSsid() {
            // nmcli leaves the security field empty for an open network.
            var map = Logic.parseWifiList("HomeWifi:WPA2:85:*\nCafe::40:", {})
            compare(Object.keys(map).length, 2)
            compare(map.HomeWifi.security, "WPA2")
            compare(map.HomeWifi.signal, 85)
            verify(map.HomeWifi.connected)
            verify(!map.HomeWifi.existing)
            compare(map.Cafe.security, "--", "an empty security field reads as open")
            verify(!map.Cafe.connected)
        }

        function test_parseWifiListKeepsStrongestBand() {
            // One SSID on two radios: the active band must stay flagged and
            // keep its own signal, not be overwritten by a stronger idle one.
            var map = Logic.parseWifiList("Net:WPA2:40:\nNet:WPA2:90:*\nNet:WPA2:70:", {})
            compare(Object.keys(map).length, 1)
            verify(map.Net.connected)
            compare(map.Net.signal, 90)
        }

        function test_parseWifiListActiveBandSignalWins() {
            var map = Logic.parseWifiList("Net:WPA2:40:*\nNet:WPA2:90:", {})
            verify(map.Net.connected)
            compare(map.Net.signal, 40, "a stronger idle band must not steal the row")
        }

        function test_parseWifiListEscapedSsid() {
            var map = Logic.parseWifiList("Cafe\\:2.4G:WPA2:70:", {})
            verify(map["Cafe:2.4G"] !== undefined, "escaped SSID is unescaped")
            compare(map["Cafe:2.4G"].signal, 70)
        }

        function test_parseWifiListSkipsHiddenAndJunk() {
            var map = Logic.parseWifiList(":WPA2:30:\n\ngarbage\nCafe:WPA2:20:", {})
            compare(Object.keys(map).length, 1)
            compare(map.Cafe.ssid, "Cafe")
        }

        function test_parseWifiListEmptyInput() {
            compare(Object.keys(Logic.parseWifiList("", {})).length, 0)
            compare(Object.keys(Logic.parseWifiList(null, null)).length, 0)
        }
    }

    TestCase {
        name: "NetworkProfileLookup"
        when: windowShown

        // NetworkManager renames a duplicate profile to "<name> 1", so the
        // profile name stops matching the SSID. Matching on name alone left
        // every such network looking unsaved, and each tap then asked for a
        // password / failed on a profile that actually existed.
        function test_parseProfileListMatchesSsidNotName() {
            var base = "Mate 40 Pro 1:uuid-a:802-11-wireless\n"
                + "Hasee-TA5NS:uuid-b:802-11-wireless\n"
                + "Mihomo:uuid-c:tun"
            // Real `nmcli -t -f …ssid,connection.uuid,…key-mgmt` output: one
            // "<field>:<value>" line per field, groups split by a blank line.
            var detail = "802-11-wireless.ssid:Mate 40 Pro\n"
                + "connection.uuid:uuid-a\n"
                + "802-11-wireless-security.key-mgmt:wpa-psk\n"
                + "\n"
                + "802-11-wireless.ssid:Hasee-TA5NS\n"
                + "connection.uuid:uuid-b\n"
                + "802-11-wireless-security.key-mgmt:sae\n"
                + "\n"
                + "connection.uuid:uuid-c\n"
            var result = Logic.parseProfileList(base, detail)
            verify(result.bySsid["Mate 40 Pro"] !== undefined, "saved by SSID")
            compare(result.bySsid["Mate 40 Pro"].name, "Mate 40 Pro 1")
            compare(result.bySsid["Mate 40 Pro"].uuid, "uuid-a")
            compare(result.bySsid["Mate 40 Pro"].keyMgmt, "wpa-psk")
            compare(result.bySsid["Hasee-TA5NS"].keyMgmt, "sae")
            verify(result.bySsid["Mihomo"] === undefined, "non-wireless profile is ignored")
            verify(result.byName["Mate 40 Pro 1"], "names are still indexed")
        }

        function test_parseProfileListIsOrderIndependent() {
            // Groups arriving in a different order must not cross profiles:
            // pairing rows by position did exactly that.
            var base = "Net A 1:uuid-a:802-11-wireless\nNet B 1:uuid-b:802-11-wireless"
            var forward = "802-11-wireless.ssid:Net A\nconnection.uuid:uuid-a\n"
                + "802-11-wireless-security.key-mgmt:wpa-psk\n\n"
                + "802-11-wireless.ssid:Net B\nconnection.uuid:uuid-b\n"
                + "802-11-wireless-security.key-mgmt:sae\n"
            var reversed = "802-11-wireless.ssid:Net B\nconnection.uuid:uuid-b\n"
                + "802-11-wireless-security.key-mgmt:sae\n\n"
                + "802-11-wireless.ssid:Net A\nconnection.uuid:uuid-a\n"
                + "802-11-wireless-security.key-mgmt:wpa-psk\n"
            var a = Logic.parseProfileList(base, forward).bySsid
            var b = Logic.parseProfileList(base, reversed).bySsid
            compare(a["Net A"].uuid, "uuid-a")
            compare(b["Net A"].uuid, "uuid-a")
            compare(a["Net B"].uuid, "uuid-b")
            compare(b["Net B"].uuid, "uuid-b")
        }

        function test_parseProfileListFallsBackToNames() {
            // A rejected detail call must not lose every saved network.
            var base = "HomeWifi:uuid-a:802-11-wireless"
            var result = Logic.parseProfileList(base, "")
            verify(result.bySsid["HomeWifi"] !== undefined)
            compare(result.bySsid["HomeWifi"].uuid, "uuid-a")
        }

        function test_parseProfileListFirstProfileWins() {
            var base = "Cafe:uuid-a:802-11-wireless\nCafe 1:uuid-b:802-11-wireless"
            var detail = "802-11-wireless.ssid:Cafe\nconnection.uuid:uuid-a\n"
                + "802-11-wireless-security.key-mgmt:wpa-psk\n\n"
                + "802-11-wireless.ssid:Cafe\nconnection.uuid:uuid-b\n"
                + "802-11-wireless-security.key-mgmt:wpa-psk\n"
            var result = Logic.parseProfileList(base, detail)
            compare(Object.keys(result.bySsid).length, 1)
            compare(result.bySsid["Cafe"].uuid, "uuid-a", "repeated scans must not flap")
        }

        function test_parseProfileListOpenProfileHasNoKeyMgmt() {
            var base = "OpenNet:uuid-a:802-11-wireless"
            var detail = "802-11-wireless.ssid:OpenNet\nconnection.uuid:uuid-a\n\n"
            var result = Logic.parseProfileList(base, detail)
            compare(result.bySsid["OpenNet"].keyMgmt, "")
        }

        function test_parseProfileDetailSkipsFieldlessGroups() {
            var rows = Logic.parseProfileDetail("connection.uuid:uuid-a\n\n\n")
            compare(rows.length, 1)
            compare(rows[0].uuid, "uuid-a")
            compare(rows[0].ssid, "")
        }

        function test_parseWifiListUsesProfileLookup() {
            var saved = { "Mate 40 Pro": { name: "Mate 40 Pro 1", uuid: "uuid-a" } }
            var map = Logic.parseWifiList("Mate 40 Pro:WPA2:60:", saved)
            verify(map["Mate 40 Pro"].existing, "renamed profile still counts as saved")
            compare(map["Mate 40 Pro"].savedUuid, "uuid-a")
            compare(map["Mate 40 Pro"].savedName, "Mate 40 Pro 1")
        }
    }

    TestCase {
        name: "NetworkSecurity"
        when: windowShown

        function test_securityKeyFor() {
            compare(Logic.securityKeyFor(""), "open")
            compare(Logic.securityKeyFor("--"), "open")
            compare(Logic.securityKeyFor("OPEN"), "open")
            compare(Logic.securityKeyFor("WPA2"), "wpa-psk")
            compare(Logic.securityKeyFor("WPA1 WPA2"), "wpa-psk")
            compare(Logic.securityKeyFor("WPA2 WPA3"), "wpa-psk")
            compare(Logic.securityKeyFor("SAE"), "sae")
            compare(Logic.securityKeyFor("WEP"), "wep")
        }

        function test_isEnterprise() {
            verify(Logic.isEnterprise("WPA2 802.1X"))
            verify(Logic.isEnterprise("WPA2 ENT"))
            verify(Logic.isEnterprise("WPA2 EAP"))
            verify(!Logic.isEnterprise("WPA2 WPA3"))
            verify(!Logic.isEnterprise(""))
            verify(!Logic.isEnterprise(undefined))
        }

        function test_isEnterpriseKeyMgmt() {
            verify(Logic.isEnterpriseKeyMgmt("802-1x"))
            verify(Logic.isEnterpriseKeyMgmt("wpa-eap"))
            verify(!Logic.isEnterpriseKeyMgmt("wpa-psk"))
            verify(!Logic.isEnterpriseKeyMgmt(""))
        }

        function test_isSecured() {
            verify(Logic.isSecured("WPA2"))
            verify(Logic.isSecured("WPA2 WPA3"))
            verify(!Logic.isSecured("--"))
            verify(!Logic.isSecured(""))
            verify(!Logic.isSecured("open"))
            verify(!Logic.isSecured(undefined))
        }
    }

    TestCase {
        name: "NetworkConnectPlan"
        when: windowShown

        function test_planActivatesSavedProfile() {
            compare(Logic.connectPlan({ uuid: "u", name: "n" }, false), "activate")
        }

        function test_planModifiesSavedProfileWithRetypedSecret() {
            compare(Logic.connectPlan({ uuid: "u", name: "n" }, true), "modify")
        }

        function test_planCreatesForUnknownNetwork() {
            compare(Logic.connectPlan(null, false), "create")
            compare(Logic.connectPlan(null, true), "create")
        }

        function test_activateArgsTargetsUuid() {
            // By uuid, never by name: a " 1" suffixed name is the real profile.
            var args = Logic.activateArgs("uuid-a", "wlo1")
            compare(args.join(" "), "connection up uuid uuid-a ifname wlo1")
        }

        function test_modifyArgsKeepsKeyMgmt() {
            // Forcing key-mgmt to wpa-psk would downgrade a WPA3 (SAE) profile.
            var args = Logic.modifyArgs("uuid-a", "hunter2")
            compare(args.join(" "),
                "connection modify uuid uuid-a 802-11-wireless-security.psk hunter2")
        }

        function test_createArgsCarriesEveryInput() {
            compare(Logic.createArgs("Cafe", "pw", true, "wlo1").join(" "),
                "device wifi connect Cafe password pw hidden yes ifname wlo1")
            compare(Logic.createArgs("OpenNet", "", false, "").join(" "),
                "device wifi connect OpenNet")
        }
    }

    TestCase {
        name: "NetworkErrorMessages"
        when: windowShown

        // nmcli runs under LC_ALL=C in the service, so these needles are the
        // English strings it actually emits.
        function test_classifyCredentialFailure() {
            compare(Logic.classifyConnectError(
                "Error: Connection activation failed: Secrets were required, but not provided."),
            "Incorrect password")
            compare(Logic.classifyConnectError("Error: 4-IP address already assigned"),
            "4-IP address already assigned", "unmatched reasons pass through verbatim")
        }

        function test_classifyEnterprise() {
            compare(Logic.classifyConnectError(
                "Error: Connection activation failed: 802.1X supplicant took too long to respond."),
            "Enterprise (EAP) network — not supported")
        }

        function test_classifyMissingNetwork() {
            compare(Logic.classifyConnectError("Error: No network with SSID 'ZZZ' found."),
            "Network not found")
        }

        function test_classifyTimeout() {
            compare(Logic.classifyConnectError("Error: Connection activation timed out"),
            "Connection timeout")
        }

        function test_classifyUnknownConnection() {
            compare(Logic.classifyConnectError("Error: unknown connection 'MIFI-D9AD'."),
            "Saved profile is gone")
        }

        function test_classifySkipsWarningLines() {
            compare(Logic.classifyConnectError(
                "Warning: password for '802-11-wireless-security.psk' not given in 'passwd-file'\n"
                + "Error: Connection activation failed: No key available."),
            "Incorrect password")
        }

        function test_classifyTruncatesLongReason() {
            var message = Logic.classifyConnectError(
                "Error: " + new Array(200).join("x"))
            verify(message.length <= 72, "long reasons are trimmed, got " + message.length)
        }

        function test_classifyEmptyFallsBack() {
            compare(Logic.classifyConnectError(""), "Connection failed")
            compare(Logic.classifyConnectError("   "), "Connection failed")
        }

        function test_isCredentialFailure() {
            verify(Logic.isCredentialFailure("Incorrect password"))
            verify(!Logic.isCredentialFailure("Network not found"))
            verify(!Logic.isCredentialFailure(""))
        }
    }

    TestCase {
        name: "NetworkSignal"
        when: windowShown

        function test_signalLabelLadder() {
            compare(Logic.signalLabel(100), "Excellent")
            compare(Logic.signalLabel(80), "Excellent")
            compare(Logic.signalLabel(60), "Good")
            compare(Logic.signalLabel(35), "Fair")
            compare(Logic.signalLabel(15), "Poor")
            compare(Logic.signalLabel(0), "Weak")
        }

        function test_signalIconLadderIsMonotonic() {
            var rungs = [95, 70, 45, 20, 5].map(function (s) { return Logic.signalIcon(s, false, "full") })
            for (var i = 1; i < rungs.length; i++)
                verify(rungs[i] !== rungs[i - 1], "rung " + i + " repeats the previous glyph")
        }

        function test_signalIconFlagsLimitedConnectivity() {
            compare(Logic.signalIcon(90, true, "limited"), "")
            compare(Logic.signalIcon(90, true, "portal"), "")
            compare(Logic.signalIcon(90, true, "full"), Logic.signalIcon(90, false, "full"))
        }
    }
}
